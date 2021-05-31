FROM alpine:3.8

LABEL maintainer="nileio@nileio.io"

ENV DUMB_INIT_VERSION=1.2.5
ENV PHP_VERSION=7
ENV TIMEZONE=Australia/Melbourne
ENV PHP_MEMORY_LIMIT=512M
ENV MAX_UPLOAD=50M
ENV PHP_MAX_FILE_UPLOAD=200
ENV PHP_MAX_POST=100M

ENV X2CRMDBUSER_PASSWORD=strongPass1rd
ENV MYSQLROOT_PASSWORD="root"

RUN apk add --update --no-cache && apk upgrade && \
    apk add wget tzdata \
    mysql mysql-client apache2 php7-apache2 \
    curl openssl \
    php7-cli php7-phar php7-zlib php7-zip php7-bz2 php7-ctype php7-mysqli php7-mbstring php7-pdo_mysql \
    php7-opcache php7-pdo php7-json php7-curl php7-gd php7-gmp php7-mcrypt php7-openssl php7-dom \
    php7-xml php7-iconv php7-fileinfo php7-ssh2 php7-imap php7-posix php7-session php7-calendar php7-intl


RUN cp /usr/share/zoneinfo/${TIMEZONE} /etc/localtime && \
    echo "${TIMEZONE}" > /etc/timezone

#configure mysql
RUN mkdir -p /run/mysqld && \
    chown -R mysql:mysql /run/mysqld /var/lib/mysql && \
    mysql_install_db --user=mysql --verbose=1 --basedir=/usr --datadir=/var/lib/mysql --rpm > /dev/null && \
    echo 'Database initialized' && \
    sed -i '/skip-external-locking/a log_error = \/var\/lib\/mysql\/error.log' /etc/mysql/my.cnf && \
    sed -i '/skip-external-locking/a general_log = ON' /etc/mysql/my.cnf && \
    sed -i '/skip-external-locking/a general_log_file = \/var\/lib\/mysql\/query.log' /etc/mysql/my.cnf && \
    sed -i 's|.*skip-networking.*|skip-networking|g' /etc/mysql/my.cnf && \
    ln -s /usr/lib/libxml2.so.2 /usr/lib/libxml2.so

#configure apache & php
RUN sed -i 's#AllowOverride None#AllowOverride All#' /etc/apache2/httpd.conf && \
    sed -i 's#ServerName www.example.com:80#\nServerName localhost:80#' /etc/apache2/httpd.conf && \
    sed -i 's#^DocumentRoot ".*#DocumentRoot "/www"#g' /etc/apache2/httpd.conf && \
    sed -i 's#/var/www/localhost/htdocs#/www#g' /etc/apache2/httpd.conf && \
    sed -i 's@^#LoadModule rewrite_module modules/mod_rewrite.so@LoadModule rewrite_module modules/mod_rewrite.so@g' /etc/apache2/httpd.conf && \
    sed -i 's@^#LoadModule ssl_module modules/mod_ssl.so@LoadModule ssl_module modules/mod_ssl.so@g'  /etc/apache2/httpd.conf && \
    sed -i "s|;*date.timezone =.*|date.timezone = ${TIMEZONE}|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*memory_limit =.*|memory_limit = ${PHP_MEMORY_LIMIT}|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*upload_max_filesize =.*|upload_max_filesize = ${MAX_UPLOAD}|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*max_file_uploads =.*|max_file_uploads = ${PHP_MAX_FILE_UPLOAD}|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*post_max_size =.*|post_max_size = ${PHP_MAX_POST}|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*cgi.fix_pathinfo=.*|cgi.fix_pathinfo= 0|i" /etc/php${PHP_VERSION}/php.ini && \
    sed -i "s|;*session.save_path =.*|session.save_path= /tmp/sessions|i" /etc/php${PHP_VERSION}/php.ini && \ 
    mkdir -p /run/apache2 && \
    mkdir -p /tmp/sessions && \
    chown -R apache:apache /run/apache2 /tmp/sessions
   

# create a start script for apache and mysql
# it creates a db called db on mysql start
RUN echo "#!/bin/sh" > /start.sh && \
    echo "httpd" >> /start.sh && \
    echo "nohup mysqld --bind-address 0.0.0.0 --user mysql > /dev/null 2>&1 &" >> /start.sh && \
    echo "sleep 3 && mysql -uroot -e \"CREATE DATABASE x2crm;CREATE USER x2crmuser@localhost IDENTIFIED BY '${X2CRMDBUSER_PASSWORD}';GRANT ALL ON x2crm.* TO x2crmuser@localhost;\"" >> /start.sh && \
    echo "mysqladmin -uroot password ${MYSQLROOT_PASSWORD}" >> /start.sh && \
    echo "tail -f /var/log/apache2/access.log" >> /start.sh && \
    chmod u+x /start.sh

# Add dumb-init

RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_x86_64 && \
    chmod +x /usr/local/bin/dumb-init

#

#RUN wget https://codeload.github.com/X2Engine/X2CRM/tar.gz/refs/tags/${X2CRMVERSION} && \
#RUN wget https://phoenixnap.dl.sourceforge.net/project/x2engine/X2CRM-${X2CRMVERSION}.zip && \
RUN wget https://codeload.github.com/Dolibarr/dolibarr/zip/refs/tags/13.0.1 && \
    unzip 13.0.1 -oq  && \
    mv dolibarr-13.0.1/htdocs /www && \
    chown -R apache:apache /www

WORKDIR /www

EXPOSE 80


ENTRYPOINT ["/usr/local/bin/dumb-init", "/start.sh"]