#!/usr/bin/env bash

CWD=$(pwd)

PROJECT_ROOT=$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )
if [[ ! -d "$PROJECT_ROOT" ]]; then PROJECT_ROOT="$PWD"; fi

cd $PROJECT_ROOT

# Get colors.
. ./docker/scripts/ld.colors.sh

# Get functions.
. ./docker/scripts/ld.functions.sh

# 1st param, The Command.
ACTION=${1-'help'}

# Collect all available commands.
for FILE in $(ls ./docker/scripts/ld.command.*.sh ); do
    FILE=$(basename $FILE)
    COMMAND=$(cut -d'.' -f3 <<<"$FILE")
    COMMANDS="$COMMANDS $COMMAND"
done
# Use fixed name, since docker-sync is supposed to be locally only.
DOCKERSYNC_FILE=docker-sync.yml
DOCKER_COMPOSE_FILE=docker-compose.yml
DOCKER_YML_STORAGE=./docker
DOCKER_PROJECT=$(basename $PROJECT_ROOT)

import_root_env
ENV_IMPORT_FAILED=$?

DATE=$(date +%Y-%m-%d--%H-%I-%S)
RESTORE_INFO="mysql --host "$CONTAINER_DB" -uroot  -p"$MYSQL_ROOT_PASSWORD" -e 'show databases'"
USERS="mysql --host "$CONTAINER_DB" -uroot  -p"$MYSQL_ROOT_PASSWORD" -D mysql -e \"SELECT User, Host from mysql.user WHERE User NOT LIKE 'mysql%';\""

# Read (and create if necessary) the .env file, allowing overrides to any of our config values.
if [[ "$ACTION" != 'help' ]]; then
    if [[ "$ENV_IMPORT_FAILED" -ne "0" ]]; then
        if [ ! -f "./.env.example" ]; then
            echo "Files .env.example are .env are missing. Please add either one to project root."
            echo "Then start over."
            cd $CWD
            exit 1
        fi
        sleep 2
        echo "Copying .env.example -file => .env. "
        sleep 2
        cp -f ./.env.example ./.env
        echo "Please review your .env file:"
        echo
        echo -e "${BIWhite}========  START OF .env =========${Color_Off}"
        sleep 1
        cat ./.env
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
    if [[ "$ACTION" != 'init' ]] && [[ "$ACTION" != 'help' ]] && [[ "$ACTION" != 'self-update' ]]; then
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

"help")

    echo "This is a simple script, aimed to help in developer's daily use of local environment."
    echo "If you have docker-sync installed and configuration present (docker-sync.yml) it controls that too."
    echo
    echo 'Usage:'
    echo "$SCRIPT_NAME_SHORT [command]"
    echo
    echo "Available commands:"

    # Loop through all commands printing whatever they explain to be doing.
    for COMMAND in ${COMMANDS[@]}; do
      FILE=./docker/scripts/ld.command.$COMMAND.sh
      if [[ -f "$FILE" ]]; then
          . $FILE
          FUNCTION="ld_command_"$COMMAND"_help"
          function_exists $FUNCTION && echo -n "  - $COMMAND: $($FUNCTION)" && echo

      fi
    done
    cd $CWD
    exit 0
    ;;

*)
    # Loop through all commands printing whatever they explain to be doing.
    FILE=./docker/scripts/ld.command.$ACTION.sh

    if [[ -f "$FILE" ]]; then
        . $FILE
        FUNCTION="ld_command_"$ACTION"_exec"
        function_exists $FUNCTION && $FUNCTION ${@:2} || echo -e "${Red}ERROR: Command not found (hook '$FUNCTION' missing for command $ACTION).${Color_Off}."
    else
        echo -e "${Red}ERROR: Command not found (hook file missing).${Color_Off}."
    fi

esac

cd $CWD
