#!/bin/bash

#  Author : Dariusz Kowalczyk
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License Version 2 as
#  published by the Free Software Foundation.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.

#####config###

FQDN=lms.example.com
userpanelFQDN=boa.example.com
WEBMASTER_EMAIL=hostmaster@example.com

LMS_DIR=/var/www/html/lms
backup_dir=/mnt/backup/lms

shell_user=lms
shell_group=lms
shell_password=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c8)

lms_db_host=localhost
lms_db_user=lms
lms_db_password=$(< /dev/urandom tr -dc A-Z-a-z-0-9 | head -c16)
lms_db=lms

virtualhost_lms_conf=/etc/apache2/sites-available/lms.conf
virtualhost_userpanel_conf=/etc/apache2/sites-available/userpanel.conf

#####install#####

sudo apt -y install apache2
sudo cp /dev/null /var/www/html/index.html

sudo apt -y install php php-pgsql php-gd php-mbstring php-posix php-bcmath php-xml php-imap php-soap php-zip

echo "date.timezone =Europe/Warsaw" |sudo tee -a /etc/php/7.4/apache2/php.ini

sudo mkdir -p $backup_dir
sudo chown -R 33:33 $backup_dir
sudo chmod -R 755 $backup_dir

sudo mkdir /etc/lms
sudo touch /etc/lms/lms.ini

echo "[database]" | sudo tee -a /etc/lms/lms.ini
echo "type = postgres" | sudo tee -a /etc/lms/lms.ini
echo "host = $lms_db_host" | sudo tee -a  /etc/lms/lms.ini
echo "user = $lms_db_user" | sudo tee -a  /etc/lms/lms.ini
echo "password = $lms_db_password" | sudo tee -a  /etc/lms/lms.ini
echo "database = $lms_db" | sudo tee -a  /etc/lms/lms.ini

echo "[directories]" | sudo tee -a /etc/lms/lms.ini
echo "sys_dir          = $LMS_DIR" | sudo tee -a /etc/lms/lms.ini
echo "backup_dir       = $backup_dir" | sudo tee -a /etc/lms/lms.ini
echo "userpanel_dir  = $LMS_DIR/userpanel" | sudo tee -a /etc/lms/lms.ini

sudo useradd -m $shell_user
echo "$shell_user:$shell_password" |sudo chpasswd

sudo mkdir $LMS_DIR
sudo chown $shell_user.$shell_group $LMS_DIR

sudo su $shell_user -c "cd /var/www/html; git clone https://github.com/lmsgit/lms.git"
sudo su $shell_user -c "cd $LMS_DIR; curl -sS https://getcomposer.org/installer | php"
sudo su $shell_user -c "cd $LMS_DIR; $LMS_DIR/composer.phar install"

sudo chown -R 33:33 /var/www/html/lms/templates_c
sudo chmod -R 755 /var/www/html/lms/templates_c
sudo chown -R 33:33 /mnt/backup/lms
sudo chmod -R 755 /mnt/backup/lms
sudo chown -R 33:33 /var/www/html/lms/documents
sudo chmod -R 755 /var/www/html/lms/documents
sudo mkdir /var/www/html/lms/js/xajax_js/deferred
sudo chown -R 33:33 /var/www/html/lms/js/xajax_js/deferred
sudo chmod -R 755 /var/www/html/lms/js/xajax_js/deferred

sudo chown 33:33 /var/www/html/lms/userpanel/templates_c
sudo chmod 755 /var/www/html/lms/userpanel/templates_c

echo "<VirtualHost *:80>" | sudo tee -a $virtualhost_lms_conf
echo "    ServerAdmin $WEBMASTER_EMAIL" | sudo tee -a $virtualhost_lms_conf
echo "    DocumentRoot /var/www/html/lms" | sudo tee -a $virtualhost_lms_conf
echo "    ServerName $FQDN" | sudo tee -a $virtualhost_lms_conf
echo "    ErrorLog logs/$FQDN-error_log" | sudo tee -a $virtualhost_lms_conf
echo "    CustomLog logs/$FQDN-access_log common" | sudo tee -a $virtualhost_lms_conf
echo "</VirtualHost>" | sudo tee -a $virtualhost_lms_conf

echo "<VirtualHost *:80>" | sudo tee -a $virtualhost_userpanel_conf
echo "    ServerAdmin $WEBMASTER_EMAIL" | sudo tee -a $virtualhost_userpanel_conf
echo "    DocumentRoot /var/www/html/lms/userpanel" | sudo tee -a $virtualhost_userpanel_conf
echo "    ServerName $userpanelFQDN" | sudo tee -a $virtualhost_userpanel_conf
echo "    ErrorLog logs/$userpanelFQDN-error_log" | sudo tee -a $virtualhost_userpanel_conf
echo "    CustomLog logs/$userpanelFQDN-access_log common" | sudo tee -a $virtualhost_userpanel_conf
echo "</VirtualHost>" | sudo tee -a $virtualhost_userpanel_conf

sudo systemctl enable apache2.service
sudo systemctl restart apache2.service

sudo apt -y install postgresql postgresql-contrib
sudo systemctl start postgres.service
sudo systemctl enable postgres.service

sudo su - postgres -c "createuser $lms_db_user"
sudo -u postgres psql -c "ALTER USER $lms_db_user PASSWORD '$lms_db_password'"
sudo su - postgres -c "createdb -E UNICODE -O $lms_db_user $lms_db"
sudo su - $shell_user -c "psql -f $LMS_DIR/doc/lms.pgsql"

echo
echo "LMS DIR $LMS_DIR"
echo "LMS shell user account: $shell_user"
echo "LMS shell user password: $shell_password" 
