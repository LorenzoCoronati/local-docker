# https://github.com/drupal-docker/php/blob/master/7.2/Dockerfile-alpine-fpm
# + Xdebug
FROM nginx:1.16.0-alpine

# Configure Nginx. We could do this via docker-compose -recipe, but
# this is chpeaper.
COPY ./conf.d/default.conf /etc/nginx/conf.d/default.conf
