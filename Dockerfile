FROM debian:latest
MAINTAINER Adam Talsma <se-adam.talsma@ccpgames.com>

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update -qty
RUN apt search mysql-server
RUN apt-get install -qqy php8.2 php8.2-cli php8.2-mcrypt php8.2-intl php8.2-mysql php8.2-curl php8.2-gd curl git default-mysql-client default-mysql-server expect

RUN git clone https://bitbucket.org/daimian/tripwire.git /var/www/tripwire
RUN curl -L https://bitbucket.org/daimian/tripwire/downloads/tripwire.sql > /tmp/tripwire.sql
RUN curl -L https://bitbucket.org/daimian/tripwire/downloads/eve_api.sql > /tmp/eve_api.sql

RUN chown -R www-data:www-data /var/www/tripwire

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80
WORKDIR /var/www/tripwire

CMD /entrypoint.sh
