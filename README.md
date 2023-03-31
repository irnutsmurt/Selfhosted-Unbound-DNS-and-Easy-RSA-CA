# Selfhosted-Unbound-DNS-and-Easy-RSA-CA
Automated script for installing Unbound and Easy-RSA. Includes a script for adding and removing DNS entries into unbound, as well as easily creating your own CA. I got tired of all the guides that were like "install this. run this command. configure this option." I'm able to do this, but not everyone can. So I created these 2 scripts that will automate the installation of Unbound, Easy-RSA, and OpenSSL for Ubuntu Server 20.04 and Raspberry Pi OS. 

place both scripts in the same directory then type
```chmod +x install-unbound-easy-rsa.sh && chmod +x add-dns-sign-cert.sh```

Then run the install-unbound-easy-rsa.sh
```./install-unbound-easy-rsa.sh```

The install script will replace a variable in the add-dns-sign-cert.sh ```user_domain="your_domain_here"```
But if you don't need to install these, then just run the add-dns-sign-cert.sh and replace the "your_domain_here" with your respective domain.

