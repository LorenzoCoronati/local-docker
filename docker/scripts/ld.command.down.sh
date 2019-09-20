#!/usr/bin/env bash
# File
#
# This file contains down -command for local-docker script ld.sh.

function ld_command_down_exec() {
    $SCRIPT_NAME dump
    CONN=$?
    if [ "$CONN" -ne "0" ]; then
        cd $CWD
        exit 1
    fi
    docker-compose -f $DOCKER_COMPOSE_FILE  down
    if is_dockersync; then
        docker-sync clean
    fi
}

function ld_command_down_help() {
    echo "Generates a database backup and removes containers & networks (stops docker-sync)"
}
