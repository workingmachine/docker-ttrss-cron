FROM php:7.3-apache
RUN set -ex; \
    \
    apt-get update -y -q; \
    apt-get install -y -q --no-install-recommends \
        git \
        busybox-static \
        supervisor \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    mkdir -p /var/spool/cron/crontabs; \
    echo '*/15 * * * * php /var/www/html/update.php --feeds' > /var/spool/cron/crontabs/www-data
# testing cron
    #echo '*/1 * * * * echo "Hi" >> /var/log/cron.log 2>&1\n#' > /var/spool/cron/crontabs/www-data

# install the PHP extensions
RUN set -ex; \
    \
    savedAptMark="$(apt-mark showmanual)"; \
    \
    apt-get update -y -q; \
    apt-get install -y -q --no-install-recommends \
        libfreetype6-dev \
        libjpeg-dev \
        libpng-dev \
        libwebp-dev \
        libxml2-dev \
        libpq-dev \
    ; \
    rm -rf /var/lib/apt/lists/*; \
    \
    docker-php-ext-configure gd \
    --with-freetype-dir=/usr \
    --with-png-dir=/usr \
    --with-jpeg-dir=/usr \
    --with-webp-dir=/usr \
    ; \
    \
    docker-php-ext-install -j "$(nproc)" \
        gd \
        intl \
        opcache \
        pcntl \
        mysqli \
        pdo_mysql \
        pdo_pgsql \
    ; \
    \
# reset apt-mark's "manual" list so that "purge --auto-remove" will remove all build dependencies
    apt-mark auto '.*' > /dev/null; \
    apt-mark manual $savedAptMark; \
    ldd "$(php -r 'echo ini_get("extension_dir");')"/*.so \
        | awk '/=>/ { print $3 }' \
        | sort -u \
        | xargs -r dpkg-query -S \
        | cut -d: -f1 \
        | sort -u \
        | xargs -rt apt-mark manual; \
    \
    apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
    rm -rf /var/lib/apt/lists/*

# set recommended PHP.ini settings

# use the default production configuration
RUN mv "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"

# enable apache modules and confguration
RUN set -ex; \
    \
    a2enmod remoteip; \
    touch /etc/apache2/conf-available/remoteip.conf; \
    a2enconf remoteip; \
    \
    a2enmod headers; \
    touch /etc/apache2/conf-available/headers.conf; \
    a2enconf headers

RUN mkdir -p \
    /var/log/supervisord \
    /var/run/supervisord

COPY supervisord.conf /etc/supervisor/supervisord.conf
COPY cron.sh /cron.sh

RUN chmod +x /cron.sh

# log file for testing cron
#RUN set -ex; \
#    touch /var/log/cron.log; \
#    chmod www-data:www-data /var/log/cron.log

CMD ["/usr/bin/supervisord"]
