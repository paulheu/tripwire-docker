#!/bin/bash

function wait_for() {
    SERVICE=$1
    PORT=$2
    HOST=${3-localhost}
    bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT"
    while [[ $? != 0 ]]; do
        echo "waiting for $SERVICE at $HOST to online..."
        sleep 1
        bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT"
    done
    echo "connected to $SERVICE on $HOST port $PORT"
}

DB_HOSTNAME=${DB_HOSTNAME-localhost}
DB_USERNAME=${DB_USERNAME-tripwire}
DB_PASSWORD=${DB_PASSWORD-secret}
ADMIN_EMAIL=${ADMIN_EMAIL-"webmaster@localhost"}
SERVER_NAME=${SERVER_NAME-"tripwire.local"}

DBRPWD=(echo -e `date` | md5sum | awk '{ print $1 }');
DB_ROOTPASS=${DB_ROOTPASS-$DBRPWD}

service mysql restart

wait_for mysql 3306

echo $(expect -c "
set timeout 10
spawn mysql_secure_installation
expect \"Enter current password for root (enter for none):\"
send \"\r\"
expect \"Set root password?\"
send \"y\r\"
expect \"New password:\"
send \"$DB_ROOTPASS\r\"
expect \"Re-enter new password:\"
send \"$DB_ROOTPASS\r\"
expect \"Remove anonymous users?\"
send \"y\r\"
expect \"Disallow root login remotely?\"
send \"y\r\"
expect \"Remove test database and access to it?\"
send \"y\r\"
expect \"Reload privilege tables now?\"
send \"y\r\"
expect eof
")

apt-get remove -y expect
apt-get autoremove -y

mysql -uroot -p$DB_ROOTPASS -e "create database tripwire;"
mysql -uroot -p$DB_ROOTPASS -e "GRANT ALL ON tripwire.* to '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"
mysql -uroot -p$DB_ROOTPASS -e "GRANT SUPER ON *.* to '$DB_USERNAME'@'localhost' IDENTIFIED BY '$DB_PASSWORD';"

mysql -u$DB_USERNAME -p$DB_PASSWORD tripwire < /var/www/tripwire/.docker/mysql/tripwire.sql


cp /var/www/tripwire/db.inc.example.php /var/www/tripwire/db.inc.php
sed -i -e "s/host=localhost/host=$SERVER_NAME/g" /var/www/tripwire/db.inc.php
sed -i -e "s/dbname=tripwire_database/dbname=$DBNAME/g" /var/www/tripwire/db.inc.php
sed -i -e "s/username/$DB_USERNAME/g" /var/www/tripwire/db.inc.php
sed -i -e "s/password/$DB_USERPWD/g" /var/www/tripwire/db.inc.php

cp /var/www/tripwire/config.example.php /var/www/tripwire/config.php
sed -i -e "s/false)/True)/g" /var/www/tripwire/config.php
sed -i -e "s/localhost/$SERVER_NAME/g" /var/www/tripwire/config.php
sed -i -e "s/adminEmail@example.com/$ADMIN_EMAIL/g" /var/www/tripwire/config.php
sed -i -e "s/clientID/$SSO_CLIENT_ID/g" /var/www/tripwire/config.php
sed -i -e "s/secret/$SSO_SECRET_KEY/g" /var/www/tripwire/config.php
sed -i -e "s/http://localhost/index.php?mode=sso/$SSO_REDIRECT/g" /var/www/tripwire/config.php

echo "ServerName $SERVER_NAME" >> /etc/apache2/apache2.conf
unlink /etc/apache2/sites-enabled/000-default.conf
sed -i -e "s/ServerTokens OS/ServerTokens Prod/g" /etc/apache2/conf-enabled/security.conf
sed -i -e "s/ServerSignature On/ServerSignature Off/g" /etc/apache2/conf-enabled/security.conf

cat <<EOF >> /etc/apache2/sites-available/100-$SERVER_NAME.conf
<VirtualHost *:80>
    ServerAdmin $ADMIN_EMAIL
    DocumentRoot "/var/www/tripwire/public"
    ServerName $SERVER_NAME
    ServerAlias www.$SERVER_NAME
    ErrorLog /var/log/apache2/$SERVER_NAME-error.log
    CustomLog /var/log/apache2/$SERVER_NAME-access.log combined
    <Directory "/var/www/tripwire/public">
        AllowOverride All
        Order allow,deny
        Allow from all
    </Directory>
</VirtualHost>
EOF

ln -s /etc/apache2/sites-available/100-$SERVER_NAME.conf /etc/apache2/sites-enabled/

service apache2 restart
