#!/bin/bash
# ============================================================
#  NexOS Gaming Distro — ISO Builder
#  Base: Fedora 40  |  DE: Openbox + Picom (lightweight)
#  Run this on a Fedora 40 host (or VM/container)
# ============================================================

set -euo pipefail

# ── Colors ──────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
YELLOW='\033[1;33m'; BOLD='\033[1m'; NC='\033[0m'

log()  { echo -e "${CYAN}[NexOS]${NC} $*"; }
ok()   { echo -e "${GREEN}[  OK  ]${NC} $*"; }
warn() { echo -e "${YELLOW}[ WARN ]${NC} $*"; }
die()  { echo -e "${RED}[ FAIL ]${NC} $*"; exit 1; }

# ── Config ───────────────────────────────────────────────────
DISTRO_NAME="NexOS"
DISTRO_VERSION="1.0"
BUILD_DIR="/tmp/nexos-build"
ISO_LABEL="NexOS-Gaming-${DISTRO_VERSION}"
OUTPUT_ISO="NexOS-${DISTRO_VERSION}-x86_64.iso"
KICKSTART_FILE="$(pwd)/kickstart/nexos.ks"
LORAX_TMPL="$(pwd)/configs/lorax.conf"
LOG_FILE="/tmp/nexos-build.log"

# ── Preflight checks ─────────────────────────────────────────
preflight() {
  log "Running preflight checks..."
  [[ $(id -u) -eq 0 ]] || die "Must run as root. Use: sudo ./build.sh"
  command -v lorax       &>/dev/null || die "lorax not installed. Run: dnf install lorax"
  command -v livemedia-creator &>/dev/null || die "livemedia-creator not found. Run: dnf install lorax"
  command -v virt-install &>/dev/null || warn "virt-install not found — VM mode unavailable, using --no-virt"

  # Check disk space (need ~20GB)
  AVAIL=$(df /tmp --output=avail -BG | tail -1 | tr -d 'G')
  [[ $AVAIL -lt 20 ]] && die "Need at least 20GB free in /tmp. Available: ${AVAIL}GB"

  ok "Preflight passed."
}

# ── Install build dependencies ────────────────────────────────
install_deps() {
  log "Installing build dependencies..."
  dnf install -y \
    lorax \
    pykickstart \
    genisoimage \
    syslinux \
    grub2-tools \
    squashfs-tools \
    anaconda \
    &>> "$LOG_FILE"
  ok "Build dependencies installed."
}

# ── Validate kickstart ────────────────────────────────────────
validate_ks() {
  log "Validating kickstart file..."
  ksvalidator "$KICKSTART_FILE" && ok "Kickstart valid." || die "Kickstart has errors — check $KICKSTART_FILE"
}

# ── Build the ISO ─────────────────────────────────────────────
build_iso() {
  log "Starting ISO build (this takes 20–60 min depending on internet speed)..."
  mkdir -p "$BUILD_DIR"

  livemedia-creator \
    --ks="$KICKSTART_FILE" \
    --no-virt \
    --resultdir="$BUILD_DIR/result" \
    --project="$DISTRO_NAME" \
    --make-iso \
    --volid="$ISO_LABEL" \
    --iso-only \
    --iso-name="$OUTPUT_ISO" \
    --releasever=40 \
    --macaddr="" \
    --title="$DISTRO_NAME $DISTRO_VERSION" \
    2>&1 | tee -a "$LOG_FILE"

  ok "ISO build complete!"
  log "Output: ${BUILD_DIR}/result/${OUTPUT_ISO}"
}

# ── Post-build checksum ───────────────────────────────────────
checksum() {
  log "Generating checksums..."
  cd "${BUILD_DIR}/result"
  sha256sum "$OUTPUT_ISO" > "${OUTPUT_ISO}.sha256"
  ok "SHA256: $(cat ${OUTPUT_ISO}.sha256)"
}

# ── Copy to current dir ───────────────────────────────────────
collect() {
  cp "${BUILD_DIR}/result/${OUTPUT_ISO}" ./
  cp "${BUILD_DIR}/result/${OUTPUT_ISO}.sha256" ./
  log "ISO copied to current directory."
  echo ""
  echo -e "${BOLD}${GREEN}╔══════════════════════════════════════════╗"
  echo -e "║   🎮  NexOS ISO Build Complete!          ║"
  echo -e "║   File: ${OUTPUT_ISO}   ║"
  echo -e "╚══════════════════════════════════════════╝${NC}"
  echo ""
  echo "Flash to USB with:"
  echo -e "  ${CYAN}sudo dd if=${OUTPUT_ISO} of=/dev/sdX bs=4M status=progress oflag=sync${NC}"
  echo "Or use Ventoy / Balena Etcher."
}

# ── Main ──────────────────────────────────────────────────────
main() {
  echo ""
  echo -e "${BOLD}${CYAN}  ███╗   ██╗███████╗██╗  ██╗ ██████╗ ███████╗"
  echo -e "  ████╗  ██║██╔════╝╚██╗██╔╝██╔═══██╗██╔════╝"
  echo -e "  ██╔██╗ ██║█████╗   ╚███╔╝ ██║   ██║███████╗"
  echo -e "  ██║╚██╗██║██╔══╝   ██╔██╗ ██║   ██║╚════██║"
  echo -e "  ██║ ╚████║███████╗██╔╝ ██╗╚██████╔╝███████║"
  echo -e "  ╚═╝  ╚═══╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝${NC}"
  echo -e "${YELLOW}  Gaming Linux Distro Builder — Fedora 40 Base${NC}"
  echo ""

  preflight
  install_deps
  validate_ks
  build_iso
  checksum
  collect
}

main "$@"
