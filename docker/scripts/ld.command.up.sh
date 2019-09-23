#!/usr/bin/env bash
# File
#
# This file contains up -command for local-docker script ld.sh.

function ld_command_up_exec() {
    if is_dockersync; then
        docker-sync start
    fi
    ensure_folders_present $DATABASE_DUMP_STORAGE
    docker-compose -f $DOCKER_COMPOSE_FILE up -d
    $SCRIPT_NAME drupal-files-folder-perms
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo
        echo -e "${Red}ERROR: Something went wrong when bringing the project up.${Color_Off}"
        echo -e "${Red}Check that required ports are not allocated (by other containers or programs) and re-configure them if needed.${Color_Off}"
        cd $CWD
        exit 1
    fi

    db_connect
    CONN=$?

    if [ "$CONN" -ne 0 ]; then
        echo "${Red}Oww... DB container is not up, even after a few retries.${Color_Off}"
        cd $CWD
        exit 1
    fi

    echo
    echo 'Current databases:'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
    echo 'Current database users:'
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
    echo "${Yellow}NOTE: No database dump restored.${Color_Off}"
    echo 'In case you need to do that (Drupal DB is gone?),'
    echo '1) check your symlink target in db_dumps/db-container-dump-LATEST.sql.gz'
    echo '2) execute the following command:'
    echo $SCRIPT_NAME_SHORT restore
}

function ld_command_up_help() {
    echo "Brings containers up with building step if necessary (starts docker-sync)"
}
