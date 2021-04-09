#!/bin/sh

declare HTTPADDR

say() {
    echo "$@" | sed \
    -e "s/\(\(@\(red\|green\|yellow\|blue\|magenta\|cyan\|white\|reset\|b\|u\)\)\+\)[[]\{2\}\(.*\)[]]\{2\}/\1\4@reset/g" \
    -e "s/@red/$(tput setaf 1)/g" \
    -e "s/@green/$(tput setaf 2)/g" \
    -e "s/@yellow/$(tput setaf 3)/g" \
    -e "s/@blue/$(tput setaf 4)/g" \
    -e "s/@magenta/$(tput setaf 5)/g" \
    -e "s/@cyan/$(tput setaf 6)/g" \
    -e "s/@white/$(tput setaf 7)/g" \
    -e "s/@reset/$(tput sgr0)/g" \
    -e "s/@b/$(tput bold)/g" \
    -e "s/@u/$(tput sgr 0 1)/g"
}
# Let's validate the IP address for them fat fingererers.
function validateIpAddress() {

    ip=${1:-$1}
    if expr "$ip" : '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*$' >/dev/null; then
        for i in 1 2 3 4; do
            if [ $(echo "$ip" | cut -d. -f$i) -gt 255 ]; then
                printf "${ip} is not a valid IP address. Try again."
                #say @b@red[[$ip is not a valid IP address. Try again.]]
                printf "\n"
                fail
            fi
        done
        pass $ip
    else
        printf "\n\n"
        say @b@red[[You messed something up horribly... Do not do whatever you did again... Try again, geesh! REF: $1 is probably not what you wanted it to be.]]
        fail
    fi
}
# Prompt for user to enter an IP address
function getIpAddress() {
    read -p "Enter an IP Address: " grayloghttp
    printf = "\n"
    validateIpAddress $grayloghttp
}
function pass() {
    var=$1
    #say @u@green[[$var is a valid IP address]]
    printf "${var} is not a valid IP address.\n"
    HTTPADDR=$var
    return
}
function fail() {
    getIpAddress
}
# Get the latest package lists
printf "\n"
say @b@yellow[[Getting Latest Packages]]
say @b@yellow[[=======================]]
apt update
printf "\n\n"
say @b@green[[Done!]]
printf "\n"
# Ensure base packages are installed
printf "\n"
say @b@yellow[[Adding Base Packages and Repositories]]
# Add Universe repo
printf "\n\n"
say @b@magenta[[Adding Universe Repository]]
say @b@magenta[[==========================]]
add-apt-repository universe
printf "\n\n"
say @b@green[[Done!]]
printf "\n"
say @u@cyan[[Finished Adding Base Packages and Repositories]]
printf "\n"
# Update Package lists
printf "\n"
say @b@yellow[[Updating Package Lists]]
say @b@yellow[[======================]]
apt update
printf "\n"
say @b@green[[Done!]]
printf "\n\n"
# Ensure we have the required utilities.
say @b@yellow[[Getting Required Utilities]]
say @b@yellow[[==========================]]
apt install apt-transport-https openjdk-8-jre-headless uuid-runtime pwgen -y
apt install wget
printf "\n"
say @b@green[[Done!]]
printf "\n\n"
say @b@magenta[[Now for the fun stuff...]]
printf "\n\n"
# Install MongoDB
say @b@yellow[[Installing MongoDB]]
say @b@yellow[[==================]]
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
apt update
apt install mongodb-org -y
systemctl daemon-reload
systemctl enable mongod.service
systemctl restart mongod.service
systemctl --type=service --state=active | grep mongod
printf "\n\n"
say @b@green[[MongoDB: Done!]]
printf "\n\n"
# Install Elasticsearch
say @b@yellow[[Installing Elasticsearch]]
say @b@yellow[[========================]]
wget -q https://artifacts.elastic.co/GPG-KEY-elasticsearch -O myKey
apt-key add myKey
echo "deb https://artifacts.elastic.co/packages/oss-6.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list
apt update && apt install elasticsearch-oss
tee -a /etc/elasticsearch/elasticsearch.yml > /dev/null <<EOT
cluster.name: graylog
action.auto_create_index: false
EOT
systemctl daemon-reload
systemctl enable elasticsearch.service
systemctl restart elasticsearch.service
systemctl --type=service --state=active | grep elasticsearch
printf "\n\n"
say @b@green[[Elasticsearch: Done!]]
printf "\n\n"
# Install Graylog
say @b@yellow[[Installing Graylog]]
say @b@yellow[[==================]]
wget https://packages.graylog2.org/repo/packages/graylog-3.3-repository_latest.deb
dpkg -i graylog-3.3-repository_latest.deb
apt update && apt install graylog-server graylog-integrations-plugins -y
SECRET=$(pwgen -s 96 1)
sudo -E sed -i -e 's/password_secret =.*/password_secret = '$SECRET'/' /etc/graylog/server/server.conf
printf "\n\n"
# Get an admin user pass from user for Graylog
say @b@red[[Please enter a password for Graylog admin user login...]]
read -s -p "Enter Password: " graylogadminpass
printf "\n\n"
PASSWORD=$(echo -n $graylogadminpass | sha256sum | awk '{print $1}')
sudo -E sed -i -e 's/root_password_sha2 =.*/root_password_sha2 = '$PASSWORD'/' /etc/graylog/server/server.conf
# Get the IP address user wants to user to bind web interface to
printf "\n\n"
say @b@red[[To be able to connect to Graylog you should set http_bind_address to the public host name or a public IP address of the/this machine that you can connect to.]]
getIpAddress
printf "\n"
say @b@green[[Wrapping Up Graylog Installation...]]
printf "\n"
sudo -E sed -i -e 's/#http_bind_address = 127.0.0.1:9000/http_bind_address = '$HTTPADDR':9000/' /etc/graylog/server/server.conf
say @b@green[[HTTP Bind Address Set To: $HTTPADDR]]
printf "\n\n"
wget -t0 -c https://github.com/DocSpring/geolite2-city-mirror/raw/master/GeoLite2-City.tar.gz
tar -xvf GeoLite2-City.tar.gz
cp GeoLite2-City_*/GeoLite2-City.mmdb /etc/graylog/server
systemctl daemon-reload
systemctl enable graylog-server.service
systemctl start graylog-server.service
systemctl --type=service --state=active | grep graylog
