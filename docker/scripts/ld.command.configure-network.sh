#!/usr/bin/env bash
# File
#
# This file contains configure-network -command for local-docker script ld.sh.
# Internal use only.

function ld_command_configure-network_exec() {
    LOCAL_IP=${LOCAL_IP:-127.0.0.1}
    LOCAL_DOMAIN=${LOCAL_DOMAIN:-localhost}
    SUDO_REQUESTED=

    if [ "$LOCAL_IP" == "127.0.0.1" ]; then
        echo -e "${Yellow}Project is using IP address 127.0.0.1, so IP alias is not needed.${Color_Off}"
    else
        IP_ALIAS_SET=$(ifconfig lo0 | grep -c $LOCAL_IP)
        if [  "$IP_ALIAS_SET" == "0" ]; then
            echo -e "${Yellow}Configuring networking may require your password. Your password is not stored anywhere by local-docker.${Color_Off}"
            echo -e "${Yellow}Adding an IP alias to your loopback network interface.${Color_Off}"
            echo -e "${Yellow}Alias will be removed when you put this project down, or reboot your computer.${Color_Off}"
            SUDO_REQUESTED=1
            sudo ifconfig lo0 alias $LOCAL_IP
        else
            echo -e "${Green}IP alias $LOCAL_IP is already set.${Color_Off}"
        fi
    fi

    DOMAIN_SET=$(egrep -e $LOCAL_IP'\s*([a-z0-9\.-]*\s?\s*)*('$LOCAL_DOMAIN')' /etc/hosts)
    if [ "$LOCAL_DOMAIN" != "localhost" ]; then
        if [ -z "$DOMAIN_SET" ]; then
            echo -e "${Yellow}Adding domain $LOCAL_DOMAIN to your hosts file to poin to $LOCAL_IP.${Color_Off}"
            echo -e "${BYellow}NOTE: This DNS record is not removed automatically.${Color_Off}"
            if [ -z "$SUDO_REQUESTED" ]; then
                echo -e "${Yellow}Configuring networking may require your password. Your password is not stored anywhere by local-docker.${Color_Off}"
                echo
            fi
            sudo bash -c "echo && echo '############  Project (local-docker): $PROJECT_NAME   ##############' >> /etc/hosts"
            sudo bash -c "echo '$LOCAL_IP      $LOCAL_DOMAIN' >> /etc/hosts"
        else
            echo -e "${Green}Domain $LOCAL_DOMAIN is already configured.${Color_Off}"
        fi
    fi
}

#function ld_command_configure-network_help() {
#    echo "Brings containers up with building step if necessary (starts docker-sync)"
#}
