#!/usr/bin/env bash

# 1st param, The Command.
ACTION=${1-'help'}

# Use fixed name, since docker-sync is supposed to be locally only.
DOCKERSYNC_FILE="./docker-sync.yml"
DOCKER_COMPOSER_FILE='docker-compose.yml';

CWD=$(pwd)
DOCKER_PROJECT=$(basename $CWD)

# DB container name, ie. the container key that holds mysql/mariadb.
CONTAINER_DB='db';
CONTAINER_PHP='php';

# This is one of the reasons to NEVER use the local-docker publicly:
MYSQL_ROOT_PASSWORD=root_password

DATE=$(date +%Y-%m-%d--%H-%I-%S)
RESTORE_INFO="mysql --host db -uroot  -p"$MYSQL_ROOT_PASSWORD" -e 'show databases'"
USERS="mysql --host db -uroot  -p"$MYSQL_ROOT_PASSWORD" -D mysql -e \"SELECT User, Host from mysql.user WHERE User NOT LIKE 'mysql%';\""

# Use fixed name, since docker-sync is supposed to be locally only.
DOCKERSYNC_FILE="./docker-sync.yml"

CWD=$(pwd)
DOCKER_PROJECT=$(basename $CWD)

# Get current script name, and use a symlink if it exists.
if [ ! -L "$( basename "$0" .sh)" ]; then
    SCRIPT_NAME="./"$( basename "$0")
else
    SCRIPT_NAME="./"$( basename "$0" .sh)
fi


if [ ! -f "$DOCKER_COMPOSER_FILE" ]; then
  echo "docker-compose file not present ($DOCKER_COMPOSER_FILE)"
  exit 1
fi


find_db_container() {
    TMP_NAME=$DOCKER_PROJECT"_"$CONTAINER_DB
    FOUND_NAME=$(docker ps  | grep "$TMP_NAME" | sed 's/.*\ //' )
    if [ -z "$FOUND_NAME" ]; then
        echo ''
    fi
    echo $FOUND_NAME;
}

is_dockersync() {
    if [ -z "$(which docker-sync)" ] || [ ! -f "$DOCKERSYNC_FILE" ]; then
        echo 0
    fi
    echo 1
}

IS_DOCKERSYNC=$(is_dockersync)

db_connect() {
  CONTAINER_DB_ID=$(find_db_container)
  RESPONSE=0
  ROUND=0
  ROUNDS_MAX=30
  RET='-'
  if [ -z "$CONTAINER_DB_ID" ]; then
    echo "DB container not running (or not yet created)."
    exit 1
  else
    echo "Connecting to DB container ($CONTAINER_DB_ID), please wait..."
  fi

  while [ "$RESPONSE" -eq "0" ]; do
    ROUND=$(( $ROUND + 1 ))
    RESPONSE=$(docker exec $CONTAINER_DB_ID sh -c '/usr/bin/mysqladmin -uroot -proot_password status 2>/dev/null |wc -l ')
    if [ "$RESPONSE" -ne "0" ]; then
      RET=0
      break;
    elif [ "$ROUND" -ge  "$ROUNDS_MAX" ]; then
      echo "DB container did not respond in due time."
      RET=1
      break;
    else
      echo "Please wait, trying ($ROUND/$ROUNDS_MAX)..."
      sleep 1
    fi
  done

  return $RET
}

# Cross-OS way to do in-place find-and-replace with sed.
# Use: replace_in_file PATTERN FILENAME
replace_in_file () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}


case "$ACTION" in
"dump")
    db_connect
    CONN=$?
    if [ "$CONN" -ne "0" ]; then
        exit 1
    fi

  echo "Using datestamp: $DATE"
  DUMPER="mysqldump --host db -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --lock-all-tables --compress --flush-logs --flush-privileges  --dump-date --tz-utc --verbose"
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$DUMPER  2>/dev/null | gzip --fast -f > /var/db_dumps/db-container-dump-$DATE.sql.gz"
  cd $CWD/db_dumps
  ln -sf db-container-dump-$DATE.sql.gz db-container-dump-LATEST.sql.gz
  cd $CWD
  echo "DB backup in db_dumps/db-container-dump-$DATE.sql.gz"
  echo "DB backup symlink: db_dumps/db-container-dump-LATEST.sql.gz"
  ;;

"down")
  $SCRIPT_NAME dump
  CONN=$?
  if [ "$CONN" -ne "0" ]; then
    exit 1
  fi
  docker-compose -f $DOCKER_COMPOSER_FILE  down
  if [ "$IS_DOCKERSYNC" -eq "1" ]; then
    docker-sync clean
  fi
  ;;

"stop")
  echo "Stopping containers (volumes and content intact)"
  echo "No backup of database content created."
  docker-compose -f $DOCKER_COMPOSER_FILE stop
  if [ $IS_DOCKERSYNC -eq "1" ]; then
    docker-sync clean
  fi
  ;;

"restore")
    if [ ! -e "db_dumps/db-container-dump-LATEST.sql.gz" ]; then
        echo
        echo "********************************************************************************************"
        echo "** Dump file missing! Create a symlin to your DB backup file:                             **"
        echo "** ln -s PATH/TO/GZIPPED/MYSQLDUMP/FILE.sql.gz ./db_dumps/db-container-dump-LATEST.sql.gz **"
        echo "********************************************************************************************"
        exit 1
    fi

    db_connect
    CONN=$?

    if [ "$CONN" -ne 0 ]; then
        echo "Oww... DB container is not up, even after a few retries. Exiting..."
        exit 2
    fi

    echo "Restoring state with DB dump."

  echo
  echo 'Databases *before* the restore:'
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo
  echo 'Restoring db...'
  echo -n "DB backup used: db_dumps/db-container-dump-LATEST.sql.gz => "
  echo $(readlink db_dumps/db-container-dump-LATEST.sql.gz)
  echo "[This may take some time...]"
  RESTORER="gunzip < /var/db_dumps/db-container-dump-LATEST.sql.gz | mysql --host db -uroot -p"$MYSQL_ROOT_PASSWORD""
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$RESTORER 2>/dev/null"
  echo
  echo 'Databases after the restore:'
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo 'Users after the restore:'
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
  ;;

"up")
  if [ "$IS_DOCKERSYNC" -eq "1" ]; then
    docker-sync start
  fi
  docker-compose -f $DOCKER_COMPOSER_FILE up -d
  OK=$?
  if [ "$OK" -ne "0" ]; then
    echo 'Something went wrong when bringing the project back."
    echo "Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.'
    exit 1
  fi

  db_connect
  CONN=$?

  if [ "$CONN" -ne 0 ]; then
    echo "Oww... DB container is not up, even after a few retries."
    exit 1
  fi

  echo
  echo 'Current databases:'
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo 'Current database users:'
  docker-compose -f $DOCKER_COMPOSER_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
  echo 'No DB content restoration done.'
  echo 'In case you need to do that (Drupal DB is gone?),'
  echo '1) check your symlink target in db_dumps/db-container-dump-LATEST.sql.gz'
  echo '2) execute the following command:'
  echo $SCRIPT_NAME restore
  ;;

"rebuild")
    $SCRIPT_NAME down 2&>/dev/null
    # Return value is not important here.
    docker-compose -f $DOCKER_COMPOSER_FILE build
    $SCRIPT_NAME up
    $SCRIPT_NAME restore
    ;;

"nuke-volumes")
    echo " "
    echo " *************************"
    echo " ******   WARNING ********"
    echo " *************************"
    echo " "
    echo " ALL volumes localbase* will be destroyed permanently in 5 secs."
    WAIT=5
    while [ $WAIT -gt 0 ]; do
        echo -n "$WAIT ... "
        ((WAIT--))
        sleep 1
    done
    echo
    docker-compose -f $DOCKER_COMPOSER_FILE down
    if [ "$IS_DOCKERSYNC" -eq "1" ]; then
        docker-sync clean
    fi
    for VOL in $(docker volume ls --filter="name=localbase*" -q); do
        echo "Handling volume: $VOL"
        for CONT in $(docker ps --filter volume=$VOL -q); do
            echo "Kill container : $CONT "
            docker -v kill $CONT
        done
        echo "Removing volume: $VOL"
        docker -v volume rm -f $VOL
    done
    ;;

"init")
    # Suggest Skeleton cleanup only when it is relevant.
    if [ -e "docker-sync.skeleton.yml" ] || [ -e "docker-compose.skeleton.yml" ]; then
        read -p "Is this a Skeleton -project? (y/n)" CHOISE
        case "$CHOISE" in
            y|Y ) $SCRIPT_NAME skeleton-switch;;
            n|N ) $SCRIPT_NAME skeleton-cleanup;;
            * ) echo "ERROR: Unclear answer, exiting" && exit;;
        esac
        read -p "Use project-name based docker-sync -volumes (recommended)? (y/n)" CHOISE
        case "$CHOISE" in
            y|Y ) $SCRIPT_NAME rename-volumes;;
        esac
    fi

    if [ -e "drupal/comopser.json" ]; then
      echo 'Looks like project is already created? File drupal/composer.json exists.'
      echo 'Maybe you should install composer codebase instead:'
      echo $SCRIPT_NAME composer install
      exit 1
    fi
    echo
    sleep 3
    echo 'Installing Drupal project, please wait...'
    sleep 1
    if [ "$IS_DOCKERSYNC" -eq "1" ]; then
        docker-sync start
    fi
    # Use verbose output on this composer command.
    TMP_FOLDER=/tmp/composer_temp_$(date +%s)
    COMPOSER_INIT="composer -vv create-project drupal-composer/drupal-project:8.x-dev $TMP_FOLDER --no-interaction --stability=dev"
    COMPOSER_MOVE="cp -rf $TMP_FOLDER/* /var/www"
    COMPOSER_CLEAN="rm -rf $TMP_FOLDER"
    docker-compose -f $DOCKER_COMPOSER_FILE up -d php
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo 'Something went wrong when bringing the project back."
        echo "Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.'
        exit 1
    fi

    echo "Next: $COMPOSER_INIT"
    echo "Then: $COMPOSER_MOVE"
    echo "Finally: $COMPOSER_CLEAN"
    docker-compose -f $DOCKER_COMPOSER_FILE exec php bash -c "$COMPOSER_INIT; $COMPOSER_MOVE; $COMPOSER_CLEAN"
    echo "============="
    echo "Project created and copied to /var/www"
    echo "============="
    echo "Creating some folder to project created and copied to /var/www"
    docker-compose -f $DOCKER_COMPOSER_FILE exec php bash -c 'mkdir -vp ./web/modules/custom && mkdir -vp ./web/themes/custom'
    docker-compose -f $DOCKER_COMPOSER_FILE exec php bash -c 'echo > ./web/modules/custom/.gitkeep'
    docker-compose -f $DOCKER_COMPOSER_FILE exec php bash -c 'echo > ./web/themes/custom/.gitkeep'
    echo 'Drupal 8 codebase built. Drupal is in ./drupal -folder, and public webroot in ./drupal/web/index.php.'
    sleep 1
    echo 'Happy coding!'
   ;;

"restart")
    $SCRIPT_NAME down
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo 'Putting local down failed. Database backup may have failed, so stopping process here.'
        exit 1
    fi
    $SCRIPT_NAME up
    $SCRIPT_NAME restore
    ;;

"composer")
    CONTAINER_PHP_ID=$CONTAINER_PHP
    if [ ! -z "$CONTAINER_PHP_ID" ]; then
        COMM="docker-compose exec ${CONTAINER_PHP} /usr/local/bin/composer -vv ${@:2}"
        echo "=========================================================="
        echo "COMMAND: $COMM"
        $COMM
    else
        echo "PHP container is not up"
    fi
    ;;

"rename-volumes")
    if [ $IS_DOCKERSYNC -eq "1" ]; then
        echo 'Turning off docker-sync, please wait...'
        docker-sync clean
    fi
    DEFAULT=$(basename $CWD)
    VALID=0
    while [ "$VALID" -eq "0" ]; do
        read -p "Please give me yoru project name ([ENTER]: \"$DEFAULT\")? " PROJECTNAME
        if [ -z "$PROJECTNAME" ]; then
            PROJECTNAME=$DEFAULT
            VALID=1
        elif [[ $PROJECTNAME =~ ^[0-9a-z\-\_]$ ]]; then
            VALID=1
        else
            echo 'ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-).'
            sleep 2
            echo
        fi
    done;

     echo "Renaming volumes to '$PROJECTNAME' for docker-sync, please wait..."
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKERSYNC_FILE
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKER_COMPOSER_FILE
     echo 'Done. You can now (re)start your project:'
     echo "$SCRIPT_NAME init - installs Drupal 8 codebase if not present"
     echo "$SCRIPT_NAME up - boots up this project"
    ;;

"skeleton-switch")
    echo "Replacing docker-sync.yml and docker-composer.yml with Skeleton -versions. This will overwrite any changes in your docker-sync.yml and docker-compose.yml."
    read -p "Continue (y/n)?" CHOISE
    case "$CHOISE" in
        y|Y ) echo "Continuing...please wait.";;
        n|N ) exit;;
        * ) exit;;
    esac
    if [ ! -f "docker-sync.skeleton.yml" ]; then
      echo "ERROR: Check that docker-sync.skeleton.yml file exists."
      exit;
    fi
    if [ ! -f "docker-compose.skeleton.yml" ]; then
      echo "ERROR: Check that docker-compose.skeleton.yml file exists."
      exit;
    fi
    rm -f docker-sync.yml 2>/dev/null
    rm -f docker-compose.yml 2>/dev/null
    mv docker-sync.skeleton.yml docker-sync.yml
    mv docker-compose.skeleton.yml docker-compose.yml
    echo "Done. Consider renaming your docker-sync volumes next:"
    echo "$SCRIPT_NAME rename-volumes"
    echo "Don't forget to ensure your database connection is configure properly (host should be 'db', database 'drupal', credentials 'drupal'/'drupal')"
    ;;

"skeleton-cleanup")
    echo "Removing docker-sync.skeleton.yml and docker-composer.skeleton.yml."
    read -p "Continue (y/n)?" CHOISE
    case "$CHOISE" in
        y|Y ) echo "Continuing...please wait.";;
        n|N ) exit;;
        * ) exit;;
    esac
    if [ -f "docker-sync.skeleton.yml" ]; then
      rm docker-sync.skeleton.yml
    fi
    if [ -f "docker-compose.skeleton.yml" ]; then
      rm docker-compose.skeleton.yml
    fi
    echo "Done. Consider renaming your docker-sync volumes next:"
    echo "$SCRIPT_NAME rename-volumes"
    ;;

*)
    echo "This is a simple script, aimed to help in developer's daily use of local environment."
    echo "If you have docker-sync installed and configuration present (docker-sync.yml) it controls that too."
    echo
    echo 'Usage:'
    echo "$SCRIPT_NAME [composer|down|dump|init|nuke-volumes|rebuild|restart|restore|stop|up]"
    echo
    echo " - composer: run composer command in PHP container (if up and running)"
    echo " - down: backups databases and removes containers & networks (stops docker-sync)"
    echo " - dump: backup databases to db_dump -folder"
    echo " - init: build project to ./drupal -folder, using composer and drupal-project"
    echo " - nuke-volumes: remove permanently synced volumes (NO BACKUPS!)"
    echo " - rebuild: runs DB backup, builds containers and starts with the restored DB backup (restarts docker-sync too)"
    echo " - restart: down, up and restore (restarts docker-sync too)"
    echo " - restore: import latest db. Database container must be running."
    echo " - rename-volumes: Rename your local-docker volumes (helps to avoid collisions with other projects)"
    echo " - skeleton-cleanup: remove config for Skeleton projects"
    echo " - skeleton-switch: switch config to Skeleton -based structure"
    echo " - stop: stops containers leaving them hanging around (stops docker-sync)"
    echo " - up: brings containers up (starts docker-sync)"
    exit 0
    ;;

esac

cd $CWD



