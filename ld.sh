#!/usr/bin/env bash

CWD=$(pwd)

PROJECT_ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
if [[ ! -d "$PROJECT_ROOT" ]]; then PROJECT_ROOT="$PWD"; fi

cd $PROJECT_ROOT

# Get colors.
. $PROJECT_ROOT/docker/scripts/ld.colors.sh

# Get functions.
. $PROJECT_ROOT/docker/scripts/ld.functions.sh

# 1st param, The Command.
ACTION=${1-'help'}

# Use fixed name, since docker-sync is supposed to be locally only.
DOCKERSYNC_FILE=docker-sync.yml
DOCKER_COMPOSE_FILE=docker-compose.yml
DOCKER_YML_STORAGE=$PROJECT_ROOT/docker
DOCKER_PROJECT=$(basename $PROJECT_ROOT)

import_root_env
ENV_IMPORT_FAILED=$?

DATE=$(date +%Y-%m-%d--%H-%I-%S)
RESTORE_INFO="mysql --host "$CONTAINER_DB" -uroot  -p"$MYSQL_ROOT_PASSWORD" -e 'show databases'"
USERS="mysql --host "$CONTAINER_DB" -uroot  -p"$MYSQL_ROOT_PASSWORD" -D mysql -e \"SELECT User, Host from mysql.user WHERE User NOT LIKE 'mysql%';\""

# Read (and create if necessary) the .env file, allowing overrides to any of our config values.
if [[ "$ACTION" != 'help' ]]; then
    if [[ "$ENV_IMPORT_FAILED" -ne "0" ]]; then
        if [ ! -f "$PROJECT_ROOT/.env.example" ]; then
            echo "Files .env.example are .env are missing. Please add either one to project root."
            echo "Then start over."
            cd $CWD
            exit 1
        fi
        sleep 2
        echo "Copying .env.example -file => .env. "
        sleep 2
        cp -f $PROJECT_ROOT/.env.example $PROJECT_ROOT/.env
        echo "Please review your .env file:"
        echo
        echo -e "${BIWhite}========  START OF .env =========${Color_Off}"
        sleep 1
        cat $PROJECT_ROOT/.env
        echo -e "${BIWhite}========  END OF .env =========${Color_Off}"
        echo
        read -p "Does this look okay? [Y/n] " CHOICE
        case "$CHOICE" in
            ''|y|Y|'yes'|'YES' ) import_root_env && echo "Cool, let's continue!" & echo ;;
            n|N|'no'|'NO' ) echo -e "Ok, we'll stop here. ${BYellow}Please edit .env file manually, and then continue.${Color_Off}" && exit 1 ;;
            * ) echo -e "${BRed}ERROR: Unclear answer, exiting.${Color_Off}" && cd $CWD && exit 2;;
        esac
    fi
fi

# Get current script name, and use a symlink if it exists.
if [ ! -L "$( basename "$0" .sh)" ]; then
    SCRIPT_NAME=$PROJECT_ROOT/$( basename "$0")
    SCRIPT_NAME_SHORT=./$( basename "$0")
else
    SCRIPT_NAME=$PROJECT_ROOT/$( basename "$0" .sh)
    SCRIPT_NAME_SHORT=./$( basename "$0" .sh)
fi

if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
    echo '$ACTION' is $ACTION
    if [[ "$ACTION" != 'init' ]] && [[ "$ACTION" != 'help' ]]; then
        echo "Starting to initialise local-docker, please wait..."
        $SCRIPT_NAME init
    fi
fi

if [ -z "$(which docker)" ]; then
  echo -e "${Red}Docker is not running. Docker is required to use local-docker.${Color_Off}"
  cd $CWD
  exit 1
fi

case "$ACTION" in
"init")
    # Suggest Skeleton cleanup only when it is relevant.
    APP_ROOT='app/'
    if [ ! -e "$DOCKERSYNC_FILE" ] || [ ! -e "$DOCKER_COMPOSE_FILE" ]; then
        echo "Copying Docker compose/sync files. What is project type? "
        echo " [0] New project, application built in ./$APP_ROOT -folder [default]"
        #echo " [1] Old project, application built in ./$APP_ROOT -folder "
        echo " [2] Skeleton -proejct. Drupal in drupal/ and custom code spread in src/ folder."
        read -p "Project type: " CHOICE
        case "$CHOICE" in
            ''|0|1 ) yml_move;;
            2 ) APP_ROOT='drupal/'; yml_move skeleton;;
            * ) echo "ERROR: Unclear answer, exiting" && cd $CWD && exit;;
        esac
        echo 'APP_ROOT='$APP_ROOT >> $PROJECT_ROOT/.env
        read -p "Use project-name based docker-sync -volumes [default]? [Y/n]" CHOICE
        case "$CHOICE" in
            ''|y|Y|'yes'|'YES' ) $SCRIPT_NAME rename-volumes;;
            n|N|'no'|'NO' ) echo "Volume names will start with 'webroot-'";;
        esac
    fi
    if [[ "$(docker-compose -f $DOCKER_COMPOSE_FILE ps)" ]]; then
        echo "Turning off current container stack."
        docker-compose -f $DOCKER_COMPOSE_FILE down
        echo 'ALL containers: stopped.'
    fi
    if is_dockersync; then
        docker-sync clean
        docker-sync start
    fi
    echo 'Starting PHP container only, to use it to build the codebase.'
    docker-compose -f $DOCKER_COMPOSE_FILE up -d php
    echo 'PHP container: started.'

    DELETE_ROOT=
    if [ -e "$APP_ROOT""composer.json" ]; then
      echo "Looks like project is already created? File "$APP_ROOT"composer.json exists."
      echo "Maybe you should install composer codebase instead:"
      echo "$SCRIPT_NAME_SHORT up && $SCRIPT_NAME_SHORT composer install"
      cd $CWD
      exit 1
    elif [ ! -d "$APP_ROOT" ]; then
      mkdir $APP_ROOT;
    fi
    echo "Verify application root can be used to install codebase (must be empty)..."
    APP_ROOT_FILES="ls -lha /var/www"
    echo "Next: $APP_ROOT_FILES"
    docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$APP_ROOT_FILES"
    echo "Currently on host $APP_ROOT:"
    ls -lha $APP_ROOT

    if [ "$(ls -A $APP_ROOT)" ]; then
      echo "Application root folder $APP_ROOT is not empty. Installation requires an empty folder. Currently there is: "
      ls -A $APP_ROOT
      read -p "WARNING: If you continue all of these will be deleted. Type 'PLEASE-DELETE' to continue: " CHOICE
      case "$CHOICE" in
          'PLEASE-DELETE' ) rm -rf $APP_ROOT && mkdir $APP_ROOT && DELETE_ROOT=1;;
          * ) echo "Clear the folder manually and start overm - or initialize codebase manually." && cd $CWD && exit;;
      esac
    fi

    echo
    echo 'Installing Drupal project, please wait...'
    echo "============="
    if [[ ! -z "$DELETE_ROOT" ]]; then
        echo "Clearing old things from the app root."
        CLEAN_ROOT="rm -rf /var/www/*"
        echo "Next: $CLEAN_ROOT"
        docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$CLEAN_ROOT"
    fi

    # Use verbose output on this composer command.
    COMPOSER_INIT="composer -vv create-project drupal-composer/drupal-project:8.x-dev /var/www --no-interaction --stability=dev"
    echo "Next: $COMPOSER_INIT"
    docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$COMPOSER_INIT"
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo "ERROR: Something went wrong when initializing the codebase."
        echo "Check that required ports are not allocated (by other containers or programs) and re-configure them if needed."
        cd $CWD
        exit 1
    fi
    echo "============="
    echo "Project created to ./$APP_ROOT -folder (/var/www in containers)"
    # This must be run after composer install.
    $SCRIPT_NAME drupal-structure-fix
    $SCRIPT_NAME drupal-files-folder-perms
    echo "Drupal 8 codebase built. Drupal is in ./$APP_ROOT -folder, and public webroot in ./$APP_ROOT/web/index.php."
    sleep 1
    echo 'Bringing the containers up now... Please wait.'
    $SCRIPT_NAME up
    sleep 1
    echo 'No errors, all good.'
    sleep 1
    echo
    echo "Codebase ready!!"
    echo
    echo "NOTE: Once Drupal is installed, you should remove write perms in sites/default -folder with:"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0755 web/sites/default'"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0644 web/sites/default/settings.php'"
    echo "With these changes you can edit settings.php from host, but Drupal is happy not to be allowed to write there."
    echo
    sleep 1
    echo 'Happy coding!'
   ;;

"up")
  if is_dockersync; then
    docker-sync start
  fi
  docker-compose -f $DOCKER_COMPOSE_FILE up -d
  $SCRIPT_NAME drupal-files-folder-perms
  OK=$?
  if [ "$OK" -ne "0" ]; then
    echo
    echo "ERROR: Something went wrong when bringing the project up."
    echo "Check that required ports are not allocated (by other containers or programs) and re-configure them if needed."
    cd $CWD
    exit 1
  fi

  db_connect
  CONN=$?

  if [ "$CONN" -ne 0 ]; then
    echo "Oww... DB container is not up, even after a few retries."
    cd $CWD
    exit 1
  fi

  echo
  echo 'Current databases:'
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo 'Current database users:'
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
  echo 'No DB content restoration done.'
  echo 'In case you need to do that (Drupal DB is gone?),'
  echo '1) check your symlink target in db_dumps/db-container-dump-LATEST.sql.gz'
  echo '2) execute the following command:'
  echo $SCRIPT_NAME_SHORT restore
  ;;

"down")
  $SCRIPT_NAME dump
  CONN=$?
  if [ "$CONN" -ne "0" ]; then
    cd $CWD
    exit 1
  fi
  docker-compose -f $DOCKER_COMPOSE_FILE  down
  if is_dockersync; then
    docker-sync clean
  fi
  ;;

"stop")
  echo "Stopping containers (volumes and content intact)"
  echo "No backup of database content created."
  docker-compose -f $DOCKER_COMPOSE_FILE stop
  if is_dockersync; then
    docker-sync stop
  fi
  ;;

"rebuild")
    $SCRIPT_NAME down 2&>/dev/null
    # Return value is not important here.
    docker-compose -f $DOCKER_COMPOSE_FILE build
    $SCRIPT_NAME up
    $SCRIPT_NAME restore
    ;;

"restart")
    $SCRIPT_NAME down
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo 'Putting local down failed. Database backup may have failed, so stopping process here.'
        cd $CWD
        exit 1
    fi
    $SCRIPT_NAME up
    $SCRIPT_NAME restore
    ;;

"dump")
    db_connect
    CONN=$?
    if [ "$CONN" -ne "0" ]; then
        cd $CWD
        exit 1
    fi

  echo "Using datestamp: $DATE"
  DUMPER="mysqldump --host "$CONTAINER_DB" -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --lock-all-tables --compress --flush-logs --flush-privileges  --dump-date --tz-utc --verbose"
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$DUMPER  2>/dev/null | gzip --fast -f > /var/db_dumps/db-container-dump-$DATE.sql.gz"
  cd $PROJECT_ROOT/db_dumps
  ln -sf db-container-dump-$DATE.sql.gz db-container-dump-LATEST.sql.gz
  cd $PROJECT_ROOT
  echo "DB backup in db_dumps/db-container-dump-$DATE.sql.gz"
  echo "DB backup symlink: db_dumps/db-container-dump-LATEST.sql.gz"
  ;;

"restore")
    if [ ! -e "db_dumps/db-container-dump-LATEST.sql.gz" ]; then
        echo
        echo "********************************************************************************************"
        echo "** Dump file missing! Create a symlin to your DB backup file:                             **"
        echo "** ln -s PATH/TO/GZIPPED/MYSQLDUMP/FILE.sql.gz ./db_dumps/db-container-dump-LATEST.sql.gz **"
        echo "********************************************************************************************"
        cd $CWD
        exit 1
    fi

    db_connect
    CONN=$?

    if [ "$CONN" -ne 0 ]; then
        echo "Oww... DB container is not up, even after a few retries. Exiting..."
        cd $CWD
        exit 2
    fi

    echo "Restoring state with DB dump."

  echo
  echo 'Databases *before* the restore:'
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo
  echo 'Restoring db...'
  echo -n "DB backup used: db_dumps/db-container-dump-LATEST.sql.gz => "
  echo $(readlink db_dumps/db-container-dump-LATEST.sql.gz)
  echo "[This may take some time...]"
  RESTORER="gunzip < /var/db_dumps/db-container-dump-LATEST.sql.gz | mysql --host "$CONTAINER_DB" -uroot -p"$MYSQL_ROOT_PASSWORD""
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORER 2>/dev/null"
  echo
  echo 'Databases after the restore:'
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
  echo 'Users after the restore:'
  docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
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

"drush")
    CONTAINER_PHP_ID=$CONTAINER_PHP
    if [ ! -z "$CONTAINER_PHP_ID" ]; then
        COMM="docker-compose exec ${CONTAINER_PHP} /var/www/vendor/drush/drush/drush ${@:2}"
        echo "=========================================================="
        echo "COMMAND: $COMM"
        $COMM
    else
        echo "PHP container is not up"
    fi
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
    docker-compose -f $DOCKER_COMPOSE_FILE down
    if is_dockersync; then
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

"drupal-structure-fix")
    echo "============="
    echo "Creating some folders to project below /var/www"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c '[[ ! -d "config/sync" ]] &&  mkdir -vp config/sync'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c '[[ ! -d "web/sites/default/files" ]] &&  mkdir -vp web/sites/default/files'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c '[[ ! -w "web/sites/default/files" ]] &&  chmod -r 0777 web/sites/default/files'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'if [ $(su -s /bin/sh www-data -c "test -w \"web/sites/default/files\"") ]; then echo "web/sites/default/files is writable - GREAT!"; else chmod -v a+wx web/sites/default/files; fi'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'if [ $(su -s /bin/sh www-data -c "test -w \"web/sites/default/settings.php\"") ]; then echo "web/sites/default/settings.php is writable - GREAT!"; else chmod -v a+w web/sites/default/settings.php; fi'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'mkdir -vp ./web/modules/custom && mkdir -vp ./web/themes/custom'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'echo > ./web/modules/custom/.gitkeep'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'echo > ./web/themes/custom/.gitkeep'
    ;;

"drupal-files-folder-perms")
    echo 'Restoring files directory ownership...'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c "chown -R www-data:www-data /var/www/web/sites/*/files"
    echo 'Restoring done.'
    ;;

"rename-volumes")
    if is_dockersync; then
        echo 'Turning off docker-sync, please wait...'
        docker-sync clean
    fi
    DEFAULT=$(basename $PROJECT_ROOT)
    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo "Please give me your project name [default: \"$DEFAULT\"]? "
        read -p "Project name: " PROJECTNAME
        if [ -z "$PROJECTNAME" ]; then
            PROJECTNAME=$DEFAULT
            VALID=1
        elif [[ "$PROJECTNAME" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]; then
            VALID=1
        else
            echo 'ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-).'
            echo 'ERROR: Also the project name must not start or end with underscore or hyphen.'
            sleep 2
            echo
        fi
    done;

     echo "Renaming volumes to '$PROJECTNAME' for docker-sync, please wait..."
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKERSYNC_FILE
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKER_COMPOSE_FILE
     echo 'Done. You can now (re)start your project:'
     echo "$SCRIPT_NAME_SHORT init - installs Drupal 8 codebase if not present"
     echo "$SCRIPT_NAME_SHORT up - boots up this project"
    ;;

*)
    echo "This is a simple script, aimed to help in developer's daily use of local environment."
    echo "If you have docker-sync installed and configuration present (docker-sync.yml) it controls that too."
    echo
    echo 'Usage:'
    echo "$SCRIPT_NAME_SHORT [composer|down|dump|init|nuke-volumes|rebuild|restart|restore|stop|up]"
    echo
    echo " - composer: run composer command in PHP container (if up and running)"
    echo " - down: backups databases and removes containers & networks (stops docker-sync)"
    echo " - drupal-files-folder-perms: ensure all Drupal sites files -dirs are writable"
    echo " - drush: run drush command in PHP container (if up and running)"
    echo " - dump: backup databases to db_dump -folder"
    echo " - init: build project to ./app -folder, using composer and drupal-project"
    echo " - nuke-volumes: remove permanently synced volumes (NO BACKUPS!)"
    echo " - rebuild: runs DB backup, builds containers and starts with the restored DB backup (restarts docker-sync too)"
    echo " - restart: down, up and restore (restarts docker-sync too)"
    echo " - restore: import latest db. Database container must be running."
    echo " - rename-volumes: Rename your local-docker volumes (helps to avoid collisions with other projects)"
    echo " - stop: stops containers leaving them hanging around (stops docker-sync)"
    echo " - up: brings containers up (starts docker-sync)"
    cd $CWD
    exit 0
    ;;

esac

cd $CWD
