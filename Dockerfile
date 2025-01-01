FROM debian:latest
LABEL MAINTAINER="Paul van der Heu<pvdh@outlook.com>"

ENV DEBIAN_FRONTEND noninteractive

RUN apt-get -qq update
RUN apt-get -qq install php php-cli php-mcrypt php-intl php-mysql php-curl php-gd php-mbstring curl git mysql-client mysql-server expect

RUN git clone https://bitbucket.org/daimian/tripwire.git /var/www/tripwire

RUN chown -R www-data:www-data /var/www/tripwire

COPY entrypoint.sh /entrypoint.sh

EXPOSE 80
WORKDIR /var/www/tripwire

CMD ["/entrypoint.sh"]
