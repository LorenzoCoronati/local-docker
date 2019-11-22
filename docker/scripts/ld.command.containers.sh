#!/usr/bin/env bash
# File
#
# This file contains containers -command for local-docker script ld.sh.

function ld_command_containers_exec() {

    COMM="docker ps -a --filter=name=${PROJECT_NAME}_".
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: $COMM${Color_Off}"
    PROJ=$($COMM)
    if [ ! -z "$PROJ" ]; then
        echo -e "${BYellow} === Project containers ===${Color_Off}"
        $COMM
    fi
    COMM="docker ps --filter=name=${PROJECT_NAME}-".
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: $COMM${Color_Off}"
    PROJ=$($COMM)
    if [ ! -z "$PROJ" ]; then
        echo -e "${BYellow} === Docker-sync containers ===${Color_Off}"
        $COMM
    fi
}

function ld_command_containers_help() {
    echo "Get info about running containers."
}
