#!/usr/bin/env bash
# File
#
# This file contains db-dump -command for local-docker script ld.sh.

# Create a full backup of the DB container.
function ld_command_db-dump_exec() {

    DATE=$(date +%Y-%m-%d--%H-%I-%S)
    FILENAME="db-container-db-dump-$DATE.sql.gz"
    COMMAND_SQL_DB_DUMPER="mysqldb-dump --host "${CONTAINER_DB:-db}" -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --lock-all-tables --compress --flush-logs --flush-privileges  --db-dump-date --tz-utc --verbose  2>/dev/null | gzip --fast -f > /var/db_db-dumps/${FILENAME}"

    db_connect
    RET="$?"
    case "$RET" in
        1|"1")
          echo -e "${Red}ERROR: Trying to locate a container with empty name.${Color_Off}"
          return $RET
          ;;

        2|"2")
          if ! is_dockersync && [ -f "${DOCKER_PROJECT}/${DOCKERSYNC_FILE}" ]; then
            [ "$LD_VERBOSE" -ge "1" ] && echo 'Starting docker-sync, please wait...'
            docker-sync start
            DOCKER_SYNC_STARTED=1
          fi
          COMM="docker-compose -f $DOCKER_COMPOSE_FILE  up -d $CONTAINER_DB"
          [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Yellow}Starting DB container for backup purposes.${Color_Off}"
          $COMM
          STARTED=1
          ;;

        3|"3")
         echo -e "${Red}ERROR: DB container not running (or not yet created).${Color_Off}"
         return $RET
       ;;
    esac

    echo -e "${Yellow}Using datestamp: $DATE${Color_Off}"
    docker-compose -f $DOCKER_COMPOSE_FILE exec ${CONTAINER_DB:-db} sh -c "$COMMAND_SQL_DB_DUMPER"
    cd $PROJECT_ROOT/$DATABASE_DUMP_STORAGE
    ln -sf ${FILENAME} db-container-db-dump-LATEST.sql.gz
    cd $PROJECT_ROOT
    if [ "$STARTED" -eq "1" ]; then
       echo -e "${Yellow}Stopping DB container.${Color_Off}"
       docker-compose -f $DOCKER_COMPOSE_FILE stop $CONTAINER_DB
    fi
    if [ ! -z "$DOCKER_SYNC_STARTED" ]; then
        [ "$LD_VERBOSE" -ge "1" ] && echo 'Turning off docker-sync (stop), please wait...'
        docker-sync stop
    fi
    echo "DB container backup in $DATABASE_DUMP_STORAGE/${FILENAME}"
    echo "DB container backup symlinked from $DATABASE_DUMP_STORAGE/db-container-db-dump-LATEST.sql.gz"

}

function ld_command_db-dump_help() {
    echo "Backup the DB container contents (all databases). Dump file will be place in $DATABASE_DUMP_STORAGE -folder."
}
