#!/bin/bash
PASSWORD="CyberPatriot2025!"

#gets full location of both the Users.txt and Admins.txt   
INPUT=$(pwd) 
INPUT+="/Input.txt" 

#Gets the absolute file path 
USERS=$(pwd)"/Users.txt"

#Removes blank lines *'/^$/'' is regex for starts and ends with nothing) and d removes lines  
#Greps for the autorized header and removes them 
#Greps for the passwords and removes them 
#Removes the (you) text the s option replaces text using 's/old/new/' the double dash replaces it with nothing
#Puts that into a User.txt and saves that under the USERS variable 
sed '/^$/d' $INPUT | grep -vi "Authorized" | grep -vi "password" | sed 's/ (you)//' > $USERS

#Gets the absolute file path
ADMINS=$(pwd)"/Admins.txt"

#Removes the first line (Authorized Admins) and Authorized Users with all lines after it 
#Greps and removes the passwords 
#Removes the (you) on your user
#Puts that into an Admins.txt and saves it in the Admins Variable 
sed '1d;/Authorized Users/,$d' $INPUT | grep -vi "password" | sed 's/ (you)//'| sed '/^$/d' > $ADMINS

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
	#give feedback if successful or not using if statement and exit code
	echo "Changed ${user}'s password"
done < $CURRENT_USERS 

#Stores users to remove and add in log files
echo  -------------- 
#comm compares 2 sorted files, and prints 3 different colums and the -# options remove colulms (unique to 1 | unique to 2 | common)

comm -13 <(sort $USERS) <(sort $CURRENT_USERS) >> removedUsers.txt #Unique to Current Users means that they are not desired 
comm -23 <(sort $USERS) <(sort $CURRENT_USERS) >> addedUsers.txt #Unique to Users means that they do not exist and should  

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

CURRENT_ADMINS=CurrentAdmins.txt
(sudo grep "sudo" /etc/gshadow | cut -c 9- | tr , "\n" > $CURRENT_ADMINS) 

comm -13 <(sort $ADMINS) <(sort $CURRENT_ADMINS) >> removedAdmins.txt #Unique to Current Users means that they are not desired 
comm -23 <(sort $ADMINS) <(sort $CURRENT_ADMINS) >> addedAdmins.txt #Unique to Users means that they do not exist and should 

echo  --------------

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
FILES="foundfiles.txt"
touch $FILES
find /home -nowarn -type f -name "*.png" | grep -v "snap" >> $FILES 
find /home -nowarn -type f -name "*.jpg" >> $FILES
find /home -nowarn -type f -name "*.mp4" >> $FILES
find /home -nowarn -type f -name "*.mp3" >> $FILES

#Chmod appropriate files 
chmod 0644 /etc/passwd
chmod 0640 /etc/shadow
chmod 0640 /etc/gshadow

sudo apt upgrade 