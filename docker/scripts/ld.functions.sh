#!/usr/bin/env bash
# File
#
# This file contains functions for local-docker script ld.sh.

find_container() {
    if [ -z "$1" ]; then
        echo -e "${Red}ERROR: Trying to locate a container with empty name.${Color_Off}"
        return 1
    fi
    TMP_NAME=$PROJECT_NAME"_"$1
    FOUND_NAME=$(docker ps  | grep "$TMP_NAME" | sed 's/.*\ //' )
    if [ ! -z "$FOUND_NAME" ]; then
        echo $FOUND_NAME;
    fi
}

is_dockersync() {
    [ ! -z "$(which docker-sync)" ] && [ -f "$PROJECT_ROOT/$DOCKERSYNC_FILE" ]
}

# Copy conf of your choosing to project root, destroy leftovers.
# Template must be found using filename patters
# TPL-NAME => $DOCKER_YML_STORAGE/docker-compose.TPL-NAME.yml,
# usually: docker/docker-compose.TPL-NAME.yml
# Usage
#   yml_move template-name
yml_move() {
    MODE=$1
    if [ -z "$MODE" ]; then
       echo -e "${Red}Trying to use yml files without project type.${Color_Off}"
       exit 1
    fi

    if [ -f "$DOCKER_YML_STORAGE/docker-compose.$MODE.yml" ]; then
        echo "Using $DOCKER_YML_STORAGE/docker-compose.$MODE.yml as the docker-compose recipe."
        cp $DOCKER_YML_STORAGE/docker-compose.$MODE.yml ./$DOCKER_COMPOSE_FILE
    else
        echo -e "${Red} Docker-compose template file missing: $DOCKER_YML_STORAGE/docker-compose.$MODE.yml"
    fi
    # NFS template does not have docker-sync -flavor, as it uses nfs mounts for folder sharing.
    if [ "$MODE" != "nfs" ] && [ -f "$DOCKER_YML_STORAGE/docker-sync.$MODE.yml" ]; then
        echo "Using $DOCKER_YML_STORAGE/docker-sync.$MODE.yml as the docker-sync recipe."
        cp $DOCKER_YML_STORAGE/docker-sync.$MODE.yml ./$DOCKERSYNC_FILE
    else
        echo -e "${Red} Docker-sync template file missing: $DOCKER_YML_STORAGE/docker-sync.$MODE.yml"
    fi
}

db_connect() {
    CONTAINER_DB_ID=$(find_container $CONTAINER_DB)
    RESPONSE=0
    ROUND=0
    ROUNDS_MAX=30
    if [ -z "$CONTAINER_DB_ID" ]; then
        echo -e "${Red}DB container not running (or not yet created).${Color_Off}"
        exit 1
    else
        echo -n  "Connecting to DB container ($CONTAINER_DB_ID), please wait .."
    fi

    while [ -z "$RESPONSE" ] || [ "$RESPONSE" -eq "0" ]; do
        ROUND=$(( $ROUND + 1 ))
        echo -n '.'
        COMMAND="/usr/bin/mysqladmin -uroot -p$MYSQL_ROOT_PASSWORD status 2>/dev/null |wc -l "
        RESPONSE=$(docker exec $CONTAINER_DB_ID sh -c "$COMMAND")
        if [ "${#RESPONSE}" -gt "0" ]; then
            if [ "$RESPONSE" -ne "0" ]; then
                echo -e " ${Green}connected.${Color_Off}"
                return 0;
            fi
        fi
        if [ "$ROUND" -lt  "$ROUNDS_MAX" ]; then
            sleep 1
        else
            echo -e " ${BRed}failed!${Color_Off}"
            echo -e "${BRed}DB container did not respond in due time.${Color_Off}"
            break;
        fi
    done

    return 1
}

# Cross-OS way to do in-place find-and-replace with sed.
# Use: replace_in_file PATTERN FILENAME
replace_in_file () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

# Import all environment variables from .env -file.
# This should be done every time after vars are updated.
import_root_env() {
    ENV_FILE="$PROJECT_ROOT/.env"

    if [ -f "$ENV_FILE" ]; then
        # Read .env -file variables. These override possible values defined
        # earlier in this script.
        export $(grep -v '^#' $ENV_FILE | xargs)
        return 0
    fi
    return 1
}

function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}

function ensure_folders_present() {
    for DIR in $@; do
       if [ ! -e "$DIR" ]; then
            mkdir -vp $DIR
       fi
    done
}

function ensure_envvar_present() {
    NAME=$1
    VAL=$2
    if [ ! -e ".env" ]; then
        echo -e "${Red}ERROR: File .env not present while trying to store a value into it.${Color_Off}";
        exit;
    fi
    EXISTS=$(grep $NAME .env | wc -l)
    if [ "$EXISTS" -gt "0" ]; then
        PATTERN="s/^$NAME=.*/$NAME=$VAL/"
        replace_in_file $PATTERN .env
    else
        echo "${NAME}=${VAL}" >> $PROJECT_ROOT/.env
    fi
    # Re-import all vars to take effect in host and container shell, too.
    import_root_env
}
