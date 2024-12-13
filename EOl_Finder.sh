
# Error may occur if jq is not installed on host
############################################################################################
# Update applications
debianphpinstall() {
    apt install -y php-fpm
    ./EOLTracker.sh
}
RHphpinstall() {
    chmod +x update-php.sh
    ./rhupdate-php.sh
}
python310() {
    apt install -y python3.10 python3.10-venv python3.10-dev
    ./EOLTracker.sh
}
node_exporter_install() {
    wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
    tar xvf node_exporter-1.6.1.linux-amd64.tar.gz
    sudo mv node_exporter-1.6.1.linux-amd64/node_exporter /usr/local/bin/


    sudo useradd --no-create-home --shell /bin/false node_exporter

    sudo tee /etc/systemd/system/node_exporter.service > /dev/null <<EOL
[Unit]
Description=Node Exporter
Documentation=https://prometheus.io/docs/guides/node-exporter/
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9200
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOL

    if command -v apt > /dev/null; then
        sudo apt update
        sudo apt install -y firewalld
    elif command -v yum > /dev/null; then
        sudo yum install -y firewalld
    fi

    sudo systemctl start firewalld
    sudo firewall-cmd --add-port=9200/tcp --permanent
    sudo firewall-cmd --reload

    sudo systemctl daemon-reload
    sudo systemctl enable node_exporter
    sudo systemctl start node_exporter

    sudo systemctl status node_exporter
}


installSaltminionDeb(){
    rm -rf /etc/apt/keyrings
    mkdir /etc/apt/keyrings
    sudo  curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | sudo tee /etc/apt/keyrings/salt-archive-keyring.pgp
    sudo curl -fsSL https://github.com/saltstack/salt-install-guide/releases/latest/download/salt.sources | sudo tee /etc/apt/sources.list.d/salt.sources
    echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring.pgp arch=amd64] https://packages.broadcom.com/artifactory/saltproject-deb/ stable main" | sudo tee /etc/apt/sources.list.d/salt.list
    apt-get update
    apt upgrade -y
    sudo apt-get install salt-master -y
    sudo apt-get install salt-minion -y
    sudo apt-get install salt-ssh -y
    sudo apt-get install salt-syndic -y
    sudo apt-get install salt-cloud -y
    sudo apt-get install salt-api -y
    echo "master <IP or Hostname>" > /etc/salt/minion

    sudo systemctl enable salt-minion && sudo systemctl start salt-minion
    sudo systemctl enable salt-syndic && sudo systemctl start salt-syndic
    sudo systemctl enable salt-api && sudo systemctl start salt-api
    ./EOLTracker.sh
}

installSaltminionRH(){
    rm -rf /etc/apt/keyrings
    mkdir /etc/apt/keyrings
    rpm --import https://repo.saltproject.io/salt/py3/redhat/8/x86_64/SALT-PROJECT-GPG-PUBKEY-2023.pub
    curl -fsSL https://repo.saltproject.io/salt/py3/redhat/8/x86_64/latest.repo | sudo tee /etc/yum.repos.d/salt.repo
    sudo yum install salt-master -y
    sudo yum install salt-minion -y
    sudo yum install salt-ssh -y
    sudo yum install salt-syndic -y
    sudo yum install salt-cloud -y
    sudo yum install salt-api -y
    echo "master: <IP or Hostname>" > /etc/salt/minion
    sudo systemctl enable salt-master && sudo systemctl start salt-master
    sudo systemctl enable salt-minion && sudo systemctl start salt-minion
    sudo systemctl enable salt-syndic && sudo systemctl start salt-syndic
    sudo systemctl enable salt-api && sudo systemctl start salt-api
}
############################################################################################
host=$(hostname)
os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')

Flav=$(grep PRETTY_NAME= /etc/os-release | cut -d'"' -f2 | awk -F ' ' '{print $1}')
ver=$(grep VERSION_ID= /etc/os-release | awk -F'"' '{print $2}')

if [[ $Flav == "Red Hat Enterprise Linux" ]]; then
    ver=$(grep VERSION_ID= /etc/os-release | awk -F'"' '{print $2}' | awk -F. '{print $1}')
    Flav="CentOS"
fi

if [[ $Flav == "Rocky" ]]; then
    ver=$(grep VERSION_ID= /etc/os-release | awk -F'"' '{print $2}' | awk -F. '{print $1}')
    Flav="rocky-linux"
fi

# Install jq based on the OS flavor
if [[ $Flav == "Ubuntu" ]]; then
    echo "Installing jq"
    apt-get install jq -y
elif [[ $Flav == "CentOS" || $Flav == "rocky-linux" ]]; then
    echo "Installing jq"
    yum install jq -y
fi

# Check PHP version
PHPver=$(php -r 'echo PHP_VERSION;' 2>/dev/null | awk -F. '{print $1"."$2}')
if [[ -z "$PHPver" ]]; then
    PHPver="PHP is not installed on $host"
fi

# Check MariaDB version
MariaDBver=$(mysql --version 2>/dev/null | awk '{print $5}' | awk -F'-MariaDB,' '{print $1}' | awk -F. '{print $1"."$2}')
if [[ -z "$MariaDBver" ]]; then
    MariaDBver="MariaDB is not installed on $host"
fi

# Check MySQL version
mysqlver=$(mysql --version 2>/dev/null | awk '{print $5}' | awk -F'-MariaDB,' '{print $1}')
if [[ -z "$mysqlver" ]]; then
    mysqlver="MySQL is not installed on $host"
fi

# Check Python version
Pythonver=$(python3 --version 2>/dev/null | cut -d' ' -f2 | awk -F. '{print $1"."$2}')
if [[ -z "$Pythonver" ]]; then
    Pythonver="Python is not installed on $host"
fi

# Check Salt version
Saltver=$(salt --version 2>/dev/null | awk -F" " '{print $2}' | awk -F. '{print $1}')
if [[ -z "$Saltver" ]]; then
    Saltver="Salt Minion is not installed"
fi

# Check Puppet version
Puppetver=$(puppet --version 2>/dev/null)
if [[ -z "$Puppetver" ]]; then
    Puppetver="Puppet is not installed on $host"
fi

############################################################################################
# OS EOL
osurl="https://endoflife.date/api/$Flav/$ver.json"
response=$(curl -s "$osurl")
EOL=$(echo "$response" | jq -r '.eol')
OSEOL="End of life date for $Flav $ver: $EOL"

# PHP EOL
PHPurl="https://endoflife.date/api/PHP/$PHPver.json"
PHPresponse=$(curl -s "$PHPurl")
PHPEOL=$(echo "$PHPresponse" | jq -r '.eol')
PHPEOLO="End of life for PHP $PHPver: $PHPEOL"

# MariaDB EOL
Mariaurl="https://endoflife.date/api/mariadb/$MariaDBver.json"
Mariaresponse=$(curl -s "$Mariaurl")
MariaEOL=$(echo "$Mariaresponse" | jq -r '.eol')
MariaDBEOL="End of life for MariaDB $MariaDBver: $MariaEOL"

# Python EOL
Pyurl="https://endoflife.date/api/Python/$Pythonver.json"
Pyresponse=$(curl -s "$Pyurl")
PyEOL=$(echo "$Pyresponse" | jq -r '.eol')
Pythoneol="End of life for Python $Pythonver: $PyEOL"

# Salt-stack EOL
Salturl="https://endoflife.date/api/salt/$Saltver.json"
Saltresponse=$(curl -s "$Salturl")
SaltEOL=$(echo "$Saltresponse" | jq -r '.eol')
SaltStackEOL="End of life for SaltStack (Minion): $SaltEOL"

# Puppet EOL
Puppeturl="https://endoflife.date/api/puppet/$Puppetver.json"
Puppetresponse=$(curl -s "$Puppeturl")
ppteol=$(echo "$Puppetresponse" | jq -r '.eol')
Puppeteol="End of life for Puppet is: $ppteol"

############################################################################################
# Check if applications are running (and install if not?)

# Salt Minion
SaltConnection=$(cat /etc/salt/minion)
if [[ -f /etc/salt/minion ]]; then
    SaltConnection=$(cat /etc/salt/minion)
elif [[ ! -f /etc/salt/minion ]]; then
    SaltConnection="no master"
fi
saltMinionStatus=$(systemctl is-active salt-minion.service)
if [[ $saltMinionStatus == "active" ]]; then
    saltMinion="Salt Minion is installed and running on $host and connected to $SaltConnection"
elif [[ $saltMinionStatus == "inactive" ]] || [[ $saltMinionStatus == "failed" ]]; then
    saltMinion="Salt Minion is installed but not running on $host"
else
    saltMinion="Salt Minion is not installed"
fi

# Salt Master
saltMasterStatus=$(systemctl is-active salt-master.service)
if [[ $saltMasterStatus == "active" ]]; then
    saltMaster="Salt Master is installed and running on $host"
elif [[ $saltMasterStatus == "inactive" ]] || [[ $saltMasterStatus == "failed" ]]; then
    saltMaster="Salt Master is installed but not running on $host"
else
    saltMaster="Salt Master is not installed"
fi

# Puppet
PuppetStatus=$(systemctl is-active puppet.service)
if [[ $PuppetStatus == "active" ]]; then
    Puppet="Puppet is installed and running on $host"
elif [[ $PuppetStatus == "inactive" ]] || [[ $PuppetStatus == "failed" ]]; then
    Puppet="Puppet is installed but not running on $host"
else
    Puppet="Puppet is not installed"
fi

# mariadb
MariadbStatus=$(systemctl is-active mariadb.service)
if [[ $MariaDBStatus == "active" ]]; then
    MariaDB="MariaDB is installed and running on $host"
elif [[ $MariaDBStatus == "inactive" ]] || [[ $MariaDBStatus == "failed" ]]; then
    MariaDB="MariaDB is installed but not running on $host"
else
    MariaDB="MariaDB is not installed"
fi

# MySQL
MySQLStatus=$(systemctl is-active mysql)
if [[ $MySQLStatus == "active" ]]; then
    MySQL="MySQL is installed and running on $host"
elif [[ $MySQLStatus == "inactive" ]] || [[ $MySQLStatus == "failed" ]]; then
    MySQL="MySQL is installed but not running on $host"
else
    MySQL="MySQL is not installed"
fi

############################################################################################
# Check if past EOL
date=$(date +'%Y-%m-%d')

# PHP
if [[ "$PHPEOL" < "$date" ]]; then
    PHPPastEOL="PHP is Past EOL"
else
    PHPPastEOL="PHP In support"
fi

# MariaDB
if [[ "$MariaEOL" < "$date" ]]; then
    MariaDBPastEOL="MariaDB Past EOL"
else
    MariaDBPastEOL="MariaDB is in support"
fi

# Python
if [[ "$PyEOL" < "$date" ]]; then
    PythonPastEOL="Python EOL"
else
    PythonPastEOL="Python is in support"

fi

# Output
############################################################################################
clear

echo "############################################################################################"
echo "                                 Versions and EOL"
echo ""
echo "Hostname: $host"
echo ""
echo "OS/Ver: $os"
echo "$OSEOL"
echo ""
echo "PHP version: $PHPver"
echo "$PHPEOLO"
echo ""
echo "MariaDB version: $MariaDBver"
echo "$MariaDBEOL"
echo ""
echo "MySQL version: $mysqlver"
echo ""
echo "Python version: $Pythonver"
echo "$Pythoneol"
echo ""
echo "Salt(Master) version: $Saltver"
echo "$SaltStackEOL"
echo ""
echo "Puppet Version: $Puppetver"
echo "$Puppeteol"
echo "############################################################################################"
echo "                        Check if applications are running"
echo ""
echo "$saltMinion"
echo "$saltMaster"
echo ""
echo "$Puppet"
echo ""
echo "$MariaDB"
echo "$MySQL"
echo "############################################################################################"
############################################################################################
echo "                                Update Applications"
# Prompt if application is EOL if it is to be updated
echo ""
if [[ "$PHPPastEOL" == "PHP is Past EOL" || "$PHPver" == "PHP is not installed on $host" ]]; then
    echo "PHP seems to be either not installed or past EOL. Do you want to install PHP (8.1 on debian)(8.3 on Rocky/RH/CentOS)?"
    read -p "Please put [y/n] to update/install: " UpdatePHP

    if [[ "$UpdatePHP" == "Y" || "$UpdatePHP" == "y" ]]; then
        if [[ "$Flav" == "rocky-linux" || "$Flav" == "CentOS" ]]; then
            RHphpinstall
        elif [[ "$Flav" == "Ubuntu" ]]; then
            debianphpinstall
        else
            echo "Unsupported OS for PHP installation"
        fi
    else
        echo "PHP installation skipped."

    fi
fi
echo ""
# Python
if [[ "$PythonPastEOL" == "Python EOL" ]]; then
    echo "Python seems to be either not installed or past EOL. Do you want to install Python3.10?"
    read -p "Please put [y/n] to update/install: " UpdatePython
    if [[ "$UpdatePython" == "Y" || "$UpdatePython" == "y"  ]]; then
        apt purge -y python3*
        python310
    else
        echo "Python installation skipped."
    fi
fi
echo ""
# Install to salt master
if [[ $saltMinion == "Salt Minion is installed but not running on $host" ]]; then
    echo "Salt Minion seems to be either not installed or past EOL. Do you want to install Salt minion?"
    read -p "Please put [y/n] to update/install: " InstallSalt
    if [[ "$InstallSalt" == "y" || "$InstallSalt" == "Y" ]]; then
        if [[ $Flav == "Ubuntu" ]]; then
            installSaltminionDeb
        elif [[ $Flav == "CentOS" || $Flav == "rocky-linux" ]]; then
            installSaltminionRH
    else
        echo "Salt Minion installation skipped."
        fi
    fi
fi
echo ""
# Connect minion
if [[ ! -f /etc/salt/minion || "$(cat /etc/salt/minion)" != "master: <IP or Hostname>.28.51" ]]; then
    echo "The Salt minion doesn't seem to be connected to a master"
    read -p "Would you like the minion file to be created again and restart the minion to connect back to the master? [y/n]: " ConnectSalt
    if [[ "$ConnectSalt" == "y" || "$ConnectSalt" == "Y" ]]; then
        echo "master: <IP or Hostname>.28.51" > /etc/salt/minion
        sudo systemctl enable salt-minion && sudo systemctl start salt-minion
        sudo systemctl enable salt-syndic && sudo systemctl start salt-syndic
        sudo systemctl enable salt-api && sudo systemctl start salt-api
        ./EOLTracker.sh
    else
        echo "Salt Minion not connected to master"
    fi
fi
echo "############################################################################################"
echo ""
echo ""
echo ""
echo ""
