#!/bin/bash
# @require /data
# @require /www
# @require /data/logs
# @require /data/www
# @require /data/certs
# @require /data/svn
clear
printf "
#######################################################################
#                         LNMP for Ubuntu 16+                         #
#                         author:  zblogcn                            #
#######################################################################
"

# Check if user is root
[ $(id -u) != "0" ] && { echo "${CFAILURE}Error: You must be root to run this script${CEND}"; exit 1; }
sudo mkdir config default
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/create-site.sh
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/default/index.php -P default
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/config/global.conf -P config
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/config/gzip.conf -P config
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/config/nginx.conf -P config
wget https://raw.githubusercontent.com/zblogcn/QuickZBP/master/src/config/ssl.conf -P config

ask_MYSQL_PASS() {
    read -p ">>>>>>>>Please enter the password for root of mysql:" mysql_root_password
    echo "You entered: $mysql_root_password"

    #mysql_root_password="zblogcn"
    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password password ${mysql_root_password}'
    sudo debconf-set-selections <<< 'mysql-server mysql-server/root_password_again password ${mysql_root_password}'
    sudo debconf-set-selections <<< 'mysql-server mysql-server/start_on_boot: true'
    sudo apt-get install -y mysql-server
}

while  true; do
    read -p ">>>>>>>>>>>>>>>Do you want to install mysql?(y/n)" yn
    case $yn in
    [Yy]* ) ask_MYSQL_PASS; break;;
    [Nn]* ) break;;
    * ) echo "Please answer yes or no.";;
    esac
done

sudo apt-get -y update
# upgrade software
sudo apt-get -y upgrade
# upgrade ubuntu
#sudo apt-get -y dist-upgrade
sudo apt-get -y install nginx postgresql postgresql-client git
sudo mkdir /data/ /data/logs/ /data/logs/nginx /data/www/ /data/tools /data/certs /www/
sudo apt-get -y install python-software-properties software-properties-common
sudo LC_ALL=C.UTF-8 add-apt-repository -y ppa:ondrej/php
sudo apt-get -y update
sudo apt-get -y install php7.1-fpm php7.1-gd php7.1-curl php7.1-mysql php7.1-cli php7.1-xml php7.1-json  php7.1-sqlite3 php7.1-mbstring php7.1-pgsql php7.1-opcache php7.1-bcmath php7.1-mcrypt
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer

sitename='default'
url='localhost'
data=/data/www/${sitename}

# User permissions
sudo groupadd ${sitename}
sudo useradd -g ${sitename} ${sitename}
sudo usermod -a -G www-data ${sitename}
whoami | sudo xargs usermod -a -G ${sitename}

# Logs
sudo mkdir /data/logs/nginx/${sitename}
sudo chown -R www-data:${sitename} /data/logs/nginx/${sitename}
# Website
sudo mkdir ${data}
sudo mkdir -p ${data}/www ${data}/bin ${data}/dev ${data}/tmp ${data}/lib ${data}/etc/
sudo mkdir -p ${data}/usr/sbin/ ${data}/usr/share/zoneinfo/ ${data}/var/run/nscd/
sudo mkdir -p ${data}/var/lib/php/sessions
sudo cp -a /dev/zero /dev/urandom /dev/null ${data}/dev/
sudo chmod --reference=/tmp ${data}/tmp/
sudo chmod --reference=/var/lib/php/sessions ${data}/var/lib/php/sessions
sudo chown -R root:root ${data}/
sudo chown -R ${sitename}:${sitenme} ${data}/www
sudo cp /etc/resolv.conf /etc/hosts /etc/nsswitch.conf ${data}/etc
sudo cp /lib/x86_64-linux-gnu/{libc.so.6,libdl.so.2,libnss_dns.so.2,libnss_files.so.2,libresolv.so.2}  ${data}/lib/
sudo cp -R /usr/share/zoneinfo ${data}/usr/share
sudo chmod g+r -R ${data}/www
sudo ln -s /data/www/${sitename}/www/ /www/${sitename}

#copy default site files
sudo cp default/index.php ${data}/www
sudo apt-get install -y unzip
wget https://files.phpmyadmin.net/phpMyAdmin/4.7.0/phpMyAdmin-4.7.0-all-languages.zip
unzip phpMyAdmin-4.7.0-all-languages.zip
sudo cp -r phpMyAdmin-4.7.0-all-languages ${data}/www/phpmyadmin

# Conf files
sudo bash -c "echo \"[${sitename}]
user = ${sitename}
group = ${sitename}
listen = /var/run/php71-fpm-${sitename}.sock
listen.owner = www-data
listen.group = www-data
php_admin_value[disable_functions] = exec,passthru,shell_exec,system
php_admin_flag[allow_url_fopen] = off
pm = dynamic
pm.max_children = 5
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 3
chroot = /data/www/${sitename}
chdir = /www\" > /etc/php/7.1/fpm/pool.d/${sitename}.conf"
sudo bash -c "echo \"server {
    include global.conf;

    root /data/www/${sitename}/www;
 #   server_name ${url};
    access_log /data/logs/nginx/${sitename}/\\\$year-\\\$month-\\\$day-access.log;
    error_log /data/logs/nginx/${sitename}/error.log;

    location / {
        try_files \\\$uri \\\$uri/ =404;
#        include location-root.conf;
    }

    # Custom Tag Here
    location ~ \.php\\\$ {
        try_files \\\$uri =404;
        fastcgi_split_path_info ^(.+\.php)(/.+)\\\$;
        fastcgi_pass unix:/var/run/php71-fpm-${sitename}.sock;
        fastcgi_index index.php;
        fastcgi_param DOCUMENT_ROOT  /www;
        fastcgi_param SCRIPT_FILENAME  /www\\\$fastcgi_script_name;
#        fastcgi_param SCRIPT_FILENAME \\\$document_root\\\$fastcgi_script_name;
        include fastcgi_params;
    }
    
     include gzip.conf;

}\" > /etc/nginx/sites-available/${sitename}"
#default site is on
#sudo ln -s /etc/nginx/sites-available/default /etc/nginx/sites-enabled/default
#!includedir /etc/mysql/conf.d/
# Certificate
sudo mkdir /data/certs/${sitename}

sudo cp config/nginx.conf /etc/nginx/ -f
sudo cp config/ssl.conf /etc/nginx/ -f
sudo cp config/gzip.conf /etc/nginx/ -f
sudo cp config/global.conf /etc/nginx/ -f

sudo service php7.1-fpm restart
sudo service nginx reload

printf "
you have installed LNMP on your VPS
please visit http://ip/phpmyadmin  to manage your mysql.
"
