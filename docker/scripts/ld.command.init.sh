#!/usr/bin/env bash
# File
#
# This file contains init -command for local-docker script ld.sh.

function ld_command_init_exec() {
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
        echo -e "${Yellow}Looks like project is already created? File "$APP_ROOT"composer.json exists.${Color_Off}"
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
    echo "Builds project to ./app -folder, using composer and drupal-project (default)"
}
