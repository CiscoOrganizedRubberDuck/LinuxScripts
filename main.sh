#!/bin/bash

#Remove clean.sh before moving to prod 
PASSWORD="CyberPatriot2025!"

#gets curent directory before moving 
USERS=$(pwd) 
USERS+="/Users.txt" 


#creates another directory for log
mkdir scriptLogs
cd scriptLogs

#Gets Human Users at the start of the Script and stores them in a text file 
cut -d: -f1,3 /etc/passwd | egrep ':[0-9]{4}$' | cut -d: -f1 > CurrentHumanUsers.txt
CURRENT_USERS="CurrentHumanUsers.txt" 

#Changes Current Users Password
while read user; do
	echo "${user}:$PASSWORD" | sudo chpasswd
	echo "Changed ${user}'s password"
done < $CURRENT_USERS 


#Finds what users to add and what to remove 
diff $USERS $CURRENT_USERS > dif.txt 
DIF="dif.txt" 

#Stores users to remove and add in log files 
echo  --------------
touch addedUsers.txt
grep -h "<" $DIF | cut -c 3- >> addedUsers.txt  
touch removedUsers.txt
grep -h ">" $DIF | cut -c 3- >> removedUsers.txt

#sudo grep "sudo" /etc/gshadow | cut -c 9-  

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


#os 
#Will be mint or ubuntu  
#DISTRO="$(cat /etc/*-release | grep "^ID=" | cut -b 4-)"


#UFW 
sudo apt install ufw  
sudo ufw enable 


#Ports
#netstat --abno | grep 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files for .png? 

#Password Polcies 

#Chmod appropriate files 

#SSH root login disable: