#!/bin/bash

MYSQL_RELEASE=mysql80-community-release-el7-3.noarch.rpm
MYSQL_RELEASE_URL="https://dev.mysql.com/get/${MYSQL_RELEASE}"
MYSQL_SERVICE=mysqld
MYSQL_LOG_FILE=/var/log/${MYSQL_SERVICE}.log
#MYSQL_PWD=garbage

exitError() {
	    echo "Error: $1" >&2
	        exit 1
	}

	if [[ $EUID -ne 0 ]]; then 
		    echo "Warning: Needs sudo permissions, retry"
		        exit 1
	fi

	#download
	rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022
	echo "Downloading package:"
	echo "link provided: $MYSQL_RELEASE_URL"
	wget -O $MYSQL_RELEASE $MYSQL_RELEASE_URL || exitError "could not download specified package from link"
	echo "unusable link: ($MYSQL_RELEASE_URL)"

	#install repo
	echo "installing mysql"
	yum localinstall -y $MYSQL_RELEASE || exitError "Unable to install mysql release ($MYSQL_RELEASE)"

	#check repo
	echo "Checking installation"
	yum repolist enabled | grep "mysql.*-community.*" || exitError "Mysql release package ($MYSQL_RELEASE) couldn't be added to repolist"

	# check subrepo
	#echo "Checking for enabled subrepos"
	#yum repolist enabled | grep mysql || exitError "At least one subrepository should be enabled for one release series at any time."

	# install server
	echo "Installing mysql server (community)"
	yum install -y mysql-community-server || exitError "Could not install mysql server"

	# start server
	echo "Starting mysql"
	systemctl start mysqld.service || exitError "Could not start mysql service"

	# check server status
	echo "Checking mysql status"
	systemctl status mysqld.service || exitError "Mysql is not running"

	# make server start on boot
	echo "Setting up mysql as in startup service..."
	chkconfig mysqld on

	# get auto-gen password
	echo "Getting default password from ${MYSQL_LOG_FILE}"
	MYSQL_PWD=$(grep -oP '(?<=A temporary password is generated for root@localhost: )[^ ]+' ${MYSQL_LOG_FILE})
	echo "Auto generated password: ${MYSQL_PWD}"

	# install expect redundantly
	yum install -y expect

	# Connect to mysql configure
	MYSQL_UPDATE=$(expect -c "

	set timeout 5 
	spawn mysql -u root -p

	expect \"Enter password: \"
	send \"${MYSQL_PWD}\r\"

	expect \"mysql>\"
	send \"ALTER USER 'root'@'localhost' IDENTIFIED BY 'somepassword!';\r\"

	expect \"mysql>\"
	send \"CREATE USER 'someuser'@'localhost' IDENTIFIED BY 'somepassword!';\r\"

	expect \"mysql>\"
	send \"GRANT ALL PRIVILEGES ON * . * TO 'ec2-user'@'localhost';\r\"

	expect \"mysql>\"
	send \"FLUSH PRIVILEGES;\r\"
	
	expect \"mysql>\"
	send \"CREATE DATABASE somedatabse;\r\"

	expect \"mysql>\"
	send \"USE csye6225;\r\"

	expect \"mysql>\"
	send \"create table users (id varchar(50) primary key, username varchar(40), password varchar(80), first_name varchar(20), last_name varchar(20), account_created datetime, account_updated datetime);\r\"

	expect \"mysql>\"
	send \"quit;\r\"

	expect eof
	")

	echo "$MYSQL_UPDATE"

	# remove expect
	yum remove -y expect
