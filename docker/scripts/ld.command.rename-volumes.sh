#!/usr/bin/env bash
# File
#
# This file contains rename-volumes -command for local-docker script ld.sh.

function ld_command_rename-volumes_exec() {
    if is_dockersync; then
        echo 'Turning off docker-sync, please wait...'
        docker-sync clean
    fi
    VOL_BASE_NAME=$1
    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo -e "${BBlack}==  Container volume base name ==${Color_Off}"
        read -p "Container volume base name ['$VOL_BASE_NAME']: " ANSWER
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [[ "$ANSWER" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]; then
            VOL_BASE_NAME=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Volume base name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-) and start and end with alphabetic characters or numbers.${Color_Off}"
            echo -e "${Red}ERROR: Volume base name must not start or end with underscore or hyphen.${Color_Off}"
            sleep 2
            echo
        fi
    done;

     echo "Renaming volumes to '$VOL_BASE_NAME' for docker-sync, please wait..."
     replace_in_file "s/webroot-sync/${VOL_BASE_NAME}-sync/g" $DOCKERSYNC_FILE
     replace_in_file "s/webroot-sync/${VOL_BASE_NAME}-sync/g" $DOCKER_COMPOSE_FILE
}

#function ld_command_rename-volumes_help() {
#    echo "[internal] Rename your local-docker volumes (helps to avoid collisions with other projects)."
#}
