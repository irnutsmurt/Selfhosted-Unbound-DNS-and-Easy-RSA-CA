#!/bin/bash

# Check if the script is running as root
if [[ $EUID -ne 0 ]]; then
  echo "This script must be run as root" >&2
  exit 1
fi

# Install Unbound, Easy-RSA, and OpenSSL
if [[ $(grep -i "raspbian" /etc/os-release) ]]; then
  apt update
  apt install -y unbound easy-rsa openssl
elif [[ $(grep -i "ubuntu" /etc/os-release) ]]; then
  apt update
  apt install -y unbound easy-rsa openssl
else
  echo "This script only supports Ubuntu and Raspberry Pi OS."
  exit 1
fi

function select_dns_providers() {
  dns_providers=(
    "Cisco OpenDNS:208.67.222.222,208.67.220.220"
    "Cloudflare:1.1.1.1,1.0.0.1"
    "Google Public DNS:8.8.8.8,8.8.4.4"
    "Quad9:9.9.9.9,149.112.112.112"
    "Control D:76.76.2.0,76.76.10.0"
  )

  selected_providers=()
  while [[ ${#selected_providers[@]} -lt 2 ]]; do
    echo "Select at least 2 different DNS providers:"
    for i in "${!dns_providers[@]}"; do
      echo "$((i+1)). ${dns_providers[i]%%:*}"
    done

    read -p "Enter the numbers of the providers you want to use (separated by space): " -a selected_numbers
    selected_numbers=($(echo "${selected_numbers[@]}" | tr ' ' '\n' | sort -nu))
    for number in "${selected_numbers[@]}"; do
      if [[ $number -ge 1 && $number -le ${#dns_providers[@]} ]]; then
        selected_providers+=("${dns_providers[$((number-1))]}")
      fi
    done
    selected_providers=($(echo "${selected_providers[@]}" | tr ' ' '\n' | sort -u))
    if [[ ${#selected_providers[@]} -lt 2 ]]; then
      echo "Please select at least 2 different providers."
      selected_providers=()
    fi
  done

  forward_zones=""
  for provider in "${selected_providers[@]}"; do
    provider_name="${provider%%:*}"
    provider_ips="${provider#*:}"
    for ip in ${provider_ips//,/ }; do
      forward_zones+="\n    forward-addr: $ip"
    done
  done

  sed -i "s/#\s*forward-zone:/forward-zone:/g" /etc/unbound/unbound.conf
  sed -i "s/#\s*name: \".\"/name: \".\"/g" /etc/unbound/unbound.conf
  sed -i "s~#\s*forward-addr:.*~$forward_zones~" /etc/unbound/unbound.conf
}
select_dns_providers

function set_domain_name() {
  read -p "Enter your desired default domain name (e.g., coolguynetwork.com): " domain_name
}
set_domain_name

function setup_easy_rsa() {
  cp -r /usr/share/easy-rsa/ /etc/easy-rsa
  cd /etc/easy-rsa

  read -p "Enter the CA certificate expiration in days (365 recommended, longer may appear insecure): " ca_expiration
  echo "set_var EASYRSA_CA_EXPIRE $ca_expiration" >> vars

  read -p "Enter the default certificate expiration in days (default is 1080): " default_expiration
  echo "set_var EASYRSA_CERT_EXPIRE $default_expiration" >> vars

  echo "Please provide the following information for your Certificate Authority:"
  read -p "Country Name (2 letter code): " country
  read -p "State or Province Name (full name): " state
  read -p "Locality Name (eg, city): " city
  read -p "Organization Name (eg, company): " organization
  read -p "Organizational Unit Name (eg, section): " organizational_unit
  read -p "Common Name (eg, your name or your server's hostname): " common_name
  read -p "Email Address: " email

  echo "set_var EASYRSA_REQ_COUNTRY \"$country\"" >> vars
  echo "set_var EASYRSA_REQ_PROVINCE \"$state\"" >> vars
  echo "set_var EASYRSA_REQ_CITY \"$city\"" >> vars
  echo "set_var EASYRSA_REQ_ORG \"$organization\"" >> vars
  echo "set_var EASYRSA_REQ_OU \"$organizational_unit\"" >> vars
  echo "set_var EASYRSA_REQ_CN \"$common_name\"" >> vars
  echo "set_var EASYRSA_REQ_EMAIL \"$email\"" >> vars

  source vars
  ./easyrsa init-pki
  echo "yes" | ./easyrsa build-ca nopass
}
setup_easy_rsa
