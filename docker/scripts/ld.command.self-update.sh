#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.

function ld_command_self-update_exec() {
    echo -e "${BYellow}This command is removed.${Color_Off}"
    echo -e "${Yellow}You can update the local-docker issuing command from your PROJECT_ROOT.${Color_Off}"
    echo -e "${Yellow}docker/scripts/self-update.sh TAG.${Color_Off}"
}

function ld_command_self-update_help() {
    echo "[REMOVED] Update local-docker with '\$ docker/scripts/self-update.sh TAG'."
}
