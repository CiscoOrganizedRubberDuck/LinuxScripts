#!/bin/bash

#Check is script was ran with sudo 
if [ "$(id -u)" -ne 0 ]; then 
	echo "WARNING: This script needs sudo to run."
	echo "Aborting..."
	exit 1
fi 

#Check if input.txt has content 

#Constants
PASSWORD="CyberPatriot2025!"
RESOURCES=$(pwd)"/ScriptResources"
MAL_PACK=$RESOURCES"./MalPackages.txt"
REQ_PACK=$(pwd)"/RequiredServices.txt"
INPUT=$(pwd)"/Input.txt" 
USERS=$(pwd)"/Users.txt"
ADMINS=$(pwd)"/Admins.txt"
LOGS=$(pwd)"/ScriptLogs"

#Log Files  
CURRENT_USERS=$LOGS"/CurrentUsers.txt" 
CURRENT_ADMINS=$LOGS"/CurrentAdmins.txt"
REMOVED_USERS=$LOGS"/RemovedUsers.txt"
ADDED_USERS=$LOGS"/AddedUsers.txt"
REMOVED_ADMINS=$LOGS"/RemovedAdmins.txt"
ADDED_ADMINS=$LOGS"/AddedAdmins.txt"
FILES=$LOGS"foundfiles.txt"

#Cleans up the user portion of input.txt and puts it into a Users.txt 
sed "2, $(($(grep -n User "$INPUT" | cut -f1 -d:)-1)) {n;d}" "$INPUT" | sed '/^$/d' | grep -vi "Authorized" | sed 's/ (you)//' | sed -r 's/\s*-\s*//' > "$USERS"	

#Cleans up the admin portion of input.txt and puts it into a Admins.txt
sed "$(($(grep -n Users "$INPUT"| cut -d: -f1)+1)), $(wc  -l "$INPUT"| cut -d" " -f1)d" "$INPUT" |  sed "2, $(($(grep -n User "$INPUT" | cut -f1 -d:) -1)) {n;d}" | sed '1d	;/Authorized Users/,$d' | sed 's/ (you)//'| sed '/^$/d' | sed -r 's/\s*-\s*//'  > "$ADMINS" 

#creates another directory for log and then enters that directory 
sudo mkdir "$LOGS"
cd "$LOGS" || { echo "Failure to change Directory"; exit 1; } #Overkill 

#Gets Human Users stores them in a text file 
cut -d: -f1,3 /etc/passwd | grep -E ':[0-9]{4}$' | cut -d: -f1 > "$CURRENT_USERS"


#Change Root password 
echo "root":$PASSWORD | sudo chpasswd 
echo "Changed root's password" #TODO Use exit codes to ensure that this worked

#Changes Current Users Password
while read -r user; do
	echo "${user}:$PASSWORD" | sudo chpasswd #TODO Give feedback if successful or not using if statement and exit code
	echo "Changed ${user}'s password"
done < "$CURRENT_USERS" 

#comm compares 2 sorted files, and prints 3 different colums and the -# options remove colulms (unique to 1 | unique to 2 | common)
comm -13 <(sort "$USERS") <(sort "$CURRENT_USERS") >> "$REMOVED_USERS" #Unique to Current Users means that they are not desired 
comm -23 <(sort "$USERS") <(sort "$CURRENT_USERS") >> "$ADDED_USERS" #Unique to Users means that they do not exist and should  

#adds users using log file and gives feedback
while read -r user; do
	sudo useradd  "$user"
	echo "$user":$PASSWORD | sudo chpasswd
	echo "added {$user}"
done<"$ADDED_USERS"

#removes users using log file and gives feedback
while read -r user; do 
	sudo userdel  "$user"
	echo "removed ${user}"
done<"$REMOVED_USERS"


sudo grep "sudo" /etc/gshadow | cut -c 9- | tr , "\n" > "$CURRENT_ADMINS"
#TODO consider replacing with comm with ack 

#Unique to Current Admins means that they are not desired 
comm -13 <(sort "$ADMINS") <(sort "$CURRENT_ADMINS") >> "$REMOVED_ADMINS"
#Unique to Admins means that they do not exist and should 
comm -23 <(sort "$ADMINS") <(sort "$CURRENT_ADMINS") >> "$ADDED_ADMINS"

echo  --------------

#adds users to sudoers group
while read -r admin; do
	sudo usermod -aG sudo "$admin"
	echo "Added {$admin} to sudo group"
done<"$ADDED_ADMINS" 

#removes users from sudoers group
while read -r admin; do 
	sudo deluser "$admin" sudo	
	echo "removed {$admin} from the sudo group"
done<"$REMOVED_ADMINS"

#os 
#Will be mint or ubuntu  
#DISTRO="$(cat /etc/*-release | grep "^ID=" | cut -b 4-)"

#update packages 
apt update -y -q 

#Install needed packages for script 
apt install -y -q aptitude

#UFW 
if ! aptitude search "?exact_name(UFW) ~i"; then 
	sudo apt install ufw  
else
	echo "ufw already installed"
fi 
	sudo ufw enable #TODO ufw status if enable to avoid error message 

#Remove Required Packages from Malicous packages (rare circumstance hacking tool is required)
while read -r package; do 
	# shellcheck disable=SC2094
	grep -v package "$MAL_PACK" > "$MAL_PACK" 
done < "$REQ_PACK"


#Remove Malicous Packages
while read -r package; do 
	aptitude search "?exact_name(${package} ~i)" && aptitude purge "${package}" -y -q
done < "$MAL_PACK"

#Add Required Packages 
while read -r package; do 
	if ! aptitude search "?exact_name(${package} ~i)"; then  
		aptitude install "${package}" -y -q
	fi 
	sudo system "$package" start 
done < "$REQ_PACK"


#Password Polcies 

#Login Retries, LOGIN_TIMEOUT, min, max, warn age  

#Ports
#netstat --abno 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files 

touch "$FILES"
{
find /home -nowarn -type f -name "*.png" | grep -v "snap"  
find /home -nowarn -type f -name "*.jpg" 
find /home -nowarn -type f -name "*.mp4" 
find /home -nowarn -type f -name "*.mp3" 
}>> "$FILES"

#Chmod appropriate files 
chmod 0644 /etc/passwd
chmod 0640 /etc/shadow
chmod 0640 /etc/gshadow

sudo apt upgrade

