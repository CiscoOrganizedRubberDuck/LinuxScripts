#!/bin/bash

#Remove clean.sh before moving to prod 
PASSWORD="CyberPatriot2025!"

#gets curent directory before moving 
USERS=$(pwd) 
USERS+="/Users.txt" 

ADMINS=$(pwd) 
ADMINS+="/Admins.txt"

#creates another directory for log
sudo mkdir scriptLogs
cd scriptLogs

#Gets Human Users at the start of the Script and stores them in a text file 
cut -d: -f1,3 /etc/passwd | egrep ':[0-9]{4}$' | cut -d: -f1 > CurrentHumanUsers.txt
CURRENT_USERS="CurrentHumanUsers.txt" 

#Change Root 
echo "root":$PASSWORD | sudo chpasswd 
echo "Changed root's password"

#Changes Current Users Password
while read user; do
	echo "${user}:$PASSWORD" | sudo chpasswd
	echo "Changed ${user}'s password"
done < $CURRENT_USERS 

#Finds what users to add and what to remove 
sudo diff $USERS $CURRENT_USERS > difUser.txt 
difUsers="difUser.txt" 

#Stores users to remove and add in log files 
echo  --------------
sudo touch addedUsers.txt
grep "<" $difUsers | cut -c 3- >> addedUsers.txt  
sudo touch removedUsers.txt
grep ">" $difUsers | cut -c 3- >> removedUsers.txt

#adds users using log file and gives feedback
while read user; do
	sudo useradd  $user
	echo "${user}:${PASSWORD}" | sudo chpasswd
	echo "added {$user}"
done<addedUsers.txt 

#removes users using log file and gives feedback
while read user; do 
	sudo userdel  $user
	echo "removed {$user}"
done<removedUsers.txt

sudo grep "sudo" /etc/gshadow | cut -c 9- | tr , "\n" > CurrentAdmins.txt
CURRENT_ADMINS="CurrentAdmins.txt" 

sudo diff $ADMINS $CURRENT_ADMINS > difAdmins.txt 
difAdmins="difAdmins.txt" 

echo  --------------
sudo touch addedAdmins.txt
grep "<" $difAdmins | cut -c 3- >> addedAdmins.txt  
sudo touch removedAdmins.txt
grep ">" $difAdmins | cut -c 3- >> removedAdmins.txt

#adds users to sudoers group
while read admin; do
	sudo usermod -aG sudo $admin
	echo "Added {$admin} to sudo group"
done<addedAdmins.txt 

#removes users from sudoers group
while read admin; do 
	sudo deluser {$admin} sudo	
	echo "removed {$admin} from the sudo group"
done<removedAdmins.txt


#os 
#Will be mint or ubuntu  
#DISTRO="$(cat /etc/*-release | grep "^ID=" | cut -b 4-)"


#UFW 
sudo apt install ufw  
sudo ufw enable 


#Password Polcies 


#Login Retries, LOGIN_TIMEOUT, min, max, warn age  


#Ports
#netstat --abno | grep 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files for .png? 

#Chmod appropriate files 

#SSH root login disable: