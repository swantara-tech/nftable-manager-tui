#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Script Uninstall
# =============================================================================
# Script untuk menghapus NFT Manager dari sistem
# Jalankan sebagai root: sudo ./uninstall.sh
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
INSTALL_DIR="/opt/nft-manager"

# =============================================================================
# Fungsi Helper
# =============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}   ${APP_NAME} - Uninstaller${NC}"
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
# Validasi
# =============================================================================

check_root() {
    print_info "Memeriksa hak akses root..."
    if [[ $EUID -ne 0 ]]; then
        print_error "Script harus dijalankan sebagai root!"
        echo ""
        echo "Gunakan: sudo ./uninstall.sh"
        exit 1
    fi
    print_step "Hak akses root: OK"
}

check_installation() {
    print_info "Memeriksa instalasi..."
    
    if [[ ! -d "${INSTALL_DIR}" ]]; then
        print_error "Direktori instalasi tidak ditemukan: ${INSTALL_DIR}"
        print_error "Aplikasi mungkin belum terinstall."
        exit 1
    fi
    
    print_step "Instalasi ditemukan di: ${INSTALL_DIR}"
}

# =============================================================================
# Backup Data
# =============================================================================

backup_data() {
    print_info "Membuat backup data sebelum uninstall..."
    
    local backup_dir
    backup_dir="${INSTALL_DIR}/uninstall-backup-$(date '+%Y%m%d-%H%M%S')"
    
    mkdir -p "$backup_dir"
    
    # Backup konfigurasi
    if [[ -d "${INSTALL_DIR}/config" ]]; then
        cp -r "${INSTALL_DIR}/config" "$backup_dir/"
        print_step "Backup konfigurasi"
    fi
    
    # Backup logs
    if [[ -d "${INSTALL_DIR}/logs" ]]; then
        cp -r "${INSTALL_DIR}/logs" "$backup_dir/"
        print_step "Backup logs"
    fi
    
    # Backup data (jika user mau)
    if [[ -d "${INSTALL_DIR}/backups" ]]; then
        local backup_count
        backup_count=$(find "${INSTALL_DIR}/backups" -name "*.tar.gz" -type f 2>/dev/null | wc -l)
        
        if [[ "$backup_count" -gt 0 ]]; then
            echo ""
            print_info "Ditemukan ${backup_count} file backup firewall."
            read -p "Sertakan dalam backup? (y/n): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                cp -r "${INSTALL_DIR}/backups" "$backup_dir/"
                print_step "Backup data firewall"
            fi
        fi
    fi
    
    echo ""
    print_info "Backup disimpan di: ${backup_dir}"
}

# =============================================================================
# Hapus Service
# =============================================================================

remove_systemd_service() {
    print_info "Menghapus systemd service..."
    
    local service_file="/etc/systemd/system/nft-manager-monitor.service"
    
    if [[ -f "$service_file" ]]; then
        # Stop service jika running
        systemctl stop nft-manager-monitor.service 2>/dev/null || true
        systemctl disable nft-manager-monitor.service 2>/dev/null || true
        
        # Hapus service file
        rm -f "$service_file"
        systemctl daemon-reload
        
        print_step "Systemd service dihapus"
    else
        print_info "Systemd service tidak ditemukan"
    fi
}

# =============================================================================
# Hapus Symlink
# =============================================================================

remove_symlink() {
    print_info "Menghapus symbolic link..."
    
    local symlink_path="/usr/local/bin/nft-manager"
    
    if [[ -L "$symlink_path" ]]; then
        rm -f "$symlink_path"
        print_step "Symlink dihapus: ${symlink_path}"
    else
        print_info "Symlink tidak ditemukan"
    fi
}

# =============================================================================
# Hapus File Aplikasi
# =============================================================================

remove_application_files() {
    print_info "Menghapus file aplikasi..."
    
    if [[ -d "${INSTALL_DIR}" ]]; then
        rm -rf "${INSTALL_DIR}"
        print_step "Direktori aplikasi dihapus: ${INSTALL_DIR}"
    else
        print_warning "Direktori aplikasi tidak ditemukan"
    fi
}

# =============================================================================
# Hapus Firewall Rules (Opsional)
# =============================================================================

remove_firewall_rules() {
    echo ""
    print_warning "PERINGATAN: Tindakan ini akan menghapus semua rule firewall!"
    print_warning "Firewall akan dikembalikan ke state kosong."
    echo ""
    
    read -p "Hapus semua rule nftables? (y/n): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Menghapus semua rule nftables..."
        
        if command -v nft &>/dev/null; then
            # Flush semua ruleset
            nft flush ruleset 2>/dev/null
            
            print_step "Semua rule nftables dihapus"
            print_warning "PENTING: Server Anda sekarang TIDAK memiliki proteksi firewall!"
            print_info "Untuk mengamankan kembali, install ulang atau konfigurasi manual."
        else
            print_error "nftables tidak ditemukan"
        fi
    else
        print_info "Rule firewall dipertahankan"
    fi
}

# =============================================================================
# Verifikasi Uninstall
# =============================================================================

verify_uninstall() {
    print_info "Memverifikasi uninstall..."
    
    local errors=0
    
    # Cek direktori
    if [[ -d "${INSTALL_DIR}" ]]; then
        print_error "Direktori masih ada: ${INSTALL_DIR}"
        errors=$((errors + 1))
    fi
    
    # Cek symlink
    if [[ -L "/usr/local/bin/nft-manager" ]]; then
        print_error "Symlink masih ada: /usr/local/bin/nft-manager"
        errors=$((errors + 1))
    fi
    
    # Cek command
    if command -v nft-manager &>/dev/null; then
        print_error "Command 'nft-manager' masih tersedia"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -eq 0 ]]; then
        print_step "Verifikasi: UNINSTALL BERHASIL"
        return 0
    else
        print_error "Verifikasi: ${errors} MASALAH DITEMUKAN"
        return 1
    fi
}

# =============================================================================
# Post-Uninstall
# =============================================================================

show_post_uninstall_info() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}   UNINSTALL SELESAI${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${BLUE}Informasi:${NC}"
    echo "  - Aplikasi ${APP_NAME} telah dihapus"
    echo "  - Backup data tersimpan di direktori uninstall-backup-*"
    echo ""
    echo -e "${YELLOW}PENTING:${NC}"
    echo "  - Pastikan Anda sudah backup konfigurasi penting"
    echo "  - Cek status firewall: sudo nft list ruleset"
    echo "  - Reinstall kapan saja jika diperlukan"
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_header
    
    echo "Uninstaller akan:"
    echo "  1. Backup data dan konfigurasi"
    echo "  2. Hapus systemd service"
    echo "  3. Hapus symlink"
    echo "  4. Hapus file aplikasi"
    echo "  5. (Opsional) Hapus rule firewall"
    echo ""
    
    print_warning "PERINGATAN: Tindakan ini tidak dapat dibatalkan!"
    echo ""
    
    read -p "Lanjutkan uninstall? (y/n): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Uninstall dibatalkan."
        exit 0
    fi
    
    echo ""
    
    # Langkah 1: Validasi
    check_root
    check_installation
    
    # Langkah 2: Backup
    backup_data
    
    echo ""
    
    # Langkah 3: Hapus service
    remove_systemd_service
    
    # Langkah 4: Hapus symlink
    remove_symlink
    
    # Langkah 5: Hapus file aplikasi
    remove_application_files
    
    # Langkah 6: Hapus firewall rules (opsional)
    remove_firewall_rules
    
    # Langkah 7: Verifikasi
    echo ""
    verify_uninstall
    
    # Langkah 8: Post-uninstall info
    show_post_uninstall_info
}

# Jalankan main
main
