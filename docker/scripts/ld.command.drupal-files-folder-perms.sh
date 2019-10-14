#!/usr/bin/env bash
# File
#
# This file contains drupal-files-folder-perms -command for local-docker script ld.sh.

function ld_command_drupal-files-folder-perms_exec() {
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
    # Can't figure out how to print msg. with quotes so that it also
    # works as a command string.
    COMM="docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c 'chown -R www-data:root /var/www/web/sites'"
    echo -e "${Cyan}Next: $COMM${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_PHP bash -c "chown -R www-data:root /var/www/web/sites"
}

function ld_command_drupal-files-folder-perms_help() {
    echo "Tries to ensure all Drupal sites files -dirs are writable inside php container."
}
