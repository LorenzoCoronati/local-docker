#!/usr/bin/env bash
# File
#
# This file contains restore -command for local-docker script ld.sh.

function ld_command_restore_exec() {
    TARGET_FILE_NAME=${1:-db-container-dump-LATEST.sql.gz}
    if [ ! -e "$DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME" ]; then
        if [ -z "$1" ]; then
            echo -e "${Red}"
            echo "********************************************************************************************"
            echo "** Dump file missing! Create a symlin to your DB backup file:                             **"
            echo "** ln -s PATH/TO/GZIPPED/MYSQLDUMP/FILE.sql.gz ./$DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME **"
            echo "********************************************************************************************"
            echo -e "${Color_Off}"
        else
            echo -e "${Red}ERROR: File $DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME does not exists${Color_Off}"
        fi
        cd $CWD
        exit 1
    fi
    INFO=$(file -b $DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME | cut -d' ' -f1)
    if [ "$INFO" != "gzip" ]; then
        echo -e "${Red}ERROR: File $DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME type is not gzip${Color_Off}"
        cd $CWD
        exit 3
    fi

    db_connect
    CONN=$?

    if [ "$CONN" -ne 0 ]; then
        echo -e "${Red}ERROR: DB container is not up, even after a few retries.${Color_Off}."
        cd $CWD
        exit 2
    fi

    echo -e "${Yellow}Restoring db from:\n $DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME${Color_Off}"
    echo "This may take some time."

    echo
    echo -e "${Yellow}Databases before the restore:${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
    echo
    RESTORER="gunzip < /var/db_dumps/db-container-dump-LATEST.sql.gz | mysql --host "$CONTAINER_DB" -uroot -p"$MYSQL_ROOT_PASSWORD""
    echo "Please wait..."
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORER 2>/dev/null"
    echo
    echo -e "${Yellow}Databases after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
    echo -e "${Yellow}Users after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
  }

function ld_command_restore_help() {
    echo "Import latest db. Optionally provide file name. Dump file must be located in $DATABASE_DUMP_STORAGE -folder."
}
