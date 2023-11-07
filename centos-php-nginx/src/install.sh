#!/bin/bash
set -e
. $CURRENT_FOLDER/setup.config

OS=""
OS_VER=""
OS_USER=$PHPUSER
CURRENT_FOLDER=$PWD
if $OS_USER; then
  OS_USER='nginx'
fi
# Check sudo user
if [[ "$EUID" -ne 0 ]]; then
  echo "Please run as root or sudo"
  exit 1
fi

# Check OS
echo "Check Your OS"
if cat /etc/*release | grep CentOS >/dev/null 2>&1; then
  OS="CentOS"
  if [ $(rpm --eval '%{centos_ver}') == '6' ]; then
    OS_VER="CentOS6"
  elif [ $(rpm --eval '%{centos_ver}') == '7' ]; then
    OS_VER="CentOS7"
  elif [ $(rpm --eval '%{centos_ver}') == '8' ]; then
    OS_VER="CentOS8"
  fi
elif cat /etc/*release | grep ^NAME | grep 'Amazon Linux AMI' >/dev/null 2>&1; then
  OS="Amazon Linux AMI"
  OS_VER="CentOS7"
elif cat /etc/*release | grep ^NAME | grep 'Amazon Linux' >/dev/null 2>&1; then
  OS="Amazon Linux 2"
  OS_VER="CentOS7"
else
  echo "Script doesn't support or verify this OS type/version"
  exit 1
fi

ColorGreen() {
  echo -ne $Green$1$clear
}
ColorBlue() {
  echo -ne $Blue$1$clear
}
ColorDefault() {
  echo -ne $Color_Off$1$clear
}
ColorDefault

echo ">> OS : $OS"
echo ">> OS Version : $OS_VER"
echo ">> OS User : $OS_USER"
echo ">> FOLDER INSTALL : $CURRENT_FOLDER"

function setPermission() {
  echo '>> Add your user (in this case, $OS_USER) to the apache group.'
  usermod -a -G nginx $OS_USER
  #echo '>> Change the group ownership of /var/www and its contents to the apache group.'
  chown -R $OS_USER:nginx /var/www
}

function createSwap() {
  isSwapOn=$(swapon -s | tail -1)
  if [[ "$isSwapOn" == "" ]]; then
    echo '>> Configuring swap'
    dd if=/dev/zero of=/swapfile count=4096 bs=1MiB
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    sh -c 'echo "/swapfile none swap sw 0 0" >> /etc/fstab'
  fi
}

function setTimeZone() {
  cp /usr/share/zoneinfo/Asia/Tokyo /etc/localtime
}

inputProject() {
  echo -n "Enter name project: "
  read PROJECT
}

function registerPackage() {
  if ! rpm -qa | grep epel-release &>/dev/null; then
    rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  fi
  if ! rpm -qa | grep remi-release-7 &>/dev/null; then
    rpm -Uvh https://rpms.remirepo.net/enterprise/remi-release-7.rpm
  fi
}

function setupProject() {
  while true; do
    inputProject

    if [[ $PROJECT ]]; then
      break
    fi
  done

  NGINX_CONFIG_FILE=/etc/nginx/conf.d/$PROJECT.conf

  rm $NGINX_CONFIG_FILE -f
  touch $NGINX_CONFIG_FILE
  chmod +w $NGINX_CONFIG_FILE
  echo 'server_tokens off;' >>$NGINX_CONFIG_FILE
  echo 'server {' >>$NGINX_CONFIG_FILE
  echo '  listen 80;' >>$NGINX_CONFIG_FILE
  echo '  index index.php index.html;' >>$NGINX_CONFIG_FILE
  echo '  error_log  /var/log/nginx/error.log;' >>$NGINX_CONFIG_FILE
  echo '  access_log /var/log/nginx/access.log;' >>$NGINX_CONFIG_FILE
  echo "  root /var/www/$PROJECT/public;" >>$NGINX_CONFIG_FILE
  echo '  client_max_body_size 100M;' >>$NGINX_CONFIG_FILE
  echo '  include /etc/nginx/default.d/*.conf;' >>$NGINX_CONFIG_FILE
  echo '  location / {' >>$NGINX_CONFIG_FILE
  echo '    try_files $uri $uri/ /index.php?$query_string;' >>$NGINX_CONFIG_FILE
  echo '    gzip_static on;' >>$NGINX_CONFIG_FILE
  echo '  }' >>$NGINX_CONFIG_FILE
  echo '  location ~ \.php$ {' >>$NGINX_CONFIG_FILE
  echo '        try_files $uri =404;' >>$NGINX_CONFIG_FILE
  echo '        fastcgi_split_path_info ^(.+\.php)(/.+)$;' >>$NGINX_CONFIG_FILE
  echo '        fastcgi_pass localhost:9000;' >>$NGINX_CONFIG_FILE
  echo '        fastcgi_index index.php;' >>$NGINX_CONFIG_FILE
  echo '        include fastcgi_params;' >>$NGINX_CONFIG_FILE
  echo '        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;' >>$NGINX_CONFIG_FILE
  echo '        fastcgi_param PATH_INFO $fastcgi_path_info;' >>$NGINX_CONFIG_FILE
  echo '  }' >>$NGINX_CONFIG_FILE
  echo '}' >>$NGINX_CONFIG_FILE

  rm -rf /var/www/$PROJECT
  mkdir -p /var/www/$PROJECT/public
  touch /var/www/$PROJECT/public/index.php
  echo "<?php phpinfo();?>" >>/var/www/$PROJECT/public/index.php

  #  wget https://raw.githubusercontent.com/ice-s/script/master/nginx.conf
  yes | cp -rf $CURRENT_FOLDER/nginx.conf /etc/nginx/nginx.conf
}

function installLib() {
  if [[ $OS_VER == 'CentOS6' ]] || [[ $OS_VER == 'CentOS7' ]] || [[ $OS_VER == 'CentOS8' ]]; then
    yum update -y
    yum install git -y
    yum install figlet -y
    yum install htop -y
    yum install wget -y
    cd /etc/profile.d
    #    rm -f /etc/profile.d/greeting-console.sh
    #    touch /etc/profile.d/greeting-console.sh
    #wget https://raw.githubusercontent.com/ice-s/script/master/greeting.sh
    yes | cp -rf $CURRENT_FOLDER/greeting.sh /etc/profile.d/greeting-console.sh
    chmod +x /etc/profile.d/greeting-console.sh

    #rpm -Uvh https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-x.x.x-1nodesource.x86_64.rpm
    if ! rpm -qa | grep nodejs; then
      rpm -Uvh https://rpm.nodesource.com/pub_16.x/el/7/x86_64/nodejs-16.13.1-1nodesource.x86_64.rpm
    fi
    npm install pm2 -g
    yum install redis -y
  else
    exit 1
  fi
}

php=("PHP 5.6" "PHP 7.3" "PHP 7.4" "PHP 8.0" "PHP 8.1" "Remove PHP" "Install Composer")
showPHPList(){
  echo -ne "$(ColorDefault '') ========================== PHP ==========================\n"
  for i in "${!php[@]}";
  do
    printf "%s) %s\n" "$(($i + 1))" "${php[$i]}"
  done
  printf "%s) %s\n" "0" "Exit"
  echo -ne "$(ColorDefault '') ========================== PHP ==========================\n"
}
installPHP56(){
  echo ">> Installing PHP 5.6"
  yum -y remove php*

  if [[ "$OS" == "Amazon Linux 2" ]] || [[ "$OS" == "Amazon Linux AMI" ]]; then
    if ! rpm -qa | grep webtatic &>/dev/null; then
      rpm -Uvh https://mirror.webtatic.com/yum/el7/webtatic-release.rpm
    fi
    yum install -y php56w php56w-common php56w-fpm php56w-gd php56w-mysql php56w-mbstring  php56w-ldap php-redis php56w-xml php56w-intl php56w-bcmath yum-plugin-replace --skip-broken
    #yum replace php-common --replace-with=php56w-common --skip-broken
  else
    yum install -y yum-utils
    yum-config-manager --enable remi-php56
    yum-config-manager --disable remi-php73
    yum-config-manager --disable remi-php74
    yum-config-manager --disable remi-php80
    yum-config-manager --disable remi-php81
    yum install -y php php-cli --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  fi

  yes | cp -rf $CURRENT_FOLDER/local.ini /etc/php.d/local.ini
  settingPHPFPM
  php -v
}
installPHP73(){
  echo ">> Installing PHP 7.3"
  yum -y remove php*
  if [[ "$OS" == "Amazon Linux 2" ]] || [[ "$OS" == "Amazon Linux AMI" ]]; then
    amazon-linux-extras install -y php7.3 --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  else
    yum install -y yum-utils
    yum-config-manager --disable remi-php56
    yum-config-manager --enable remi-php73
    yum-config-manager --disable remi-php74
    yum-config-manager --disable remi-php80
    yum-config-manager --disable remi-php81
    yum install -y php php-cli --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  fi
  yes | cp -rf $CURRENT_FOLDER/local.ini /etc/php.d/local.ini
  settingPHPFPM
  php -v
}
installPHP74(){
  echo ">> Installing PHP 7.4"
  yum -y remove php*
  if [[ "$OS" == "Amazon Linux 2" ]] || [[ "$OS" == "Amazon Linux AMI" ]]; then
    amazon-linux-extras install -y php7.4 --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  else
    yum install -y yum-utils
    yum-config-manager --disable remi-php56
    yum-config-manager --disable remi-php73
    yum-config-manager --enable remi-php74
    yum-config-manager --disable remi-php80
    yum-config-manager --disable remi-php81
    yum install -y php php-cli --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  fi
  yes | cp -rf $CURRENT_FOLDER/local.ini /etc/php.d/local.ini
  settingPHPFPM
  php -v
}
installPHP80(){
  echo ">> Installing PHP 8.0"
  yum -y remove php*
  if [[ "$OS" == "Amazon Linux 2" ]] || [[ "$OS" == "Amazon Linux AMI" ]]; then
    amazon-linux-extras install -y php8.0 --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  else
    #install php8 temp
    #yum install -y --enablerepo=remi-php80 php php-cli

    #install php8 longtime
    yum install -y yum-utils
    yum-config-manager --disable remi-php56
    yum-config-manager --disable remi-php73
    yum-config-manager --disable remi-php74
    yum-config-manager --enable remi-php80
    yum-config-manager --disable remi-php81
    yum install -y php php-cli --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  fi

  yes | cp -rf $CURRENT_FOLDER/local.ini /etc/php.d/local.ini
  settingPHPFPM
  php -v
}
installPHP81(){
  echo ">> Installing PHP 8.1"
  yum -y remove php*
  if [[ "$OS" == "Amazon Linux 2" ]] || [[ "$OS" == "Amazon Linux AMI" ]]; then
    amazon-linux-extras install -y php8.1 --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  else
    yum install -y yum-utils
    yum-config-manager --disable remi-php56
    yum-config-manager --disable remi-php73
    yum-config-manager --disable remi-php74
    yum-config-manager --disable remi-php80
    yum-config-manager --enable remi-php81

    yum install -y php php-cli --skip-broken
    yum install -y php-mbstring php-xml php-gd php-zip php-fpm php-redis --skip-broken
  fi
  yes | cp -rf $CURRENT_FOLDER/local.ini /etc/php.d/local.ini
  settingPHPFPM
  php -v
}

installComposer(){
  cd /
  curl -sS https://getcomposer.org/installer -o composer-setup.php
  php composer-setup.php --install-dir=/usr/local/bin --filename=composer
  composer -v
}

settingPHPFPM(){
  #/etc/php-fpm.d/www.conf
  #
  #listen.owner = $OS_USER
  #listen.group = nginx
  #listen.mode = 0660
  #
  sed -i "s/^user = apache$/user = $OS_USER/" /etc/php-fpm.d/www.conf
  sed -i "s/^group = apache$/group = nginx/" /etc/php-fpm.d/www.conf
  sed -i "s/^pm.max_children = 50$/pm.max_children = ${max_children}/" /etc/php-fpm.d/www.conf
  sed -i "s/^pm.start_servers = 5$/pm.start_servers = ${start_servers}/" /etc/php-fpm.d/www.conf
  sed -i "s/^pm.min_spare_servers = 5$/pm.min_spare_servers = ${min_spare_servers}/" /etc/php-fpm.d/www.conf
  sed -i "s/^pm.max_spare_servers = 35$/pm.max_spare_servers = ${max_spare_servers}/" /etc/php-fpm.d/www.conf
}
removePHP(){
  echo "Remove PHP"
  yum -y remove php*
}
choosePHPVersion(){
  echo -ne "$(ColorDefault 'Choose an PHP version:') "
  read a
      case $a in
        1) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installPHP56 ;;
        2) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installPHP73 ;;
        3) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installPHP74 ;;
        4) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installPHP80 ;;
        5) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installPHP81 ;;
        6) ColorDefault;echo -ne "Choose: Remove PHP and Reinstall\n";removePHP;choosePHPVersion;;
        7) ColorDefault;echo -ne "Choose: ${items[$a - 1]}\n";installComposer;choosePHPVersion ;;
    		0) echo -ne "Bye!\n";ColorDefault;break ;;
    		*) echo -ne "Wrong option.\n"; choosePHPVersion;;
      esac
}

function installWebServer() {
  if [[ $OS_VER == 'CentOS6' ]] || [[ $OS_VER == 'CentOS7' ]] || [[ $OS_VER == 'CentOS8' ]]; then
    echo '>> Installing Nginx'
    yum install -y nginx
    showPHPList
    choosePHPVersion
  fi
}

function installMySQLServer() {
  echo "Install MySQL Server"

  if ! rpm -qa | grep mysql80-community; then
    curl -sSLO https://dev.mysql.com/get/mysql80-community-release-el7-5.noarch.rpm
    rpm -ivh mysql80-community-release-el7-5.noarch.rpm
  fi

  yum install mysql-server -y
  grep 'temporary password' /var/log/mysqld.log
  mysql_secure_installation
}

function resetService() {
  if systemctl list-units | grep nginx &>/dev/null; then
    echo "Enable Nginx"
    systemctl enable nginx
    echo "Restart Nginx"
    systemctl restart nginx
  fi

  if systemctl list-units | grep php-fpm &>/dev/null; then
    echo "Enable PHP-FPM"
    systemctl enable php-fpm
    echo "Restart PHP-FPM"
    systemctl restart php-fpm
  fi

#  if systemctl list-units | grep redis.service &>/dev/null; then
#    echo "Enable Redis"
#    systemctl enable redis.service
#    echo "Restart Redis"
#    systemctl restart redis.service
#  fi

  if systemctl list-units | grep mysqld &>/dev/null; then
    echo "Enable MySQL service"
    systemctl enable mysqld
    echo "Restart MySQL service"
    systemctl restart mysqld
  fi
}

function installAll() {
  installLib
  installWebServer
  installMySQLServer
  setupProject
  createSwap
  setPermission
}

if [[ $OS_VER == 'CentOS6' ]] || [[ $OS_VER == 'CentOS7' ]] || [[ $OS_VER == 'CentOS8' ]]; then
  registerPackage
fi

items=("Install Library (git, figlet, htop, redis, composer, NodeJS, welcome)" "Install Nginx PHP" "Install MySQL Server" "Setup a Sample Project" "Create Swap" "Setup Permission (/var/www)" "Install All" "Restart Services")

showMenu(){
 echo -ne "$(ColorGreen '') ========================== MENU ==========================\n"
  for i in "${!items[@]}";
  do
     printf "%s) %s\n" "$(($i + 1))" "${items[$i]}"
  done
  printf "%s) %s\n" "0" "Exit"
  echo -ne "$(ColorGreen '') ========================== MENU ==========================\n"
}

handleAction(){
  echo -ne "$(ColorBlue 'Choose an option:') "
  read a
      case $a in
        1) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;installLib ;menu;;
        2) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;installWebServer ;menu;;
        3) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;installMySQLServer ;menu;;
        4) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;setupProject ;menu;;
        5) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;createSwap ;menu;;
        6) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;setPermission ;menu;;
        7) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;installAll ;menu;;
        8) clear;showMenu;ColorBlue;echo -ne "Starting: ${items[$a - 1]}\n";ColorDefault;resetService ;menu;;
    		0) ColorBlue;echo -ne "Bye!\n";ColorDefault;exit 0 ;;
    		*) echo -e $Red"Wrong option.\n"; handleAction;;
      esac
}

menu() {
  ColorDefault
  showMenu
  handleAction
  ColorDefault
}

menu
