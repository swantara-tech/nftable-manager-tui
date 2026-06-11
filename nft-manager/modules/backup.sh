#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Backup
# =============================================================================
# Membuat dan mengelola backup konfigurasi nftables
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_backups
# Deskripsi: Menu utama untuk manajemen backup
# -----------------------------------------------------------------------------
manage_backups() {
    local choice
    while true; do
        choice=$(whiptail --title "Backup & Restore" --menu \
            "Pilih operasi yang ingin dilakukan:" \
            14 60 5 \
            "1" "Buat backup baru" \
            "2" "Lihat daftar backup" \
            "3" "Restore dari backup" \
            "4" "Hapus backup" \
            "5" "Hapus semua backup lama" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) create_backup ;;
            2) list_backups ;;
            3) select_and_restore ;;
            4) delete_backup ;;
            5) cleanup_old_backups ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: create_backup
# Deskripsi: Membuat backup konfigurasi nftables
# -----------------------------------------------------------------------------
create_backup() {
    local timestamp backup_filename backup_path rules_file
    
    # Generate nama file backup
    timestamp=$(date '+%Y%m%d-%H%M%S')
    backup_filename="${BACKUP_PREFIX}-${timestamp}.${BACKUP_FORMAT}"
    backup_path="${BACKUP_DIR}/${backup_filename}"
    rules_file=$(mktemp /tmp/nft-rules-XXXXXX)
    
    # Ambil ruleset saat ini
    if ! nft list ruleset > "$rules_file" 2>&1; then
        whiptail --msgbox "Gagal membaca konfigurasi nftables saat ini!" 8 60
        rm -f "$rules_file"
        log_activity "Gagal membuat backup: Tidak dapat membaca ruleset"
        return 1
    fi
    
    # Buat archive tar.gz
    if tar -czf "$backup_path" -C "$(dirname "$rules_file")" "$(basename "$rules_file")" 2>&1; then
        rm -f "$rules_file"
        
        # Tampilkan informasi backup
        local backup_size
        backup_size=$(du -h "$backup_path" | cut -f1)
        
        whiptail --msgbox "Backup berhasil dibuat!\n\nFile: ${backup_filename}\nUkuran: ${backup_size}\nLokasi: ${BACKUP_DIR}" 12 60
        log_activity "Membuat backup: ${backup_filename} (${backup_size})"
        
        # Cleanup backup lama jika melebihi batas
        if [[ "$BACKUP_MAX_FILES" -gt 0 ]]; then
            cleanup_old_backups_silent
        fi
        
        return 0
    else
        rm -f "$rules_file"
        whiptail --msgbox "Gagal membuat backup!" 8 50
        log_activity "Gagal membuat backup"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: list_backups
# Deskripsi: Menampilkan daftar backup yang tersedia
# -----------------------------------------------------------------------------
list_backups() {
    local backup_files backup_text
    
    # Cek direktori backup
    if [[ ! -d "$BACKUP_DIR" ]]; then
        whiptail --msgbox "Direktori backup tidak ditemukan!" 8 50
        return
    fi
    
    # Ambil daftar file backup
    backup_files=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}-*.${BACKUP_FORMAT}" -type f 2>/dev/null | sort -r)
    
    if [[ -z "$backup_files" ]]; then
        whiptail --msgbox "Tidak ada backup yang tersedia." 8 50
        return
    fi
    
    # Format tampilan
    backup_text="DAFTAR BACKUP KONFIGURASI\n"
    backup_text+="========================================\n\n"
    
    local count=0
    while IFS= read -r backup_file; do
        count=$((count + 1))
        local filename filesize filedate
        filename=$(basename "$backup_file")
        filesize=$(du -h "$backup_file" | cut -f1)
        filedate=$(stat -c '%y' "$backup_file" 2>/dev/null | cut -d'.' -f1 || echo "N/A")
        
        backup_text+="${count}. ${filename}\n"
        backup_text+="   Ukuran: ${filesize}\n"
        backup_text+="   Tanggal: ${filedate}\n\n"
    done <<< "$backup_files"
    
    backup_text+="========================================\n"
    backup_text+="Total: ${count} backup\n"
    
    whiptail --title "Daftar Backup" --msgbox --scrolltext "$backup_text" 25 70
    log_activity "Melihat daftar backup (${count} file)"
}

# -----------------------------------------------------------------------------
# Fungsi: delete_backup
# Deskripsi: Menghapus satu backup
# -----------------------------------------------------------------------------
delete_backup() {
    local backup_files backup_list selection
    
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
        local filename filesize
        filename=$(basename "$backup_file")
        filesize=$(du -h "$backup_file" | cut -f1)
        menu_items+=("$count" "${filename} (${filesize})")
    done <<< "$backup_files"
    
    # Pilih backup
    selection=$(whiptail --title "Hapus Backup" --menu \
        "Pilih backup yang ingin dihapus:" \
        20 70 10 \
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
    if ! whiptail --title "Konfirmasi Hapus" --yesno \
        "Yakin ingin menghapus backup:\n${filename}?" 10 60; then
        return
    fi
    
    # Hapus
    if rm -f "$selected_file"; then
        whiptail --msgbox "Backup berhasil dihapus!" 8 50
        log_activity "Menghapus backup: ${filename}"
    else
        whiptail --msgbox "Gagal menghapus backup!" 8 50
        log_activity "Gagal menghapus backup: ${filename}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: cleanup_old_backups
# Deskripsi: Membersihkan backup lama (dengan output)
# -----------------------------------------------------------------------------
cleanup_old_backups() {
    if [[ "$BACKUP_MAX_FILES" -eq 0 ]]; then
        whiptail --msgbox "Tidak ada batas maksimum backup (unlimited)." 8 50
        return
    fi
    
    local backup_files count deleted=0
    backup_files=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}-*.${BACKUP_FORMAT}" -type f 2>/dev/null | sort -r)
    count=$(echo "$backup_files" | grep -c . || echo "0")
    
    if [[ "$count" -le "$BACKUP_MAX_FILES" ]]; then
        whiptail --msgbox "Jumlah backup (${count}) masih di bawah batas (${BACKUP_MAX_FILES})." 8 60
        return
    fi
    
    # Hapus backup terlama
    local to_delete=$((count - BACKUP_MAX_FILES))
    echo "$backup_files" | tail -n "$to_delete" | while read -r old_backup; do
        if rm -f "$old_backup"; then
            deleted=$((deleted + 1))
            log_activity "Menghapus backup lama: $(basename "$old_backup")"
        fi
    done
    
    whiptail --msgbox "Cleanup selesai!\n${deleted} backup lama dihapus." 8 50
    log_activity "Cleanup backup: ${deleted} file dihapus"
}

# -----------------------------------------------------------------------------
# Fungsi: cleanup_old_backups_silent
# Deskripsi: Membersihkan backup lama (tanpa output, untuk otomatis)
# -----------------------------------------------------------------------------
cleanup_old_backups_silent() {
    [[ "$BACKUP_MAX_FILES" -eq 0 ]] && return
    
    local backup_files count
    backup_files=$(find "$BACKUP_DIR" -name "${BACKUP_PREFIX}-*.${BACKUP_FORMAT}" -type f 2>/dev/null | sort -r)
    count=$(echo "$backup_files" | grep -c . || echo "0")
    
    if [[ "$count" -le "$BACKUP_MAX_FILES" ]]; then
        return
    fi
    
    local to_delete=$((count - BACKUP_MAX_FILES))
    echo "$backup_files" | tail -n "$to_delete" | while read -r old_backup; do
        rm -f "$old_backup" 2>/dev/null
        log_activity "Auto-cleanup backup lama: $(basename "$old_backup")"
    done
}
