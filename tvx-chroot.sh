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

read -p "Enter hostname: " hstm
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

read -p "Enter username: " username
echo "Creating new user"
if [[ -z "$username" ]]; then
  useradd -m -g users -G wheel -s /bin/bash $username
  passwd $username
else
  useradd -m -g users -G wheel -s /bin/bash arch
  passwd arch
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
