#!/bin/bash
# @require /data
# @require /www
# @require acme.sh
# @require /data/logs
# @require /data/www
# @require /data/certs
# @require /data/svn

if [ $# -ne 2 ]
then
  echo "Usage: zblogcn.sh SITENAME URL"
  exit 1
fi

sitename=$1
url=$2
data=/data/www/${sitename}

. "$HOME/.acme.sh/acme.sh.env"

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
sudo chown -R ${sitename}:${sitename} ${data}/www
sudo cp /etc/resolv.conf /etc/hosts /etc/nsswitch.conf ${data}/etc
sudo cp /lib/x86_64-linux-gnu/{libc.so.6,libdl.so.2,libnss_dns.so.2,libnss_files.so.2,libresolv.so.2}  ${data}/lib/
sudo cp -R /usr/share/zoneinfo ${data}/usr/share
sudo chmod g+r -R ${data}/www
sudo ln -s /data/www/${sitename}/www/ /www/${sitename}

# SVN
sudo svnadmin create /data/svn/${sitename}

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

#    ssl_certificate      /data/certs/${sitename}/fullchain.crt;
#    ssl_certificate_key  /data/certs/${sitename}/key.key;
#    ssl_trusted_certificate    /data/certs/${sitename}/ca.pem;
#    ssl_dhparam          /data/certs/dhparam.pem;

    
     include gzip.conf;
#    include ssl.conf;

}\" > /etc/nginx/sites-available/${sitename}"
sudo ln -s /etc/nginx/sites-available/${sitename} /etc/nginx/sites-enabled/${sitename}

# Certificate
mkdir /data/certs/${sitename}
#$HOME/.acme.sh/acme.sh --issue -d ${url} --dns dns_dp
#$HOME/.acme.sh/acme.sh  --installcert  -d  ${url}   \
#        --keypath   /data/certs/${sitename}/key.key \
#        --certpath  /data/certs/${sitename}/cert.pem \
#        --capath /data/certs/${sitename}/ca.pem \
#        --fullchainpath /data/certs/${sitename}/fullchain.crt
sudo service php7.1-fpm restart
sudo service nginx reload
