#!/bin/bash

#Constants
PASSWORD="CyberPatriot2025!"
RESOURCES=$(pwd)"/ScriptResources"
PACKS=$RESOURCES"/Packages.txt"
MAL_PACKS=$RESOURCES"/MalPackages.txt"
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
FILES=$LOGS"/FoundFiles.txt"

#Check is script was ran with sudo 
check_root(){
	if [ "$(id -u)" -ne 0 ]; then 
		echo "WARNING: This script needs sudo to run."
		echo "Aborting..."
		exit 1
	fi 
}

#Check if input.txt has content 
check_input_txt(){
	if ! grep -i "Authorized" "$INPUT"; then 
		echo "WARNING: Improper Input.txt format"
		return 1
	else 
		return 0
	fi 

}

add_and_remove_users() {
	#Cleans up the user portion of input.txt and puts it into a Users.txt 
	sed "2, $(($(grep -n User "$INPUT" | cut -f1 -d:)-1)) {n;d}" "$INPUT" | sed '/^$/d' | grep -vi "Authorized" | sed 's/ (you)//' | sed -r 's/\s*-\s*//' > "$USERS"	

	#Cleans up the admin portion of input.txt and puts it into a Admins.txt
	sed "$(($(grep -n Users "$INPUT"| cut -d: -f1)+1)), $(wc  -l "$INPUT"| cut -d" " -f1)d" "$INPUT" |  sed "2, $(($(grep -n User "$INPUT" | cut -f1 -d:) -1)) {n;d}" | sed '1d	;/Authorized Users/,$d' | sed 's/ (you)//'| sed '/^$/d' | sed -r 's/\s*-\s*//'  > "$ADMINS" 

	#Gets Human Users stores them in a text file 
	cut -d: -f1,3 /etc/passwd | grep -E ':[0-9]{4}$' | cut -d: -f1 > "$CURRENT_USERS"


	#Change Root password 
	echo "root":$PASSWORD | sudo chpasswd 
	echo "Changed root's password" #TODO Use exit codes to ensure that this worked

	#Changes Current Users Password
	while read -r user; do
		echo "${user}:$PASSWORD" | sudo chpasswd #TODO Give feedback if successful or not using if statement and exit code
		echo "Changed ${user}'s password"
		
		sudo chage -m 1 "${user}" #Set min password age to 1 day
		sudo chage -M 90 "${user}" #Set max password age to 90 days 
		sudo chage -W 7 "${user}" #Set time before expiration warning to 7 days
		echo "Changed ${user}'s password min, max, and warn age"
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
}


print_OS_info(){
	#os 
	#Will be mint or ubuntu 
	echo "------OS INFO------" 
	cat /etc/*-release | grep -iv url
	echo "-------------------"
}


#UFW 
install_ufw(){
	#Install needed packages for script 
	apt-get update -qq && apt-get -qq install -y aptitude --fix-missing

	if ! aptitude search "?exact-name(UFW) ~i"; then 
		sudo apt-get -qq install ufw --fix-missing
	else
		echo "ufw already installed"
	fi 
		sudo ufw enable #TODO ufw status if enable to avoid error message 
}

add_and_remove_packages(){
	apt-get -qq update && apt-get -qq install -y aptitude --fix-missing
	
	#Write PACKS into MAL_PACKS. This allows the us to keep PACKs later for manually removing packages if needed
	cat "$PACKS" > "$MAL_PACKS"
	
	#Remove Required Packages from Malicous packages 
	while read -r package; do 
		sed -i "/$package/d" "$MAL_PACKS"
	done < "$REQ_PACK"

	#Remove Malicous Packages
	while read -r package; do 
		aptitude search "?exact-name(${package}) ~i" && aptitude purge "${package}" -y -q
	done < "$MAL_PACKS"

	#Add Required Packages 
	while read -r package; do 
		if ! aptitude search "?exact-name(${package}) ~i"; then  
			aptitude install "${package}" -y -q
		fi 
		sudo system "$package" start 
	done < "$REQ_PACK"

	apt-get autoremove -y -qq 
	apt-get autoclean -qq
}



#Password Polcies 

#Login Retries, LOGIN_TIMEOUT, min, max, warn age  

#Ports
#netstat --abno 

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Searchs User files and stories in a log file

search_user_files(){
	touch "$FILES"
	{
	find /home -nowarn -type f -name "*.png" | grep -v "snap"  
	find /home -nowarn -type f -name "*.jpg" 
	find /home -nowarn -type f -name "*.mp4" 
	find /home -nowarn -type f -name "*.mp3"
	find /home -nowarn -type f -name "*.ogg" 
	}>> "$FILES"
}

fix_file_permissions(){
	#Chmod appropriate files 
	chmod 0755 /var/log
	chmod 0640 /var/log/syslog
	chmod 0644 /etc/passwd
	chmod 0640 /etc/shadow
	chmod 0640 /etc/gshadow
	chmod 440 /etc/sudoers
	
	#Checks library files permissions and corrects them if they are not correct
	find /lib /lib64 /usr/lib /usr/lib64 -type f -name '*.so*' -perm /022 -exec chmod go-w {} +\

	#Checks library directory permissions and corrects them if they are not correct 
	find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -perm /022 -type d -exec chmod -R 755 '{}' \;

	#TODO fix UID vulns  

	#Disable root login
	passwd -l root
}

configure_password_policy(){
	#Create backups directory 
	local timestamp 
	timestamp=$(date +%Y%m%d-%H%M%S) #Doing in two steps prevents hiding the error of the subshell  
	local backup_dir="/root/policy-backups-$timestamp"
	mkdir -p "$backup_dir"
	local ssh_config="/etc/ssh/sshd_config"
	
	apt-get -y -qq install libpam-pwquality 
		
	#Back Up Pam.d files 
	for file in /etc/pam.d/common-password /etc/pam.d/common-auth; do
		if [ -f "$file" ]; then
			cp "$file" "$backup_dir/"
			echo "Backed up $file"
		else
			echo "WARNING: $file not found, skipping"
		fi
	done

	#Start Common-password Edits 
	cp /etc/pam.d/common-password /etc/pam.d/common-password.tmp

	sed -i '/pam_unix.so/d' /etc/pam.d/common-password.tmp #removes old pam_unix line 
	
	#Replace the EOF with a libpam module line  
	#GPT said success=2 but that doesn't make sense so triple check 
	cat <<'EOF' >> /etc/pam.d/common-password.tmp
password   [success=1 default=ignore]   pam_unix.so obscure use_authtok try_first_pass sha512 minlen=10 
EOF
	mv /etc/pam.d/common-password.tmp /etc/pam.d/common-password #Move the tmp file contents back into the original file

	#Start Common-Auth Edits 
	cp /etc/pam.d/common-auth /etc/pam.d/common-auth.tmp

	sed -i 's/\<nullok\>//g' /etc/pam.d/common-auth.tmp # remove 'nullok' option if it exists

	if ! grep -q 'pam_unix.so' /etc/pam.d/common-auth.tmp; then
    	echo "auth [success=1 default=ignore] pam_unix.so" >> /etc/pam.d/common-auth.tmp
	fi

	#Code For Editing SSHD
	if ( grep -iq "$REQ_PACK" sshd ); then
		cp $ssh_config "$backup_dir/"
	fi

	#Back up System Conf files 
	cp "/etc/sysctl.conf" "$backup_dir/"

}

edit_shadow_pass_parameters(){
	echo TODO 
}

configure_audit_policy(){
	apt-get -y -qq install auditd audispd-plugins
	wget --directory-prefix="$RESOURCES" -O audit.rules https://github.com/Neo23x0/auditd.git
	mv audit.rules "$RESOURCES"
	cp "$RESOURCES"/audit.rules /etc/audit/rules.d/
	systemctl restart auditd.service
	systemctl enable auditd.service
}

configure_setting(){
	local config_file="$1"
	local setting="$2"
	local value="$3"

	#find if the value setting is in the config file 
	#Regex searchs for a string that starts with # then any white space and then the setting 
	if grep -q "^[#]*\s*${setting}" "$config_file"; then  
        sed -i "s/^[#]*\s*${setting}.*/${setting} ${value}/" "$config_file" #substitute the value of the setting
    else
	#if setting is not foundm, add the setting and the value 
        echo "${setting} ${value}" >> "$config_file"
    fi
}

main(){
	check_root 
	
	#Create Logging Directory 
	mkdir "$LOGS"
	cd "$LOGS" || { echo "Failure to change Directory"; exit 1; } #Overkill 
	
	#Fix DNS issues?  
	echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf > /dev/null
	
	#update packages
	apt-get update -y -qq
	
	#Only do the users stuff if there is an Input.txt
	check_input_txt
	INPUTSTATUS=$? 
	if [ $INPUTSTATUS -eq 0 ]; then 
		add_and_remove_users
	fi 

	add_and_remove_packages
	install_ufw
	fix_file_permissions
	passpolicy
	search_user_files
	configure_audit_policy
	configure_password_policy
	print_OS_info 
}


main
echo Upgrading Packages
sudo apt upgrade -q -y
echo Done
echo Upgrading Distro
sudo apt dist-upgrade -q -y
echo Done

