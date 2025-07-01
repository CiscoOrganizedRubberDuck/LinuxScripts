#!/bin/bash
PASSWORD="CyberPatriot2025!"

#gets full location of both the Users.txt and Admins.txt   
USERS=$(pwd) 
USERS+="/Users.txt" 
ADMINS=$(pwd) 
ADMINS+="/Admins.txt"

#creates another directory for log and then enters that directory 
sudo mkdir scriptLogs
cd scriptLogs

#Gets Human Users at the start of the Script and stores them in a text file 
cut -d: -f1,3 /etc/passwd | egrep ':[0-9]{4}$' | cut -d: -f1 > CurrentHumanUsers.txt
CURRENT_USERS="CurrentHumanUsers.txt" 

#Change Root password 
echo "root":$PASSWORD | sudo chpasswd 
echo "Changed root's password"

#Changes Current Users Password
while read user; do
	echo "${user}:$PASSWORD" | sudo chpasswd
	echo "Changed ${user}'s password"
done < $CURRENT_USERS 

#Finds what users to add and what to remove 
#difUsers=$(sudo diff $USERS $CURRENT_USERS > difUser.txt) 
#
echo  -------------- 
comm -23 <(sort $USERS) <(sort $CURRENT_USERS)
comm -13 <(sort $USERS) <(sort $CURRENT_USERS)


#Stores users to remove and add in log files

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
#netstat --abno 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files 
FILES = $(touch foundfiles.txt)
find /home -nowarn -type f -name "*.png" | grep -v "snap" >> $FILES 
find /home -nowarn -type f -name "*.jpg" >> $FILES
find /home -nowarn -type f -name "*.mp4" >> $FILES
find /home -nowarn -type f -name "*.mp3" >> $FILES

#Chmod appropriate files 
chmod 0644 /etc/passwd
chmod 0640 /etc/shadow
chmod 0640 /etc/gshadow

sudo apt upgrade 