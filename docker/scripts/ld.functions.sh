#!/usr/bin/env bash
# File
#
# This file contains functions for local-docker script ld.sh.

find_db_container() {
    TMP_NAME=$DOCKER_PROJECT"_"$CONTAINER_DB
    FOUND_NAME=$(docker ps  | grep "$TMP_NAME" | sed 's/.*\ //' )
    if [ -z "$FOUND_NAME" ]; then
        echo ''
    fi
    echo $FOUND_NAME;
}

is_dockersync() {
    [ ! -z "$(which docker-sync)" ] && [ -f "$PROJECT_ROOT/$DOCKERSYNC_FILE" ]
}

# Copy conf of your choosing to project root, destroy leftovers.
# Usage
#   yml_move
#   yml_move skeleton
yml_move() {
    MODE=${1-'common'}
    echo "MODE: $MODE"
    if [ -f "$DOCKER_YML_STORAGE/docker-compose.$MODE.yml" ]; then
        echo "Using $DOCKER_YML_STORAGE/docker-compose.$MODE.yml as the docker-compose recipe."
        mv -v $DOCKER_YML_STORAGE/docker-compose.$MODE.yml ./$DOCKER_COMPOSE_FILE
        rm -f $DOCKER_YML_STORAGE/docker-compose.*.yml
    fi
    if [ -f "$DOCKER_YML_STORAGE/docker-sync.$MODE.yml" ]; then
        echo "Using $DOCKER_YML_STORAGE/docker-sync.$MODE.yml as the docker-sync recipe."
        mv -v $DOCKER_YML_STORAGE/docker-sync.$MODE.yml ./$DOCKERSYNC_FILE
        rm -f $DOCKER_YML_STORAGE/docker-sync.*.yml
    fi
}

db_connect() {
  CONTAINER_DB_ID=$(find_db_container)
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

import_root_env() {
    ENV_FILE="$PROJECT_ROOT/.env"

    if [ -f "$ENV_FILE" ]; then
        # Read .env -file variables. These override possible values defined
        # earlier in this script.
        export $(grep -v '^#' $ENV_FILE | xargs)
        return 0
    fi
    exit 1
}

function_exists() {
    declare -f -F $1 > /dev/null
    return $?
}
