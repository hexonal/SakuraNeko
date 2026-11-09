FROM php:8.4-fpm-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash ca-certificates caddy cron curl git libfcgi-bin procps redis-tools supervisor unzip \
    libfreetype6-dev libgmp-dev libicu-dev libjpeg62-turbo-dev libpng-dev libzip-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j2 bcmath gd gettext gmp intl mysqli pcntl pdo_mysql sockets sysvsem zip opcache \
    && pecl install igbinary redis \
    && docker-php-ext-enable igbinary redis \
    && rm -rf /var/lib/apt/lists/* /tmp/pear

COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer
COPY php-fpm.conf /usr/local/etc/php-fpm.conf
COPY php.ini /usr/local/etc/php/conf.d/zz-lotusboard.ini
COPY supervisord.conf /etc/supervisor/lotusboard.conf
COPY entrypoint.sh /usr/local/bin/lotusboard-entrypoint
RUN chmod +x /usr/local/bin/lotusboard-entrypoint \
    && mkdir -p /www /wwwlogs /run/caddy /run/supervisor /etc/crontabs

ENV RUN_WORKERS=true RUN_SCHEDULER=true
WORKDIR /www
EXPOSE 80
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD SCRIPT_NAME=/fpm-ping SCRIPT_FILENAME=/fpm-ping REQUEST_METHOD=GET cgi-fcgi -bind -connect /tmp/php-cgi.sock | grep -q pong
ENTRYPOINT ["/usr/local/bin/lotusboard-entrypoint"]
CMD ["supervisord", "-c", "/etc/supervisor/lotusboard.conf"]
