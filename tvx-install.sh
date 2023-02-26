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

echo "Setup Mirrorlist"
pacman -S reflector --noconfirm
reflector -c "US" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist

echo "Install base system"
pacstrap /mnt base base-devel linux linux-firmware

echo "Installing desktop & tools"
pacstrap /mnt plasma kate kwrite htop neofetch screenfetch ark dolphin dolphin-plugins elisa filelight kcalc konsole okular spectacle sweeper networkmanager firefox sudo nano vim sddm discord base-devel git jre-openjdk-headless python3 python-pip cmake

echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Generate chroot script"
cat > /mnt/tvx-chroot.sh << EOF
#!/bin/bash

echo "Which GPU driver do you want to install?"
echo "1. NVIDIA"
echo "2. AMD"
echo "3. Intel"
echo "4. AMD ROCm"
read -p "Enter your choice (1, 2, 3 or 4): " choice
case $choice in
  1)
    echo "Installing NVIDIA drivers..."
    sudo pacman -S nvidia nvidia-utils nvidia-settings
    sudo systemctl enable nvidia-persistenced
    sudo systemctl enable nvidia-fallback
    ;;
  2)
    echo "Installing AMD drivers..."
    sudo pacman -S mesa vulkan-radeon libva-mesa-driver libva-vdpau-driver
    sudo pacman -S lib32-mesa lib32-vulkan-radeon lib32-libva-mesa-driver lib32-libva-vdpau-driver
    ;;
  3)
    echo "Installing Intel drivers..."
    sudo pacman -S mesa libva-intel-driver vulkan-intel
    sudo pacman -S lib32-mesa lib32-libva-intel-driver lib32-vulkan-intel
    ;;
  4)
    echo "Installing AMD ROCm drivers..."
    sudo pacman -S rocm-libs rocm-dev rocm-utils
    ;;
  *)
    echo "Invalid choice. Exiting..."
    exit 1
    ;;
esac

if [[ $choice == 1 || $choice == 2 || $choice == 3 || $choice == 4 ]]; then
  echo "GPU driver installation completed successfully. You can now use your GPU."
else
  echo "GPU driver installation failed. Please try again."
fi


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
pacman -S --noconfirm console-data ntfs-3g

# Set keyboard layout in vconsole.conf
echo "KEYMAP=de-latin1" > /etc/vconsole.conf

echo "Enable network manager"
systemctl enable NetworkManager.service

echo "Enable sddm"
systemctl enable sddm.service

echo "arch" > /etc/hostname
touch /etc/hosts
echo "127.0.0.1	localhost\n::1		localhost\n127.0.1.1	myarch" > /etc/hosts

echo "Enter a username for the new system:"
read username
useradd -m -G wheel -s /bin/bash \$username
echo "Set a password for the new user:"
passwd \$username
echo "Set a password for the root user:"
passwd
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers
pacman -S grub efibootmgr --noconfirm
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch_grub --recheck
grub-mkconfig -o /boot/grub/grub.cfg

flatpak install brave -y
flatpak install flathub com.valvesoftware.Steam -y
flatpak install flathub com.spotify.Client -y
flatpak install flathub com.visualstudio.code -y

# Install VirtualBox and required packages
pacman -S virtualbox virtualbox-host-modules-arch virtualbox-guest-utils --noconfirm

# Enable the vboxdrv kernel module
modprobe vboxdrv

# Enable and start the vboxservice systemd service
systemctl enable vboxservice.service
systemctl start vboxservice.service

wget https://github.com/tvx-dev/packages/raw/main/multimc-bin-x86_64.pkg.tar.zst
pacman -U --noconfirm multimc-bin-x86_64.pkg.tar.zst
wget https://github.com/tvx-dev/packages/raw/main/yay-x86_64.pkg.tar.zst
pacman -U --noconfirm yay-x86_64.pkg.tar.zst

EOF

# Make chroot script executable
chmod +x /mnt/tvx-chroot.sh
mv -v tvx-chroot.sh /mnt/

echo "Chrooting into the new system"
echo "Type ./tvx-chroot.sh"
echo "if error just reexecute"
arch-chroot /mnt

echo "Installation complete. Please run tvx-chroot.sh script in the new system to perform additional configurations."
