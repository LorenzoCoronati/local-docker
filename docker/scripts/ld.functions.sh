#!/usr/bin/env bash
# File
#
# This file contains functions for local-docker script ld.sh.

function find_container() {
    if [ -z "$1" ]; then
        return 1
    fi
    TMP_NAME=$PROJECT_NAME"_"$1
    FOUND_NAME=$(docker ps  | grep "$TMP_NAME" | sed 's/.*\ //' )
    if [ ! -z "$FOUND_NAME" ]; then
        echo $FOUND_NAME;
    fi
}

function is_dockersync() {
    [ ! -z "$(which docker-sync)" ] && [ -f "$PROJECT_ROOT/$DOCKERSYNC_FILE" ]
}

# Copy conf of your choosing to project root, destroy leftovers.
# Template must be found using filename patters
# TPL-NAME => $DOCKER_YML_STORAGE/docker-compose.TPL-NAME.yml,
# usually: docker/docker-compose.TPL-NAME.yml
# Usage
#   yml_move template-name
function yml_move() {
    MODE=$1
    if [ -z "$1" ]; then
       return 1
    fi

    if [ -f "$DOCKER_YML_STORAGE/docker-compose.$MODE.yml" ]; then
        cp $DOCKER_YML_STORAGE/docker-compose.$MODE.yml ./$DOCKER_COMPOSE_FILE
    else
        echo -e "${Red} Docker-compose template file missing: $DOCKER_YML_STORAGE/docker-compose.$MODE.yml"
    fi
    # NFS template does not have docker-sync -flavor, as it uses nfs mounts for folder sharing.
    if [ "$MODE" != "nfs" ] && [ -f "$DOCKER_YML_STORAGE/docker-sync.$MODE.yml" ]; then
        cp $DOCKER_YML_STORAGE/docker-sync.$MODE.yml ./$DOCKERSYNC_FILE
    else
        echo -e "${Red} Docker-sync template file missing: $DOCKER_YML_STORAGE/docker-sync.$MODE.yml.${Color_Off}"
    fi
}

function db_connect() {
    CONTAINER_DB_ID=$(find_container ${CONTAINER_DB:-db})
    if [ "$?" -eq "1" ]; then
      return 1
    fi
    RESPONSE=0
    ROUND=0
    ROUNDS_MAX=30
    if [ -z "$CONTAINER_DB_ID" ]; then
      return 2
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
            return 3
            break;
        fi
    done

    return 0
}

# Cross-OS way to do in-place find-and-replace with sed.
# Use: replace_in_file PATTERN FILENAME
function replace_in_file () {
    sed --version >/dev/null 2>&1 && sed -i -- "$@" || sed -i "" "$@"
}

# Import all environment variables from .ld.config and .env -files.
# This should be done every time after vars are updated.
function import_config() {
    CONFIG_FILE="$PROJECT_ROOT/.ld.config"
    ENV_FILE="$PROJECT_ROOT/.env"
    IMPORTED="0"

    if [ -f "$CONFIG_FILE" ]; then
        # Read .ld.config -file variables. These override possible values defined
        # earlier in this script.
        export $(grep -v '^#' $CONFIG_FILE | xargs)
        (( IMPORTED = IMPORTED + 1 ))

    fi
    if [ -f "$ENV_FILE" ]; then
        # Read .env -file variables. These override possible values defined
        # earlier in this script.
        export $(grep -v '^#' $ENV_FILE | xargs)
        (( IMPORTED = IMPORTED + 1 ))
    fi

    [ "$IMPORTED" -eq "0" ] && return 1 || return 0
}

# Copy .env.example to .env.
# If file exists, append to the endo if it..
function create_root_env() {
  FILE="./.env"
  TEMPLATE="${FILE}.example"
  if [ ! -f "${TEMPLATE}" ]; then
    echo -e "${Red}ERROR: File ${BRed}${TEMPLATE}${Red} does not exist!.${Color_Off}";
    return 5;
  fi

  if [ ! -f "$FILE" ]; then
    echo -e "${Green}Creating default ${BGreen}${FILE}${Green}- file from the template. ${Color_Off}"
    cp -f ${TEMPLATE} ${FILE}
  else
    echo -e "${Yellow}Adding default values from ${TEMPLATE} -file to your ${BYellow}EXISTING${Yellow} ${BYellow}${FILE}${Yellow} -file. ${Color_Off}"
    cat ${TEMPLATE} >> ${FILE}
  fi
  echo -e "${Yellow}Your ${FILE} -file ${BYellow}should NOT be committed to Git repository${Yellow}  (and it is .gitignore'd by default).${Color_Off}"

  return
}

# Copy .ld.config.example to .ld.config.
# If file exists, append to the endo if it.
function create_project_config() {
  FILE="./.ld.config"
  TEMPLATE="${FILE}.example"
  if [ ! -f "${TEMPLATE}" ]; then
    echo -e "${Red}ERROR: File ${BRed}${TEMPLATE}${Red} does not exist!.${Color_Off}";
    return 5;
  fi

  if [ ! -f "$FILE" ]; then
    echo -e "${Green}Creating default ${BGreen}${FILE}${Green}- file from the template. ${Color_Off}"
    cp -f ${TEMPLATE} ${FILE}
  else
    echo -e "${Yellow}Adding default values from ${TEMPLATE} -file to your ${BYellow}EXISTING${Yellow} ${BYellow}${FILE}${Yellow} -file. ${Color_Off}"
    cat ${TEMPLATE} >> ${FILE}
  fi

  echo -e "${Yellow}Your ${FILE} -file ${BYellow}should be committed to Git repository${Yellow}.${Color_Off}"
  return
}

function function_exists() {
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

function define_configuration_value() {
    NAME=$1
    VAL=$2
    FILE="./.ld.config"

    if [ ! -e "$FILE" ]; then
        echo -e "${Red}ERROR: File $FILE not present while trying to store a value into it.${Color_Off}";
        return 1;
    fi
    EXISTS=$(grep $NAME $FILE | wc -l)
    if [ "$EXISTS" -gt "0" ]; then
        PATTERN="s|^$NAME=.*|$NAME=$VAL|"
        replace_in_file $PATTERN $FILE
    else
        echo "${NAME}=${VAL}" >> $PROJECT_ROOT/$FILE
    fi
    # Re-import all vars to take effect in host and container shell, too.
    import_config
    return $?
}

function osx_version() {
  VERSION_LONG=$(defaults read loginwindow SystemVersionStampAsString)
  VERSION_SHORT=$(echo $VERSION_LONG | cut -d'.' -f1 -f2)
  if [ ! -z "$VERSION_SHORT" ]; then
    echo $VERSION_SHORT;
    return;
  fi

  return 1;
}

# Check base requirements to run local-docker.
# Some shells have built-in "which" (zsh), some use the BSD which (bash, sh)
# and they behave differently. Trying to catch all the flavors and behaviours here.
function required_binaries_check() {

  if [ ! -z "$(which docker | grep 'not found')" ] ||
      [ "$(which docker >/dev/null 2>&1 ; echo $?)" -ne "0" ] ; then
    return 1
  fi

  if [ ! -z "$(which docker-compose | grep 'not found')" ] ||
      [ "$(which docker-compose >/dev/null 2>&1 ; echo $?)" -ne "0" ] ; then
    return 2
  fi

  if [ ! -z "$(which git | grep 'not found')" ] ||
      [ "$(which git >/dev/null 2>&1 ; echo $?)" -ne "0" ] ; then
    return 3
  fi

}
