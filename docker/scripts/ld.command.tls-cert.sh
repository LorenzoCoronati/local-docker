#!/usr/bin/env bash
# File
#
# This file contains tls-cert -command for local-docker script ld.sh.

function ld_command_tls-cert_exec() {
    CERT_FOLDER="./docker/certs"
    mkdir -p ${CERT_FOLDER}

    CERTFILENAME="${PROJECT_NAME}--self-signed"
    CERTFILEBASE_FULL="${CERT_FOLDER}/${CERTFILENAME}"
    CONF_FILE=${CERTFILEBASE_FULL}.conf
    CONF_FILE_TMP=${CONF_FILE}.tmp
    CERTS_FILE=${CERT_FOLDER}/certs.yml

    # Create the local project cert confiuration (tmp file). Ideally it should
    # not change so we create it only when it is not present.
    # However, since we actually may have the file but need to create cert with
    # some other configurations, create the file as temporary file first.
    touch ${CONF_FILE_TMP}
    echo "[req]"                                > ${CONF_FILE_TMP}
    echo "default_bits       = 2048"            >> ${CONF_FILE_TMP}
    echo "distinguished_name = dn"              >> ${CONF_FILE_TMP}
    echo "prompt             = no"              >> ${CONF_FILE_TMP}
    echo "[dn]"                                 >> ${CONF_FILE_TMP}
    echo "C=FI"                                 >> ${CONF_FILE_TMP}
    echo "ST=Helsinki"                          >> ${CONF_FILE_TMP}
    echo "OU=LocalDocker"                       >> ${CONF_FILE_TMP}
    echo "emailAddress=admin@${LOCAL_DOMAIN}"   >> ${CONF_FILE_TMP}
    echo "CN=*.${LOCAL_DOMAIN}"                 >> ${CONF_FILE_TMP}
    echo "[req_ext]"                            >> ${CONF_FILE_TMP}
    echo "subjectAltName = @alt_names"          >> ${CONF_FILE_TMP}
    echo "[alt_names]"                          >> ${CONF_FILE_TMP}
    echo "DNS.0 = ${LOCAL_DOMAIN}"              >> ${CONF_FILE_TMP}
    echo "DNS.1 = www.${LOCAL_DOMAIN}"          >> ${CONF_FILE_TMP}
    echo "DNS.2 = traefik.${LOCAL_DOMAIN}"      >> ${CONF_FILE_TMP}
    echo "DNS.3 = whoami.${LOCAL_DOMAIN}"       >> ${CONF_FILE_TMP}
    echo "DNS.4 = solr.${LOCAL_DOMAIN}"         >> ${CONF_FILE_TMP}
    echo "DNS.5 = adminer.${LOCAL_DOMAIN}"      >> ${CONF_FILE_TMP}
    echo "DNS.6 = mailhog.${LOCAL_DOMAIN}"      >> ${CONF_FILE_TMP}

    if [ ! -f "$CONF_FILE" ]; then
        mv $CONF_FILE_TMP $CONF_FILE
        [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Green}TLS Certificate configuration created: ${BGreen}${CONF_FILE}.${Color_Off}"
    else
        echo -e "${Red}ERROR: TLS certificate configuration exists, new config written to: ${BRed}${CONF_FILE_TMP}.${Color_Off}"
        echo -e "${Red}Please investigate manually.${Color_Off}"
        cd $CWD
        exit 1
    fi

    # Heavily borrowed from https://github.com/abmruman/traefik-docker-compose/
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} Generating random key...${Color_Off}"

    COMM="openssl genrsa -out ${CERTFILEBASE_FULL}.key"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: ${COMM} >/dev/null${Color_Off}"
    $COMM >/dev/null

    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} Generating CSR file...${Color_Off}"
    COMM="openssl req -new -key ${CERTFILEBASE_FULL}.key -out ${CERTFILEBASE_FULL}.csr -config ${CONF_FILE}"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: ${COMM}${Color_Off}"
    $COMM

    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} Generating TLS file (the HTTPS certificate) ...${Color_Off}"
    COMM="openssl x509 -req -days 365 -in ${CERTFILEBASE_FULL}.csr -signkey ${CERTFILEBASE_FULL}.key -out ${CERTFILEBASE_FULL}.crt -extensions req_ext -extfile ${CERTFILEBASE_FULL}.conf"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${Cyan}Next: ${COMM}${Color_Off}"
    $COMM

    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} Writing instructions for Traefik how to use our certs.${Color_Off}"
    echo "# https://docs.traefik.io/v2.0/https/tls/"            > ${CERTS_FILE}
    echo "tls:"                                                 >> ${CERTS_FILE}
    echo "  stores:"                                            >> ${CERTS_FILE}
    echo "    default:"                                         >> ${CERTS_FILE}
    echo "        defaultCertificate:"                          >> ${CERTS_FILE}
    echo "          certFile: /certs/${CERTFILENAME}.crt"       >> ${CERTS_FILE}
    echo "          keyFile: /certs/${CERTFILENAME}.key"        >> ${CERTS_FILE}
    echo "#  certificates:"                                     >> ${CERTS_FILE}
    echo "#  # tls.certificates is array"                       >> ${CERTS_FILE}
    echo "#    - certFile: /path/to/other-domain.cert"          >> ${CERTS_FILE}
    echo "#      keyFile: /path/to/other-domain.key"            >> ${CERTS_FILE}
    echo "#    - certFile: /path/to/more-domain.cert"           >> ${CERTS_FILE}
    echo "#      keyFile: /path/to/more-domain.key"             >> ${CERTS_FILE}
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} You may generate more certs manually, and then add the files to ./docker/certs/certs.yml file.${Color_Off}"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} Traefik uses them if the domain matches, and generates a temporary cert if no matching cert file is found${Color_Off}"
    [ "$LD_VERBOSE" -ge "2" ] && echo -e "${BYellow}INFO:${Yellow} More info in local-docker README file.${Color_Off}"

}

function ld_command_tls-cert_help() {
    echo "Create local TLS certificate (HTTPS). Does not adjust your Traefik settings, so consult you docker-compose.yml file's traefik -servicde labels for required changes."
}


function ld_command_tls-cert_extended_help() {
    echo "Create local TLS certificate (HTTPS)"
    echo " "
    echo "Certificates and the configuration are created during init -phase"
    echo "prefixed with the project neme and stored in docker/certs -folder."
    echo "Traefik learns about your HTTPS certificates via ./docker/certs/certs.yml -file"
    echo "(mounted volume)."
    echo " "
    echo "Certificate is a multidomain certificate: "
    echo "    *.${LOCAL_DOMAIN:-example.com}"
    echo " "
    echo "You can re-generate the files any time. Should you need more than one certificate"
    echo "you can rename existing files and generate new ones using command "
    echo "$ ./ld tls-cert"
    echo " "
    echo "Remember to update also file ./docker/certs/certs.yml to contain all the certificates"
    echo "your project needs."
    echo " "
    echo "NOTE: By default Traefik configuration is set to handle also HTTPS requests, but "
    echo "redirection HTTP -> HTTPS (nginx, mailhog, solr, etc.) need docker-compose.yml file "
    echo "edits to work properly".
}
