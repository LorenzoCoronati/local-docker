#!/usr/bin/env bash
# File
#
# This file contains init -command for local-docker script ld.sh.

function ld_command_init_exec() {

    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo  -e "${BBlack}== Project name == ${Color_Off}"
        echo  "Provide a string without spaces and use chars a-z and 0-9, - and _ (no dots)."
        PROJECT_NAME=${PROJECT_NAME:-$(basename $PROJECT_ROOT)}
        read -p "Project name ['$PROJECT_NAME']: " ANSWER
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [[ "$ANSWER" =~  ^(([a-zA-Z0-9])([a-zA-Z0-9]*))?([a-zA-Z0-9])$ ]]; then
            PROJECT_NAME=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-).${Color_Off}"
            echo -e "${Red}ERROR: Also the project name must not start or end with underscore or hyphen.${Color_Off}"
            sleep 2
            echo
        fi
    done
    # Remove spaces.
    PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[[:space:]]/-/g')

    define_configuration_value PROJECT_NAME $PROJECT_NAME

    VALID=0
    while [ "$VALID" -eq "0" ]; do
      echo  -e "${BBlack}== Local development base domain == ${Color_Off}"
      echo -e "Do not add protocol nor www -part but just the domain name. It is recommended to use domain ending with ${BBlack}.ld${Black}.${Color_Off}"
      LOCAL_DOMAIN=${LOCAL_DOMAIN:-${$PROJECT_NAME}.ld}
      read -p "Domain [$LOCAL_DOMAIN] " ANSWER
      TEST=$(echo $ANSWER | egrep -e '^(([a-zA-Z0-9])([a-zA-Z0-9\.]*))?([a-zA-Z0-9])$')
      if [ -z "$ANSWER" ]; then
          VALID=1
      elif [ "${#TEST}" -gt 0 ]; then
          LOCAL_DOMAIN=$ANSWER
          VALID=1
      else
          echo -e "${Red}ERROR: Domain name can contain only alphabetic characters (a-z), numbers (0-9), hyphens (-), underscoreds (_) and dots (.).${Color_Off}"
          echo -e "${Red}ERROR: Also the domain name must not start or end with underscore, hyphen or dot.${Color_Off}"
          sleep 2
          echo
      fi
    done
    # Remove spaces.
    LOCAL_DOMAIN=$(echo "$LOCAL_DOMAIN" | sed 's/[[:space:]]/./g')
    echo "LOCAL_DOMAIN is '$LOCAL_DOMAIN' (${#LOCAL_DOMAIN})"
    define_configuration_value LOCAL_DOMAIN $LOCAL_DOMAIN
    echo "Default URL for drush operations is http://www.$LOCAL_DOMAIN"
    define_configuration_value DRUSH_OPTIONS_URI "http://www."$LOCAL_DOMAIN

    echo -e "${BBlack}== Local development IP address ==${Color_Off}"
    echo "Random 127.0.0.0./16 will be generated for you if you so wish?"
    read -p "Use the random IP address 127.0.0.0./16 [Y/n]? " LOCAL_IP
    case "$LOCAL_IP" in
        'n'|'N'|'no'|'NO') LOCAL_IP='127.0.0.1';;
        *) LAST=$((RANDOM % 240 + 3 )) && LOCAL_IP=$( printf "127.0.%d.%d\n" "$((RANDOM % 256))" "$LAST");;
    esac
    echo -e "${Yellow}Using IP address $LOCAL_IP.${Color_Off}"
    define_configuration_value LOCAL_IP $LOCAL_IP

    # 2nd param, project type.
    TYPE=${1-'common'}
    # Suggest Skeleton cleanup only when it is relevant.
    if [ -e "$DOCKERSYNC_FILE" ] || [ -e "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${BYellow}WARNING: There is docker-compose and/or docker-sync recipies in project root.${Color_Off}"
        echo -e "${BYellow}If you continue your containers with their volumes ${BRed}will be destroyed.${Color_Off}"
        echo -e "This does not delete your application root directory, but ${BYellow}database volumes will be destroyed.${Color_Off}"
        read -p "Continue? [y/N]" CHOICE
        case "$CHOICE" in
            n|N|'no'|'NO' ) echo "Cancelled." && exit;;
        esac
    fi

    echo "Setting up docker-compose and docker-sync files for project type '$TYPE'."

    # Skeleton uses different folder as the main location for app code.
    [[ "$TYPE" == "skeleton" ]] &&  APP_ROOT='drupal'
    [[ "$TYPE" == "ddev" ]] &&  APP_ROOT='.' && TYPE="common"

    yml_move $TYPE
    if [ "$?" -eq "1" ]; then
      echo -e "${Red}Trying to use yml files without project type.${Color_Off}"
      return 1
    fi

    APP_ROOT=${APP_ROOT:-app}
    define_configuration_value APP_ROOT $APP_ROOT
    ensure_folders_present $APP_ROOT
    echo -e "${BYellow}Application root is in $APP_ROOT.${Color_Off}"

    DATABASE_DUMP_STORAGE=${DATABASE_DUMP_STORAGE:-db_dumps}
    define_configuration_value DATABASE_DUMP_STORAGE $DATABASE_DUMP_STORAGE
    ensure_folders_present $DATABASE_DUMP_STORAGE
    echo -e "${BYellow}Database dumps will be placed in $DATABASE_DUMP_STORAGE.${Color_Off}"
    if [[ "$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q)" ]]; then
        echo "Turning off current container stack."
        docker-compose -f $DOCKER_COMPOSE_FILE down 2> /dev/null
    fi
    if is_dockersync; then
        [ "$LD_VERBOSE" -ge "1" ] && echo 'Turning off docker-sync (clean), please wait...'
        docker-sync clean
    fi

    $SCRIPT_NAME rename-volumes $PROJECT_NAME

    if is_dockersync; then
        [ "$LD_VERBOSE" -ge "1" ] && echo "Starting docker-sync, please wait..."
        docker-sync start
    fi

    echo 'Starting PHP container only, to use it to build the codebase.'
    docker-compose -f $DOCKER_COMPOSE_FILE up -d php
    echo 'PHP container: started.'

    DELETE_ROOT=
    if [ -e "${APP_ROOT}/composer.json" ]; then
        echo -e "${Yellow}Looks like project is already created? File "$APP_ROOT"/composer.json exists.${Color_Off}"
        echo -e "${Yellow}Maybe you should install codebase using composer:${Color_Off}"
        echo -e "${Yellow}$SCRIPT_NAME_SHORT up && $SCRIPT_NAME_SHORT composer install${Color_Off}"
        cd $CWD
        exit 1
    elif [ ! -d "$APP_ROOT" ]; then
        mkdir $APP_ROOT;
    fi
    echo "Verify application root can be used to install codebase (must be empty)..."
    APP_ROOT_FILES="ls -lha /var/www"
    docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$APP_ROOT_FILES"

    if [ "$(ls -A $APP_ROOT)" ]; then
        echo "Application root folder $APP_ROOT is not empty. Installation requires an empty folder. Currently there is: "
        ls -A $APP_ROOT
        echo -en "${Red}WARNING: If you continue all of these will be deleted. ${Color_Off}"
        read -p "Type 'PLEASE-DELETE' to continue: " CHOICE
        case "$CHOICE" in
            'PLEASE-DELETE' ) rm -rf $APP_ROOT && mkdir $APP_ROOT && DELETE_ROOT=1;;
            * ) echo -en "${Red}Clear the folder manually and start overm - or initialize codebase manually.${Color_Off}" && cd $CWD && exit;;
        esac
    fi

    echo
    echo 'Installing Drupal project, please wait...'
    echo
    if [[ ! -z "$DELETE_ROOT" ]]; then
        echo "Clearing old things from the app root."
        CLEAN_ROOT="rm -rf /var/www/*"
        [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$CLEAN_ROOT\"${Color_Off}"
        docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$CLEAN_ROOT"
    fi

    # Use verbose output on this composer command.
    COMPOSER_INIT="composer -vv create-project drupal-composer/drupal-project:8.x-dev /var/www --no-interaction --stability=dev"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$COMPOSER_INIT\"${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$COMPOSER_INIT"
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo -e "${Red}ERROR: Something went wrong when initializing the codebase.${Color_Off}"
        echo -e "${Red}Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.${Color_Off}"
        cd $CWD
        exit 1
    fi
    echo
    echo -e "${Green}Project created to ./$APP_ROOT -folder (/var/www in containers).${Color_Off}"
    # This must be run after composer install.
    $SCRIPT_NAME drupal-structure-fix
    $SCRIPT_NAME drupal-files-folder-perms
    echo -e "${Green}Drupal 8 codebase built. Drupal is in ./$APP_ROOT -folder, and public webroot in ./$APP_ROOT/web/index.php.${Color_Off}"
    echo
    echo 'Bringing the containers up now... Please wait.'
    $SCRIPT_NAME up
    echo
    echo -e "${Green}Codebase ready!!${Color_Off}"
    echo
    echo -e "${Yellow}NOTE: Once Drupal is installed, you should remove write perms in sites/default -folder:${Color_Off}"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0755 web/sites/default'"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0644 web/sites/default/settings.php'"
    echo "With these changes you can edit settings.php from host, but Drupal is happy not to be allowed to write there."
    echo
    echo -e "${BGreen}Happy coding!${Color_Off}"
}

function ld_command_init_help() {
    echo "Builds the project (default: codebase in./app -folder, use composer, use drupal-project)"
}
