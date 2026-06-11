#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Script Update
# =============================================================================
# Script untuk mengupdate NFT Manager ke versi terbaru dari GitHub
# Jalankan sebagai root: sudo ./update.sh
# =============================================================================

set -euo pipefail

# Warna untuk output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Informasi aplikasi
APP_NAME="NFT Manager"
INSTALL_DIR="/opt/nft-manager"
REPO_URL="https://github.com/swantara-tech/nftable-manager-tui.git"
REPO_BRANCH="main"
TEMP_DIR="/tmp/nft-manager-update"

# =============================================================================
# Fungsi Helper
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ${APP_NAME} - Updater${NC}"
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

print_success() {
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   $1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

# =============================================================================
# Validasi
# =============================================================================

check_root() {
    print_info "Memeriksa hak akses root..."
    if [[ $EUID -ne 0 ]]; then
        print_error "Script harus dijalankan sebagai root!"
        echo ""
        echo "Gunakan: sudo ./update.sh"
        exit 1
    fi
    print_step "Hak akses root: OK"
}

check_installation() {
    print_info "Memeriksa instalasi saat ini..."
    
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        print_error "Direktori instalasi tidak ditemukan: ${INSTALL_DIR}"
        print_error "Aplikasi belum terinstall."
        echo ""
        print_info "Silakan jalankan install.sh terlebih dahulu."
        exit 1
    fi
    
    print_step "Instalasi ditemukan di: ${INSTALL_DIR}"
}

check_internet() {
    print_info "Memeriksa koneksi internet..."
    
    if ! ping -c 1 -W 3 github.com &>/dev/null; then
        print_error "Tidak ada koneksi internet!"
        print_error "Tidak dapat terhubung ke GitHub."
        exit 1
    fi
    
    print_step "Koneksi internet: OK"
}

check_git() {
    print_info "Memeriksa Git..."
    
    if ! command -v git &>/dev/null; then
        print_warning "Git tidak ditemukan. Menginstall git..."
        apt-get update -qq
        apt-get install -y git -qq
        print_step "Git berhasil diinstall"
    else
        print_step "Git: OK ($(git --version | awk '{print $3}'))"
    fi
}

# =============================================================================
# Backup Sebelum Update
# =============================================================================

backup_current_version() {
    print_info "Membuat backup versi saat ini..."
    
    local backup_dir="/opt/nft-backups/update-backup-$(date '+%Y%m%d-%H%M%S')"
    
    mkdir -p "$backup_dir"
    
    # Backup files penting (exclude backups dan logs)
    print_info "Backing up files..."
    
    # Buat struktur direktori
    mkdir -p "$backup_dir/current-installation/modules"
    mkdir -p "$backup_dir/current-installation/config"
    
    # Copy main scripts
    if [[ -f "${INSTALL_DIR}/nft-manager.sh" ]]; then
        cp "${INSTALL_DIR}/nft-manager.sh" "$backup_dir/current-installation/"
    fi
    
    if [[ -f "${INSTALL_DIR}/install.sh" ]]; then
        cp "${INSTALL_DIR}/install.sh" "$backup_dir/current-installation/"
    fi
    
    if [[ -f "${INSTALL_DIR}/uninstall.sh" ]]; then
        cp "${INSTALL_DIR}/uninstall.sh" "$backup_dir/current-installation/"
    fi
    
    if [[ -f "${INSTALL_DIR}/update.sh" ]]; then
        cp "${INSTALL_DIR}/update.sh" "$backup_dir/current-installation/"
    fi
    
    # Copy modules
    if [[ -d "${INSTALL_DIR}/modules" ]]; then
        cp -r "${INSTALL_DIR}/modules/"* "$backup_dir/current-installation/modules/" 2>/dev/null || true
    fi
    
    # Copy config
    if [[ -d "${INSTALL_DIR}/config" ]]; then
        cp -r "${INSTALL_DIR}/config/"* "$backup_dir/current-installation/config/" 2>/dev/null || true
    fi
    
    # Verify backup
    if [[ -f "$backup_dir/current-installation/nft-manager.sh" ]]; then
        print_step "Backup dibuat: ${backup_dir}"
        BACKUP_PATH="$backup_dir"
    else
        print_error "Gagal membuat backup!"
        print_warning "Update dibatalkan untuk keamanan."
        exit 1
    fi
}

backup_config_only() {
    print_info "Membuat backup konfigurasi..."
    
    local config_backup="/tmp/nft-config-backup-$(date '+%Y%m%d-%H%M%S').tar.gz"
    
    if [[ -d "${INSTALL_DIR}/config" ]]; then
        tar -czf "$config_backup" -C "${INSTALL_DIR}" config 2>/dev/null
        print_step "Backup konfigurasi: ${config_backup}"
    fi
}

# =============================================================================
# Download Versi Terbaru
# =============================================================================

get_current_version() {
    local current_version="Unknown"
    
    if [[ -f "${INSTALL_DIR}/config/nft-manager.conf" ]]; then
        current_version=$(grep "^APP_VERSION=" "${INSTALL_DIR}/config/nft-manager.conf" 2>/dev/null | cut -d'"' -f2 || echo "Unknown")
    fi
    
    echo "$current_version"
}

download_latest_version() {
    print_info "Mengunduh versi terbaru dari GitHub..."
    
    # Cleanup temp dir jika ada
    rm -rf "$TEMP_DIR"
    
    # Clone repository
    if git clone --depth 1 --branch "$REPO_BRANCH" "$REPO_URL" "$TEMP_DIR" 2>&1; then
        print_step "Download berhasil"
    else
        print_error "Gagal mengunduh dari GitHub!"
        exit 1
    fi
    
    # Ambil versi terbaru
    local new_version="Unknown"
    if [[ -f "${TEMP_DIR}/nft-manager/config/nft-manager.conf" ]]; then
        new_version=$(grep "^APP_VERSION=" "${TEMP_DIR}/nft-manager/config/nft-manager.conf" | cut -d'"' -f2)
    fi
    
    print_info "Versi terbaru: ${new_version}"
    NEW_VERSION="$new_version"
}

# =============================================================================
# Update Aplikasi
# =============================================================================

compare_versions() {
    local current_version="$1"
    local new_version="$2"
    
    if [[ "$current_version" == "$new_version" ]]; then
        return 0 # Sama
    else
        return 1 # Berbeda
    fi
}

update_files() {
    print_info "Mengupdate file aplikasi..."
    
    local current_version="$1"
    local new_version="$2"
    
    # Backup konfigurasi user (jangan timpa)
    local user_config="${INSTALL_DIR}/config/nft-manager.conf"
    local temp_config="${TEMP_DIR}/nft-manager/config/nft-manager.conf"
    
    if [[ -f "$user_config" ]]; then
        cp "$user_config" "/tmp/nft-manager-user-config.conf"
        print_step "Konfigurasi user diamankan"
    fi
    
    # Hapus file lama (kecuali backups dan logs)
    print_info "Menghapus file lama..."
    find "${INSTALL_DIR}" -maxdepth 1 -name "*.sh" -type f -delete 2>/dev/null || true
    rm -rf "${INSTALL_DIR}/modules" 2>/dev/null || true
    rm -rf "${INSTALL_DIR}/config" 2>/dev/null || true
    
    print_step "File lama dihapus"
    
    # Copy file baru
    print_info "Menyalin file baru..."
    
    # Main script
    cp "${TEMP_DIR}/nft-manager/nft-manager.sh" "${INSTALL_DIR}/"
    chmod +x "${INSTALL_DIR}/nft-manager.sh"
    print_step "nft-manager.sh"
    
    # Modules
    mkdir -p "${INSTALL_DIR}/modules"
    for module in "${TEMP_DIR}/nft-manager/modules/"*.sh; do
        if [[ -f "$module" ]]; then
            cp "$module" "${INSTALL_DIR}/modules/"
            chmod +x "${INSTALL_DIR}/modules/$(basename "$module")"
            print_step "modules/$(basename "$module")"
        fi
    done
    
    # Config (jika user belum punya config)
    if [[ ! -f "$user_config" ]]; then
        mkdir -p "${INSTALL_DIR}/config"
        cp "${TEMP_DIR}/nft-manager/config/nft-manager.conf" "${INSTALL_DIR}/config/"
        print_step "config/nft-manager.conf (baru)"
    else
        # Restore konfigurasi user
        cp "/tmp/nft-manager-user-config.conf" "$user_config"
        print_step "config/nft-manager.conf (user config dipertahankan)"
        
        # Update versi di config user
        sed -i "s|^APP_VERSION=.*|APP_VERSION=\"${new_version}\"|" "$user_config" 2>/dev/null || true
    fi
    
    # Install & uninstall scripts
    if [[ -f "${TEMP_DIR}/nft-manager/install.sh" ]]; then
        cp "${TEMP_DIR}/nft-manager/install.sh" "${INSTALL_DIR}/"
        chmod +x "${INSTALL_DIR}/install.sh"
        print_step "install.sh"
    fi
    
    if [[ -f "${TEMP_DIR}/nft-manager/uninstall.sh" ]]; then
        cp "${TEMP_DIR}/nft-manager/uninstall.sh" "${INSTALL_DIR}/"
        chmod +x "${INSTALL_DIR}/uninstall.sh"
        print_step "uninstall.sh"
    fi
    
    # Cleanup
    rm -f "/tmp/nft-manager-user-config.conf"
    rm -rf "$TEMP_DIR"
    
    print_step "Semua file berhasil diupdate"
}

update_symlink() {
    print_info "Memperbarui symbolic link..."
    
    local symlink_path="/usr/local/bin/nft-manager"
    
    if [[ -L "$symlink_path" ]]; then
        rm -f "$symlink_path"
    fi
    
    ln -sf "${INSTALL_DIR}/nft-manager.sh" "$symlink_path"
    chmod +x "$symlink_path"
    
    print_step "Symlink diperbarui: ${symlink_path}"
}

fix_permissions() {
    print_info "Memperbaiki permissions..."
    
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
    chmod 755 "${INSTALL_DIR}/install.sh" 2>/dev/null || true
    chmod 755 "${INSTALL_DIR}/uninstall.sh" 2>/dev/null || true
    chmod 644 "${INSTALL_DIR}/config/nft-manager.conf"
    chmod 600 "${INSTALL_DIR}/logs/nft-manager.log" 2>/dev/null || true
    
    # Module files
    for module in "${INSTALL_DIR}/modules/"*.sh; do
        if [[ -f "$module" ]]; then
            chmod 755 "$module"
        fi
    done
    
    print_step "Permissions diperbaiki"
}

# =============================================================================
# Verifikasi Update
# =============================================================================

verify_update() {
    print_info "Memverifikasi update..."
    
    local errors=0
    
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
    
    # Cek config
    if [[ ! -f "${INSTALL_DIR}/config/nft-manager.conf" ]]; then
        print_error "File konfigurasi tidak ditemukan"
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
        print_step "Verifikasi: UPDATE BERHASIL"
        return 0
    else
        print_error "Verifikasi: ${errors} ERROR DITEMUKAN"
        return 1
    fi
}

# =============================================================================
# Rollback (jika update gagal)
# =============================================================================

rollback_update() {
    print_warning "Update gagal! Melakukan rollback..."
    
    if [[ -n "${BACKUP_PATH:-}" && -d "${BACKUP_PATH}/current-installation" ]]; then
        # Hapus instalasi yang gagal
        rm -rf "${INSTALL_DIR}"
        
        # Restore dari backup
        cp -r "${BACKUP_PATH}/current-installation" "${INSTALL_DIR}"
        
        print_step "Rollback berhasil ke versi sebelumnya"
        print_info "Backup ada di: ${BACKUP_PATH}"
    else
        print_error "Tidak ada backup untuk rollback!"
        print_error "Silakan reinstall aplikasi."
    fi
}

# =============================================================================
# Post-Update
# =============================================================================

show_changelog() {
    print_info "Mengecek changelog..."
    
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}   CHANGELOG${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    
    # Coba ambil dari GitHub releases atau tampilkan info umum
    echo "Untuk melihat changelog lengkap, kunjungi:"
    echo "  https://github.com/swantara-tech/nftable-manager-tui/releases"
    echo ""
    echo "Atau cek commit terbaru:"
    echo "  https://github.com/swantara-tech/nftable-manager-tui/commits/main"
    echo ""
}

show_post_update_info() {
    echo ""
    print_success "UPDATE BERHASIL!"
    echo ""
    
    local current_version
    current_version=$(get_current_version)
    
    echo -e "${BLUE}Informasi Update:${NC}"
    echo "  Versi Sebelumnya : ${OLD_VERSION}"
    echo "  Versi Terbaru    : ${NEW_VERSION}"
    echo "  Lokasi Install   : ${INSTALL_DIR}"
    echo "  Backup           : ${BACKUP_PATH}"
    echo ""
    
    echo -e "${BLUE}Cara Menjalankan:${NC}"
    echo "  sudo nft-manager"
    echo ""
    
    echo -e "${YELLOW}PENTING:${NC}"
    echo "  - Konfigurasi Anda telah dipertahankan"
    echo "  - Backup versi lama ada di: ${BACKUP_PATH}"
    echo "  - Jika ada masalah, Anda bisa rollback manual:"
    echo "    sudo rm -rf ${INSTALL_DIR}"
    echo "    sudo cp -r ${BACKUP_PATH}/current-installation ${INSTALL_DIR}"
    echo ""
    
    show_changelog
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_header
    
    echo "Updater akan:"
    echo "  1. Memeriksa versi terbaru di GitHub"
    echo "  2. Backup versi saat ini"
    echo "  3. Download dan install update"
    echo "  4. Verifikasi update"
    echo ""
    
    # Baca versi saat ini
    OLD_VERSION=$(get_current_version)
    print_info "Versi saat ini: ${OLD_VERSION}"
    
    echo ""
    read -p "Lanjutkan update? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Update dibatalkan."
        exit 0
    fi
    
    echo ""
    
    # Langkah 1: Validasi
    check_root
    check_installation
    check_internet
    check_git
    
    # Langkah 2: Download versi terbaru
    echo ""
    download_latest_version
    
    # Cek apakah ada update
    if compare_versions "$OLD_VERSION" "$NEW_VERSION"; then
        print_warning "Anda sudah menggunakan versi terbaru (${OLD_VERSION})"
        echo ""
        read -p "Tetap install ulang? (y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$TEMP_DIR"
            exit 0
        fi
    else
        print_info "Update tersedia: ${OLD_VERSION} → ${NEW_VERSION}"
    fi
    
    # Langkah 3: Backup
    echo ""
    backup_current_version
    backup_config_only
    
    # Langkah 4: Update
    echo ""
    if update_files "$OLD_VERSION" "$NEW_VERSION"; then
        # Update symlink dan permissions
        update_symlink
        fix_permissions
        
        # Verifikasi
        echo ""
        if verify_update; then
            # Success
            show_post_update_info
            exit 0
        else
            # Verification failed - rollback
            rollback_update
            exit 1
        fi
    else
        # Update failed - rollback
        rollback_update
        exit 1
    fi
}

# Trap untuk cleanup
trap 'rm -rf "$TEMP_DIR" 2>/dev/null || true' EXIT

# Jalankan main
main
