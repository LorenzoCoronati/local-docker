#!/usr/bin/env bash
# File
#
# This file contains init -command for local-docker script ld.sh.

function ld_command_init_exec() {

    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo  -e "${BBlack}What is the project name?${Color_Off}"
        echo  "Provide a string without spaces and use chars a-z and 0-9."
        PROJECT_NAME=$(basename $PROJECT_ROOT)
        read -p "Project name ['$PROJECT_NAME']: " ANSWER
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [[ "$ANSWER" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]; then
            PROJECT_NAME=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-).${Color_Off}"
            echo -e "${Red}ERROR: Also the project name must not start or end with underscore or hyphen.${Color_Off}"
            sleep 2
            echo
        fi
    done;
    # Remove spaces.
    PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[[:space:]]/-/g')

    ensure_envvar_present PROJECT_NAME $PROJECT_NAME

    echo  -e "${BBlack}What is the local development domain?${Color_Off}"
    echo  " Do not add protocol, but just the domain name. For clarity it is recommended to use specified domains locally."
    read -p "Domain [$PROJECT_NAME.ld] " LOCAL_DOMAIN
    case "$LOCAL_DOMAIN" in
        '') LOCAL_DOMAIN="$PROJECT_NAME.ld"
    esac
    # Remove spaces.
    LOCAL_DOMAIN=$(echo "$LOCAL_DOMAIN" | sed 's/[[:space:]]/./g')
    ensure_envvar_present LOCAL_DOMAIN $LOCAL_DOMAIN

    echo  -e "${BBlack}What is the local development IP address?${Color_Off}"
    echo  "Random 10.10.0.0./16 will be generated for you if you so wish?"
    read -p "Use the random IP address 10.10.0.0./16 [Y/n]? " LOCAL_IP
    case "$LOCAL_IP" in
        'n'|'N'|'no'|'NO') LOCAL_IP='127.0.0.1';;
        *) LOCAL_IP=$( printf "10.10.%d.%d\n" "$((RANDOM % 256))" "$((RANDOM % 256))");;
    esac
    echo -e "${Yellow}Using IP address $LOCAL_IP.${Color_Off}"
    ensure_envvar_present LOCAL_IP $LOCAL_IP

    # 2nd param, project type.
    TYPE=${1-'common'}
    # Suggest Skeleton cleanup only when it is relevant.
    if [ -e "$DOCKERSYNC_FILE" ] || [ -e "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${BYellow}WARNING: There is docker-compose and/or docker-sync recipies in project root.${Color_Off}"
        echo -e "${BYellow}If you continue your containers with their volumes ${BRed}will be destroyed.${Color_Off}"
        echo -e "However it this does not delete code from your application root directory."
        read -p "Continue? [y/N]" CHOICE
        case "$CHOICE" in
            n|N|'no'|'NO' ) echo "Cancelled." && exit;;
        esac
    fi

    echo "Setting up docker-compose and docker-sync files for project type '$TYPE'."
    yml_move $TYPE

    # Skeleton uses different folder as the main location for app code.
    [[ "$TYPE" == "skeleton" ]] &&  APP_ROOT='drupal'

    APP_ROOT=${APP_ROOT:-app}
    ensure_envvar_present APP_ROOT $APP_ROOT
    ensure_folders_present $APP_ROOT
    echo -e "${Yellow}NOTE: Application root is in $APP_ROOT.${Color_Off}"

    DATABASE_DUMP_STORAGE=${DATABASE_DUMP_STORAGE:-db_dumps}
    ensure_envvar_present DATABASE_DUMP_STORAGE $DATABASE_DUMP_STORAGE
    ensure_folders_present $DATABASE_DUMP_STORAGE
    echo -e "${Yellow}Database dumps will appear in $DATABASE_DUMP_STORAGE.${Color_Off}"

    read -p "Use project-name based docker-sync -volumes ['${PROJECT_NAME}-*']? [Y/n]" CHOICE
    case "$CHOICE" in
        ''|y|Y|'yes'|'YES' ) $SCRIPT_NAME rename-volumes $PROJECT_NAME;;
        *) echo "Volume names will start with 'webroot-'";;
    esac

    if [[ "$(docker-compose -f $DOCKER_COMPOSE_FILE ps)" ]]; then
        echo "Turning off current container stack."
        docker-compose -f $DOCKER_COMPOSE_FILE down
    fi
    if is_dockersync; then
        docker-sync clean
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
        echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$CLEAN_ROOT\"${Color_Off}"
        docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$CLEAN_ROOT"
    fi

    # Use verbose output on this composer command.
    COMPOSER_INIT="composer -vv create-project drupal-composer/drupal-project:8.x-dev /var/www --no-interaction --stability=dev"
    echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$COMPOSER_INIT\"${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$COMPOSER_INIT"
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo -e "${Red}ERROR: Something went wrong when initializing the codebase.${Color_Off}"
        echo -e "${Red}Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.${Color_Off}"
        cd $CWD
        exit 1
    fi
    echo
    echo echo -e "${Green}Project created to ./$APP_ROOT -folder (/var/www in containers).${Color_Off}"
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
    echo-e "${Yellow}NOTE: Once Drupal is installed, you should remove write perms in sites/default -folder:${Color_Off}"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0755 web/sites/default'"
    echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0644 web/sites/default/settings.php'"
    echo "With these changes you can edit settings.php from host, but Drupal is happy not to be allowed to write there."
    echo
    echo -e "${BGreen}Happy coding!${Color_Off}"
}

function ld_command_init_help() {
    echo "Builds the project (default: codebase in./app -folder, use composer, use drupal-project)"
}
