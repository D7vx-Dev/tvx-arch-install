#!/bin/bash

echo "Welcome to TVX Archlinux install script"
# Ask user to select disk for installation
echo "Listing Disks:"
lsblk
echo "Please select the disk to install Arch Linux on:"
read -p "Disk (e.g. /dev/sda): " disk

echo "Partition the disk"
parted --script "${disk}" \
    mklabel gpt \
    mkpart ESP fat32 1MiB 513MiB \
    set 1 boot on \
    mkpart primary ext4 513MiB 100%

echo "Format partitions"
mkfs.fat -F32 "${disk}1"
mkfs.ext4 "${disk}2"

echo "Mount the partitions"
mount "${disk}2" /mnt
mkdir /mnt/boot
mount "${disk}1" /mnt/boot

echo "Updating system clock"
timedatectl set-ntp true

echo "Install base system"
pacstrap /mnt base base-devel linux linux-firmware

echo "Installing desktop & tools"
pacstrap /mnt plasma kate kwrite htop neofetch screenfetch ark dolphin dolphin-plugins elisa filelight kcalc konsole okular spectacle sweeper networkmanager sudo nano vim sddm

echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Generate chroot script"
cat > /mnt/tvx-chroot.sh << EOF
#!/bin/bash
echo "Setting timezone"
ln -sf /usr/share/zoneinfo/Europe/Berlin /etc/localtime
hwclock --systohc

echo "Setting system language"
pacman -S locales
echo "de_DE.UTF-8 UTF-8" > /etc/locale.gen
locale-gen
echo "LANG=de_DE.UTF-8" > /etc/locale.conf
export LANG=de_DE.UTF-8

# Install console-data package
pacman -S --noconfirm console-data

# Set keyboard layout in vconsole.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf

echo "Enable network manager"
systemctl enable NetworkManager.service

echo "Enable sddm"
systemctl enable sddm.service

echo "arch" > /etc/hostname

echo "Enter a username for the new system:"
read username
useradd -m -G wheel -s /bin/bash \$username
echo "Set a password for the root user:"
passwd
echo "Set a password for the new user:"
passwd \$username
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck
grub-mkconfig -o /boot/grub/grub.cfg

echo "Enabling multilib repository"
sed -i 's/#\[multilib\]/\[multilib\]/' /etc/pacman.conf
sed -i 's/#Include = \/etc\/pacman.d\/mirrorlist/Include = \/etc\/pacman.d\/mirrorlist/' /etc/pacman.conf
EOF

# Make chroot script executable
chmod +x /mnt/tvx-chroot.sh
mv -v tvx-chroot.sh /mnt/

echo "Chrooting into the new system"
echo "Type ./tvx-chroot.sh"
echo "if error just reexecute"
arch-chroot /mnt

echo "Installation complete. Please run tvx-chroot.sh script in the new system to perform additional configurations."
