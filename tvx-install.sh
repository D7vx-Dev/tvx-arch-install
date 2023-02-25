#!/bin/bash

echo "Welcome to Arch Linux installation script"

read -p "Do you want to install in EFI mode? (y/n) " choice
case "$choice" in 
  y|Y ) efi="true";;
  n|N ) efi="false";;
  * ) echo "Invalid choice"; exit;;
esac

lsblk
read -p "Enter the disk to partition: " disk

if [ "$efi" == "true" ]; then
  echo "Creating partitions"
  parted --script /dev/$disk mklabel gpt
  parted --script /dev/$disk mkpart ESP fat32 1MiB 512MiB
  parted --script /dev/$disk set 1 boot on
  parted --script /dev/$disk mkpart primary ext4 512MiB 100%
  
  echo "Formatting partitions"
  mkfs.fat -F32 /dev/${disk}1
  mkfs.ext4 /dev/${disk}2
  
  echo "Mounting partitions"
  mount /dev/${disk}2 /mnt
  mkdir /mnt/boot
  mount /dev/${disk}1 /mnt/boot
else
  echo "Creating root partition"
  parted --script /dev/$disk mklabel msdos
  parted --script /dev/$disk mkpart primary ext4 1MiB 100%
  parted --script /dev/$disk set 1 boot on

  echo "Formatting partition"
  mkfs.ext4 /dev/${disk}1

  echo "Mounting partition"
  mount /dev/${disk}1 /mnt
fi

echo "Updating system clock"
timedatectl set-ntp true

echo "Installing base system"
pacstrap /mnt base linux linux-firmware

echo "Installing desktop & tools"
pacstrap /mnt plasma kate kwrite htop neofetch screenfetch ark dolphin dolphin-plugins elisa filelight kcalc konsole okular spectacle sweeper networkmanager sudo nano vim sddm

echo "Installing Grubinstaller"
if [ "$efi" == "true" ]; then
  pacstrap /mnt grub efibootmgr
else
  pacstrap /mnt grub
fi

echo "Install ntfs Support"
pacstrap /mnt ntfs-3g

echo "Generating fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Getting Chroot script"
wget https://raw.githubusercontent.com/tvx-dev/tvx-arch-install/main/tvx-chroot.sh
mv -v tvx-chroot.sh /mnt/root/
echo "Chrooting into the new system"
arch-chroot /mnt
