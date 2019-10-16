#!/usr/bin/env bash
# File
#
# This file contains dump -command for local-docker script ld.sh.

function ld_command_dump_exec() {
    db_connect
    CONN=$?
    if [ "$CONN" -ne "0" ]; then
        cd $CWD
        exit 1
    fi

    echo -e "${Yellow}Using datestamp: $DATE${Color_Off}"
    DUMPER="mysqldump --host "$${CONTAINER_DB:-db}" -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --lock-all-tables --compress --flush-logs --flush-privileges  --dump-date --tz-utc --verbose"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$DUMPER  2>/dev/null | gzip --fast -f > /var/db_dumps/db-container-dump-$DATE.sql.gz"
    cd $PROJECT_ROOT/$DATABASE_DUMP_STORAGE
    ln -sf db-container-dump-$DATE.sql.gz db-container-dump-LATEST.sql.gz
    cd $PROJECT_ROOT
    echo "DB backup in $DATABASE_DUMP_STORAGE/db-container-dump-$DATE.sql.gz"
    echo "DB backup symlink: $DATABASE_DUMP_STORAGE/db-container-dump-LATEST.sql.gz"
}

function ld_command_dump_help() {
    echo "Backup databases to $DATABASE_DUMP_STORAGE -folder"
}
