# 🎮 NexOS — Gaming Linux Distro

**Base:** Fedora 40 | **DE:** Openbox (lightweight + beautiful) | **Focus:** Maximum gaming performance

---

## What's Included

| Category | Software |
|----------|----------|
| Gaming | Steam + Proton-GE, Lutris, Wine, Winetricks |
| Performance | GameMode, GameScope, MangoHud, GOverlay |
| GPU | NVIDIA (akmod) + AMD (AMDGPU + ROCm) auto-detected |
| Compositor | Picom (blur, shadows, rounded corners, animations) |
| Launcher | Rofi (cyberpunk theme, Super+Space) |
| Taskbar | Tint2 |
| Audio | Pipewire (low-latency) |
| Tweaks | Custom kernel args, sysctl, udev, tuned governor |

---

## 🛠️ Option A — Build a Full ISO (bootable USB)

> Run this on a **Fedora 40 host machine or VM**. Needs ~20GB free space.

```bash
# 1. Clone / download these files
cd nexos/

# 2. Install build tools
sudo dnf install -y lorax pykickstart

# 3. Run the builder
sudo ./build.sh
```

The ISO will appear in the current directory as `NexOS-1.0-x86_64.iso`.

Flash to USB:
```bash
sudo dd if=NexOS-1.0-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync
# Replace /dev/sdX with your USB drive (check with: lsblk)
```

---

## ⚡ Option B — Install on Existing Fedora 40 (Faster!)

If you already have Fedora 40 installed, just run the post-install script:

```bash
cd nexos/scripts/
chmod +x post-install.sh
sudo ./post-install.sh
```

Then **reboot**, and at the login screen select **Openbox** as your session.

---

## ⌨️ Key Bindings

| Shortcut | Action |
|----------|--------|
| `Super + Space` | App launcher (Rofi) |
| `Super + Enter` | Terminal |
| `Super + S` | Steam (with GameMode) |
| `Super + L` | Lutris |
| `Ctrl + F12` | Toggle MangoHud overlay |
| `Super + ↑` | Maximize window |
| `Super + ← / →` | Snap window left/right (50%) |
| `Super + 1-4` | Switch desktops |
| `Print Screen` | Screenshot |

---

## 🎛️ Performance Explained

### Kernel Boot Args
- `mitigations=off` — Disables Spectre/Meltdown patches for ~5-15% CPU perf gain
- `transparent_hugepage=madvise` — Better RAM allocation for games
- `nowatchdog` — Less kernel interrupt overhead

### sysctl Tweaks
- `vm.max_map_count=2147483642` — Required by many games (default is too low)
- `vm.swappiness=10` — Keeps game data in RAM longer
- `net.ipv4.tcp_fastopen=3` — Faster TCP connections (online gaming)

### GameMode
Automatically applied when you launch games via Steam or Lutris.  
Switches CPU governor to `performance`, boosts GPU clocks.  
Uses the keybind `gamemoderun %command%` as a Steam launch option.

### MangoHud
Real-time FPS, CPU %, GPU %, VRAM, temps displayed in-game.  
Toggle: `Ctrl+F12`  
Config file: `~/.config/MangoHud/MangoHud.conf`

---

## 📁 File Structure

```
nexos/
├── build.sh                   ← ISO builder (run as root on Fedora host)
├── kickstart/
│   └── nexos.ks               ← Full distro definition (packages, post-install)
├── scripts/
│   └── post-install.sh        ← Install NexOS on top of existing Fedora 40
├── theme/
│   └── rofi-nexos.rasi        ← Cyberpunk Rofi app launcher theme
└── docs/
    └── README.md              ← This file
```

---

## 🔧 Customization Tips

**Change wallpaper:**
```bash
feh --bg-scale /path/to/your/wallpaper.jpg
# Make permanent by editing ~/.config/openbox/autostart
```

**Add a program to autostart:**
```bash
echo "myprogram &" >> ~/.config/openbox/autostart
```

**Adjust blur/compositor:**  
Edit `~/.config/picom/nexos.conf` — change `blur-strength` (1-10)

**Switch GPU profile (AMD):**
```bash
echo "high" | sudo tee /sys/class/drm/card0/device/power_dpm_force_performance_level
```

---

## ⚠️ Notes

- `mitigations=off` is a security trade-off. Fine for a gaming machine, not for servers.
- NVIDIA drivers are installed via `akmod-nvidia` — they compile on first boot (takes ~5 min).
- Proton-GE is downloaded during install and placed in Steam's compatibility tools folder. Select it in Steam → Settings → Compatibility.
- Default user created in ISO mode: `gamer` / `nexos` (you'll be asked to change it on first login).

---

*NexOS — Built for games. Tuned for speed. Made to look good doing it.*
