#!/usr/bin/env bash
# File
#
# This file contains info -command for local-docker script ld.sh.

function ld_command_info_exec() {
    echo -e "${BYellow}=== Project information ===${Color_Off}"
    echo
    echo -e "${Green}Project name                      : ${BGreen}${PROJECT_NAME:-MISSING}${Color_Off}"
    echo -e "${Green}Project local domain              : ${BGreen}${LOCAL_DOMAIN:-MISSING}${Color_Off}"
    echo -e "${Green}Project root                      : ${BGreen}${APP_ROOT:-MISSING}${Color_Off}"
    echo -e "${Green}Project IP address (local)        : ${BGreen}${LOCAL_IP:-MISSING}${Color_Off}"
    echo -e "${Green}Project www port                  : ${BGreen}${CONTAINER_PORT_WEB:-MISSING}${Color_Off}"
    echo -e "${Green}Project MySQL port                : ${BGreen}${CONTAINER_PORT_DB:-MISSING}${Color_Off}"
    echo -e "${Green}Project Varnish port (if present) : ${BGreen}${CONTAINER_PORT_VARNISH:-MISSING}${Color_Off}"
    echo -e "${Green}Project MySQL root password       : ${BGreen}${MYSQL_ROOT_PASSWORD:-[MISSING, may prevent DB container to start properly]}${Color_Off}"
    echo -e "${Green}Database name (may be others too) : ${BGreen}${MYSQL_DATABASE:-MISSING}${Color_Off}"
    echo -e "${Green}Database user (for ${MYSQL_DATABASE:-MISSING})        : ${BGreen}${MYSQL_USER:-MISSING}${Color_Off}"
    echo -e "${Green}Database pass (may be others too) : ${BGreen}${MYSQL_PASSWORD:-MISSING}${Color_Off}"
    echo -e "${Green}PHP version                       : ${BGreen}${PROJECT_PHP_VERSION:-MISSING}${Color_Off}"
    echo -e "${Green}PHP memory limit                  : ${BGreen}${PHP_MEMORY_LIMIT:-MISSING}${Color_Off}"
    echo -e "${Green}Xdebug port (for your editor)     : ${BGreen}${PHP_XDEBUG_REMOTE_PORT:-MISSING}${Color_Off}"

    echo -e "${Green}Default URL for Drush             : ${BGreen}${DRUSH_OPTIONS_URI:-MISSING}${Color_Off}"
    echo -e "${Green}Created dB dumps location         : ${BGreen}${DATABASE_DUMP_STORAGE:-MISSING}${Color_Off}"
    echo
    echo -e "${BGreen}Happy coding!${Color_Off}"
}

function ld_command_info_help() {
    echo "Displays information about the initialized project."
}
