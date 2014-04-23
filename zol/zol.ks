# Kickstart file for use as a minimal (~240 packages) CentOS/RHEL v6.x installer for a ZOL (ZFS on Linux) test VM
# Expects the following hardware:
# 512+MB RAM
# Hard disk 1 = 6+GB	OS
# Hard disk 2 = 4+GB	data	(ZFS, will be provisioned later)
# Hard disk 3 = 4+GB	logs	(ZFS, will be provisioned later)
# Updated for CentOS v6.5
#
# NOTE: Edit network and timezone as necessary
# See:
# http://fedoraproject.org/wiki/Anaconda/Kickstart
# &
# https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-options.html
# for latest documentation of kickstart options

# platform=x86, AMD64, or Intel EM64T
# version=1.0

# Install OS instead of upgrade
install

# Use network installation
url --url="http://mirror.centos.org/centos/6.5/os/x86_64/"

# System language
# Using en_US.UTF-8 over en_US as it gives us correct ncurses UI display in the console.
lang en_US.UTF-8

# System keyboard
keyboard us

# Use text mode (ncurses) install
text

# Install logging level
logging --level=info

# Enable firewall, open ports for ssh, HTTP and HTTPS (TCP 22, 80 and 443)
# The ssh option is enabled by default, regardless of the presence of the --ssh flag. See: http://fedoraproject.org/wiki/Anaconda/Kickstart#firewall
firewall --enabled --ssh --http --port=443:tcp

# Use SHA-512 encrypted password instead of the usual UNIX crypt or md5
authconfig --enableshadow --passalgo=sha512

# Root password
rootpw ZOL2014

# SELinux configuration
# See http://zfsonlinux.org/faq.html
# 1.14 How do I automatically mount ZFS file systems during startup?
selinux --permissive

# Edit the network settings as required
# If you need to manually specify network settings during an otherwise-automated kickstart installation, do not use network.
# Instead, boot the system with the "asknetwork" option (refer to Section 32.10, “Starting a Kickstart Installation”), which will prompt
## https://access.redhat.com/site/documentation/en-US/Red_Hat_Enterprise_Linux/6/html/Installation_Guide/s1-kickstart2-startinginstall.html
# anaconda to ask you for network settings rather than use the default settings. anaconda will ask this before fetching the kickstart file.
# Once the network connection is established, you can only reconfigure network settings with those specified in your kickstart file.
network --device=eth0 --onboot=yes --noipv6 --bootproto=dhcp

# Do not configure the X Window System
skipx

# Reboot after the installation is complete and eject the install DVD. Normally, kickstart displays a message and waits for the user to press a key before rebooting.
# default is halt
# reboot --eject

# System timezone - Edit as required
# Option --utc — If present, the system assumes the hardware clock is set to UTC (Greenwich Mean) time.
timezone --utc America/New_York # Eastern
# timezone --utc America/Chicago # Central
# timezone --utc America/Boise # Mountain
# timezone --utc America/Phoenix # Mountain - No DST observed in AZ except in the Navajo Nation
# timezone --utc America/Los_Angeles # Pacific


# System bootloader configuration
bootloader --location=mbr --driveorder=sda,sdb,sdc,sdd --append="crashkernel=auto rhgb quiet"

# If zerombr is specified any invalid partition tables found on disks are initialized. This destroys all of the contents of disks with invalid partition tables.
zerombr

# Disk partitioning information
clearpart --all --initlabel
part /boot --fstype="ext4" --size=256 --ondisk=sda
part swap --fstype="swap" --size=1024 --ondisk=sda
part / --fstype="ext4" --grow --size=1 --ondisk=sda

##############################################################################
#
# packages part of the KickStart configuration file
#
##############################################################################
# following is MINIMAL https://partner-bugzilla.redhat.com/show_bug.cgi?id=593309
# Minimal + the packages listed below = 240 packages
%packages --nobase
@core
@server-policy
@network-file-system-client
nano
system-config-network-tui
ntp
perl
nfs-utils
wget
unzip
rsync
man
logwatch
dmidecode # Needed for vSphere version checking
# firstboot - This crap has ~100 dependant packages and takes 170MB on disk! Don't fall for it.
# xfsprogs # Only install on systems with an XFS filesystem
parted
pciutils
lsof
patch
bind-utils # provides nslookup and dig
# Don't install these packages, no need for firmware patches on a VM, gets us down to 240 packages
-iwl100-firmware
-netxen-firmware
-iwl6000g2b-firmware
-bfa-firmware
-iwl5150-firmware
-iwl6050-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-aic94xx-firmware
-rt61pci-firmware
-ql2400-firmware
-iwl5000-firmware
-libertas-usb8388-firmware
-xorg-x11-drv-ati-firmware
-atmel-firmware
-iwl4965-firmware
-iwl1000-firmware
-iwl3945-firmware
-ql2200-firmware
-rt73usb-firmware
-ql2100-firmware
-ql2500-firmware
-zd1211-firmware
-ipw2100-firmware
-ql23xx-firmware
-ipw2200-firmware
-ivtv-firmware
-b43-openfwwf.noarch
%end
