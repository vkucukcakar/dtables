#!/usr/bin/env bash

###
# sptables - Pure Iptables firewall for servers
#
# Copyright (c) 2018, Volkan Kucukcakar
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
###

###
# This file is a part of sptables - Pure Iptables firewall for servers
# Filename		: install.sh
# Description	: sptables installer
###


# This installation file tested on Debian Stretch, Ubuntu 17, CentOS 7
# Requires iptables, ipset, systemd to be installed


### Pre-defined command paths, correct if something goes wrong! ###


# ipset command ( default = ipset )
IPSET="ipset"

# iptables command ( default = iptables )
IPTABLES="iptables"

# systemctl command ( default = systemctl )
SYSTEMCTL="systemctl"

# Systemd vendor path ( default = /usr/lib/systemd )
USRSYSTEMD="/usr/lib/systemd"

# sysctl command ( default = sysctl )
SYSCTL="sysctl"

# sysctl.d path ( default = /etc/sysctl.d )
SYSCTLD="/etc/sysctl.d"


### Check installation requirements ###


# Check if running with root permissions
[ `id -u` -eq 0 ] || { echo "Error: This script must be run as root. Please run as root or try \"sudo\"."; exit 1; }

# Check if Docker installed
docker --version >/dev/null 2>&1
EXITCODE=$?
if [[ $EXITCODE > 0 ]]; then
	echo "Notice: Docker not installed. sptables will run in standalone mode.";
else
	echo "Notice: Docker is installed. sptables will run in Docker mode.";
fi

# Check if ipset available
$IPSET --version >/dev/null 2>&1 || { echo "Error: \"IPset\" not available, please install IPset to continue."; exit 1; }

# Check if iptables available
$IPTABLES --version >/dev/null 2>&1 || { echo "Error: \"Iptables\" not available, please install Iptables to continue."; exit 1; }

# Check if systemctl available
$SYSTEMCTL --version >/dev/null 2>&1 || { echo "Error: \"Systemd\" not available, please install Systemd to continue or use manual installation as described in README.md."; exit 1; }

# Check if Systemd vendor path exists
[ -d $USRSYSTEMD ] || { echo "Error: \"Systemd\" vendor path not found."; exit 1; }

# Check if sysctl available
$SYSCTL --version >/dev/null 2>&1 || { echo "Error: \"sysctl\" not available."; exit 1; }

# Check if sysctl.d path exists
[ -d $SYSCTLD ] || { echo "Error: \"sysctl.d\" path not found."; exit 1; }

# Check if ip command is available
ip -V >/dev/null 2>&1 || { echo "Error: \"ip\" command not available, please install the required packages or use manual installation described in README.md."; exit 1; }

# Check if grep command is available
grep --version >/dev/null 2>&1 || { echo "Error: \"grep\" command not available, please install the required packages or use manual installation described in README.md."; exit 1; }

# Check if sed command is available
sed --version >/dev/null 2>&1 || { echo "Error: \"sed\" command not available, please install the required packages or use manual installation described in README.md."; exit 1; }

# Check if already installed
[ -d /etc/sptables ] && { echo "Error: Already installed. Backup and delete the old installation ( mv /etc/sptables /etc/sptables.backup ) to repair or install again."; exit 1; }


### Start installation ###

# Get default network interface name
#IF_NAME=$(ip route | grep "^default\s" | sed -e "s/^.*dev\s//" -e "s/\s.*//")
IF_NAME=$(ip route | grep "^default[[:blank:]]" | sed -e "s/^.*dev[[:blank:]]//" -e "s/[[:blank:]].*//")
if [ ! "$IF_NAME" ]; then
	echo -e "\e[31mWarning: Default network interface name could not be detected automatically. Please manually edit \"/etc/sptables/conf/iptables.conf\" and \"/etc/sptables/conf/iptables.docker.conf\" files and replace \"eth0\" with your default network interface name after installation.\e[0m";
fi

# Exit on errors
set -e

# Enable xtrace
set -x

# Copy files
{ echo -e "Copying files"; } 2> /dev/null;
mkdir /etc/sptables
cp -rf files/* /etc/sptables/

# Replace "eth0" with the default network interface name in configuration files
if [ "$IF_NAME" ]; then
	sed 's/\([ 	"]\)eth0\([ 	"]\)/\1'"$IF_NAME"'\2/g' files/conf/iptables.conf > /etc/sptables/conf/iptables.conf
	sed 's/\([ 	"]\)eth0\([ 	"]\)/\1'"$IF_NAME"'\2/g' files/conf/iptables.docker.conf > /etc/sptables/conf/iptables.docker.conf
fi

# Apply Sysctl hardening configuration
{ echo -e "Applying Sysctl hardening configuration"; } 2> /dev/null;
# Make symbolic link to sysctl.hardening.conf
ln -sf /etc/sptables/conf/sysctl.hardening.conf $SYSCTLD/zzz-sysctl.hardening.conf
# Make sysctl read all configuration files again
$SYSCTL --quiet --system

# Give execute permission to scripts
{ echo -e "\nSetting permissions"; } 2> /dev/null;
chmod +x /etc/sptables/start.sh
chmod +x /etc/sptables/stop.sh
chmod +x /etc/sptables/reload.sh
chmod +x /etc/sptables/save.sh

# Create symbolic links for systemd services
{ echo -e "\nCreating symbolic link"; } 2> /dev/null;
[ -d $USRSYSTEMD/system ] || mkdir $USRSYSTEMD/system
ln -sf /etc/sptables/service/sptables.service $USRSYSTEMD/system/

# Reload systemd manager configuration
{ echo -e "\nReloading systemd manager configuration"; } 2> /dev/null;
$SYSTEMCTL daemon-reload

# Echo sysctl notice
{ echo -e "\nWarning: Your default sysctl configuration is not modified but a new symbolic link to sysctl hardening configuration is created in $SYSCTLD/.\n\nDefault sysctl configuration file /etc/sysctl.conf has always higher predecence over vendor configurations.\n\nPlease make sure that /etc/sysctl.conf does not contain directives overriding sysctl hardening configuration at /etc/sptables/conf/sysctl.hardening.conf"; } 2> /dev/null;

# Completed
{ echo -e "\nInstallation completed. Please see README.md for usage."; } 2> /dev/null;
