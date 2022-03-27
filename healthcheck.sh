#!/usr/bin/env bash

# Separates the domain into individual domain components
# i.e. example.org => dc=example,dc=org
get_domain_components() {
  echo $LDAP_DOMAIN | sed "s/\./,dc=/g" | sed "s/^/dc=/g";
}

export LDAP_DOMAIN_COMPONENTS=$(get_domain_components)

ldapwhoami -x -H ldapi:/// -D cn=admin,$LDAP_DOMAIN_COMPONENTS -w $LDAP_PASSWORD
