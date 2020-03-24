#!/usr/bin/env bash
# File
#
# This file contains tls-cert-check -command for local-docker script ld.sh.

function ld_command_tls-cert-check_exec() {
    CERT_FOLDER="./docker/certs"
    mkdir -p ${CERT_FOLDER}

    CERTFILENAME="${PROJECT_NAME}--self-signed"
    CERTFILEBASE_FULL="${CERT_FOLDER}/${CERTFILENAME}"


    [ "$LD_VERBOSE" -ge "1" ] && echo -e "${BYellow}INFO:${Yellow} Checking certificate in: ${CERTFILEBASE_FULL}.crt${Color_Off}"
    COMM="openssl x509 -in ${CERTFILEBASE_FULL}.crt -noout -text"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: ${COMM}${Color_Off}"
    $COMM

}

function ld_command_tls-cert-check_help() {
    echo "Check the local TLS certificate (HTTPS)."
}


function ld_command_tls-cert-check_extended_help() {
    echo "Check the local TLS certificate (HTTPS)."
    echo " "
    echo "You can re-generate the certificate at any point."
    echo "$ ./ld tls-cert"
    echo " "
}
