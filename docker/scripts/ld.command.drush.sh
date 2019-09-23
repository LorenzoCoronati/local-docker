#!/usr/bin/env bash
# File
#
# This file contains drush -command for local-docker script ld.sh.

function ld_command_drush_exec() {
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
    COMM="docker-compose exec ${CONTAINER_PHP} /var/www/vendor/drush/drush/drush $@"
    echo -e "${Cyan}Next: $COMM${Color_Off}"
    $COMM
}

function ld_command_drush_help() {
    echo "Run drush command in PHP container (if up and running)"
}
