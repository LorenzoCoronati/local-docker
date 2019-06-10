FROM xoxoxo/php-composer:7.2-composer-1.8.5

# Drush needs mysql connection outside PHP. Composer needs git.
RUN apk add --no-cache mariadb-client git

# Configure PHP for local development.
COPY ./conf.d/90-mailhog.ini /usr/local/etc/php/conf.d/90-mailhog.ini

# Configure PHP to send all mail to Mailhog.
COPY ./conf.d/95-drupal-development.ini /usr/local/etc/php/conf.d/95-drupal-development.ini

# Add some aliases to Bash
COPY ./bash/bashrc /root/.bashrc

RUN curl -L -o drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.4.2/drush.phar \
    && chmod +x drush.phar \
    && mv drush.phar /usr/local/bin/drush \
    && curl -L -o drupal.phar https://drupalconsole.com/installer \
    && chmod +x drupal.phar \
    && mv drupal.phar /usr/local/bin/drupal
