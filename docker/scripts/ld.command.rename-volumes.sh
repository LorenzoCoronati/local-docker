#!/usr/bin/env bash
# File
#
# This file contains rename-volumes -command for local-docker script ld.sh.

function ld_command_rename-volumes_exec() {
    if is_dockersync; then
        echo 'Turning off docker-sync, please wait...'
        docker-sync clean
    fi
    DEFAULT=$(basename $PROJECT_ROOT)
    VALID=0
    while [ "$VALID" -eq "0" ]; do
        echo "Please give me your project name [default: \"$DEFAULT\"]? "
        read -p "Project name: " PROJECTNAME
        if [ -z "$PROJECTNAME" ]; then
            PROJECTNAME=$DEFAULT
            VALID=1
        elif [[ "$PROJECTNAME" =~ ^[a-z0-9]([a-z0-9_-]*[a-z0-9])?$ ]]; then
            VALID=1
        else
            echo -e "${Red}ERROR: Project name can contain only alphabetic characters (a-z), numbers (0-9), underscore (_) and hyphen (-).${Color_Off}"
            echo -e "${Red}ERROR: Also the project name must not start or end with underscore or hyphen.${Color_Off}"
            sleep 2
            echo
        fi
    done;

     echo "Renaming volumes to '$PROJECTNAME' for docker-sync, please wait..."
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKERSYNC_FILE
     replace_in_file "s/webroot-sync/$PROJECTNAME""-sync/g" $DOCKER_COMPOSE_FILE
}

#function ld_command_rename-volumes_help() {
#    echo "[internal] Rename your local-docker volumes (helps to avoid collisions with other projects)."
#}
