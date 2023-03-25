#!/bin/bash

echo "Welcome to TVX Archlinux install script"
# Ask user to select disk for installation
echo "Listing Disks:"
lsblk
echo "Please select the disk to install Arch Linux on:"
read -p "Disk (e.g. /dev/sda): " disk

echo "Which desktop environment would you like to install? Type 'kde' or 'gnome': "
read desktop_env

echo "Partition the disk"
parted --script "${disk}" \
    mklabel msdos \
    mkpart primary ext4 1MiB 100% \
    set 1 boot on

echo "Format partitions"
mkfs.ext4 "${disk}1"

echo "Mount the partitions"
mount "${disk}1" /mnt

echo "Updating system clock"
timedatectl set-ntp true

echo "Setup Mirrorlist"
pacman -S reflector --noconfirm
reflector -c "US" -f 12 -l 10 -n 12 --save /etc/pacman.d/mirrorlist

echo "Install base system"
pacstrap /mnt base base-devel linux linux-firmware

echo "Installing desktop & tools"
pacstrap /mnt wget htop neofetch screenfetch networkmanager firefox sudo nano vim discord base-devel git jre-openjdk-headless python3 python-pip cmake

# Install packages based on user's choice
if [ "$desktop_env" = "kde" ]; then
  pacstrap /mnt plasma kate kwrite ark dolphin dolphin-plugins elisa filelight kcalc konsole okular spectacle sweeper sddm
elif [ "$desktop_env" = "gnome" ]; then
  pacstrap /mnt gdm gnome gnome-tweaks gedit gnome-calculator gnome-terminal gnome-system-monitor file-roller evince totem eog gnome-screenshot gnome-disk-utility gnome-shell-extensions gnome-software
else
  echo "Invalid choice. Please type 'kde' or 'gnome'."
  exit 1
fi

echo "Generate fstab"
genfstab -U /mnt >> /mnt/etc/fstab

echo "Generate chroot script"
cat > /mnt/tvx-chroot.sh << EOF
#!/bin/bash

echo "Enter a username for the new system:"
read username
useradd -m -G wheel -s /bin/bash \$username
echo "Set a password for the new user:"
passwd \$username
echo "Set a password for the root user:"
passwd
echo '%wheel ALL=(ALL) ALL' >> /etc/sudoers

echo "Which GPU driver do you want to install?"
echo "1. NVIDIA"
echo "2. AMD"
echo "3. Intel"
read -p "Enter your choice (1, 2, or 3): " choice

if [[ \$choice == 1 ]]; then
    echo "Installing NVIDIA drivers..."
    pacman -S nvidia nvidia-utils nvidia-settings --noconfirm
    systemctl enable nvidia-persistenced
    systemctl enable nvidia-fallback
elif [[ \$choice == 2 ]]; then
    echo "Installing AMD drivers..."
    pacman -S mesa vulkan-radeon libva-mesa-driver libva-vdpau-driver --noconfirm
    pacman -S lib32-mesa lib32-vulkan-radeon lib32-libva-mesa-driver lib32-libva-vdpau-driver --noconfirm
elif [[ \$choice == 3 ]]; then
    echo "Installing Intel drivers..."
    pacman -S mesa libva-intel-driver vulkan-intel --noconfirm
    pacman -S lib32-mesa lib32-libva-intel-driver lib32-vulkan-intel --noconfirm
else
    echo "Invalid choice. Exiting..."
    exit 1
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

if [ "$desktop_env" = "kde" ]; then
  pacman -S --noconfirm sddm
  systemctl enable sddm.service
elif [ "$desktop_env" = "gnome" ]; then
  pacman -S --noconfirm gdm
  systemctl enable gdm.service
else
  echo "Impossible to get here... i thought"
fi

echo "arch" > /etc/hostname
touch /etc/hosts
echo "127.0.0.1	localhost\n::1		localhost\n127.0.1.1	myarch" > /etc/hosts

pacman -S grub --noconfirm
grub-install --target=i386-pc "$disk"
grub-mkconfig -o /boot/grub/grub.cfg

flatpak install flathub com.valvesoftware.Steam -y

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

cd /boot/grub/themes/
sudo mkdir arch
sudo wget https://github.com/AdisonCavani/distro-grub-themes/releases/download/v3.1/arch.tar
sudo tar -xf arch.tar -C arch/
echo 'GRUB_THEME="/boot/grub/themes/arch/theme.txt"' | sudo tee -a /etc/default/grub
pacman -S grub --noconfirm
grub-mkconfig -o /boot/grub/grub.cfg

cat > /home/\$username/finish_install.sh << EOF2
#!/bin/bash
echo "Installing Tools"
yay -Sy --noconfirm visual-studio-code-bin
yay -Sy --noconfirm spotify

echo "Fix Gnome thing"
if [ "$desktop_env" = "gnome" ]; then
  yay -Sy --noconfirm gnome-browser-connector
else
  echo "Don't need this for KDE!"
fi
EOF2
chmod +x /home/\$username/finish_install.sh
chown \$username:\$username /home/\$username/finish_install.sh
echo "Install Finisched!"
echo "Rebbot, Login and in terminal type ./finish_install.sh"
EOF

# Make chroot script executable
chmod +x /mnt/tvx-chroot.sh
mv -v tvx-chroot.sh /mnt/

echo "Chrooting into the new system"
echo "Type ./tvx-chroot.sh"
echo "if error just reexecute"
arch-chroot /mnt

echo "Installation complete. Please run tvx-chroot.sh script in the new system to perform additional configurations."
