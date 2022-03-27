#!/usr/bin/env bash

# Volume mount point
DATA="/data"
# Token that will be in our read/write volume to verify that we've initialized.
TOKEN="$DATA/token"

# Separates the domain into individual domain components
# i.e. example.org => dc=example,dc=org
get_domain_components() {
  echo $LDAP_DOMAIN | sed "s/\./,dc=/g" | sed "s/^/dc=/g";
}

export LDAP_DOMAIN_COMPONENTS=$(get_domain_components)

# Seeds the database
seed() {
  # We need the service running if we're going to seed without slapadd
  slapd -h ldapi:///,ldaps:///,ldap:///
  echo "Seeding the database..."
  # Modifies the base configuration
  for f in /seed/modify/*; do
    ldapmodify -Q -Y EXTERNAL -H ldapi:/// -f $f
  done

  # Adds additional schema
  for f in /seed/schema/*; do
    ldapadd -Q -Y EXTERNAL -H ldapi:/// -f $f
  done

  # Seeds the database with new entries
  for f in /seed/add/*; do
    ldapadd -D cn=admin,$LDAP_DOMAIN_COMPONENTS -f $f -H ldapi:/// -x -w $LDAP_PASSWORD
  done

  # Kill it so we can run it properly later
  killall -e -9 slapd
}

# Initialization function
initialize() {
  echo "Initializing the container..."
  # Setup environmental variables
  # Copy the base configuration and db to the new mount point
  echo "Moving databases to volume..."
  mkdir $DATA/ldap
  mv /etc/ldap $DATA/ldap/config
  mv /var/lib/ldap $DATA/ldap/db

  # Overwrite the default directories
  echo "Symlinking the volume to the old database locations..."
  ln -sf $DATA/ldap/config /etc/ldap
  ln -sf $DATA/ldap/db /var/lib/ldap

  # Match permissions of the original directory
  chown -R openldap:openldap /var/lib/ldap

  echo "Updating debconf selections for our headless install..."
  # Overwrite the default debconf settings for slapd
  envsubst < /root/ldap/seed.txt | debconf-set-selections

  echo "Configuring slapd..."
  # Reconfigure slapd to properly init slapd with our domain and stuff.
  DEBIAN_FRONTEND=noninteractive dpkg-reconfigure slapd

  # Seed the database
  seed

  # Write that we've finished initialization to the disk
  touch "$TOKEN"
}


# Run the initialization if the token doesn't exist.
if [[ ! -e $TOKEN ]]; then
  initialize
fi

echo "Starting slapd..."
# Start the slapd service
slapd -h "ldapi:/// ldaps:/// ldap:///"

# Create a shell so we can connect and disconnect
exec /bin/bash
