#!/usr/bin/env bash
# File
#
# This file contains stop -command for local-docker script ld.sh.

function ld_command_stop_exec() {
    [ "$LD_VERBOSE" -ge "1" ] && echo "Stopping containers (volumes and content intact)"
    echo -e "${Yellow}No backup of database content created.${Color_Off}"

    COMM="docker-compose -f $DOCKER_COMPOSE_FILE stop"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: $COMM${Color_Off}"
    $COMM

    if is_dockersync; then
        [ "$LD_VERBOSE" -ge "1" ] && echo "Stopping docker-sync (keeping sync volumes), please wait..."
        docker-sync stop
    fi

}

function ld_command_stop_help() {
    echo "Generates a database backup and removes containers & networks (stops docker-sync)"
}
