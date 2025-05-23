#!/bin/bash

PASSFILE = "/passwords.txt"
PASSWORD = "CyberPatriot2025!"

#os 
DISTRO="$(cat /etc/*-release | grep "^ID=" | cut -b 4-)"


#Users 
for i in $(cat $PASSFILE | cut -d " " -f2); 
do 
    useradd $i
    $1:$PASSWORD | chpasswd
done 

#sudo deluser -r $username


#UFW or iptables  
sudo apt install ufw #APT using Distros 

#Ports 

netstat --abno | grep 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files for .png? 


#Password Polcies 

#Chmod appropriate files 

#SSH root login disable: