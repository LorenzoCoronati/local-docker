#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.

function ld_command_self-update_exec() {
    echo -e "${BYellow}This command is removed.${Color_Off}"
    echo -e "${Yellow}You can update the local-docker issuing command from your PROJECT_ROOT.${Color_Off}"
    echo -e "\$ ${Yellow}docker/scripts/self-update.sh [TAG].${Color_Off}"
    echo -e "${Yellow}View available releases: ${BYellow}https://github.com/Exove/local-docker/releases${Yellow}.${Color_Off}"
}

function ld_command_self-update_help() {
    echo "Updates local-docker to a specified release, see https://github.com/Exove/local-docker/releases. Defaults to the latest release (may or may not be the latest TAG)."
}
