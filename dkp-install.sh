#! /bin/bash

echo "installing devkitpro" 
export DEVKITPRO=/opt/devkitpro
export DEVKITARM=/opt/devkitpro/devkitARM
export DEVKITPPC=/opt/devkitpro/devkitPPC

sudo pacman-key --recv BC26F752D25B92CE272E0F44F7FD5492264BB9D0 --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign BC26F752D25B92CE272E0F44F7FD5492264BB9D0

wget https://pkg.devkitpro.org/devkitpro-keyring.pkg.tar.xz

sudo pacman -U devkitpro-keyring.pkg.tar.xz --noconfirm

sudo echo '[dkp-libs]' | sudo tee -a /etc/pacman.conf
sudo echo 'Server = https://pkg.devkitpro.org/packages' | sudo tee -a /etc/pacman.conf
sudo echo ' ' | sudo tee -a /etc/pacman.conf
sudo echo '[dkp-linux]' | sudo tee -a /etc/pacman.conf
sudo echo 'Server = https://pkg.devkitpro.org/packages/windows/$arch/' | sudo tee -a /etc/pacman.conf
sudo echo ' ' | sudo tee -a /etc/pacman.conf

sudo pacman -Syu --noconfirm

sudo pacman -S 3ds-dev 3ds-portlibs nds-dev nds-portlibs wii-dev gamecube-dev wiiu-dev gba-dev --noconfirm

echo "Installation Finished"

