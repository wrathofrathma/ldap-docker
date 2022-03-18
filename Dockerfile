FROM ubuntu:latest

EXPOSE 389/tcp
EXPOSE 389/udp
EXPOSE 636/tcp
EXPOSE 636/udp

# Non interactive debian installs
ARG DEBIAN_FRONTEND=noninteractive
# Update repos
RUN apt update
# Upgrade packages
RUN apt upgrade -y

# Create directories we're going to use to store default configs and our init items
RUN mkdir -p /root/ldap

# Preseed the debconf database with our configuration for slapd
RUN apt install -y apt-utils gettext-base
COPY ./seed.txt /root/ldap/seed.txt
# RUN debconf-set-selections < /root/ldap/seed.txt

# Install ldap server with our config
RUN apt install -y slapd ldap-utils

# Copy the startup script
COPY ./startup.sh /root/startup.sh

CMD ["/usr/bin/bash", "/root/startup.sh"]

# Make directories for the user to mount their own LDIFs to
RUN mkdir -p /seed/modify
RUN mkdir -p /seed/add

# Create volume to contain our persistent data
VOLUME /data

# Environmental Variables
ENV LDAP_PASSWORD="password"
ENV LDAP_ADMIN_PASSWORD="password"
ENV LDAP_ORGANIZATION="Salisbury University"
ENV LDAP_DOMAIN="salisbury.edu"
