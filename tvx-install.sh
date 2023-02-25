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
  read -p "Enter size of root partition (in GB): " root_size
  read -p "Do you want to create a swap partition? (y/n) " swap_choice
  case "$swap_choice" in 
    y|Y ) read -p "Enter size of swap partition (in GB): " swap_size;;
    n|N ) swap_size="0";;
    * ) echo "Invalid choice"; exit;;
  esac

  echo "Creating root partition"
  parted --script /dev/$disk mklabel msdos
  parted --script /dev/$disk mkpart primary ext4 1MiB ${root_size}GB
  parted --script /dev/$disk set 1 boot on
  
  if [ "$swap_size" != "0" ]; then
    echo "Creating swap partition"
    parted --script /dev/$disk mkpart primary linux-swap ${root_size}GB 100%
    mkswap /dev/${disk}2
    swapon /dev/${disk}2
  fi
  
  echo "Formatting partitions"
  mkfs.ext4 /dev/${disk}1
  
  echo "Mounting partitions"
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

read -p "Enter username: " username
read -p "Enter hostname: " hstm

echo "Chrooting into the new system"
arch-chroot /mnt /bin/bash <<EOF
echo "Setting timezone"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

echo "Setting system language"
pacman -S locales
echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
export LANG=de_DE.UTF-8

echo "Setting keyboard layout"
pacman -S console-data
loadkeys de-latin1

echo "Setting hostname"
if [[ -z "$hstm" ]]; then
  echo "arch" > /etc/hostname
else
  echo "$hstm" > /etc/hostname
fi

echo "Enable network manager"
systemctl enable NetworkManager.service

echo "Enable sddm"
systemctl enable sddm.service

echo "Creating new user"
if [[ -z "$username" ]]; then
  useradd -m -g users -G wheel -s /bin/bash \$USERNAME
else
  useradd -m -g users -G wheel -s /bin/bash "$username"
fi

echo "Configuring bootloader"
if [ "$efi" == "true" ]; then
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
else
  grub-install /dev/\$disk
fi
grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling multilib repository"
sed -i 's/#\[multilib\]/\[multilib\]/' /etc/pacman.conf
sed -i 's/#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf

echo "Installation complete!"
EOF
echo "Chrooting into /mnt"
echo "Please type passwd and passwd <your uasername> or passwd arch"
arch-chroot /mnt
