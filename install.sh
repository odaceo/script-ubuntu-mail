#!/bin/bash

# Init variables
MailRootAddress=${1}
MailHostname=`hostname --fqdn`

# Check preconditions
if [ -z "${MailRootAddress}" ]; then
    echo 'The mail root address is required.'
    exit 1
fi

# Generate the Postifx configuration
sudo debconf-set-selections <<< "postfix postfix/main_mailer_type string 'Internet Site'"
sudo debconf-set-selections <<< "postfix postfix/mailname string ${MailHostname}"
sudo debconf-set-selections <<< "postfix postfix/root_address string ${MailRootAddress}"
sudo debconf-set-selections <<< "postfix postfix/destinations string ${MailHostname}, localhost"

# Update your local package index
sudo apt-get update

# Install the Postfix package
sudo apt-get -y install mailutils

# Configure the network interface addresses that this mail system receives mail on
sudo postconf -e "inet_interfaces = loopback-only"

# Redirect root mail to an external e-mail address
cat <<EOF | sudo tee /etc/aliases
# See man 5 aliases for format
postmaster: root
root: ${MailRootAddress}
EOF

# Rewrite the root outgoing address mail
# TODO: http://serverfault.com/questions/147921/forcing-the-from-address-when-postfix-relays-over-smtp
cat <<EOF | sudo tee /etc/postfix/generic
root ${MailRootAddress}
EOF

# Rebuild the postfix lookup tables
sudo postmap /etc/postfix/generic

# Enable sender address rewriting
sudo postconf -e "smtp_generic_maps = hash:/etc/postfix/generic"

# Reload the Postfix configuration
sudo dpkg-reconfigure -f noninteractive postfix

# Start Postfix when the system starts
sudo systemctl enable postfix

# Start Postfix
sudo systemctl restart postfix

# Send email to root
sudo mail -s "MTA / ${MailHostname}" root <<EOF
Server ${MailHostname} can send email on behalf of root.
EOF
