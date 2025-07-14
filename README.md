# Project0_Plus

System Initialization Tasks:
# 1. TODO: Create a drive initialization script - Configure the data drive to allow for the installation of crosstool-ng
# 1.a. Enumerate the hard disk devices 
# 1.b. Identify the hard disk with no active partitions
# 1.c. Create a single partition spanning the entire usable space of the identified device
# 1.d. Format the partition
# 1.e. Move \home to the newly formatted filesystem and mount it persistently

# 2. TODO: Create a network initialization script - Configure the additional unallocated network interface for DHCP
# 2.a. Enumerate the interfaces 
# 2.b. Identify the interface with no IP address assigned
# 2.c. Configure sudo dhclient <interface> to be persistently assigned after reboot

Functionality required for crosstool.sh:
# 1. Check if crosstool-ng is installed, if not, install it
# 2. Check if the architecture is supported, if not, exit with an error message
# 3. Download the appropriate config file based on the architecture
# 4. Run crosstool-ng to generate the sysroot
# 5. Provide instructions for using the generated sysroot or install the sysroot on the system

Consider:
Welcome to Ubuntu 16.04.5 LTS (GNU/Linux 4.4.0-87-generic x86_64)

 * Documentation:  https://help.ubuntu.com
 * Management:     https://landscape.canonical.com
 * Support:        https://ubuntu.com/advantage

266 packages can be updated.
196 updates are security updates.

New release '18.04.6 LTS' available.
Run 'do-release-upgrade' to upgrade to it.

.. did it... 
Still:
ldd (Ubuntu GLIBC 2.27-3ubuntu1.6) 2.27

Kernel Version
uname -r
4.15.0-213-generic

** Need kernel > 4.18
See: https://askubuntu.com/questions/517136/list-of-ubuntu-versions-with-corresponding-linux-kernel-version
Can we use do-release-upgrade to upgrade Ubuntu 16.04.5 LTS to Ubuntu 18.10?
running crosstool.sh to build glibc version that should be compatible with VSCode Extension