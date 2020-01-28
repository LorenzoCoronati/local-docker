#!/usr/bin/env bash
# File
#
# This file contains init -command for local-docker script ld.sh.

function ld_command_init_exec() {

    if ! project_config_file_check; then
        echo -e "${BRed}This project is already initialized. ${Color_Off}"
        echo -e "${Yellow}Are you really sure you want to re-initialize the project? ${Color_Off}"
        read -p "[yes/NO] " ANSWER
        case "$ANSWER" in
            'y'|'yes')
                echo -e "${Green}Sure, thanks for the confirmation.${Color_Off}"
                ;;
            *)
              echo -e "${BRed}Initialization cancelled.${Color_Off}"
              return;
              ;;
        esac
    fi

    # Project type, defaults to common.
    TYPE=${1:-'common'}
    # Read all template files available for whitelist
    WHITELIST_TYPES=$(find ./docker -maxdepth 1 -name 'docker-compose.*.yml' | cut -d'/' -f3 | cut -d'.' -f2 | xargs)
    if [[ " ${WHITELIST_TYPES[@]} " != *" $TYPE "* ]]; then
        echo
        echo -e "${Red}The requested template ${BRed}\"$TYPE\"${Red} is not available.. ${Color_Off}"
        echo -e "${Yellow}Available templates include: ${WHITELIST_TYPES[@]}. ${Color_Off}"
        echo
        exit 1
    fi


    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo
        echo  -e "${BBlack}== Project name == ${Color_Off}"
        echo  "Provide a string without spaces and use chars a-z, 0-9, - and _ (no dots)."
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
    echo -e "${BYellow}Project name is: $PROJECT_NAME.${Color_Off}"

    VALID=0
    while [ "$VALID" -eq "0" ]; do
      echo
      echo  -e "${BBlack}== Local development base domain == ${Color_Off}"
      echo -e "Do not add protocol nor www -part but just the domain name. It is recommended to use domain ending with ${BBlack}.ld${Black}.${Color_Off}"
      DEFAULT=${PROJECT_NAME}.ld
      LOCAL_DOMAIN=${LOCAL_DOMAIN:-${DEFAULT}}
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
    define_configuration_value LOCAL_DOMAIN $LOCAL_DOMAIN
    echo -e "${BYellow}Local develoment domain is: $LOCAL_DOMAIN.${Color_Off}"
    define_configuration_value DRUSH_OPTIONS_URI "http://www."$LOCAL_DOMAIN
    echo -e "${BYellow}Default URL for drush is: $DRUSH_OPTIONS_URI.${Color_Off}"

    echo
    echo -e "${BBlack}== Local development IP address ==${Color_Off}"
    echo "Random 127.0.0.0./16 will be generated for you if you so wish?"
    read -p "Use the random IP address 127.0.0.0./16 [Y/n]? " LOCAL_IP
    case "$LOCAL_IP" in
        'n'|'N'|'no'|'NO') LOCAL_IP='127.0.0.1';;
        *) LAST=$((RANDOM % 240 + 3 )) && LOCAL_IP=$( printf "127.0.%d.%d\n" "$((RANDOM % 256))" "$LAST");;
    esac
    define_configuration_value LOCAL_IP $LOCAL_IP
    echo -e "${BYellow}IP address is: $LOCAL_IP.${Color_Off}"

    echo
    echo -e "${BBlack}== PHP version ==${Color_Off}"
    while [ -z "$PROJECT_PHP_VERSION" ]; do
        echo "What is the PHP version to use?"
        echo "Options:"
        echo " [1] - PHP 7.1"
        echo " [2] - PHP 7.2"
        echo " [3] - PHP 7.3 (default)"
        read -p "Selected version: " VERSION
        case "$VERSION" in
            ''|'3'|3) PROJECT_PHP_VERSION='7.3';;
            '2'|2) PROJECT_PHP_VERSION='7.2';;
            '1'|1) PROJECT_PHP_VERSION='7.1';;
            *) echo -e "${Red}ERROR: PHP version selection failed. Please use the available options.${Color_Off}"
        esac
    done
    define_configuration_value PROJECT_PHP_VERSION $PROJECT_PHP_VERSION
    echo -e "${BYellow}Using PHP version: $PROJECT_PHP_VERSION.${Color_Off}"

    # Suggest Skeleton cleanup only when it is relevant.
    if [ -e "$DOCKERSYNC_FILE" ] || [ -e "$DOCKER_COMPOSE_FILE" ]; then
        echo -e "${BYellow}WARNING: There is docker-compose and/or docker-sync recipies in project root.${Color_Off}"
        echo -e "${BYellow}If you continue your containers with their volumes ${BRed}will be destroyed.${Color_Off}"
        echo -e "This does not delete your application root directory, but ${BYellow}database volumes will be destroyed.${Color_Off}"
        read -p "Continue? [y/N]" CHOICE
        case "$CHOICE" in
            n|N|'no'|'NO' ) echo "Cancelled." && return 1;;
        esac
    fi

    echo
    [ "$LD_VERBOSE" -ge "2" ] && echo "Setting up docker-compose and docker-sync files for project type '$TYPE'."

    # Skeleton uses different folder as the main location for app code.
    [[ "$TYPE" == "skeleton" ]] &&  APP_ROOT='drupal'
    [[ "$TYPE" == "ddev" ]] &&  APP_ROOT='.'

    yml_move $TYPE
    if [ "$?" -eq "1" ]; then
      echo -e "${Red}Trying to use yml files without project type.${Color_Off}"
      return 1
    fi

    echo

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

    $SCRIPT_NAME rename-volumes $PROJECT_NAME

    if is_dockersync; then
        [ "$LD_VERBOSE" -ge "1" ] && echo "Starting docker-sync, please wait..."
        docker-sync start
    fi

    echo -e "${BYellow}Starting PHP container only, to use it to build the codebase.${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE up -d php
    echo -e "${Green}PHP container: started.${Color_Off}"

    if [ -e "${APP_ROOT}/composer.json" ]; then
        echo -e "${Yellow}Looks like project is already created? File "$APP_ROOT"/composer.json exists.${Color_Off}"
        echo -e "${Yellow}Maybe you should install codebase using composer:${Color_Off}"
        echo -e "${Yellow}$SCRIPT_NAME_SHORT up && $SCRIPT_NAME_SHORT composer install${Color_Off}"
        cd $CWD
        return 1
    elif [ ! -d "$APP_ROOT" ]; then
        mkdir $APP_ROOT;
    fi
    echo "Verify application root can be used to install codebase (must be empty)..."

    DELETION_ASKED=0
    APP_FILES_COUNT=$([ -e ./$APP_ROOT ] && find ./$APP_ROOT -print -maxdepth 1 | wc -l | tr -d ' ' || echo 0)
    echo "Files (count) in ./$APP_ROOT: $APP_FILES_COUNT"

    if [ "$APP_FILES_COUNT" -ne "0" ]; then
        echo "Application root folder ./$APP_ROOT is not empty. Installation requires an empty folder."
        echo "Current folder contents:"
        ls -A $APP_ROOT
        echo -en "${Red}WARNING: If you continue all of these will be deleted. ${Color_Off}"
        read -p "Type 'PLEASE-DELETE' to continue: " CHOICE
        case "$CHOICE" in
            'PLEASE-DELETE' )
              echo "Clearing old things from the app root."
              CLEAN_ROOT="rm -rf /var/www/{,.[!.],..?}*"
              [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$CLEAN_ROOT\"${Color_Off}"
              docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$CLEAN_ROOT"
              ;;

        esac
    fi

    COMPOSER_INIT=''
    POST_COMPOSER_INIT=
    if [ "$(ls -A $APP_ROOT | wc -l | tr -d ' ')" -eq "0" ]; then

        echo
        echo -e "${BBlack}== Installing Drupal project ==${Color_Off}"
        echo "Please select which version of drupal you wish to have."
        echo "Alternatively you can install your codebase manually into $APP_ROOT."
        echo "Options:"
        echo " [1] - Drupal 8.8 recommended (drupal/recommended-project:~8.8.0)"
        echo " [2] - Drupal 8.8 legacy (drupal/legacy-project:~8.8.0)"
        echo " [3] - Drupal 8.7 using contrib template (drupal-composer/drupal-project:8.x-dev)"
        echo " [no] - Skip this, I'll build my codebase via other means"
        read -p "select version [default: 1]? " VERSION
        case "$VERSION" in
          ''|'1'|1)
            COMPOSER_INIT='composer -vv create-project drupal/recommended-project:~8.8.0 /var/www --no-interaction --stability=dev'
            POST_COMPOSER_INIT='composer -vv require drupal/console:^1.9.4 drush/drush:^9.7'
            echo -e "${Green}Creating project using ${BGreen}Drupal 8.8+${Green}, recommended structure (${BGreen}drupal/recommended-project:~8.8.0${Green}).${Color_Off}"
            ;;
          '2'|2)
            COMPOSER_INIT='composer -vv create-project drupal/legacy-project:~8.8.0 /var/www --no-interaction --stability=dev'
            POST_COMPOSER_INIT='composer -vv require drupal/console:^1.9.4 drush/drush:^9.7'
            echo -e "${Green}Creating project using ${BGreen}Drupal 8.8+${Green}, legacy structure (${BGreen}drupal/legacy-project:~8.8.0${Green}).${Color_Off}"
            ;;
          '3'|3)
            COMPOSER_INIT='composer -vv create-project drupal-composer/drupal-project:8.x-dev /var/www --no-interaction --stability=dev'
            echo -e "${Green}Creating project using ${BGreen}Drupal 8.7${Green}, contrib template (drupal-composer/drupal-project:8.x-dev).${Color_Off}"
            ;;
          *)
            PROJECT=''
            echo -e "${BYellow}Build phase skipped, no codebase built!${Color_Off}"
            ;;
        esac

        if [ ! -z "$COMPOSER_INIT" ]; then
          # Use verbose output on this composer command.
          [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$COMPOSER_INIT\"${Color_Off}"
          docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$COMPOSER_INIT"
          OK=$?
          if [ "$OK" -ne "0" ]; then
              echo -e "${Red}ERROR: Something went wrong when initializing the codebase.${Color_Off}"
              echo -e "${Red}Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.${Color_Off}"
              cd $CWD
              return 1
          fi
          if [ -n "$POST_COMPOSER_INIT" ]; then
              # Use verbose output on this composer command.
              [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c \"$POST_COMPOSER_INIT\"${Color_Off}"
              docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c "$POST_COMPOSER_INIT"
          fi
          # This must be run after composer install.
          $SCRIPT_NAME drupal-structure-fix
          $SCRIPT_NAME drupal-files-folder-perms
          echo
          echo -e "${Green}Project created to ./$APP_ROOT folder (/var/www in containers).${Color_Off}"
        else
          echo -e "${Green}Projec root is set to ./$APP_ROOT folder (/var/www in containers).${Color_Off}"
        fi

        echo
    else
      echo -en "${Red}Application root ./$APP_ROOT is not empty.${Color_Off}"
    fi
    echo
    echo 'Bringing the containers up now... Please wait.'
    $SCRIPT_NAME up
    echo
    echo -e "${BGreen}Codebase ready!!${Color_Off}"
    echo
    if [ -z "$COMPOSER_INIT" ]; then
      echo -e "${Yellow}NOTE: Once Drupal is installed, you should remove write perms in sites/default -folder:${Color_Off}"
      echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0755 web/sites/default'"
      echo "docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'chmod -v 0644 web/sites/default/settings.php'"
      echo "With these changes you can edit settings.php from host, but keep Drupal happy and allow it to write these files."
      echo
    fi
    $SCRIPT_NAME info
}

function ld_command_init_help() {
    echo "Builds the project (default: codebase in./app -folder, use composer, use drupal-project)"
}
