#!/bin/bash
# ============================================================
#  NexOS Post-Install Script
#  Run this on a fresh Fedora 40 install to turn it into NexOS
#  Usage: sudo ./post-install.sh
# ============================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}▶${NC} $*"; }
ok()   { echo -e "${GREEN}✔${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
die()  { echo -e "${RED}✘ FATAL:${NC} $*"; exit 1; }
step() { echo ""; echo -e "${BOLD}━━━ $* ━━━${NC}"; }

[[ $(id -u) -eq 0 ]] || die "Run with sudo."
ACTUAL_USER=${SUDO_USER:-$(logname 2>/dev/null || echo "user")}
HOME_DIR="/home/${ACTUAL_USER}"

echo ""
echo -e "${BOLD}${CYAN}"
echo "  ███╗   ██╗███████╗██╗  ██╗ ██████╗ ███████╗"
echo "  ████╗  ██║██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝"
echo "  ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗"
echo "  ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║"
echo "  ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║"
echo "  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝"
echo -e "${NC}"
echo -e "${YELLOW}  Gaming Linux Post-Install — Fedora 40${NC}"
echo -e "  Installing for user: ${BOLD}${ACTUAL_USER}${NC}"
echo ""

# ──────────────────────────────────────────────────────────────
step "1/12 · RPMFusion Repos"
# ──────────────────────────────────────────────────────────────
dnf install -y \
  https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
dnf install -y rpmfusion-free-release-tainted rpmfusion-nonfree-release-tainted
ok "RPMFusion enabled"

# ──────────────────────────────────────────────────────────────
step "2/12 · Flathub"
# ──────────────────────────────────────────────────────────────
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
ok "Flathub added"

# ──────────────────────────────────────────────────────────────
step "3/12 · System Update"
# ──────────────────────────────────────────────────────────────
dnf upgrade -y
ok "System updated"

# ──────────────────────────────────────────────────────────────
step "4/12 · Gaming Core Packages"
# ──────────────────────────────────────────────────────────────
dnf install -y \
  steam \
  steam-devices \
  lutris \
  wine \
  wine-mono \
  wine-gecko \
  winetricks \
  gamemode \
  gamescope \
  mangohud \
  goverlay \
  \
  openbox \
  obconf \
  tint2 \
  rofi \
  picom \
  feh \
  dunst \
  xfce4-terminal \
  thunar \
  thunar-volman \
  gvfs gvfs-mtp \
  lxappearance \
  qt5ct \
  pavucontrol \
  blueman \
  \
  pipewire \
  pipewire-alsa \
  pipewire-pulseaudio \
  wireplumber \
  \
  vulkan-loader \
  vulkan-tools \
  vkd3d \
  \
  tuned \
  thermald \
  cpupower \
  nvtop \
  htop \
  papirus-icon-theme \
  google-noto-emoji-fonts
ok "Core packages installed"

# ──────────────────────────────────────────────────────────────
step "5/12 · GPU Drivers"
# ──────────────────────────────────────────────────────────────
GPU=$(lspci | grep -i 'vga\|3d\|display')
log "Detected GPU: $GPU"

if echo "$GPU" | grep -qi nvidia; then
  log "NVIDIA GPU detected — installing proprietary drivers..."
  dnf install -y akmod-nvidia xorg-x11-drv-nvidia xorg-x11-drv-nvidia-cuda \
    nvidia-settings nvidia-vaapi-driver libva-nvidia-driver
  # NVIDIA tweaks
  cat > /etc/modprobe.d/nexos-nvidia.conf << 'EOF'
options nvidia NVreg_UsePageAttributeTable=1
options nvidia NVreg_EnablePCIeGen3=1
options nvidia NVreg_RegistryDwords="PowerMizerEnable=0x1;PerfLevelSrc=0x2222;PowerMizerLevel=0x1"
EOF
  ok "NVIDIA drivers + tweaks applied"
elif echo "$GPU" | grep -qi amd; then
  log "AMD GPU detected — installing AMDGPU drivers..."
  dnf install -y mesa-dri-drivers mesa-vulkan-drivers mesa-vdpau-drivers \
    libva-mesa-driver radeontop rocm-opencl xorg-x11-drv-amdgpu
  ok "AMD drivers installed"
else
  warn "Could not auto-detect GPU. Install GPU drivers manually."
fi

# ──────────────────────────────────────────────────────────────
step "6/12 · Kernel Boot Tweaks"
# ──────────────────────────────────────────────────────────────
KERNEL_OPTS="quiet splash mitigations=off nowatchdog transparent_hugepage=madvise"
CURRENT_OPTS=$(grubby --info=DEFAULT | grep args | cut -d'"' -f2)
if ! echo "$CURRENT_OPTS" | grep -q "mitigations=off"; then
  grubby --update-kernel=DEFAULT --args="$KERNEL_OPTS"
  ok "Kernel boot args updated (mitigations=off, tickless, hugepages)"
else
  ok "Kernel args already set"
fi

# ──────────────────────────────────────────────────────────────
step "7/12 · sysctl Performance Tweaks"
# ──────────────────────────────────────────────────────────────
cat > /etc/sysctl.d/99-nexos-gaming.conf << 'EOF'
# NexOS Gaming sysctl tweaks

# === Memory ===
vm.swappiness=10
vm.dirty_ratio=10
vm.dirty_background_ratio=5
vm.max_map_count=2147483642      # Required by many games (Steam/Proton)

# === Network (low-latency online gaming) ===
net.core.rmem_max=16777216
net.core.wmem_max=16777216
net.ipv4.tcp_fastopen=3
net.ipv4.tcp_mtu_probing=1
net.core.netdev_max_backlog=16384

# === Scheduler ===
kernel.sched_autogroup_enabled=1
kernel.nmi_watchdog=0
EOF
sysctl -p /etc/sysctl.d/99-nexos-gaming.conf
ok "sysctl tweaks applied"

# ──────────────────────────────────────────────────────────────
step "8/12 · CPU Governor + Tuned"
# ──────────────────────────────────────────────────────────────
mkdir -p /etc/tuned/nexos-gaming/
cat > /etc/tuned/nexos-gaming/tuned.conf << 'EOF'
[main]
summary=NexOS Gaming Profile — Maximum Performance

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
EOF
systemctl enable --now tuned
tuned-adm profile nexos-gaming
ok "CPU set to performance governor via tuned"

# ──────────────────────────────────────────────────────────────
step "9/12 · GameMode Config"
# ──────────────────────────────────────────────────────────────
mkdir -p /etc/gamemode.ini.d/
cat > /etc/gamemode.ini.d/nexos.ini << 'EOF'
[general]
reaper_freq=5
desiredgov=performance
softrealtime=auto
renice=0
ioprio=0

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
nv_powermizer_mode=1
amd_performance_level=high

[custom]
start=notify-send "🎮 GameMode" "Performance mode activated"
end=notify-send "GameMode" "Performance mode deactivated"
EOF
# Add user to gamemode group
usermod -aG gamemode "$ACTUAL_USER"
ok "GameMode configured"

# ──────────────────────────────────────────────────────────────
step "10/12 · Openbox + Picom + MangoHud Config"
# ──────────────────────────────────────────────────────────────
sudo -u "$ACTUAL_USER" mkdir -p \
  "${HOME_DIR}/.config/openbox" \
  "${HOME_DIR}/.config/picom" \
  "${HOME_DIR}/.config/MangoHud" \
  "${HOME_DIR}/.config/rofi" \
  "${HOME_DIR}/.config/dunst" \
  "${HOME_DIR}/.config/tint2"

# Openbox autostart
cat > "${HOME_DIR}/.config/openbox/autostart" << 'EOF'
#!/bin/bash
# NexOS Openbox Autostart
picom --config ~/.config/picom/nexos.conf --daemon
feh --bg-scale /usr/share/nexos/wallpaper.jpg
tint2 &
dunst &
lxsession &
nm-applet &
blueman-applet &
/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1 &
/usr/local/bin/nexos-welcome &
EOF

# Openbox RC (keybinds)
cat > "${HOME_DIR}/.config/openbox/rc.xml" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<openbox_config>
  <theme>
    <name>Numix-Frost</name>
    <titleLayout>NLIMC</titleLayout>
    <keepBorder>yes</keepBorder>
    <animateIconify>yes</animateIconify>
    <font place="ActiveWindow"><name>Syne Bold</name><size>10</size></font>
    <font place="InactiveWindow"><name>Syne</name><size>10</size></font>
  </theme>
  <desktops><number>4</number><names><name>Games</name><name>Browser</name><name>Discord</name><name>Other</name></names></desktops>
  <keyboard>
    <!-- App launcher -->
    <keybind key="super-space"><action name="Execute"><command>rofi -show drun</command></action></keybind>
    <!-- Terminal -->
    <keybind key="super-Return"><action name="Execute"><command>xfce4-terminal</command></action></keybind>
    <!-- Steam -->
    <keybind key="super-s"><action name="Execute"><command>gamemode steam</command></action></keybind>
    <!-- Lutris -->
    <keybind key="super-l"><action name="Execute"><command>lutris</command></action></keybind>
    <!-- MangoHud toggle -->
    <keybind key="C-F12"><action name="Execute"><command>pkill -USR2 mangohud</command></action></keybind>
    <!-- Screenshots -->
    <keybind key="Print"><action name="Execute"><command>scrot ~/Pictures/screenshot-%Y%m%d-%H%M%S.png</command></action></keybind>
    <!-- Tiling shortcuts -->
    <keybind key="super-Left"><action name="MoveResizeTo"><x>0</x><y>0</y><width>50%</width><height>100%</height></action></keybind>
    <keybind key="super-Right"><action name="MoveResizeTo"><x>50%</x><y>0</y><width>50%</width><height>100%</height></action></keybind>
    <keybind key="super-Up"><action name="Maximize"/></keybind>
    <keybind key="super-Down"><action name="Unmaximize"/></keybind>
    <!-- Desktop switching -->
    <keybind key="super-1"><action name="GoToDesktop"><to>1</to></action></keybind>
    <keybind key="super-2"><action name="GoToDesktop"><to>2</to></action></keybind>
    <keybind key="super-3"><action name="GoToDesktop"><to>3</to></action></keybind>
    <keybind key="super-4"><action name="GoToDesktop"><to>4</to></action></keybind>
  </keyboard>
</openbox_config>
EOF

# Picom compositor
cat > "${HOME_DIR}/.config/picom/nexos.conf" << 'EOF'
# NexOS Picom Config
backend = "glx";
glx-no-stencil = true;
vsync = true;
use-damage = true;

# Shadows
shadow = true;
shadow-radius = 20;
shadow-opacity = 0.5;
shadow-exclude = ["class_g = 'tint2'"];

# Blur (beautiful frosted glass effect)
blur-method = "dual_kawase";
blur-strength = 5;
blur-background = true;
blur-background-exclude = ["window_type = 'dock'", "class_g = 'rofi'"];

# Rounded corners
corner-radius = 12;
rounded-corners-exclude = ["window_type = 'dock'", "class_g = 'tint2'"];

# Smooth fading
fading = true;
fade-in-step = 0.06;
fade-out-step = 0.06;

# Opacity
inactive-opacity = 0.93;
active-opacity = 1.0;
frame-opacity = 0.9;
EOF

# MangoHud
cat > "${HOME_DIR}/.config/MangoHud/MangoHud.conf" << 'EOF'
# NexOS MangoHud Overlay
legacy_layout=false
horizontal
background_alpha=0.5
background_color=020305
font_size=18
text_color=00e5ff
position=top-left
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
EOF

ok "Openbox + Picom + MangoHud configured"

# ──────────────────────────────────────────────────────────────
step "11/12 · Proton-GE"
# ──────────────────────────────────────────────────────────────
log "Fetching latest Proton-GE release..."
PROTON_VER=$(curl -s https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest \
  | grep '"tag_name"' | cut -d'"' -f4)
PROTON_DIR="${HOME_DIR}/.steam/root/compatibilitytools.d"
sudo -u "$ACTUAL_USER" mkdir -p "$PROTON_DIR"

curl -L "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${PROTON_VER}/${PROTON_VER}.tar.gz" \
  -o /tmp/proton-ge.tar.gz
sudo -u "$ACTUAL_USER" tar -xzf /tmp/proton-ge.tar.gz -C "$PROTON_DIR"
rm /tmp/proton-ge.tar.gz
chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "$PROTON_DIR"
ok "Proton-GE ${PROTON_VER} installed"

# ──────────────────────────────────────────────────────────────
step "12/12 · Udev Rules + Services"
# ──────────────────────────────────────────────────────────────
# Gaming peripheral rules
cat > /etc/udev/rules.d/99-nexos-gaming.rules << 'EOF'
# Xbox controllers
ACTION=="add", ATTRS{idVendor}=="045e", MODE="0664", GROUP="input"
# PlayStation controllers
ACTION=="add", ATTRS{idVendor}=="054c", MODE="0664", GROUP="input"
# Nintendo controllers
ACTION=="add", ATTRS{idVendor}=="057e", MODE="0664", GROUP="input"
# Generic gamepads
ACTION=="add|change", KERNEL=="js[0-9]*", SUBSYSTEM=="input", MODE="0664", GROUP="input"
EOF
udevadm control --reload-rules

# Enable services
systemctl enable --now bluetooth
systemctl enable --now thermald
systemctl enable --now pipewire pipewire-pulse wireplumber

# Welcome script
cat > /usr/local/bin/nexos-welcome << 'EOF'
#!/bin/bash
if [ ! -f ~/.nexos-configured ]; then
  touch ~/.nexos-configured
  dunstify -i "applications-games" -t 6000 \
    "🎮 Welcome to NexOS!" \
    "Steam: Super+S | Lutris: Super+L\nMangoHud: Ctrl+F12 | Apps: Super+Space\nGameMode is active on all game launches."
fi
EOF
chmod +x /usr/local/bin/nexos-welcome

# Fix ownership
chown -R "${ACTUAL_USER}:${ACTUAL_USER}" "${HOME_DIR}/"

# ──────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}"
echo "╔═════════════════════════════════════════════════════════╗"
echo "║                                                         ║"
echo "║   🎮  NexOS Installation Complete!                      ║"
echo "║                                                         ║"
echo "║   Next steps:                                           ║"
echo "║   1. Reboot your system                                 ║"
echo "║   2. Select 'Openbox' at the login screen               ║"
echo "║   3. Use Super+Space to open the app launcher           ║"
echo "║   4. Launch Steam with Super+S (GameMode auto-enabled)  ║"
echo "║                                                         ║"
echo "║   Hotkeys:                                              ║"
echo "║   Super+S       → Steam (with GameMode)                 ║"
echo "║   Super+L       → Lutris                                ║"
echo "║   Super+Space   → App Launcher (Rofi)                   ║"
echo "║   Super+Enter   → Terminal                              ║"
echo "║   Ctrl+F12      → Toggle MangoHud overlay               ║"
echo "║   Super+↑↓←→    → Window tiling                        ║"
echo "║                                                         ║"
echo "╚═════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo "Please reboot now: ${CYAN}sudo reboot${NC}"
