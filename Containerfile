FROM registry.access.redhat.com/ubi9/php-82:latest AS leantime-src


USER 0
RUN dnf --setopt=install_weak_deps=0 --noplugins --nodocs -y install git-core
USER 1001

ARG BRANCH=develop

RUN git clone https://github.com/Leantime/leantime.git /tmp/leantime \
 && cd /tmp/leantime \
 && git fetch --tags --all \
 && git checkout ${BRANCH} \
 && git checkout -b ${BRANCH} \
 && git show --summary

# -- Build node modules
FROM registry.access.redhat.com/ubi9/nodejs-22-minimal:latest AS nodejs-step1
COPY --from=leantime-src --chown=1001:1001 /tmp/leantime /tmp/leantime

WORKDIR /tmp/leantime

RUN npm install

# -- Assemble built package
FROM registry.access.redhat.com/ubi9/php-82:latest AS php-prepare

USER 0
RUN dnf install -y curl-minimal unzip
USER 1001
COPY --from=nodejs-step1 --chown=1001:1001 /tmp/leantime /tmp/leantime

RUN mkdir /tmp/php.d && \
  echo -e '[global]\nmemory_limit = 512M\npost_max_size = 4096M\nupload_max_size = 4096M\nmax_execution_time = 1800' > /tmp/php.d/leantime.ini && \
  echo -e '[global]\nerror_reporting = E_ALL & ~E_DEPRECATED & ~E_STRICT\nlog_errors = 1\ndisplay_errors = 0' > /tmp/php.d/docker-log.ini

RUN git config --global --add safe.directory /tmp/leantime

RUN mkdir /tmp/composer_temp \
 && cd /tmp/composer_temp \
 && curl -sSLo- https://getcomposer.org/installer | php

RUN cd /tmp/leantime \
 && php /tmp/composer_temp/composer.phar install --no-dev --optimize-autoloader

# -- Build node modules - p2
FROM nodejs-step1 AS nodejs-step2
RUN rm -rf /tmp/leantime
COPY --from=php-prepare --chown=1001:1001 /tmp/leantime /tmp/leantime

WORKDIR /tmp/leantime

RUN npx update-browserslist-db@latest --production
RUN npx mix --production
RUN node generateBlocklist.mjs

# -- PHP runtime

FROM registry.access.redhat.com/ubi9/php-82:latest AS php-assemble

COPY --from=nodejs-step2 --chown=1001:1001 /tmp/leantime /tmp/src
COPY --from=php-prepare --chown=1001:1001 /tmp/php.d /etc/php.d
COPY --chown=1001:1001 extra_root/health.php /tmp/src/health.php
COPY --chown=1001:1001 extra_root/null /tmp/src/null

RUN cat <<EOF >> /opt/app-root/src/.htaccess 
<IfModule mod_headers.c>
  Header set Strict-Transport-Security "max-age=31536000" env=HTTPS
  Header always set X-Frame-Options "SAMEORIGIN"
  Header setifempty Referrer-Policy: same-origin
  Header set X-XSS-Protection "1; mode=block"
  Header set X-Permitted-Cross-Domain-Policies "none"
  Header set Referrer-Policy "no-referrer"
  Header set X-Content-Type-Options: nosniff
  ServerSignature Off
</IfModule>
EOF

RUN rm -f /tmp/src/composer.json composer.lock

RUN /usr/libexec/s2i/assemble

FROM registry.access.redhat.com/ubi9/php-82:latest AS runtime
COPY --from=php-assemble /opt /opt

CMD [ "/usr/libexec/s2i/run" ]
