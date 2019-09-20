#!/usr/bin/env bash
# File
#
# This file contains composer -command for local-docker script ld.sh.

function ld_command_composer_exec() {
    if [ -z "$CONTAINER_PHP" ]; then
        echo -e "${Red}ERROR: PHP container name is missing.${Color_Off}"
        echo -e "${Red}Ensure you have variable 'CONTAINER_PHP' set in configuration.${Color_Off}"
        exit 1
    fi
    CONT_ID=$(find_container $CONTAINER_PHP)
    if [ -z "$CONT_ID" ]; then
        echo -e "${Red}ERROR: PHP container ('$CONTAINER_PHP')is not up.${Color_Off}"
        exit 1
    fi
    COMM="docker-compose exec ${CONTAINER_PHP} /usr/local/bin/composer -vv ${@:2}"
    echo -e "${Cyan}Next: $COMM${Color_Off}"
    $COMM
}

function ld_command_composer_help() {
    echo "Run composer command in PHP container (if up and running)"
}
