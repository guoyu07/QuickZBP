#!/bin/bash
# @require /data
# @require /www
# @require acme.sh
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
sudo apt-get -y update
# upgrade software
sudo apt-get -y upgrade
# upgrade ubuntu
#sudo apt-get -y dist-upgrade
sudo apt-get -y install nginx postgresql postgresql-client zsh git
sudo mkdir /data/ /data/logs/ /data/logs/nginx /data/www/ /data/tools /data/certs /www/
LC_ALL=C.UTF-8 sudo add-apt-repository ppa:ondrej/php -y
sudo apt-get -y update
sudo apt-get -y install php7.1-fpm php7.1-gd php7.1-curl php7.1-mysql php7.1-cli php7.1-xml php7.1-json  php7.1-sqlite3 php7.1-mbstring php7.1-cli php7.1-pgsql php7.1-opcache
#sh -c "$(wget https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh -O -)"
curl -sS https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer


#wget -O -  https://get.acme.sh | sh
#sudo openssl dhparam -out /data/certs/dhparam.pem 2048



sitename='default'
url='localhost'
data=/data/www/${sitename}

#. "$HOME/.acme.sh/acme.sh.env"

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

# SVN
#sudo svnadmin create /data/svn/${sitename}

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
    server_name ${url};
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
sudo ln -s /etc/nginx/sites-available/${sitename} /etc/nginx/sites-enabled/${sitename}

# Certificate
mkdir /data/certs/${sitename}

sudo cp nginx.conf /etc/nginx/ -f
sudo cp ssl.conf /etc/nginx/ -f
sudo cp gzip.conf /etc/nginx/ -f
sudo cp global.conf /etc/nginx/ -f

sudo service php7.1-fpm restart
sudo service nginx reload
