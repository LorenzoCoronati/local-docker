#!/usr/bin/env bash
# File
#
# This file contains restart -command for local-docker script ld.sh.

function ld_command_restart_exec() {
    $SCRIPT_NAME down
    OK=$?
    if [ "$OK" -ne "0" ]; then
        echo -e "${Red}Putting local down failed. Database backup may have failed, so stopping process here.${Color_Off}"
        echo -e "${Red}Please investigate manually.${Color_Off}"
        cd $CWD
        exit 1
    fi
    $SCRIPT_NAME up
    $SCRIPT_NAME db-restore
}

function ld_command_restart_help() {
    echo "Put project down (with DB dump), up again and restore DB (restarts docker-sync too)"
}
