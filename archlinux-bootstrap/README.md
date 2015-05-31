Bootstrap Archlinux
===================

This scripts will bootstrap the initial installation of archlinux. 

It follows the KISS phylosophy and it is just designed to run in my system
but easy to adapt. I got stuff from the wiki and the AUI installer.

To run it, the only pre-requisite is have a running connection with SSH:

	wifi-menu # setup wifi
	ssh-keygen -A && /usr/sbin/sshd -o Port=2222 && echo root:root1 | chpasswd
	ip addr list # check the ip

Then just do SSH and run the script, by copying or downloading the file or
by copy&paste (recommended :))

    scp -o Port=2222 basic-install.sh root@<ip>:
    ssh root@<ip> ./basic-install.sh <ip>
 
