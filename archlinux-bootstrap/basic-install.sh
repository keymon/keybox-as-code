#!/bin/bash
#
# Bootstrap of archlinux on my lenovo desktop.
#
# More info:
#  - https://github.com/helmuthdu/aui/blob/master/fifo
#  - https://wiki.archlinux.org/index.php/Dm-crypt/Device_encryption#Formatting_LUKS_partitions
#

#############################################################################
# Default variables
computer_name=keytocho
disk=/dev/sda
timezone=Europe/London

# other
MOUNTPOINT=/mnt

#############################################################################
SCRIPT_NAME=$0

usage() {
	cat <<EOF
Bootstraps the archlinux system on my Lenovo w530.

Prereqs, start the SSH daemon and set a default password with:

	wifi-menu # setup wifi
	ssh-keygen -A && /usr/sbin/sshd -o Port=2222 && echo root:root1 | chpasswd

Usage:
	$SCRIPT_NAME <ip>
EOF
}


if [ $# -lt 1 ]; then
	usage && exit
fi
ip=$1

read -p "This will destroy the disk storage! continue [Y/n]" continue
[ "$continue" == "Y" -o  "$continue" == "y"  ] || exit 1

# Copy SSH key
ssh-copy-id root@$ip

# Remove the old vg00
vgremove -f vg00
cryptsetup close lvm

# Create the partition table
boot_partition=${disk}1
luks_partition=${disk}2
home_pv=/dev/vg00/home
root_pv=/dev/vg00/root
swap_pv=/dev/vg00/swap

parted -a optimal $disk mklabel msdos ; sleep 2
parted -a optimal -- $disk unit compact mkpart primary ext2 "1" "1G"
parted -a optimal -- $disk unit compact mkpart primary  "1G" "-1"
partprobe $disk

# Format disks
mkfs.ext2 -F ${boot_partition}

# Encrypt main volume. Will ask for password
cryptsetup \
	--cipher aes-xts-plain64 \
	--key-size 512 \
	--hash sha512 \
	--iter-time 5000 \
	--verify-passphrase \
	luksFormat $luks_partition

cryptsetup open --type luks $luks_partition cryptlvm

# Setup LVM
pvcreate /dev/mapper/cryptlvm
vgcreate vg00 /dev/mapper/cryptlvm
lvcreate -L 30G vg00 -n root
lvcreate -L 8G vg00 -n swap
lvcreate -l +80%FREE vg00 -n home

# Format systems
mkfs.ext4 -F /dev/vg00/root
mkfs.ext4 -F /dev/vg00/home
mkswap -f /dev/vg00/swap

# Mount FS
swapon /dev/vg00/swap
mount /dev/vg00/root /mnt
mkdir -p /mnt/boot /mnt/home
mount /dev/vg00/home /mnt/home
mount /dev/sda1 /mnt/boot

# Install the Base system
pacstrap /mnt base
pacstrap /mnt grub grub-bios os-prober
pacstrap /mnt openssh
pacstrap /mnt python2 # required for ansible 

# configure basic stuff
genfstab -p /mnt >> /mnt/etc/fstab
echo $computer_name > /mnt/etc/hostname
§ ln -sf /usr/share/zoneinfo/$timezone /etc/localtime

# Configure mkinitcpio&grub
sed -i '/^HOOK/s/block/block keymap encrypt/' /mnt/etc/mkinitcpio.conf
sed -i '/^HOOK/s/filesystems/lvm2 filesystems/' /mnt/etc/mkinitcpio.conf
arch-chroot /mnt mkinitcpio -p linux

sed -i \
	-e "s|GRUB_CMDLINE_LINUX=\"\(.\+\)\"|GRUB_CMDLINE_LINUX=\"\1 cryptdevice=${luks_partition}:cryptlvm\"|g" \
	-e "s|GRUB_CMDLINE_LINUX=\"\"|GRUB_CMDLINE_LINUX=\"cryptdevice=${luks_partition}:cryptlvm\"|g" \
	${MOUNTPOINT}/etc/default/grub
arch-chroot /mnt grub-install --target=i386-pc --recheck --debug $disk
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

# Root password
echo "Type root password"
arch-chroot /mnt passwd

# Setup SSH
arch-chroot /mnt ssh-keygen -A
# systemctl stop sshd.service # stop SSH in the installer
arch-chroot /mnt /usr/sbin/sshd -o Port=2222 # start ssh on port 2222
arch-chroot /mnt systemctl enable sshd.service
mkdir -p /mnt/root/.ssh/
cp ~/.ssh/authorized_keys /mnt/root/.ssh/authorized_keys

# Setup wifi
pacstrap /mnt netctl dialog wpa_supplicant wpa_actiond # for wifi
rsync -av /etc/netctl/ /mnt/etc/netctl # Copy current config
arch-chroot /mnt systemctl enable netctl-auto@wlp3s0.service # connect wifi automagically

# Links
systemctl enable netctl-ifplugd@enp0s25.service
systemctl enable netctl-ifplugd@wwp0s20u4i6.service

########
reboot # done, from here, ansible :)


