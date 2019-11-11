#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.

function ld_command_self-update_exec() {
    TAG=${1:-latest}
    # 'latest' is not a tag
    if [ "$TAG" != "latest" ]; then
      # GET /repos/:owner/:repo/releases/tags/:tag
      EXISTS=$(curl -sI https://api.github.com/repos/Exove/local-docker/releases/tags/${TAG} | head -1 |grep '200 OK' |wc -l)
      if [ "$EXISTS" -eq "0" ]; then
        echo -e "${Red}ERROR: Specifidd tag not found.${Color_Off}"
        return 1;
      fi
    fi

    DIR=".ld-tmp-" . $(date +%s)
    mkdir -v $DIR
    curl -so $DIR/${TAG}.tar.gz https://codeload.github.com/Exove/local-docker/tar.gz/${TAG}
    # Curl creates an ASCII file out of 404 response. Let's see what we have in the file.
    INFO=$(file -b $DIR/${TAG}.tar.gz | cut -d' ' -f1)

    if [ "$INFO" != "gzip" ]; then
      echo -e "${Red}ERROR: Specifidd tag not found.${Color_Off}"
      rm -rf $DIR
      return 1
    fi

    cd $DIR
    tar xvzf ${TAG}.tar.gz
    cp -r local-docker-${TAG}/docker ../
    cp -r local-docker-${TAG}/ld.sh ../
    cp -r local-docker-${TAG}/.env.example ../
    cp -r local-docker-${TAG}/.gitignore.example ../
    cd ..
    rm -rf ld-tmp
    echo -e "${Green}Project updated to version ${BGreen}${TAG}${Green}.${Color_Off}"
    echo -e "${Yellow}Review and commit changes to ./docker, ld.sh, .env.example and .gitignore.example.${Color_Off}"
    echo -e "${Yellow}Review updates in .env.example and optionally update your own .env file, too.${Color_Off}"
}

function ld_command_self-update_help() {
    echo "Updates local-docker to a specified version. Omitting version updates to the latest published full release for local-docker."
}
