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
		echo "Changed ${user}'s password min and max age"
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
	DISTRO="$(cat /etc/*-release | grep "^ID=" | cut -b 4-)"
	echo "$DISTRO"
	echo "-------------------"
}


#UFW 
install_ufw(){
	#Install needed packages for script 
	apt-get update 
	apt install -y aptitude --fix-missing

	if ! aptitude search "?exact-name(UFW) ~i"; then 
		sudo apt install ufw --fix-missing
	else
		echo "ufw already installed"
	fi 
		sudo ufw enable #TODO ufw status if enable to avoid error message 
}

add_and_remove_packages(){
	apt-get update 
	apt install -y aptitude --fix-missing
	
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

	apt autoremove -y 
	apt autoclean 
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
	chmod 0644 /etc/passwd
	chmod 0640 /etc/shadow
	chmod 0640 /etc/gshadow
	chmod 440 /etc/sudoers
	
	#TODO fix UID vulns  

	#Disable root login
	passwd -l root
}

passpolicy(){

timestamp=$(date +%Y%m%d-%H%M%S)
backup_dir="/root/policy-backups-$timestamp"
mkdir -p "$backup_dir"

echo "=== CyberPatriot Password Policy Fix Script ==="
echo "Creating backup directory at $backup_dir"

#-------------------------------------------------
# 1. Backup target files
#-------------------------------------------------
for file in /etc/pam.d/common-password /etc/pam.d/common-auth; do
    if [ -f "$file" ]; then
        cp "$file" "$backup_dir/"
        echo "Backed up $file"
    else
        echo "WARNING: $file not found, skipping"
    fi
done

#-------------------------------------------------
# 2. Enforce minimum password length in common-password
#-------------------------------------------------
echo "Configuring /etc/pam.d/common-password for minimum length..."

cp /etc/pam.d/common-password /etc/pam.d/common-password.tmp

# remove any old pam_unix.so line (so we can rewrite cleanly)
sed -i '/pam_unix.so/d' /etc/pam.d/common-password.tmp

# Append correct pam_unix.so line as CyberPatriot expects
# According to the answer key, it must include minlen=10
cat <<'EOF' >> /etc/pam.d/common-password.tmp
password   [success=2 default=ignore]   pam_unix.so obscure use_authtok try_first_pass sha512 minlen=10
EOF

mv /etc/pam.d/common-password.tmp /etc/pam.d/common-password
echo "✓ Minimum password length set (minlen=10)"

#-------------------------------------------------
# 3. Disable null passwords in common-auth
#-------------------------------------------------
echo "Configuring /etc/pam.d/common-auth to disallow null passwords..."

cp /etc/pam.d/common-auth /etc/pam.d/common-auth.tmp

# remove 'nullok' option if it exists
sed -i 's/\<nullok\>//g' /etc/pam.d/common-auth.tmp

# make sure the pam_unix.so line exists
if ! grep -q 'pam_unix.so' /etc/pam.d/common-auth.tmp; then
    echo "auth [success=2 default=ignore] pam_unix.so" >> /etc/pam.d/common-auth.tmp
fi

mv /etc/pam.d/common-auth.tmp /etc/pam.d/common-auth
echo "✓ Null passwords are now disallowed"

#-------------------------------------------------
# 4. Summary
#-------------------------------------------------

echo
echo "=== Verification Summary ==="
grep "pam_unix.so" /etc/pam.d/common-password
grep "pam_unix.so" /etc/pam.d/common-auth
echo
echo "Backups saved in $backup_dir"
echo "CyberPatriot policy fixes applied successfully."
}

configure_setting(){
	local config_file="$1"
	local setting="$2"
	local value="$3"

	if grep -q "^[#]*\s*${setting}" "$config_file"; then
        sed -i "s/^[#]*\s*${setting}.*/${setting} ${value}/" "$config_file"
    else
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
	apt-get update -y -q 
	
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
	print_OS_info 
}


main
sudo apt-get -y upgrade 


