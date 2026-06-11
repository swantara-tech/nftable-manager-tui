#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Sistem Manajemen Firewall nftables
# =============================================================================
# Aplikasi terminal (TUI) untuk mengelola firewall nftables pada Ubuntu Server
# Target: Ubuntu 24.04 LTS
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Setup Direktori Script
# -----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# -----------------------------------------------------------------------------
# Load Konfigurasi
# -----------------------------------------------------------------------------
if [[ -f "${SCRIPT_DIR}/config/nft-manager.conf" ]]; then
    source "${SCRIPT_DIR}/config/nft-manager.conf"
else
    echo "ERROR: File konfigurasi tidak ditemukan!"
    echo "Path: ${SCRIPT_DIR}/config/nft-manager.conf"
    exit 1
fi

# -----------------------------------------------------------------------------
# Load Modules
# -----------------------------------------------------------------------------
modules=(
    "dashboard"
    "rules"
    "ports"
    "ipsets"
    "backup"
    "restore"
    "rollback"
    "monitoring"
    "security"
    "logs"
    "settings"
)

for module in "${modules[@]}"; do
    if [[ -f "${MODULE_DIR}/${module}.sh" ]]; then
        source "${MODULE_DIR}/${module}.sh"
    else
        echo "ERROR: Module tidak ditemukan: ${module}.sh"
        echo "Path: ${MODULE_DIR}/${module}.sh"
        exit 1
    fi
done

# -----------------------------------------------------------------------------
# Fungsi: log_activity
# Deskripsi: Mencatat aktivitas ke file log
# Argumen: $1 = pesan aktivitas
# -----------------------------------------------------------------------------
log_activity() {
    local message="$1"
    
    # Cek apakah logging aktif
    if [[ "$LOG_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Buat direktori log jika belum ada
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" 2>/dev/null || return 1
    fi
    
    # Format: [YYYY-MM-DD HH:MM:SS] [USER] [Aktivitas]
    local timestamp user activity
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    user=$(whoami 2>/dev/null || echo "unknown")
    activity="$message"
    
    echo "[${timestamp}] [${user}] ${activity}" >> "$LOG_FILE" 2>/dev/null || true
    
    # Rotasi log jika perlu
    rotate_logs 2>/dev/null || true
}

# -----------------------------------------------------------------------------
# Fungsi: check_root
# Deskripsi: Memastikan script dijalankan sebagai root
# -----------------------------------------------------------------------------
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo "========================================"
        echo " ERROR: Script harus dijalankan sebagai root!"
        echo "========================================"
        echo ""
        echo "Gunakan:"
        echo "  sudo ./nft-manager.sh"
        echo ""
        echo "atau login sebagai root:"
        echo "  su -"
        echo ""
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: check_dependencies
# Deskripsi: Memastikan semua dependency terinstall
# -----------------------------------------------------------------------------
check_dependencies() {
    local missing=()
    
    # Cek nft
    if ! command -v nft &>/dev/null; then
        missing+=("nftables")
    fi
    
    # Cek whiptail
    if ! command -v whiptail &>/dev/null; then
        missing+=("whiptail")
    fi
    
    # Cek ip
    if ! command -v ip &>/dev/null; then
        missing+=("iproute2")
    fi
    
    # Jika ada yang missing
    if [[ ${#missing[@]} -gt 0 ]]; then
        echo "========================================"
        echo " ERROR: Dependency tidak ditemukan!"
        echo "========================================"
        echo ""
        echo "Package yang hilang:"
        for pkg in "${missing[@]}"; do
            echo "  - ${pkg}"
        done
        echo ""
        echo "Install dengan:"
        echo "  sudo apt-get install -y ${missing[*]}"
        echo ""
        echo "atau jalankan:"
        echo "  sudo ./install.sh"
        echo ""
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: setup_initial_firewall
# Deskripsi: Setup firewall awal jika belum ada konfigurasi
# -----------------------------------------------------------------------------
setup_initial_firewall() {
    # Cek apakah sudah ada table
    if nft list tables 2>/dev/null | grep -q "${NFT_TABLE_NAME}"; then
        return 0
    fi
    
    # Tanya user
    if whiptail --title "Setup Firewall Awal" --yesno \
        "Belum ada konfigurasi firewall.\n\nBuat konfigurasi awal dengan policy:\n- Input: DROP\n- Forward: DROP\n- Output: ACCEPT\n\nLanjutkan?" 12 60; then
        
        # Buat table dan chain
        nft add table ${NFT_TABLE} ${NFT_TABLE_NAME} 2>/dev/null
        
        nft add chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} { type filter hook input priority 0\; policy ${NFT_POLICY_INPUT}\; } 2>/dev/null
        
        nft add chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_FORWARD} { type filter hook forward priority 0\; policy ${NFT_POLICY_FORWARD}\; } 2>/dev/null
        
        nft add chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_OUTPUT} { type filter hook output priority 0\; policy ${NFT_POLICY_OUTPUT}\; } 2>/dev/null
        
        # Izinkan loopback
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} i lo accept 2>/dev/null
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_OUTPUT} o lo accept 2>/dev/null
        
        # Izinkan established/related connections
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ct state established,related accept 2>/dev/null
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_OUTPUT} ct state established,related accept 2>/dev/null
        
        log_activity "Setup firewall awal dengan policy default"
        
        whiptail --msgbox "Firewall awal berhasil dibuat!\n\nPolicy:\n- Input: DROP\n- Forward: DROP\n- Output: ACCEPT\n\nLoopback dan established connections diizinkan." 14 60
    else
        log_activity "User membatalkan setup firewall awal"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: show_main_menu
# Deskripsi: Menampilkan menu utama aplikasi
# -----------------------------------------------------------------------------
show_main_menu() {
    local choice
    
    while true; do
        choice=$(whiptail --title "${APP_NAME} v${APP_VERSION}" --menu \
            "Selamat datang di ${APP_NAME}\nSistem Manajemen Firewall nftables\n\nPilih menu:" \
            18 60 10 \
            "1" "Dashboard" \
            "2" "Kelola Rule" \
            "3" "Kelola Port" \
            "4" "Whitelist & Blacklist" \
            "5" "Keamanan" \
            "6" "Monitoring" \
            "7" "Backup & Restore" \
            "8" "Log Aktivitas" \
            "9" "Pengaturan" \
            "0" "Keluar" 3>&1 1>&2 2>&3)
        
        local exit_code=$?
        
        if [[ $exit_code -ne 0 ]]; then
            # User menekan ESC atau Cancel
            if whiptail --title "Konfirmasi" --yesno "Yakin ingin keluar?" 8 50; then
                log_activity "Aplikasi ditutup"
                echo "Terima kasih telah menggunakan ${APP_NAME}!"
                exit 0
            fi
            continue
        fi
        
        case "$choice" in
            1) show_dashboard ;;
            2) manage_rules ;;
            3) manage_ports ;;
            4) manage_ipsets ;;
            5) manage_security ;;
            6) show_monitoring ;;
            7) manage_backups ;;
            8) show_logs ;;
            9) manage_settings ;;
            0)
                if whiptail --title "Konfirmasi" --yesno "Yakin ingin keluar?" 8 50; then
                    log_activity "Aplikasi ditutup"
                    echo "Terima kasih telah menggunakan ${APP_NAME}!"
                    exit 0
                fi
                ;;
            *)
                whiptail --msgbox "Pilihan tidak valid!" 8 40
                ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: cleanup
# Deskripsi: Cleanup saat aplikasi ditutup
# -----------------------------------------------------------------------------
cleanup() {
    log_activity "Aplikasi ditutup (cleanup)"
    cleanup_rollback 2>/dev/null || true
}

# Trap untuk cleanup
trap cleanup EXIT INT TERM

# =============================================================================
# MAIN
# =============================================================================

# Clear screen
clear

# Banner
echo "========================================"
echo "   ${APP_NAME} v${APP_VERSION}"
echo "   ${APP_DESCRIPTION}"
echo "========================================"
echo ""

# Cek root
check_root

# Cek dependencies
check_dependencies

# Buat direktori jika belum ada
mkdir -p "$BACKUP_DIR" "$LOG_DIR" 2>/dev/null

# Log startup
log_activity "Aplikasi dimulai"

# Setup firewall awal jika belum ada
setup_initial_firewall

# Clear screen dan tampilkan menu utama
clear
show_main_menu
