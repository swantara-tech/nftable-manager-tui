#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Logs
# =============================================================================
# Melihat dan mengelola log aktivitas aplikasi
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: show_logs
# Deskripsi: Menampilkan log aktivitas
# -----------------------------------------------------------------------------
show_logs() {
    local choice
    
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --msgbox "File log belum ada.\n${LOG_FILE}" 8 60
        return
    fi
    
    while true; do
        choice=$(whiptail --title "Log Aktivitas" --menu \
            "Pilih operasi:" \
            14 60 5 \
            "1" "Lihat 50 log terakhir" \
            "2" "Lihat 100 log terakhir" \
            "3" "Lihat seluruh log" \
            "4" "Cari log" \
            "5" "Kosongkan log" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) view_last_logs 50 ;;
            2) view_last_logs 100 ;;
            3) view_all_logs ;;
            4) search_logs ;;
            5) clear_logs ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: view_last_logs
# Deskripsi: Menampilkan N log terakhir
# Argumen: $1 = jumlah baris
# -----------------------------------------------------------------------------
view_last_logs() {
    local lines="${1:-50}"
    local log_content
    
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --msgbox "File log belum ada." 8 50
        return
    fi
    
    log_content=$(tail -n "$lines" "$LOG_FILE")
    
    if [[ -z "$log_content" ]]; then
        whiptail --msgbox "Log kosong." 8 50
        return
    fi
    
    whiptail --title "Log Terakhir (${lines} baris)" --textbox --scrolltext \
        <(echo "$log_content") 25 100
}

# -----------------------------------------------------------------------------
# Fungsi: view_all_logs
# Deskripsi: Menampilkan seluruh log
# -----------------------------------------------------------------------------
view_all_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --msgbox "File log belum ada." 8 50
        return
    fi
    
    local line_count
    line_count=$(wc -l < "$LOG_FILE")
    
    whiptail --title "Seluruh Log (${line_count} baris)" --textbox --scrolltext \
        "$LOG_FILE" 25 100
}

# -----------------------------------------------------------------------------
# Fungsi: search_logs
# Deskripsi: Mencari log berdasarkan keyword
# -----------------------------------------------------------------------------
search_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --msgbox "File log belum ada." 8 50
        return
    fi
    
    local keyword
    
    keyword=$(whiptail --title "Cari Log" --inputbox \
        "Masukkan kata kunci pencarian:" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$keyword" ]] && return
    
    local search_result
    search_result=$(grep -i "$keyword" "$LOG_FILE")
    
    if [[ $? -ne 0 || -z "$search_result" ]]; then
        whiptail --msgbox "Tidak ditemukan log dengan keyword: ${keyword}" 8 60
        return
    fi
    
    local match_count
    match_count=$(echo "$search_result" | wc -l)
    
    whiptail --title "Hasil Pencarian: ${keyword} (${match_count} ditemukan)" --textbox --scrolltext \
        <(echo "$search_result") 25 100
}

# -----------------------------------------------------------------------------
# Fungsi: clear_logs
# Deskripsi: Membersihkan/mengosongkan log
# -----------------------------------------------------------------------------
clear_logs() {
    if ! whiptail --title "Konfirmasi" --yesno \
        "Yakin ingin mengosongkan log?\nSemua riwayat aktivitas akan dihapus!" 10 60; then
        return
    fi
    
    if [[ -f "$LOG_FILE" ]]; then
        # Backup log sebelum dihapus
        local backup_log="${LOG_FILE}.$(date '+%Y%m%d-%H%M%S').bak"
        cp "$LOG_FILE" "$backup_log" 2>/dev/null
        
        # Kosongkan file
        > "$LOG_FILE"
        
        whiptail --msgbox "Log berhasil dikosongkan!\nBackup log disimpan di:\n${backup_log}" 10 70
        log_activity "Log dikosongkan (backup: $(basename "$backup_log"))"
    else
        whiptail --msgbox "File log tidak ditemukan." 8 50
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: export_logs
# Deskripsi: Export log ke file
# -----------------------------------------------------------------------------
export_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        whiptail --msgbox "File log belum ada." 8 50
        return
    fi
    
    local export_path
    export_path=$(whiptail --title "Export Log" --inputbox \
        "Path file export:" \
        10 60 "/tmp/nft-manager-log-$(date '+%Y%m%d').txt" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$export_path" ]] && return
    
    if cp "$LOG_FILE" "$export_path" 2>&1; then
        whiptail --msgbox "Log berhasil diekspor ke:\n${export_path}" 10 70
        log_activity "Log diekspor ke ${export_path}"
    else
        whiptail --msgbox "Gagal mengekspor log!" 8 50
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: rotate_logs
# Deskripsi: Rotasi log berdasarkan ukuran
# -----------------------------------------------------------------------------
rotate_logs() {
    if [[ ! -f "$LOG_FILE" ]]; then
        return
    fi
    
    # Cek ukuran file dalam MB
    local file_size_kb
    file_size_kb=$(du -k "$LOG_FILE" | cut -f1)
    local file_size_mb=$((file_size_kb / 1024))
    
    if [[ "$file_size_mb" -ge "$LOG_MAX_SIZE" ]]; then
        # Rotasi log
        local rotated_file="${LOG_FILE}.$(date '+%Y%m%d-%H%M%S')"
        mv "$LOG_FILE" "$rotated_file"
        touch "$LOG_FILE"
        
        log_activity "Log dirotasi (ukuran: ${file_size_mb}MB)"
        
        # Hapus log lama jika melebihi batas
        cleanup_old_logs
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: cleanup_old_logs
# Deskripsi: Membersihkan log lama
# -----------------------------------------------------------------------------
cleanup_old_logs() {
    if [[ "$LOG_MAX_FILES" -eq 0 ]]; then
        return
    fi
    
    local log_count
    log_count=$(find "$LOG_DIR" -name "nft-manager.log.*" -type f 2>/dev/null | wc -l)
    
    if [[ "$log_count" -gt "$LOG_MAX_FILES" ]]; then
        local to_delete=$((log_count - LOG_MAX_FILES))
        find "$LOG_DIR" -name "nft-manager.log.*" -type f 2>/dev/null | sort | head -n "$to_delete" | while read -r old_log; do
            rm -f "$old_log"
            log_activity "Log lama dihapus: $(basename "$old_log")"
        done
    fi
}
