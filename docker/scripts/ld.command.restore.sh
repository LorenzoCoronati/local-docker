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
    case "$?" in
      1|"1") echo -e "${Red}ERROR: Trying to locate a container with empty name.${Color_Off}" && return 1 ;;
      2|"2") echo -e "${Red}ERROR: DB container not running (or not yet created).${Color_Off}" && return 2 ;;
      2|"2") echo -e "${Red}ERROR: Some other and undetected issue when connecting DB container.${Color_Off}" && return 3 ;;
    esac

    echo -e "${Yellow}Restoring db from:\n $DATABASE_DUMP_STORAGE/$TARGET_FILE_NAME${Color_Off}"
    echo "This may take some time."

    echo
    echo -e "${Yellow}Databases before the restore:${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$RESTORE_INFO 2>/dev/null"
    echo
    RESTORER="gunzip < /var/db_dumps/db-container-dump-LATEST.sql.gz | mysql --host "$${CONTAINER_DB:-db}" -uroot -p"$MYSQL_ROOT_PASSWORD""
    echo "Please wait..."
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$RESTORER 2>/dev/null"
    echo
    echo -e "${Yellow}Databases after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$RESTORE_INFO 2>/dev/null"
    echo -e "${Yellow}Users after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$USERS 2>/dev/null"
  }

function ld_command_restore_help() {
    echo "Import latest db. Optionally provide file name. Dump file must be located in $DATABASE_DUMP_STORAGE -folder."
}
