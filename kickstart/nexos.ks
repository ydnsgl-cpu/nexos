# ============================================================
#  NexOS Gaming Distro — Kickstart Configuration
#  Fedora 40 Base | Openbox WM | Full Gaming Stack
# ============================================================

# ── Installation basics ───────────────────────────────────────
install
text
reboot
keyboard --vckeymap=us --xlayouts=us
lang en_US.UTF-8
timezone America/New_York --utc
selinux --permissive
firewall --enabled --service=ssh

# ── Bootloader ────────────────────────────────────────────────
bootloader --location=mbr --boot-drive=sda \
  --append="quiet splash mitigations=off nowatchdog nohz_full=1-7 rcu_nocbs=1-7 transparent_hugepage=madvise vm.swappiness=1 kernel.nmi_watchdog=0"
# mitigations=off   → removes spectre/meltdown perf penalties (gaming trade-off)
# nohz_full=1-7     → tickless CPU cores (assumes 8-core CPU, safe for all)
# transparent_hugepage=madvise → better RAM use for games

# ── Disk layout ───────────────────────────────────────────────
clearpart --all --initlabel
autopart --type=lvm

# ── Network ───────────────────────────────────────────────────
network --bootproto=dhcp --activate

# ── Users ─────────────────────────────────────────────────────
rootpw --lock
user --name=gamer --groups=wheel,gamemode --password=nexos --plaintext
# User will be prompted to change password on first login

# ── Repos ─────────────────────────────────────────────────────
repo --name=fedora        --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=fedora-40&arch=x86_64
repo --name=updates       --mirrorlist=https://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f40&arch=x86_64
repo --name=rpmfusion-free        --baseurl=https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-40.noarch.rpm
repo --name=rpmfusion-nonfree     --baseurl=https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-40.noarch.rpm
repo --name=terra         --baseurl=https://terra.fyralabs.com/terra40
repo --name=copr-mangohud --baseurl=https://download.copr.fedorainfracloud.org/results/gloriouseggroll/mangohud/fedora-40-x86_64/

# ── Package groups & individual packages ─────────────────────
%packages --excludedocs
# === Core System ===
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

# === Display Server ===
xorg-x11-server-Xorg
xorg-x11-xinit
xorg-x11-drv-libinput
xorg-x11-utils

# === Lightweight Desktop (Openbox Stack) ===
openbox
obconf
obmenu-generator
tint2                    # taskbar
rofi                     # app launcher (replaces heavy docks)
picom                    # compositor (blur, transparency, vsync)
feh                      # wallpaper setter
dunst                    # notifications
xfce4-terminal           # fast terminal
thunar                   # file manager
thunar-volman
gvfs
gvfs-mtp
polkit-gnome
lxsession                # lightweight session/polkit agent
xdg-user-dirs
xdg-utils
pavucontrol              # audio control
blueman                  # bluetooth

# === Fonts & Icons ===
google-noto-fonts-common
google-noto-emoji-fonts
fontawesome-fonts
papirus-icon-theme

# === Theming ===
gtk3
gtk4
lxappearance             # GTK theme switcher
qt5ct
adwaita-qt5
kvantum

# === Audio ===
pipewire
pipewire-alsa
pipewire-pulseaudio
pipewire-jack
wireplumber
playerctl

# === GPU Drivers — NVIDIA =====================================
akmod-nvidia             # NVIDIA kernel module (RPMFusion)
xorg-x11-drv-nvidia
xorg-x11-drv-nvidia-cuda
nvidia-settings
nvidia-vaapi-driver
libva-nvidia-driver

# === GPU Drivers — AMD ========================================
xorg-x11-drv-amdgpu
mesa-dri-drivers
mesa-vulkan-drivers
mesa-vdpau-drivers
libva-mesa-driver
radeontop                # AMD GPU monitor
rocm-opencl              # AMD OpenCL compute

# === Vulkan (both GPUs) =======================================
vulkan-loader
vulkan-tools
vkd3d                    # DirectX 12 → Vulkan
vkd3d-proton             # Better DX12 via Proton's vkd3d

# === Wine & Compatibility =====================================
wine                     # base Wine
wine-mono
wine-gecko
winetricks               # Wine helper scripts
cabextract               # needed by winetricks

# === Lutris ===================================================
lutris
python3-evdev            # gamepad support for Lutris
python3-pillow

# === Steam + Proton ===========================================
steam
steam-devices            # udev rules for controllers
# Proton GE will be auto-installed via post script

# === Performance Tools ========================================
gamemode                 # CPU/GPU perf boost on game launch
gamescope                # Valve's micro-compositor for games
mangohud                 # In-game FPS/CPU/GPU overlay
goverlay                 # MangoHud GUI configurator
cpupower                 # CPU frequency scaling
tuned                    # system tuning daemon
tuned-profiles-cpu-partitioning
thermald                 # thermal management
iotop                    # I/O monitor
htop
nvtop                    # GPU monitor (NVIDIA + AMD)

# === Networking ===============================================
NetworkManager
NetworkManager-wifi
NetworkManager-tui
nm-connection-editor

# === System Utils =============================================
flatpak                  # for extra apps
polkit
udisks2
upower
xdg-desktop-portal
xdg-desktop-portal-gtk

# === Excluded (keep it lean) ==================================
-gnome-shell
-gnome-desktop3
-plasma-desktop
-kde-settings
-libreoffice*
-rhythmbox
-totem
-cheese
-evolution
-gedit
-firefox              # user can install browser of choice
%end

# ── Post-install script ───────────────────────────────────────
%post --log=/root/nexos-post.log
set -x

# ── 1. Enable RPMFusion ───────────────────────────────────────
dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-40.noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-40.noarch.rpm

# ── 2. Enable Flathub ─────────────────────────────────────────
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

# ── 3. Install Proton-GE (latest) ─────────────────────────────
PROTON_VERSION=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest | grep tag_name | cut -d'"' -f4)
mkdir -p /home/gamer/.steam/root/compatibilitytools.d/
curl -L "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VERSION}/${PROTON_VERSION}.tar.gz" \
  -o /tmp/proton-ge.tar.gz
tar -xzf /tmp/proton-ge.tar.gz -C /home/gamer/.steam/root/compatibilitytools.d/
rm /tmp/proton-ge.tar.gz

# ── 4. CPU performance governor ───────────────────────────────
cat > /etc/tuned/nexos-gaming/tuned.conf << 'TUNED'
[main]
summary=NexOS Gaming Profile

[cpu]
governor=performance
energy_perf_bias=performance
min_perf_pct=100

[vm]
transparent_hugepages=madvise

[scheduler]
sched_min_granularity_ns=500000
sched_wakeup_granularity_ns=100000

[disk]
readahead=>4096

[audio]
timeout=0
TUNED
tuned-adm profile nexos-gaming

# ── 5. GameMode config ────────────────────────────────────────
mkdir -p /etc/gamemode.ini.d/
cat > /etc/gamemode.ini.d/nexos.ini << 'GAMEMODE'
[general]
reaper_freq=5
desiredgov=performance
igpu_desiredgov=performance
softrealtime=auto
renice=0
ioprio=0

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
amd_performance_level=high

[filter]
whitelist=steam,lutris,wine,gamemode
GAMEMODE

# ── 6. MangoHud default config ────────────────────────────────
mkdir -p /home/gamer/.config/MangoHud/
cat > /home/gamer/.config/MangoHud/MangoHud.conf << 'MANGO'
# NexOS MangoHud Config
legacy_layout=false
horizontal
background_alpha=0.4
font_size=20
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
frame_timing
MANGO

# ── 7. Openbox autostart ──────────────────────────────────────
mkdir -p /etc/xdg/openbox/
cat > /etc/xdg/openbox/autostart << 'AUTOSTART'
# NexOS Openbox Autostart
picom --config ~/.config/picom/nexos.conf &
feh --bg-scale /usr/share/nexos/wallpaper.jpg &
tint2 &
dunst &
lxsession &
nm-applet &
blueman-applet &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
AUTOSTART

# ── 8. Picom (compositor) config ─────────────────────────────
mkdir -p /etc/skel/.config/picom/
cat > /etc/skel/.config/picom/nexos.conf << 'PICOM'
# NexOS Picom Config — Beautiful + Performant
backend = "glx";
glx-no-stencil = true;
glx-no-rebind-pixmap = true;
use-damage = true;
vsync = true;

# Shadows
shadow = true;
shadow-radius = 20;
shadow-offset-x = -10;
shadow-offset-y = -10;
shadow-opacity = 0.5;
shadow-exclude = ["class_g = 'tint2'", "name = 'rofi'"];

# Blur
blur-method = "dual_kawase";
blur-strength = 6;
blur-background = true;
blur-background-frame = true;
blur-background-exclude = ["window_type = 'dock'"];

# Corners
corner-radius = 12;

# Animations (requires picom-animations)
animations = true;
animation-stiffness = 200;
animation-dampening = 25;
animation-window-mass = 0.4;
animation-for-open-window = "zoom";
animation-for-unmap-window = "zoom";

# Fading
fading = true;
fade-in-step = 0.05;
fade-out-step = 0.05;
fade-delta = 6;

# Opacity
active-opacity = 1.0;
inactive-opacity = 0.92;
frame-opacity = 0.9;
PICOM

# ── 9. NVIDIA Tweaks (if NVIDIA GPU present) ──────────────────
cat > /etc/modprobe.d/nexos-nvidia.conf << 'NVMOD'
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnablePCIeGen3=1
options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x1;RMGpuInitFBSR=4"
NVMOD

# ── 10. Udev rules for gaming peripherals ─────────────────────
cat > /etc/udev/rules.d/99-nexos-gaming.rules << 'UDEV'
# Higher priority for gaming input devices
ACTION=="add|change", KERNEL=="js[0-9]*", SUBSYSTEM=="input", MODE="0664", GROUP="input"
ACTION=="add|change", KERNEL=="event[0-9]*", SUBSYSTEM=="input", ATTRS{name}=="*Controller*", MODE="0664", GROUP="input"
# Xbox controller
ACTION=="add", ATTRS{idVendor}=="045e", MODE="0664", GROUP="input"
# PlayStation controller  
ACTION=="add", ATTRS{idVendor}=="054c", MODE="0664", GROUP="input"
# Nintendo controller
ACTION=="add", ATTRS{idVendor}=="057e", MODE="0664", GROUP="input"
UDEV

udevadm control --reload-rules

# ── 11. sysctl performance tweaks ────────────────────────────
cat > /etc/sysctl.d/99-nexos-gaming.conf << 'SYSCTL'
# Network (reduce latency for online gaming)
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1

# Memory
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.max_map_count=2147483642    # required by many games (default too low)

# Kernel
kernel.sched_autogroup_enabled=1
kernel.sched_cfs_bandwidth_slice_us=500
kernel.nmi_watchdog=0
SYSCTL
sysctl -p /etc/sysctl.d/99-nexos-gaming.conf

# ── 12. Rofi config (app launcher) ───────────────────────────
mkdir -p /etc/skel/.config/rofi/
cat > /etc/skel/.config/rofi/config.rasi << 'ROFI'
configuration {
  modi: "drun,run";
  show-icons: true;
  icon-theme: "Papirus-Dark";
  display-drun: "  Apps";
  display-run: "  Run";
  font: "Syne 14";
}

@theme "/usr/share/nexos/rofi-nexos.rasi"
ROFI

# ── 13. First boot welcome script ─────────────────────────────
cat > /usr/local/bin/nexos-welcome << 'WELCOME'
#!/bin/bash
# Runs on first login to set up user preferences
if [ ! -f ~/.nexos-configured ]; then
  # Set CPU governor
  pkexec cpupower frequency-set -g performance

  # Apply GTK dark theme
  gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark" 2>/dev/null || true
  xfconf-query -c xsettings -p /Net/ThemeName -s "Adwaita-dark" 2>/dev/null || true

  # Sync user dirs
  xdg-user-dirs-update

  touch ~/.nexos-configured
  notify-send "🎮 Welcome to NexOS!" "Your gaming system is ready.\nGameMode: active | MangoHud: CTRL+F12\nSteam: launch with gamemode steam"
fi
WELCOME
chmod +x /usr/local/bin/nexos-welcome

# ── 14. Enable services ───────────────────────────────────────
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable gdm || systemctl enable lightdm || true
systemctl enable tuned
systemctl enable thermald

# ── 15. Ownership fix ─────────────────────────────────────────
chown -R gamer:gamer /home/gamer/

# ── 16. Force password change on first login ──────────────────
chage -d 0 gamer

echo "✅ NexOS post-install complete!"
%end

# ── Firstboot ─────────────────────────────────────────────────
%addon com_redhat_firstboot
  firstboot --enable
%end
