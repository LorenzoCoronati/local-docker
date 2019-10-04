#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.

function ld_command_self-update_exec() {
    TAG=${1}
    if [ -z "$TAG" ]; then
      echo -e "${Red}ERROR: You must provide a release tag to update to.${Color_Off}"
      return 1
    fi
    mkdir ld-tmp
    cd ld-tmp
    curl -o ${TAG}.tar.gz https://codeload.github.com/Exove/local-docker/tar.gz/${TAG}
    cp -r local-docker-${TAG}/docker ../
    cp -r local-docker-${TAG}/ld.sh ../
    cp -r local-docker-${TAG}/.env.example ../
    cp -r local-docker-${TAG}/.gitignore.example ../
    cd ..
    rm -rf ld-tmp
}

function ld_command_self-update_help() {
    echo "Updates local-docker to a specified version."
}
