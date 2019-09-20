#!/usr/bin/env bash
# File
#
# This file contains stop -command for local-docker script ld.sh.

function ld_command_stop_exec() {
    echo "Stopping containers (volumes and content intact)"
    echo -e "${Yellow}No backup of database content created.${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE stop
    if is_dockersync; then
        docker-sync stop
    fi

}

function ld_command_stop_help() {
    echo "Generates a database backup and removes containers & networks (stops docker-sync)"
}
