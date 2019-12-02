#!/usr/bin/env bash
# File
#
# This file contains self-update -command for local-docker script ld.sh.
# Get colors.
if [ ! -f "./docker/scripts/ld.colors.sh" ]; then
    echo "File ./docker/scripts/ld.colors.sh missing."
    echo "You are currently in "$(pwd)
    exit 1;
fi
. ./docker/scripts/ld.colors.sh

# When no tag is provided we'll fallback to use the 'latest'.
TAG=${1:-latest}
TAG_PROVIDED=1
if [ -z "$1" ];then
    TAG_PROVIDED=
fi

# Check the tag exists if one is provided.
[ ! -z "$TAG_PROVIDED" ] && echo "Verifying release ${TAG} exists, please wait..."
[ -z "$TAG_PROVIDED" ]  && echo "Getting the latest release info, please wait..."
CURL="curl -sL https://api.github.com/repos/Exove/local-docker/releases/${TAG}"
EXISTS="|"$($CURL | grep -e '"name":' -e '"html_url":.*local-docker' -e '"published_at":' -e '"tarball_url":' -e '"body":' | tr '\n' '|')
if [ -z "$EXISTS" ]; then
    echo -e "${Red}ERROR: The specified release was not found.${Color_Off}"
    exit
fi

RELEASE_NAME=$(echo $EXISTS | grep -o -e '|\s*"name":[^|)]*' |cut -d'"' -f4)
RELEASE_PUBLISHED=$(echo $EXISTS | grep -o -e '|\s*"published_at":[^|)]*' |cut -d'"' -f4)
RELEASE_TARBALL=$(echo $EXISTS | grep -o -e '|\s*"tarball_url":[^|)]*' |cut -d'"' -f4)
RELEASE_PAGE=$(echo $EXISTS | grep -o -e '|\s*"html_url":[^|)]*' |cut -d'"' -f4)
RELEASE_BODY=$(echo $EXISTS | grep -o -e '|\s*"body":[^|)]*' |cut -d'"' -f4)

DIR=".ld-tmp-"$(date +%s)
mkdir $DIR
TEMP_FILENAME=release-${RELEASE_NAME}.tar.gz
if [ -z "$TAG_PROVIDED" ]; then
     # Latest git tags is the first one in the file.
    echo -e "Release name : ${BGreen} $RELEASE_NAME${Color_Off}"
    echo -e "Published    : ${BGreen} $RELEASE_PUBLISHED${Color_Off}"
    echo -e "Release page : ${BGreen} $RELEASE_PAGE${Color_Off}"
    echo -e "Release info : "
    echo -e "${BGreen}$RELEASE_BODY${Color_Off}"
    echo "Downloading release from $RELEASE_TARBALL, please wait..."
    # -L to follow redirects
    curl -L -s -o $DIR/$TEMP_FILENAME $RELEASE_TARBALL
fi

# Curl creates an ASCII file out of 404 response. Let's see what we have in the file.
INFO=$(file -b $DIR/$TEMP_FILENAME | cut -d' ' -f1)
if [ "$INFO" != "gzip" ]; then
    echo -e "${Red}ERROR: Download the the requested release failed.${Color_Off}"
    rm -rf $DIR
    return 1
fi

tar xzf $DIR/$TEMP_FILENAME -C $DIR
SUBDIR=$(ls |grep local-docker)
LIST=" .editorconfig .env.example .env.local.example .gitignore.example ./.github ./docker ./git-hooks ld.sh"
for FILE in $LIST; do
    cp -fr $DIR/$SUBDIR/$FILE . 2>/dev/null
done

rm -rf $DIR
echo
echo -e "${Green}Local-docker updated to version ${BGreen}${RELEASE_NAME}${Green}.${Color_Off}"
echo
echo -e "${Yellow}Review and commit changes to: "
for FILE in $LIST; do
    echo " - $FILE"
done

echo -e "${Yellow}Optionally update your own .env.local file, too.${Color_Off}"
