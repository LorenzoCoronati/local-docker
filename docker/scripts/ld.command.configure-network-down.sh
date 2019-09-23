#!/usr/bin/env bash
# File
#
# This file contains configure-network-down -command for local-docker script ld.sh.
# Internal use only.

function ld_command_configure-network-down_exec() {
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}
    SUDO_REQUESTED=

    if [ "$LOCAL_IP" != "127.0.0.1" ]; then
        IP_ALIAS_SET=$(ifconfig lo0 | grep -c $LOCAL_IP)
        if ((  "$IP_ALIAS_SET" > "0" )); then
            echo -e "${Yellow}Removing an IP alias may require your password. Your password is not stored anywhere by local-docker.${Color_Off}"
            echo -e "${Yellow}Removing an IP alias from your loopback network interface.${Color_Off}"
            sudo ifconfig lo0 delete $LOCAL_IP
        fi
    fi
}

#function ld_command_configure-network-down_help() {
#    echo "Brings containers up with building step if necessary (starts docker-sync)"
#}
