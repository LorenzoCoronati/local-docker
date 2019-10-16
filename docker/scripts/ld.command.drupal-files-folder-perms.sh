#!/usr/bin/env bash
# File
#
# This file contains drupal-files-folder-perms -command for local-docker script ld.sh.

function ld_command_drupal-files-folder-perms_exec() {
    CONT_ID=$(find_container ${CONTAINER_PHP:-php})
    if [ "$?" -eq "1" ]; then
      echo -e "${Red}ERROR: Trying to locate a container with empty name.${Color_Off}"
      exit 1
    fi
    if [ -z "$CONT_ID" ]; then
        echo -e "${Red}ERROR: PHP container ('${CONTAINER_PHP:-php}')is not up.${Color_Off}"
        exit 2
    fi
    # Can't figure out how to print msg. with quotes so that it also
    # works as a command string.
    COMM="docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_PHP:-php} bash -c 'chown -R www-data:root /var/www/web/sites'"
    echo -e "${Cyan}Next: $COMM${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_PHP:-php} bash -c "chown -R www-data:root /var/www/web/sites"
}

function ld_command_drupal-files-folder-perms_help() {
    echo "Tries to ensure all Drupal sites files -dirs are writable inside php container."
}
