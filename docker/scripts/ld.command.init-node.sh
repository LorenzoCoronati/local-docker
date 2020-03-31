#!/usr/bin/env bash
# File
#
# This file contains init -command for local-docker script ld.sh.

function ld_command_init_exec() {

    if ! project_config_file_check; then
        echo -e "${BRed}This project is already initialized. ${Color_Off}"
        echo -e "${Yellow}Are you really sure you want to re-initialize the project? ${Color_Off}"
        read -p "[yes/NO] " ANSWER
        # Lowercase.
        ANSWER="$(echo ${ANSWER} | tr [A-Z] [a-z])"
        case "$ANSWER" in
            'y'|'yes')
                if [ -e "$DOCKERSYNC_FILE" ] || [ -e "$DOCKER_COMPOSE_FILE" ]; then
                    echo -e "${BYellow}WARNING: ${Yellow}There is docker-compose and/or docker-sync configuration (.yml) files in project root.${Color_Off}"
                    echo -e "${Yellow}If you continue and rename your volumes ${BYellow}you may lose data (database).${Color_Off}"
                    echo -e "${Yellow}It is highly recommended to backup your database before continuing:${Color_Off}"
                    echo -e "${Yellow}./ld db-dump${Color_Off}"
                    read -p "Remove these files? [Y/n/cancel] " CHOICE
                    CHOICE="$(echo ${CHOICE} | tr [A-Z] [a-z])"
                    case "$CHOICE" in
                        y|'yes'|'') rm -f $DOCKERSYNC_FILE $DOCKER_COMPOSE_FILE 6& echo "Removed." ;;
                        n|'no'|c|'cancel') echo "Cancelled reinitialization of docker-compose/docker-sync config." && exit 1;;
                    esac
                fi
                ;;
            *)
              echo -e "${BRed}Initialization cancelled.${Color_Off}"
              return;
              ;;
        esac
    fi

    echo
    echo -e "${BBlack}== General setup ==${Color_Off}"

    define_configuration_value LOCAL_DOCKER_VERSION_INIT $LOCAL_DOCKER_VERSION
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO: ${Yellow}Initializing with local-docker version: ${BYellow}${LOCAL_DOCKER_VERSION}${Yellow}.${Color_Off}"

    # Project type, defaults to nodejs.
    TYPE=${1:-'nodejs'}
    # Read all template files available for whitelist.
    WHITELIST_TYPES=$(find ./docker -maxdepth 1 -name 'docker-compose.*.yml' -print0 | xargs -0 basename -a | cut -d'.' -f2 | xargs)
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
        echo  "Provide a string using characters a-z, 0-9, - and _ (no dots, must start and end with a character a-z)."
        PROJECT_NAME=${PROJECT_NAME:-$(basename $PROJECT_ROOT)}
        read -p "Project name ['$PROJECT_NAME']: " ANSWER
        # Lowercase.
        ANSWER="$(echo ${ANSWER} | tr [A-Z] [a-z])"
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [[ "$ANSWER" =~  ^(([a-z])([a-z0-9\-]*))?([a-z])$ ]]; then
            PROJECT_NAME=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9) and hyphen (-).${Color_Off}"
            echo -e "${Red}ERROR: Also the project name must not start or end with hyphen or number.${Color_Off}"
            sleep 2
            echo
        fi
    done
    # Remove spaces.
    PROJECT_NAME=$(echo "$PROJECT_NAME" | sed 's/[[:space:]]/-/g')

    define_configuration_value PROJECT_NAME $PROJECT_NAME
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO: ${Yellow}Project name is: ${BYellow}${PROJECT_NAME}${Yellow}.${Color_Off}"

    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo
        echo  -e "${BBlack}== Local development base domain == ${Color_Off}"
        echo -e "Do not add protocol nor www part but just the domain name. It is recommended to use domain ending with ${BBlack}.local${Black}.${Color_Off}"
        DEFAULT=${PROJECT_NAME}.local
        LOCAL_DOMAIN=${LOCAL_DOMAIN:-${DEFAULT}}
        read -p "Domain [$LOCAL_DOMAIN] " ANSWER
        # Lowercase.
        ANSWER="$(echo ${ANSWER} | tr [A-Z] [a-z])"
        TEST=$(echo $ANSWER | egrep -e '^(([a-zA-Z0-9])([a-zA-Z0-9\.]*))?([a-zA-Z0-9])$')
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [ "${#TEST}" -gt 0 ]; then
            LOCAL_DOMAIN=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Domain name can contain only alphabetic characters (a-z), numbers (0-9), hyphens (-) and dots (.).${Color_Off}"
            echo -e "${Red}ERROR: Also the domain name must not start or end with hyphen or dot.${Color_Off}"
            sleep 2
            echo
        fi
    done
    # Remove spaces.
    LOCAL_DOMAIN=$(echo "$LOCAL_DOMAIN" | sed 's/[[:space:]]/./g')
    define_configuration_value LOCAL_DOMAIN $LOCAL_DOMAIN
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO: ${Yellow}Local develoment domain is:  ${BYellow}${LOCAL_DOMAIN}${Yellow}.${Color_Off}"

    echo
    echo -e "${BBlack}== Local development IP address ==${Color_Off}"
    # Do not re-generate IP if one is set!
    if [ -n "$LOCAL_IP" ] && [ "$LOCAL_IP" != "127.0.0.1" ]; then
        [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BGreen}INFO: ${Green}Local development IP is pre-configured to ${LOCAL_IP} in .env file.${Color_Off}"
    else
        echo "Random IP address is recommended for local development. Once can be generated for you now."
        read -p "Generate random IP address [Y/n]? " ANSWER
        # Lowercase.
        ANSWER="$(echo ${ANSWER} | tr [A-Z] [a-z])"
        case "$ANSWER" in
            'n'|'no') LOCAL_IP='127.0.0.1';;
            *) LAST=$((RANDOM % 240 + 3 )) && LOCAL_IP=$( printf "127.0.%d.%d\n" "$((RANDOM % 256))" "$LAST");;
        esac
        # Remove spaces.
        LOCAL_IP=$(echo "$LOCAL_IP" | sed 's/[[:space:]]/./g')
        define_configuration_value LOCAL_IP $LOCAL_IP
    fi
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO: ${Yellow}IP address is: ${BYellow}${LOCAL_IP}${Yellow}.${Color_Off}"

    yml_move $TYPE
    if [ "$?" -eq "1" ]; then
      echo -e "${Red}ERROR: Moving YML files for Docker Compose and Docker Sync failed.${Color_Off}"
      return 1
    fi

    echo
    APP_ROOT=${APP_ROOT:-app}
    define_configuration_value APP_ROOT $APP_ROOT
    ensure_folders_present $APP_ROOT
    echo -e "${BYellow}INFO: ${Yellow}Application root is in ${BYellow}$APP_ROOT${Yellow}.${Color_Off}"

    DATABASE_DUMP_STORAGE=${DATABASE_DUMP_STORAGE:-db_dumps}
    define_configuration_value DATABASE_DUMP_STORAGE $DATABASE_DUMP_STORAGE
    ensure_folders_present $DATABASE_DUMP_STORAGE
    echo -e "${BYellow}INFO: ${Yellow}Database dumps will be placed in ${BYellow}$DATABASE_DUMP_STORAGE${Yellow}.${Color_Off}"

    if [[ "$(docker-compose -f $DOCKER_COMPOSE_FILE ps -q)" ]]; then
        echo -n "Turning off current container stack, please wait..."
        docker-compose -f $DOCKER_COMPOSE_FILE down 2> /dev/null
        echo  -e "${Green}DONE${Color_Off}"
    fi

    # Docker-sync shouldn't be running to avoid it getting stuck with too
    # may files being changed in a short period of time. Temporary Composer
    # container does not use these volumes.
    # "rename-volumes" will also turn off & clean docker-sync.
    $SCRIPT_NAME rename-volumes $PROJECT_NAME

    if [ -e "${APP_ROOT}/package.json" ]; then
        echo -e "${Yellow}Looks like project is already created? File ${APP_ROOT}/package.json exists.${Color_Off}"
        echo -e "${Yellow}Maybe you should install codebase using npm:${Color_Off}"
        cd $CWD
        return 1
    fi

    echo
    echo "Verify application root can be used to install codebase (must be empty)..."

    echo
    echo -e "${BBlack}== Generating SSL/TLS certificates ==${Color_Off}"
    $SCRIPT_NAME tls-cert

    echo
    echo -e "${BBlack}== Installing Node project ==${Color_Off}"
    DEFAULT="E"

    echo "Please select which version of drupal you wish to have."
    echo "Alternatively you can install your codebase manually into $APP_ROOT."
    echo "Options:"
    echo " [E] Example node project"
    echo " [N] - Thanks for the offer, but I'll handle codebase build manually."
    read -p "Select version [default: ${DEFAULT}]? " VERSION
    VERSION=${VERSION:-${DEFAULT}}
    case "$VERSION" in
      'E')
        cp docker/resources/nodejs-example-app/* app/
        echo -e "${Green}Creating example node project.${Color_Off}"
        ;;
      *)
        echo -e "${BYellow}Build phase skipped, no codebase built!${Color_Off}"
        ;;
    esac

    if [ "$LD_VERBOSE" -ge "1" ] ; then
        echo
        echo -e "${BGreen}*******************************${Color_Off}"
        echo -e "${BGreen}***** Project initialized *****${Color_Off}"
        echo -e "${BGreen}*******************************${Color_Off}"
        echo
    fi

    if [ "$LD_VERBOSE" -ge "1" ] ; then
        echo
        echo -e "${BGreen}Booting up the project now, please wait...${Color_Off}"
        echo
    fi
    $SCRIPT_NAME up

    $SCRIPT_NAME info
}

function ld_command_init_help() {
    echo "Builds the project (default: codebase in./app -folder."
}
