#!/usr/bin/env bash
# File
#
# This file contains rename-volumes -command for local-docker script ld.sh.

function ld_command_rename-volumes_exec() {
    VOL_BASE_NAME=$1
    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo
        echo -e "${BBlack}==  Container volume base name ==${Color_Off}"
        if [[ -z "$VOL_BASE_NAME" ]] || [ ! -z "$VOL_BASE_NAME_DEFAULT_FAILED" ]; then
            read -p "Container volume base name ['$VOL_BASE_NAME']: " ANSWER
        else
            echo -e "Using default value: ${VOL_BASE_NAME}"
            ANSWER=${VOL_BASE_NAME}
        fi
        if [ -z "$ANSWER" ]; then
            VALID=1
        elif [[ "$ANSWER" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]; then
            VOL_BASE_NAME=$ANSWER
            VALID=1
        else
            echo -e "${Red}ERROR: Volume base name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-) and start and end with alphabetic characters or numbers.${Color_Off}"
            echo -e "${Red}ERROR: Volume base name must not start or end with underscore or hyphen.${Color_Off}"
            VOL_BASE_NAME_DEFAULT_FAILED=1
            sleep 2
            echo
        fi
    done;

    if is_dockersync; then
        [ "$LD_VERBOSE" -ge "1" ] && echo 'Turning off docker-sync (clean), please wait...'
        docker-sync clean
    fi
    define_configuration_value VOL_BASE_NAME $VOL_BASE_NAME
    import_config

    echo "Renaming volumes to '$VOL_BASE_NAME' for docker-sync, please wait..."
    replace_in_file "s/webroot-sync/${VOL_BASE_NAME}-sync/g" $DOCKERSYNC_FILE
    replace_in_file "s/webroot-sync/${VOL_BASE_NAME}-sync/g" $DOCKER_COMPOSE_FILE
    replace_in_file "s/webroot-nfs/${VOL_BASE_NAME}-nfs/g" $DOCKER_COMPOSE_FILE
}

#function ld_command_rename-volumes_help() {
#    echo "[internal] Rename your local-docker volumes (helps to avoid collisions with other projects)."
#}
