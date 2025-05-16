#!/bin/bash

#variables 


#Users 
adduser(){
    local username = $1 
    local password = $2
    adduser $username -p $password
}

#UFW 


#Ports 

netstat --abno

#-A Displays all connections and listening ports
#-B Displays the executable involved
#-N makes names to numbers 
#-O Displays owning process ID for when you need to do taskkill

#Search User files for .png? 


#Password Polcies 

#Chmod appropriate files 

#SSH root login disable: