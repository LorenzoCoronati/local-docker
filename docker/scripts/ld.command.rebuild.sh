#!/usr/bin/env bash
# File
#
# This file contains rebuild -command for local-docker script ld.sh.

function ld_command_rebuild_exec() {
    $SCRIPT_NAME down 2&>/dev/null
    # Return value is not important here.
    docker-compose -f $DOCKER_COMPOSE_FILE build
    $SCRIPT_NAME up
    $SCRIPT_NAME restore
}

function ld_command_rebuild_help() {
    # PRINT INFO
    # Info will be printed with help -command after the command name.
    echo "Runs DB backup, builds containers and starts with the restored DB backup (restarts docker-sync too)"
}