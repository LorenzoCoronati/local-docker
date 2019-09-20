#!/usr/bin/env bash
# File
#
# This file contains nuke-volumes -command for local-docker script ld.sh.

function ld_command_nuke-volumes_exec() {
    echo -e "${Yellow}"
    echo " *************************"
    echo " ******   WARNING ********"
    echo " *************************"
    echo " "
    echo -n" ALL volumes localbase* will be destroyed permanently in 5 secs."
    echo -e "${Color_Off}"
    WAIT=5
    while [ $WAIT -gt 0 ]; do
        echo -n "$WAIT ... "
        ((WAIT--))
        sleep 1
    done
    echo
    docker-compose -f $DOCKER_COMPOSE_FILE down
    if is_dockersync; then
        docker-sync clean
    fi
    for VOL in $(docker volume ls --filter="name=localbase*" -q); do
        echo "Handling volume: $VOL"
        for CONT in $(docker ps --filter volume=$VOL -q); do
            echo "Kill container : $CONT "
            docker -v kill $CONT
        done
        echo "Removing volume: $VOL"
        docker -v volume rm -f $VOL
    done
}

function ld_command_nuke-volumes_help() {
    echo "Remove permanently all volumes, including synced ones (NO BACKUPS!)."
}
