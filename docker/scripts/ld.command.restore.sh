#!/usr/bin/env bash
# File
#
# This file contains restore -command for local-docker script ld.sh.

function ld_command_restore_exec() {
    if [ ! -e "db_dumps/db-container-dump-LATEST.sql.gz" ]; then
        echo -e "${Red}"
        echo "********************************************************************************************"
        echo "** Dump file missing! Create a symlin to your DB backup file:                             **"
        echo "** ln -s PATH/TO/GZIPPED/MYSQLDUMP/FILE.sql.gz ./db_dumps/db-container-dump-LATEST.sql.gz **"
        echo "********************************************************************************************"
        echo -e "${Color_Off}"
        cd $CWD
        exit 1
    fi

    db_connect
    CONN=$?

    if [ "$CONN" -ne 0 ]; then
        echo -e "${Red}ERROR: DB container is not up, even after a few retries. Exiting..${Color_Off}."
        cd $CWD
        exit 2
    fi

    echo "Restoring state with DB dump."

    echo
    echo -e "${Yellow}Databases before the restore:${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
    echo
    echo 'Restoring db...'
    echo -n "DB backup used: db_dumps/db-container-dump-LATEST.sql.gz => "
    echo $(readlink db_dumps/db-container-dump-LATEST.sql.gz)
    echo "[This may take some time...]"
    RESTORER="gunzip < /var/db_dumps/db-container-dump-LATEST.sql.gz | mysql --host "$CONTAINER_DB" -uroot -p"$MYSQL_ROOT_PASSWORD""
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORER 2>/dev/null"
    echo
    echo -e "${Yellow}Databases after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$RESTORE_INFO 2>/dev/null"
    echo -e "${Yellow}Users after the restore${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec $CONTAINER_DB sh -c "$USERS 2>/dev/null"
  }

function ld_command_restore_help() {
    echo "Import latest db. Database container must be running."
}
