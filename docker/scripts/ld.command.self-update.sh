#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.

function ld_command_self-update_exec() {
    TAG=${1}
    # CHeck the tag exists if one is provided.
    if [ ! -z "$TAG" ]; then
      echo "Verifying tag ${TAG} exists, read https://api.github.com/repos/Exove/local-docker/tags"
      # GET /repos/:owner/:repo/releases/tags/:tag
      EXISTS=$(curl -s https://api.github.com/repos/Exove/local-docker/tags | grep ${TAG} |wc -l)
      if [ "$EXISTS" -eq "0" ]; then
        echo -e "${Red}ERROR: Specifidd tag not found.${Color_Off}"
        return 1;
      fi
    fi

    DIR=".ld-tmp-"$(date +%s)
    mkdir $DIR
    if [ -z "$TAG" ]; then
      TAG='latest'
      # Latest git tags is the first one in the file.
      URL=$(curl -s https://api.github.com/repos/Exove/local-docker/tags | grep -A4 '"name"' | grep 'tarball_url' | head -1)
      URL=$(echo $URL |cut -d'"' -f4)
      # -L to follow redirects
      curl -L -s -o $DIR/${TAG}.tar.gz $URL

    else
      URL="https://api.github.com/repos/Exove/local-docker/tarball/${TAG}"
      # -L to follow redirects
      curl -L -s -o $DIR/${TAG}.tar.gz $URL
      ls -lah $DIR
    fi

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
    rm -rf $DIR
    echo -e "${Green}Project updated to version ${BGreen}${TAG}${Green}.${Color_Off}"
    echo -e "${Yellow}Review and commit changes to ./docker, ld.sh, .env.example and .gitignore.example.${Color_Off}"
    echo -e "${Yellow}Review updates in .env.example and optionally update your own .env file, too.${Color_Off}"
}

function ld_command_self-update_help() {
    echo "Updates local-docker to a specified git tag, see https://github.com/Exove/local-docker/tags. Defaults to the latest tag for local-docker."
}
