#!/usr/bin/env bash
# File
#
# This file contains stop -command for local-docker script ld.sh.

function ld_command_xdebug_exec() {
    if [ -z "$CONTAINER_PHP" ]; then
        echo -e "${Red}ERROR: PHP container name is missing.${Color_Off}"
        echo -e "${Red}Ensure you have variable 'CONTAINER_PHP' set in configuration.${Color_Off}"
        exit 1
    fi
    case "$1" in
        '1'|'on') ensure_envvar_present PHP_XDEBUG_REMOTE_ENABLE 1; sleep 1; docker-compose -f $DOCKER_COMPOSE_FILE up -d php && $SCRIPT_NAME xdebug;;
        '0'|'off') ensure_envvar_present PHP_XDEBUG_REMOTE_ENABLE 0; docker-compose -f $DOCKER_COMPOSE_FILE up -d php && $SCRIPT_NAME xdebug;;
        *) docker-compose -f $DOCKER_COMPOSE_FILE exec php bash -c 'echo -n "Xdebug is: "; php -i | grep xdebug.remote_enable |tr -s " => " "|" | cut -d "|" -f2';;
    esac

}

function ld_command_xdebug_help() {
    echo "Set or get Xdebug status (enabled, disabled). Optional paremeter to toggle value ['on'|1|'off'|0], omit to get current value."
}
