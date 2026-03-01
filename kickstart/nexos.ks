# ============================================================
#  NexOS Gaming Distro — Kickstart Configuration
#  Fedora 40 Base | Openbox WM | Full Gaming Stack
# ============================================================

install
text
reboot
keyboard --vckeymap=us --xlayouts=us
lang en_US.UTF-8
timezone America/New_York --utc
selinux --permissive
firewall --enabled --service=ssh

bootloader --location=mbr \
  --append="quiet splash mitigations=off nowatchdog transparent_hugepage=madvise"

clearpart --all --initlabel
autopart --type=lvm

network --bootproto=dhcp --activate

rootpw --lock
user --name=gamer --groups=wheel --password=nexos --plaintext

repo --name=fedora    --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-40&arch=x86_64
repo --name=updates   --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f40&arch=x86_64
repo --name=rpmfusion-free    --baseurl=https://download1.rpmfusion.org/free/fedora/releases/40/Everything/x86_64/os/
repo --name=rpmfusion-nonfree --baseurl=https://download1.rpmfusion.org/nonfree/fedora/releases/40/Everything/x86_64/os/

%packages --excludedocs
@core
@hardware-support
kernel
kernel-modules
kernel-modules-extra
linux-firmware
grub2
grub2-efi-x64
shim-x64
efibootmgr
dracut
xorg-x11-server-Xorg
xorg-x11-xinit
xorg-x11-drv-libinput
openbox
obconf
tint2
rofi
picom
feh
dunst
xfce4-terminal
thunar
thunar-volman
gvfs
gvfs-mtp
polkit-gnome
lxsession
xdg-user-dirs
xdg-utils
pavucontrol
blueman
lxappearance
qt5ct
google-noto-fonts-common
google-noto-emoji-fonts
papirus-icon-theme
pipewire
pipewire-alsa
pipewire-pulseaudio
pipewire-jack
wireplumber
playerctl
akmod-nvidia
xorg-x11-drv-nvidia
nvidia-settings
xorg-x11-drv-amdgpu
mesa-dri-drivers
mesa-vulkan-drivers
mesa-vdpau-drivers
libva-mesa-driver
vulkan-loader
vulkan-tools
vkd3d
wine
winetricks
cabextract
lutris
steam
steam-devices
gamemode
gamescope
mangohud
tuned
thermald
cpupower
htop
nvtop
flatpak
polkit
udisks2
upower
xdg-desktop-portal
xdg-desktop-portal-gtk
NetworkManager
NetworkManager-wifi
-gnome-shell
-gnome-desktop3
-plasma-desktop
-libreoffice*
-rhythmbox
-totem
-cheese
-evolution
%end

%post --log=/root/nexos-post.log

dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-40.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-40.noarch.rpm

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

mkdir -p /etc/tuned/nexos-gaming/
cat > /etc/tuned/nexos-gaming/tuned.conf << 'TUNED'
[main]
summary=NexOS Gaming Profile
[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100
[vm]
transparent_hugepages=madvise
[disk]
readahead=>4096
TUNED

cat > /etc/sysctl.d/99-nexos-gaming.conf << 'SYSCTL'
vm.swappiness=10
vm.max_map_count=2147483642
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_congestion_control=bbr
net.core.default_qdisc=fq
kernel.nmi_watchdog=0
kernel.sched_autogroup_enabled=1
SYSCTL

mkdir -p /etc/gamemode.ini.d/
cat > /etc/gamemode.ini.d/nexos.ini << 'GAMEMODE'
[general]
reaper_freq=5
desiredgov=performance
softrealtime=auto
renice=-10
ioprio=0
[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
amd_performance_level=high
GAMEMODE

mkdir -p /etc/skel/.config/MangoHud/
cat > /etc/skel/.config/MangoHud/MangoHud.conf << 'MANGO'
legacy_layout=false
position=top-left
background_alpha=0.5
font_size=18
fps
frametime
cpu_stats
cpu_temp
gpu_stats
gpu_temp
gpu_power
ram
vram
wine
toggle_hud=F12
MANGO

mkdir -p /etc/skel/.config/openbox/
cat > /etc/skel/.config/openbox/autostart << 'AUTOSTART'
picom --daemon &
tint2 &
dunst &
lxsession &
nm-applet &
AUTOSTART

mkdir -p /etc/skel/.config/picom/
cat > /etc/skel/.config/picom/picom.conf << 'PICOM'
backend = "glx";
vsync = true;
shadow = true;
shadow-radius = 20;
shadow-opacity = 0.5;
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
corner-radius = 12;
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;
inactive-opacity = 0.93;
PICOM

cat > /etc/modprobe.d/nexos-nvidia.conf << 'NVMOD'
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnablePCIeGen3=1
NVMOD

cat > /etc/udev/rules.d/99-nexos-gaming.rules << 'UDEV'
ACTION=="add|change", KERNEL=="js[0-9]*", SUBSYSTEM=="input", MODE="0664", GROUP="input"
ACTION=="add", ATTRS{idVendor}=="045e", MODE="0664", GROUP="input"
ACTION=="add", ATTRS{idVendor}=="054c", MODE="0664", GROUP="input"
ACTION=="add", ATTRS{idVendor}=="057e", MODE="0664", GROUP="input"
UDEV

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable tuned
systemctl enable thermald
chage -d 0 gamer

echo "NexOS post-install complete!"
%end
