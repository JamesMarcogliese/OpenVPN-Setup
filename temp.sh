#!/bin/bash
# ---------------------------------------------------------------------------
# OpenVPN-Setup - Interactive OpenVPN setup script for Ubuntu/Debian 

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License at <http://www.gnu.org/licenses/> for
# more details.

# Created by: James Marcogliese (james.marcogliese@gmail.com)
# https://github.com/JamesMarcogliese/OpenVPN-Setup

# Revision history:
# 2016-08-20 Initial shell created by gen.sh (ver. 3.3)
# 2016-09-01 Logic created. (v 0.5)
# 2016-09-04 Version 1.0. (v 1.0)
# ---------------------------------------------------------------------------

## Housekeeping routines
PROGNAME=${0##*/}
VERSION="1.0"
# Perform pre-exit housekeeping
clean_up() { 
   return
}

error_exit() {
  echo -e "${PROGNAME}: ${1:-"Unknown Error"}" >&2
  clean_up
  exit 1
}

graceful_exit() {
  clean_up
  exit
}
# Handle trapped signals
signal_exit() { 
  case $1 in
    INT)
      error_exit "Program interrupted by user" ;;
    TERM)
      echo -e "\n$PROGNAME: Program terminated" >&2
      graceful_exit ;;
    *)
      error_exit "$PROGNAME: Terminating on unknown signal" ;;
  esac
}

usage() {
  echo -e "Usage: $PROGNAME [-h|--help]"
}

help_message() {
  cat <<- _EOF_
  $PROGNAME ver. $VERSION
  

  $(usage)

  Options:
  -h, --help  Display this help message and exit.

  NOTE: You must be the superuser to run this script.

_EOF_
  return
}

# Trap signals
trap "signal_exit TERM" TERM HUP
trap "signal_exit INT"  INT

# Check for root UID
if [[ $(id -u) != 0 ]]; then
  error_exit "You must be the superuser to run this script."
fi

# Parse command-line
while [[ -n $1 ]]; do
  case $1 in
    -h | --help)
      help_message; graceful_exit ;;
    -* | --*)
      usage
      error_exit "Unknown option $1" ;;
    *)
      echo "Argument $1 to process..." ;;
  esac
  shift
done

## Main logic

client_configuration(){
## Generate Client Configurations
   echo "--- Generating Client Configurations -----------------------"
   cd ~/client-configs
   counter=1
   until [ "$counter" -gt "$num_clients" ]
      do
         echo "Generating client file $counter of $num_clients..."
         ./make_config.sh ${client_certlist[$counter]}
         echo "File generated."
         counter=$((counter + 1))
      done
   echo "Client configurations completed."
   echo "*** Client files are located in the ~/client-configs/files directory ***"
   if [ "$client_flag" -eq 0 ]
      then
         echo "OpenVPN server setup complete!"
         echo "Returning to menu. Enter any key."
         read response
      else
         echo "Additional client certificate creation complete!"
         echo "Returning to menu. Enter any key."
         read response
   fi
   unset client_certlist
   unset num_clients
   unset client_flag
   unset response
   return
}

client_setup(){
   if [ "$client_flag" -eq 1 ]
      then
         clear
   fi
   # Check if server files are present
   echo "Searching for OpenVPN server files..."
   if [ -d ~/openvpn-ca ] && [ -r ~/openvpn-ca/vars ]
      then 
         echo "Files found."
         cd ~/openvpn-ca
         source vars
      else
         echo "OpenVPN server must be setup first! Aborting."
         return
   fi

   ## Generate Client Certificates and Key Pairs
   echo "--- Generate Client Certificates and Key Pairs -------------"
   echo "How many client certificates will you be making? [0-9]"
   echo "This step can be revisited later via the menu options."
   read num_clients
   while [[ ! "$num_clients" =~ ^-?[0-9]{1}$ ]]
      do
         echo "Please enter a value between 0 and 9."
         read num_clients
      done
   client_num=1
   declare -A client_list 
   while [ "$client_num" -le "$num_clients" ]
      do
         echo "Please enter name for client certificate: $client_num of $num_clients. No duplicates allowed."
         read client_name
         while [ -z "$client_name" ]
            do
               echo "Client name cannot be null. Please enter a client name."
               read client_name
            done
         while [[ ${client_list[$client_name]} ]]
            do
               echo "Client name $client_name is already chosen. Please enter another."
               read client_name
            done
         client_list[$client_name]=1
./build-key $client_name << EOF
$KEY_COUNTRY
$KEY_PROVINCE
$KEY_CITY
$KEY_ORG
$KEY_OU
$KEY_CN
$KEY_NAME
$KEY_EMAIL
.
.
y
y
EOF
         echo "Client certificate for $client_name created."
         client_certlist[$client_num]=$client_name
         client_num=$((client_num + 1))
      done
   echo "Complete."
   unset client_num
   if [ "$client_flag" -eq 1 ]
      then
         client_configuration
   fi
   return 
}

server_setup(){
   clear 
   echo "CAUTION!! Do NOT run Server Setup if a server is already up as it WILL be overwritten!"
   echo "Are you sure you want to proceed? (Y/n)"
   read response
   if [ "$response" = "n" ] || [ "$response" = "N" ]
      then
         return
   fi

   ## Install OpenVPN
   echo "--- Installing OpenVPN ----------"
   # Check if already installed. If not, install. If so, skip.
   command -v openvpn >/dev/null 2>&1 || { echo >&2 "Installing OpenVPN... This may take some time..."; apt-get update && sudo apt-get install openvpn easy-rsa -y; }
   # If after attepted install the program is still unavailable, abort.
   command -v openvpn >/dev/null 2>&1 || { echo >&2 "An error has occured during OpenVPN installation.  Aborting."; return; }
   echo "Done."
   
   ## Setup CA Directory
   echo "--- Setting up Certificate Authority directory -------------"
   echo "Creating directory..."
   if [ -d ~/openvpn-ca ]
      then
         echo "Old directory found."
         rm -rf ~/openvpn-ca
         echo "Old directory removed."
   fi
   make-cadir ~/openvpn-ca
   # Test if directory can be created and accessed.
   if [ -d ~/openvpn-ca ]
      then 
         cd ~/openvpn-ca
         echo "Directory ready."
      else
         echo "Error creating directory. Aborting."
         return
   fi
   
   ## Set Server Name
   echo "--- Set OpenVPN Server Name --------------------------------"
   response="n"
   until [ "$response" = "y" ] || [ "$response" = "Y" ]
      do
         echo "Please enter OpenVPN server name ('server' will be chosen if none provided):"
         read server_name
         if [ -z "$server_name" ]
            then
               server_name='server'
         fi
         echo "** Server name is: $server_name. Is this correct? (Y/n) **"
         read response
      done
   # Replace server name in the vars file. Test for file first
   echo "Testing access to vars config file..."
   if [ -w vars ] && [ -r vars ]
      then 
         echo "Setting name as $server_name..."
         sed -i -e 's/KEY_NAME=.*/KEY_NAME="'"$server_name"'"/g' vars
         echo "Server name set." 
      else
         echo "Error reading/writing to vars file. Check permissions. Aborting."
         return
   fi
   unset server_name
   
   ## Set Certificate Details
   echo "--- Set Certificate details --------------------------------"
   echo "You are about to be asked to enter information that will be incorporated into your certificate request."
   echo "What you are about to enter is what is called a Distinguished Name or a DN."
   echo "There are quite a few fields but you can leave blank."
   echo "For some fields there will be a default value, if you enter '.', the field will be left blank."
   echo "-----"
   response="n"
   until [ "$response" = "y" ] || [ "$response" = "Y" ]
      do
         echo "Country Name (2 letter code) [US]:"
         read country_code
         if [ -z "$country_code" ] || [ "$country_code" = '.' ]
            then
               country_code='US'
         fi
         while [ ${#country_code} != "2" ]
            do 
               echo "String is too long, please enter a 2 letter code:"
               read country_code
            done
         echo "State or Province Name (full name) [CA]:"
         read state_name
         echo "Locality Name (eg, city) [SanFrancisco]:"
         read locality_name
         echo "Organization Name (eg, company) [Fort-Funston]:"
         read org_name
         echo "Organizational Unit Name (eg, section) [MyOrganizationalUnit]:"
         read section_name
         echo "Common Name (eg, your name or your server's hostname) [Fort-Funston CA]:"
         read common_name
         echo "Email Address [me@myhost.mydomain]:"
         read email_address
         # Assign defaults if none given
         if [ -z "$state_name" ] || [ "$state_name" = '.' ]
            then
               state_name='CA'
         fi
         if [ -z "$locality_name" ] || [ "$locality_name" = '.' ]
            then
               locality_name='SanFrancisco'
         fi
         if [ -z "$org_name" ] || [ "$org_name" = '.' ]
            then
               org_name='Fort-Funston'
         fi
         if [ -z "$section_name" ] || [ "$section_name" = '.' ]
            then
               section_name='MyOrganizationalUnit'
         fi
         if [ -z "$common_name" ] || [ "$common_name" = '.' ]
            then
               common_name='Fort-Funston CA'
         fi
         if [ -z "$email_address" ] || [ "$email_address" = '.' ]
            then
               email_address='me@myhost.mydomain'
         fi
         echo "** Are these values correct? (Y/n) **"
         echo "Country Name: $country_code"
         echo "State or Province Name: $state_name"
         echo "Locality Name: $locality_name"
         echo "Organization Name: $org_name"
         echo "Organizational Unit Name: $section_name"
         echo "Common Name: $common_name"
         echo "Email Address: $email_address"
         echo -n "Response: "
         read response 
      done
   
   # Set values into the vars file
   echo "Applying values..."
   sed -i -e 's/export KEY_COUNTRY=.*/export KEY_COUNTRY="'"$country_code"'"/g' vars
   sed -i -e 's/export KEY_PROVINCE=.*/export KEY_PROVINCE="'"$state_name"'"/g' vars
   sed -i -e 's/export KEY_CITY=.*/export KEY_CITY="'"$locality_name"'"/g' vars
   sed -i -e 's/export KEY_ORG=.*/export KEY_ORG="'"$org_name"'"/g' vars
   sed -i -e 's/export KEY_OU=.*/export KEY_OU="'"$section_name"'"/g' vars
   sed -i -e 's/export KEY_CN=.*/export KEY_CN="'"$common_name"'"/g' vars
   sed -i -e 's/export KEY_EMAIL=.*/export KEY_EMAIL="'"$email_address"'"/g' vars
   unset country_code
   unset state_name
   unset locality_name
   unset org_name
   unset section_name
   unset common_name
   unset email_address
   unset response 
   echo "Values applied."
   
   ## Clean and Build Enviroment
   echo "--- Cleaning and Building Certificate Authority Enviroment -"
   source vars
   ./clean-all
./build-ca << EOF
$KEY_COUNTRY
$KEY_PROVINCE
$KEY_CITY
$KEY_ORG
$KEY_OU
$KEY_CN
$KEY_NAME
$KEY_EMAIL
EOF
   echo " "
   echo "Clean and build complete."
   
   ## Generate Server Certificate, Key, and Encrpytion Files
   echo "--- Generating Server Certificate, Key, and Encrpytion Files"
   echo "This may take some time..."
./build-key-server $KEY_NAME << EOF
$KEY_COUNTRY
$KEY_PROVINCE
$KEY_CITY
$KEY_ORG
$KEY_OU
$KEY_CN
$KEY_NAME
$KEY_EMAIL
.
.
y
y
EOF
   echo "Generating Diffie-Hellman keys..."
   ./build-dh
   openvpn --genkey --secret keys/ta.key
   echo "Keys generated."
   
   ## Generate Client Certificates and Key Pairs
   num_clients=0
   client_setup
   
   ## Configure OpenVPN service
   echo "--- Configuring OpenVPN service ----------------------------"
   # Copy files to the OpenVPN directory
   echo "Cleaning directory..."
   find /etc/openvpn/* \! -name 'update-resolv-conf' -delete
   echo "Directory cleaned."
   echo "Copying files to directory..."
   cd ~/openvpn-ca/keys
   cp ca.crt ca.key $KEY_NAME.crt $KEY_NAME.key ta.key dh2048.pem /etc/openvpn
   gunzip -c /usr/share/doc/openvpn/examples/sample-config-files/server.conf.gz | sudo tee /etc/openvpn/"$KEY_NAME".conf
   echo "Files copied."
   # Adjust the OpenVPN configuration
   echo "Ajusting OpenVPN server configuration..."
   if [ ! -w /etc/openvpn/"$KEY_NAME".conf ] 
      then
         echo "Error writing to $KEY_NAME.conf file. Check permissions. Aborting."
         return
   fi
   sed -i -e 's/;push "redirect-gateway def1 bypass-dhcp"/push "redirect-gateway def1 bypass-dhcp"/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;push "dhcp-option DNS 208.67.222.222"/push "dhcp-option DNS 208.67.222.222"/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;push "dhcp-option DNS 208.67.220.220"/push "dhcp-option DNS 208.67.220.220"/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;tls-auth ta.key 0 # This file is secret/tls-auth ta.key 0 # This file is secret/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e '/tls-auth ta.key 0 # This file is secret/a key-direction 0' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;tls-auth ta.key 0 # This file is secret/tls-auth ta.key 0 # This file is secret/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;user nobody/user nobody/g' /etc/openvpn/"$KEY_NAME".conf
   sed -i -e 's/;group nogroup/group nogroup/g' /etc/openvpn/"$KEY_NAME".conf
   echo "Configuration changes applied."
   
   ## Adjust Server Networking Configuration
   echo "--- Adjusting Server Networking Configuration --------------"
   # Allow IP forwarding
   echo "Allowing forwarding..."
   if [ ! -w /etc/sysctl.conf ] 
      then
         echo "Error writing to sysctl.conf file. Check permissions. Aborting."
         return
   fi
   sed -i -e 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/openvpn/"$KEY_NAME".conf
   echo "Forwarding applied."
   # Adjust UFW Rules to Masquerade Client Connections
   echo "Adjusting firewall rules..."
   if [ ! -w /etc/ufw/before.rules ] 
      then
         echo "Error writing to ufw rules file. Check permissions. Aborting."
         return
   fi
   interface="$(ip route | grep default | grep -Po 'dev \K[^ ]+')"
   if [[ -z $(grep 'START OPENVPN RULES' /etc/ufw/before.rules) ]]
      then
         sed -i -e "/#   ufw-before-forward/a # START OPENVPN RULES\n\
# NAT table rules\n\
*nat\n\
:POSTROUTING ACCEPT [0:0]\n\
# Allow traffic from OpenVPN client to eth0\n\
-A POSTROUTING -s 10.8.0.0/8 -o $interface -j MASQUERADE\n\
COMMIT\n\
# END OPENVPN RULES" /etc/ufw/before.rules
   fi
   unset interface
   sed -i -e 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/g' /etc/default/ufw
   echo "Firewall rules applied."
   # Open the OpenVPN Port and Enable the changes
   echo "Opening OpenVPN port..."
   ufw allow 1194/udp
   echo "Port opened."
   echo "Enabling changes..."
   ufw disable
   ufw enable
   echo "Changes applied."
   if [[ -n $(systemctl | grep openvpn@) ]]
      then
         echo "Old service found to be running!"
         echo "Removing..."
         old_service="$(systemctl | grep openvpn@ | sed -n 's:.*openvpn@\(.*\).service.*:\1:p')"
         systemctl disable openvpn@$old_service
         systemctl stop openvpn@$old_service
         echo "Old service removed."
         unset old_service
   fi
   echo "Starting OpenVPN service..."
   systemctl start openvpn@$KEY_NAME
   echo "Service started."
   echo "Enabling service at boot..."
   systemctl enable openvpn@$KEY_NAME
   echo "Service enabled at boot."
   
   ## Creating Client Configuration Infrastructure
   echo "--- Creating Client Configuration Infrastructure -----------"
   echo "Creating directory..."
   if [ -d ~/client-configs ] 
      then
         rm -r ~/client-configs
   fi
   mkdir -p ~/client-configs/files
   echo "Directory created."
   echo "Setting permissions..."
   chmod -R 700 ~/client-configs/files
   echo "Permissions set."
   echo "Creating base configuration."   
   cp /usr/share/doc/openvpn/examples/sample-config-files/client.conf ~/client-configs/base.conf
   response="n"
   until [ "$response" = "y" ] || [ "$response" = "Y" ]
      do
         echo "Please provide the public IP address of the OpenVPN server:"
         read public_address
         echo "** Is the address $public_address correct? (Y/n) **"
         read response 
      done
   sed -i -e "s/remote .* 1194/remote $public_address 1194/g" ~/client-configs/base.conf
   echo "Public IP applied to config file."
   echo "Configuring additional settings..."
   sed -i -e 's/;user nobody/user nobody/g' ~/client-configs/base.conf
   sed -i -e 's/;group nogroup/group nogroup/g' ~/client-configs/base.conf
   sed -i -e 's/ca ca.crt/#ca ca.crt/g' ~/client-configs/base.conf
   sed -i -e 's/cert client.crt/#cert client.crt/g' ~/client-configs/base.conf
   sed -i -e 's/key client.key/#key client.key/g' ~/client-configs/base.conf
   sed -i -e '/;mute 20/a key-direction 1' ~/client-configs/base.conf
   echo "Settings applied."
   echo "Creating configuration generation script..."
   #touch ~/client-configs/make_config.sh

cat << EOF > ~/client-configs/make_config.sh
#!/bin/bash

# First argument: Client identifier

KEY_DIR=~/openvpn-ca/keys
OUTPUT_DIR=~/client-configs/files
BASE_CONFIG=~/client-configs/base.conf

cat ${BASE_CONFIG} \
    <(echo -e '<ca>') \
    ${KEY_DIR}/ca.crt \
    <(echo -e '</ca>\n<cert>') \
    ${KEY_DIR}/${1}.crt \
    <(echo -e '</cert>\n<key>') \
    ${KEY_DIR}/${1}.key \
    <(echo -e '</key>\n<tls-auth>') \
    ${KEY_DIR}/ta.key \
    <(echo -e '</tls-auth>') \
    > ${OUTPUT_DIR}/${1}.ovpn 
EOF
   chmod 755 ~/client-configs/make_config.sh
   echo "Configuration generation script created."
   client_configuration
   return
}

### Menu + Global Vars
while [ true ]
   do
      echo " "
      echo " "
      echo "Welcome to the OpenVPN setup script for Ubuntu/Debian"
      echo "Select an option from the menu below."
      echo "------------------------------------------------------------"
      echo " 1: Install and setup OpenVPN server."
      echo " 2: Generate additional client certificates."
      echo " 3: Quit."
      echo -n " Enter your selection: "
      read option
      
      case $option in
      1) client_flag=0
         server_setup
               ;;
      2) client_flag=1
         client_setup
               ;;
      3) graceful_exit 
               ;;
      *) echo "Invalid option, try again."
               ;;
      esac
   done 
