#!/bin/sh

sed -i "s|nodejs_template|${PROJECT_NAME}_nodejs|g" /etc/nginx/conf.d/nodejs.conf
rm /etc/nginx/conf.d/default.conf

cd /etc/nginx
exec $(which nginx) -g "daemon off;"
