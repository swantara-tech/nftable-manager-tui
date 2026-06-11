#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Script Instalasi
# =============================================================================
# Script untuk menginstal NFT Manager di Ubuntu Server 24.04 LTS
# Jalankan sebagai root: sudo ./install.sh
# =============================================================================

set -euo pipefail

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Informasi aplikasi
APP_NAME="NFT Manager"
APP_VERSION="1.0.0"
INSTALL_DIR="/opt/nft-manager"

# =============================================================================
# Fungsi Helper
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ${APP_NAME} v${APP_VERSION} - Installer${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
}

print_step() {
    echo -e "${GREEN}[✓]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[✗]${NC} $1"
}

print_info() {
    echo -e "${BLUE}[i]${NC} $1"
}

# =============================================================================
# Validasi Sistem
# =============================================================================

check_root() {
    print_info "Memeriksa hak akses root..."
    if [[ $EUID -ne 0 ]]; then
        print_error "Script harus dijalankan sebagai root!"
        echo ""
        echo "Gunakan: sudo ./install.sh"
        exit 1
    fi
    print_step "Hak akses root: OK"
}

check_os() {
    print_info "Memeriksa sistem operasi..."
    
    if [[ -f /etc/os-release ]]; then
        local os_name
        os_name=$(. /etc/os-release && echo "$NAME")
        
        if [[ "$os_name" != *"Ubuntu"* ]]; then
            print_warning "Sistem operasi: ${os_name}"
            print_warning "Target resmi: Ubuntu 24.04 LTS"
            print_warning "Instalasi tetap dilanjutkan, namun mungkin ada incompatibility."
            echo ""
            read -p "Lanjutkan? (y/n): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                print_info "Instalasi dibatalkan."
                exit 0
            fi
        else
            print_step "Sistem operasi: ${os_name} - OK"
        fi
    else
        print_warning "Tidak dapat mendeteksi sistem operasi."
    fi
}

check_bash_version() {
    print_info "Memeriksa versi Bash..."
    local bash_version
    bash_version=$(bash --version | head -n 1 | awk '{print $4}' | cut -d'(' -f1)
    local bash_major
    bash_major=$(echo "$bash_version" | cut -d'.' -f1)
    
    if [[ "$bash_major" -lt 5 ]]; then
        print_error "Bash versi 5+ diperlukan!"
        print_error "Versi saat ini: ${bash_version}"
        exit 1
    fi
    
    print_step "Bash versi: ${bash_version} - OK"
}

# =============================================================================
# Instalasi Dependencies
# =============================================================================

install_dependencies() {
    print_info "Memeriksa dan menginstall dependencies..."
    
    local packages_needed=()
    
    # Cek nftables
    if ! command -v nft &>/dev/null; then
        packages_needed+=("nftables")
    fi
    
    # Cek whiptail
    if ! command -v whiptail &>/dev/null; then
        packages_needed+=("whiptail")
    fi
    
    # Cek iproute2
    if ! command -v ip &>/dev/null; then
        packages_needed+=("iproute2")
    fi
    
    # Cek curl
    if ! command -v curl &>/dev/null; then
        packages_needed+=("curl")
    fi
    
    # Install jika ada yang kurang
    if [[ ${#packages_needed[@]} -gt 0 ]]; then
        print_info "Package yang akan diinstall: ${packages_needed[*]}"
        echo ""
        
        apt-get update -qq
        
        for pkg in "${packages_needed[@]}"; do
            print_info "Menginstall ${pkg}..."
            if apt-get install -y "$pkg" -qq; then
                print_step "${pkg} berhasil diinstall"
            else
                print_error "Gagal menginstall ${pkg}"
                exit 1
            fi
        done
    else
        print_step "Semua dependencies sudah terinstall"
    fi
}

# =============================================================================
# Instalasi Aplikasi
# =============================================================================

create_directories() {
    print_info "Membuat direktori aplikasi..."
    
    mkdir -p "${INSTALL_DIR}/modules"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/backups"
    mkdir -p "${INSTALL_DIR}/logs"
    
    print_step "Direktori aplikasi dibuat di: ${INSTALL_DIR}"
}

copy_files() {
    print_info "Menyalin file aplikasi..."
    
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Copy main script
    cp "${script_dir}/nft-manager.sh" "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/nft-manager.sh"
    print_step "nft-manager.sh"
    
    # Copy modules
    for module in "${script_dir}/modules/"*.sh; do
        if [[ -f "$module" ]]; then
            cp "$module" "${INSTALL_DIR}/modules/"
            chmod +x "${INSTALL_DIR}/modules/$(basename "$module")"
            print_step "modules/$(basename "$module")"
        fi
    done
    
    # Copy config
    if [[ -f "${script_dir}/config/nft-manager.conf" ]]; then
        cp "${script_dir}/config/nft-manager.conf" "${INSTALL_DIR}/config/"
        print_step "config/nft-manager.conf"
    fi
    
    # Create empty log file
    touch "${INSTALL_DIR}/logs/nft-manager.log"
    print_step "logs/nft-manager.log"
    
    print_step "Semua file berhasil disalin"
}

create_symlink() {
    print_info "Membuat symbolic link..."
    
    # Symlink untuk nft-manager
    local symlink_path="/usr/local/bin/nft-manager"
    
    # Hapus symlink lama jika ada
    if [[ -L "$symlink_path" ]]; then
        rm -f "$symlink_path"
    fi
    
    # Buat symlink baru
    ln -sf "${INSTALL_DIR}/nft-manager.sh" "$symlink_path"
    chmod +x "$symlink_path"
    
    print_step "Symlink dibuat: ${symlink_path} -> ${INSTALL_DIR}/nft-manager.sh"
    
    # Symlink untuk nft-update
    local update_symlink="/usr/local/bin/nft-update"
    
    if [[ -L "$update_symlink" ]]; then
        rm -f "$update_symlink"
    fi
    
    if [[ -f "${INSTALL_DIR}/update.sh" ]]; then
        ln -sf "${INSTALL_DIR}/update.sh" "$update_symlink"
        chmod +x "$update_symlink"
        print_step "Symlink dibuat: ${update_symlink} -> ${INSTALL_DIR}/update.sh"
    fi
}

set_permissions() {
    print_info "Mengatur permissions..."
    
    # Owner root
    chown -R root:root "${INSTALL_DIR}"
    
    # Directory permissions
    chmod 755 "${INSTALL_DIR}"
    chmod 755 "${INSTALL_DIR}/modules"
    chmod 755 "${INSTALL_DIR}/config"
    chmod 700 "${INSTALL_DIR}/backups"
    chmod 700 "${INSTALL_DIR}/logs"
    
    # File permissions
    chmod 755 "${INSTALL_DIR}/nft-manager.sh"
    chmod 644 "${INSTALL_DIR}/config/nft-manager.conf"
    chmod 600 "${INSTALL_DIR}/logs/nft-manager.log"
    
    # Module files
    for module in "${INSTALL_DIR}/modules/"*.sh; do
        if [[ -f "$module" ]]; then
            chmod 755 "$module"
        fi
    done
    
    print_step "Permissions diatur"
}

update_config_path() {
    print_info "Memperbarui konfigurasi path..."
    
    # Update APP_DIR di config
    sed -i "s|^APP_DIR=.*|APP_DIR=\"${INSTALL_DIR}\"|" "${INSTALL_DIR}/config/nft-manager.conf" 2>/dev/null || true
    
    print_step "Konfigurasi path diperbarui"
}

# =============================================================================
# Service systemd (Opsional)
# =============================================================================

create_systemd_service() {
    print_info "Membuat systemd service untuk monitoring..."
    
    local service_file="/etc/systemd/system/nft-manager-monitor.service"
    
    cat > "$service_file" << 'EOF'
[Unit]
Description=NFT Manager - Firewall Monitoring Service
After=network.target nftables.service

[Service]
Type=simple
ExecStart=/opt/nft-manager/nft-manager.sh --monitor
Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Reload systemd
    systemctl daemon-reload
    
    print_step "Systemd service dibuat: ${service_file}"
    print_info "Untuk mengaktifkan service, jalankan:"
    echo "  sudo systemctl enable nft-manager-monitor.service"
    echo "  sudo systemctl start nft-manager-monitor.service"
}

# =============================================================================
# Verifikasi Instalasi
# =============================================================================

verify_installation() {
    print_info "Memverifikasi instalasi..."
    
    local errors=0
    
    # Cek direktori
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        print_error "Direktori aplikasi tidak ditemukan: ${INSTALL_DIR}"
        errors=$((errors + 1))
    fi
    
    # Cek main script
    if [[ ! -f "${INSTALL_DIR}/nft-manager.sh" ]]; then
        print_error "Main script tidak ditemukan"
        errors=$((errors + 1))
    fi
    
    # Cek modules
    local module_count
    module_count=$(find "${INSTALL_DIR}/modules" -name "*.sh" -type f 2>/dev/null | wc -l)
    
    if [[ "$module_count" -lt 10 ]]; then
        print_error "Jumlah module tidak lengkap: ${module_count}"
        errors=$((errors + 1))
    fi
    
    # Cek symlink
    if [[ ! -L "/usr/local/bin/nft-manager" ]]; then
        print_error "Symlink tidak ditemukan"
        errors=$((errors + 1))
    fi
    
    # Cek executable
    if ! command -v nft-manager &>/dev/null; then
        print_error "Command 'nft-manager' tidak ditemukan di PATH"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_step "Verifikasi: SEMUA OK"
        return 0
    else
        print_error "Verifikasi: ${errors} ERROR DITEMUKAN"
        return 1
    fi
}

# =============================================================================
# Post-Installation
# =============================================================================

show_post_install_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   INSTALASI BERHASIL!${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Informasi Instalasi:${NC}"
    echo "  Lokasi       : ${INSTALL_DIR}"
    echo "  Command      : nft-manager"
    echo "  Config       : ${INSTALL_DIR}/config/nft-manager.conf"
    echo "  Backups      : ${INSTALL_DIR}/backups"
    echo "  Logs         : ${INSTALL_DIR}/logs/nft-manager.log"
    echo ""
    echo -e "${BLUE}Cara Menggunakan:${NC}"
    echo "  1. Jalankan sebagai root:"
    echo "     sudo nft-manager"
    echo ""
    echo "  2. Update ke versi terbaru:"
    echo "     sudo nft-update"
    echo ""
    echo "  3. Atau dari direktori:"
    echo "     cd ${INSTALL_DIR}"
    echo "     sudo ./nft-manager.sh"
    echo "     sudo ./update.sh"
    echo ""
    echo -e "${BLUE}Uninstall:${NC}"
    echo "  sudo ./uninstall.sh"
    echo ""
    echo -e "${YELLOW}PENTING:${NC}"
    echo "  - Selalu backup sebelum mengubah rule firewall"
    echo "  - Gunakan fitur rollback untuk keamanan"
    echo "  - Cek log secara berkala di: ${INSTALL_DIR}/logs/nft-manager.log"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_header
    
    echo "Installer akan:"
    echo "  1. Memeriksa sistem dan dependencies"
    echo "  2. Menginstall package yang diperlukan"
    echo "  3. Menginstall ${APP_NAME} ke ${INSTALL_DIR}"
    echo "  4. Membuat symlink dan permissions"
    echo ""
    
    read -p "Lanjutkan instalasi? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Instalasi dibatalkan."
        exit 0
    fi
    
    echo ""
    
    # Langkah 1: Validasi
    check_root
    check_os
    check_bash_version
    
    # Langkah 2: Dependencies
    install_dependencies
    
    # Langkah 3: Instalasi
    create_directories
    copy_files
    update_config_path
    set_permissions
    create_symlink
    
    # Langkah 4: Service (opsional)
    echo ""
    read -p "Install systemd service untuk monitoring? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        create_systemd_service
    fi
    
    # Langkah 5: Verifikasi
    echo ""
    verify_installation
    
    # Langkah 6: Post-install info
    show_post_install_info
}

# Jalankan main
main
