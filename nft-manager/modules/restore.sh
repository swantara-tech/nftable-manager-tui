#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Restore
# =============================================================================
# Restore konfigurasi nftables dari backup
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: select_and_restore
# Deskripsi: Memilih backup dan melakukan restore
# -----------------------------------------------------------------------------
select_and_restore() {
    local backup_files
    
    # Ambil daftar backup
    backup_files=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}-*.${BACKUP_FORMAT}" -type f 2>/dev/null | sort -r)
    
    if [[ -z "$backup_files" ]]; then
        whiptail --msgbox "Tidak ada backup yang tersedia." 8 50
        return
    fi
    
    # Buat list untuk whiptail
    local menu_items=()
    local count=0
    while IFS= read -r backup_file; do
        count=$((count + 1))
        local filename filesize filedate
        filename=$(basename "$backup_file")
        filesize=$(du -h "$backup_file" | cut -f1)
        filedate=$(stat -c '%y' "$backup_file" 2>/dev/null | cut -d'.' -f1 || echo "N/A")
        menu_items+=("$count" "${filename} - ${filesize} (${filedate})")
    done <<< "$backup_files"
    
    # Pilih backup
    local selection
    selection=$(whiptail --title "Restore Backup" --menu \
        "Pilih backup yang ingin di-restore:" \
        20 80 10 \
        "${menu_items[@]}" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Ambil file yang dipilih
    local selected_file
    selected_file=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}-*.${BACKUP_FORMAT}" -type f 2>/dev/null | sort -r | sed -n "${selection}p")
    
    if [[ -z "$selected_file" ]]; then
        whiptail --msgbox "Backup tidak ditemukan!" 8 50
        return
    fi
    
    # Konfirmasi
    local filename
    filename=$(basename "$selected_file")
    if ! whiptail --title "Konfirmasi Restore" --yesno \
        "Yakin ingin restore dari backup:\n${filename}\n\nKonfigurasi saat ini akan diganti!" 12 60; then
        return
    fi
    
    # Lakukan restore
    restore_backup "$selected_file"
}

# -----------------------------------------------------------------------------
# Fungsi: restore_backup
# Deskripsi: Melakukan restore dari file backup
# Argumen: $1 = path file backup
# -----------------------------------------------------------------------------
restore_backup() {
    local backup_file="$1"
    
    if [[ ! -f "$backup_file" ]]; then
        whiptail --msgbox "File backup tidak ditemukan:\n${backup_file}" 8 60
        log_activity "Gagal restore: File tidak ditemukan ${backup_file}"
        return 1
    fi
    
    # Backup state saat ini sebelum restore
    create_rollback_point
    
    # Extract archive ke temp
    local temp_dir
    temp_dir=$(mktemp -d /tmp/nft-restore-XXXXXX)
    local rules_file="${temp_dir}/rules.nft"
    
    if ! tar -xzf "$backup_file" -C "$temp_dir" 2>&1; then
        whiptail --msgbox "Gagal mengekstrak file backup!" 8 50
        log_activity "Gagal restore: Tidak dapat ekstrak ${backup_file}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cari file rules di dalam archive
    local extracted_file
    extracted_file=$(find "$temp_dir" -type f -name "*.nft" -o -name "nft-rules-*" | head -n 1)
    
    if [[ -z "$extracted_file" ]]; then
        whiptail --msgbox "File rules tidak ditemukan dalam backup!" 8 50
        log_activity "Gagal restore: File rules tidak ditemukan dalam ${backup_file}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    cp "$extracted_file" "$rules_file"
    
    # Validasi konfigurasi
    whiptail --msgbox "Memvalidasi konfigurasi..." 5 40
    
    if ! nft -c -f "$rules_file" 2>&1; then
        whiptail --msgbox "VALIDASI GAGAL!\n\nKonfigurasi dalam backup tidak valid.\nRestore dibatalkan untuk keamanan." 10 60
        log_activity "Gagal restore: Validasi gagal untuk ${backup_file}"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Apply konfigurasi
    if nft -f "$rules_file" 2>&1; then
        local filename
        filename=$(basename "$backup_file")
        whiptail --msgbox "RESTORE BERHASIL!\n\nBackup: ${filename}\n\nKonfigurasi telah diterapkan." 10 60
        log_activity "Restore berhasil dari: ${filename}"
        confirm_or_rollback
    else
        whiptail --msgbox "GAGAL MENERAPKAN KONFIGURASI!\n\nSistem akan rollback ke state sebelumnya." 10 60
        log_activity "Gagal restore: Tidak dapat apply konfigurasi dari ${backup_file}"
        execute_rollback
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
}

# -----------------------------------------------------------------------------
# Fungsi: quick_restore
# Deskripsi: Restore cepat dari file (untuk otomatisasi)
# Argumen: $1 = path file backup
# Return: 0 jika berhasil, 1 jika gagal
# -----------------------------------------------------------------------------
quick_restore() {
    local backup_file="$1"
    
    [[ ! -f "$backup_file" ]] && return 1
    
    local temp_dir
    temp_dir=$(mktemp -d /tmp/nft-restore-XXXXXX)
    
    if ! tar -xzf "$backup_file" -C "$temp_dir" 2>/dev/null; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    local extracted_file
    extracted_file=$(find "$temp_dir" -type f | head -n 1)
    
    if [[ -z "$extracted_file" ]]; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Validasi
    if ! nft -c -f "$extracted_file" 2>/dev/null; then
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Apply
    if nft -f "$extracted_file" 2>/dev/null; then
        rm -rf "$temp_dir"
        log_activity "Quick restore berhasil dari: $(basename "$backup_file")"
        return 0
    else
        rm -rf "$temp_dir"
        return 1
    fi
}
