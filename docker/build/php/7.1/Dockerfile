FROM xoxoxo/php-container:7.1-xdebug-1.1

# Drush needs mysql connection outside PHP. Composer needs git.
RUN apk add --no-cache mariadb-client git

# Configure PHP for local development.
COPY ./conf.d/90-mailhog.ini /usr/local/etc/php/conf.d/90-mailhog.ini

# Configure PHP to send all mail to Mailhog.
COPY ./conf.d/95-drupal-development.ini /usr/local/etc/php/conf.d/95-drupal-development.ini

# Add some aliases to Bash
COPY ./bash/bashrc /root/.bashrc

RUN apk --no-cache add patch

RUN curl -sS https://getcomposer.org/installer | php \
    && mv composer.phar /usr/local/bin/composer \
    && curl -L -o drush.phar https://github.com/drush-ops/drush-launcher/releases/download/0.4.2/drush.phar \
    && chmod +x drush.phar \
    && mv drush.phar /usr/local/bin/drush \
    && curl -L -o drupal.phar https://drupalconsole.com/installer \
    && chmod +x drupal.phar \
    && mv drupal.phar /usr/local/bin/drupal \
    && echo "export PATH=~/.composer/vendor/bin:\$PATH" >> ~/.bash_profile
