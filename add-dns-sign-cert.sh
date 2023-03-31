#!/bin/bash

# Add this line after the set_domain_name function in the first script
user_domain="your_domain_here"

function add_dns_entry() {
  read -p "Enter the name (it will end with .${user_domain}): " name
  read -p "Enter the IP address: " ip

  echo "local-data: \"$name.${user_domain}. IN A $ip\"" | sudo tee -a /etc/unbound/unbound.conf

  sudo systemctl restart unbound

  read -p "Would you like to create a signed certificate? (y/n): " choice
  case "$choice" in
    y|Y) create_signed_certificate ;;
    *) main_menu ;;
  esac
}

function delete_dns_entry() {
  dns_entries=($(grep -oP '(?<=local-data: ")[^"]+(?= IN A [0-9.]+")' /etc/unbound/unbound.conf))

  for i in "${!dns_entries[@]}"; do
    echo "$((i+1)). ${dns_entries[i]}"
  done

  echo "$((i+2)). Return to main menu"

  read -p "Select the DNS entry to delete (enter the number): " choice

  if [[ $choice -eq $((i+2)) ]]; then
    main_menu
  else
    dns_entry_to_delete="${dns_entries[$((choice-1))]}"
    sudo sed -i "/$dns_entry_to_delete/d" /etc/unbound/unbound.conf
    sudo systemctl restart unbound
    echo "DNS entry deleted successfully."
    main_menu
  fi
}

function create_signed_certificate() {
  dns_entries=($(grep -oP '(?<=local-data: ")[^"]+(?= IN A [0-9.]+")' /etc/unbound/unbound.conf))

  for i in "${!dns_entries[@]}"; do
    echo "$((i+1)). ${dns_entries[i]}"
  done

  echo "$((i+2)). Return to main menu"

  read -p "Select the DNS entry to sign (enter the number): " choice

  if [[ $choice -eq $((i+2)) ]]; then
    main_menu
  else
    domain="${dns_entries[$((choice-1))]}"
    domain="${domain%.*}"
    cd ~/easy-rsa
    source vars
    ./easyrsa gen-req "$domain" nopass
    ./easyrsa sign-req server "$domain"

    echo "Choose the certificate format:"
    echo "1. Certificate and key files"
    echo "2. PKCS#12 file"
    echo "3. Return to main menu"

    read -p "Enter the number: " cert_choice

    case $cert_choice in
      1)
        echo "Certificate and key generated successfully."
        main_menu
        ;;
      2)
        openssl pkcs12 -export -in pki/issued/"$domain".crt -inkey pki/private/"$domain".key -name "$domain" -out "$domain".p12 -passout pass:""
        echo "PKCS#12 file generated successfully."
        main_menu
        ;;
      3)
        main_menu
        ;;
      *)
        echo "Invalid option. Please try again."
        create_signed_certificate
        ;;
    esac
  fi
}

function revoke_certificate() {
  issued_certs=($(ls ~/easy-rsa/pki/issued | grep -v 'ca.crt'))

  for i in "${!issued_certs[@]}"; do
    domain="${issued_certs[i]%.*}"
    echo "$((i+1)). $domain"
  done

  echo "$((i+2)). Return to main menu"

  read -p "Select the certificate to revoke (enter the number): " choice

  if [[ $choice -eq $((i+2)) ]]; then
    main_menu
  else
    domain="${issued_certs[$((choice-1))]}"
    domain="${domain%.*}"
    cd ~/easy-rsa
    source vars
    ./easyrsa revoke "$domain"
    ./easyrsa gen-crl

    echo "Certificate revoked successfully."
    main_menu
  fi
}

function generate_signed_cert_and_key() {
  dns_entries=($(grep -oP '(?<=local-data: ")[^"]+(?= IN A [0-9.]+")' /etc/unbound/unbound.conf))

  for i in "${!dns_entries[@]}"; do
    echo "$((i+1)). ${dns_entries[i]}"
  done

  echo "$((i+2)). Return to main menu"

  read -p "Select the DNS entry to sign (enter the number): " choice

  if [[ $choice -eq $((i+2)) ]]; then
    main_menu
  else
    domain="${dns_entries[$((choice-1))]}"
    domain="${domain%.*}"
    cd ~/easy-rsa
    source vars
    ./easyrsa gen-req "$domain" nopass
    ./easyrsa sign-req server "$domain"

    echo "Certificate and key generated successfully."
    main_menu
  fi
}

function sign_csr() {
  if [[ ! -d ~/easy-rsa/csr ]]; then
    mkdir -p ~/easy-rsa/csr
  fi

  if [[ ! -d ~/easy-rsa/csr/completed ]]; then
    mkdir -p ~/easy-rsa/csr/completed
  fi

  csr_files=($(ls ~/easy-rsa/csr | grep '\.csr$'))

  if [[ ${#csr_files[@]} -eq 0 ]]; then
    echo "No CSR files found in ~/easy-rsa/csr directory."
    main_menu
  else
    echo "Available CSR files:"
    for i in "${!csr_files[@]}"; do
      echo "$((i+1)). ${csr_files[i]}"
    done

    echo "$((i+2)). Return to main menu"

    read -p "Select the CSR file to sign (enter the number): " choice

    if [[ $choice -eq $((i+2)) ]]; then
      main_menu
    else
      csr_file="${csr_files[$((choice-1))]}"

      if [[ -f ~/easy-rsa/csr/"$csr_file" ]]; then
        # Extract the domain name from the CSR file
        domain=$(openssl req -in ~/easy-rsa/csr/"$csr_file" -noout -subject | awk -F'=' '{print $NF}' | sed 's/^ *//g')

        cd ~/easy-rsa
        source vars
        ./easyrsa import-req csr/"$csr_file" "$domain"
        ./easyrsa sign-req server "$domain"

        echo "Signed certificate generated successfully: pki/issued/${domain}.crt"

        mv ~/easy-rsa/pki/issued/"$domain".crt ~/easy-rsa/csr/completed/"$domain".crt
        echo "Signed certificate moved to ~/easy-rsa/csr/completed/${domain}.crt"

        main_menu
      else
        echo "CSR file not found. Please ensure the file is in the ~/easy-rsa/csr directory."
        main_menu
      fi
    fi
  fi
}

function main_menu() {
  echo "1. Add an Unbound DNS entry"
  echo "2. Create a signed certificate (cert and key or PKCS#12)"
  echo "3. Sign a CSR (make sure CSR is already in ~/easy-rsa/csr folder)"
  echo "4. Revoke a certificate"
  echo "5. Delete a DNS entry"
  echo "6. Exit"

  read -p "Choose an option (enter the number): " choice

  case $choice in
    1)
      add_dns_entry
      ;;
    2)
      create_signed_certificate
      ;;
    3)
      sign_csr
      ;;
    4)
      revoke_certificate
      ;;
    5)
      delete_dns_entry
      ;;
    6)
      exit 0
      ;;
    *)
      echo "Invalid option. Please try again."
      main_menu
      ;;
  esac
}

main_menu
