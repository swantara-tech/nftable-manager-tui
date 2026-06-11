#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Settings
# =============================================================================
# Mengelola pengaturan aplikasi
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_settings
# Deskripsi: Menu utama untuk pengaturan
# -----------------------------------------------------------------------------
manage_settings() {
    local choice
    while true; do
        choice=$(whiptail --title "Pengaturan Aplikasi" --menu \
            "Pilih pengaturan yang ingin diubah:" \
            15 60 6 \
            "1" "Lokasi Backup" \
            "2" "Durasi Rollback" \
            "3" "Tema Terminal" \
            "4" "Konfigurasi Log" \
            "5" "Preset Keamanan Default" \
            "6" "Lihat Konfigurasi Saat Ini" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) set_backup_dir ;;
            2) set_rollback_duration ;;
            3) set_theme ;;
            4) configure_logging ;;
            5) set_default_security_preset ;;
            6) view_current_config ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: set_backup_dir
# Deskripsi: Mengubah direktori backup
# -----------------------------------------------------------------------------
set_backup_dir() {
    local current_dir new_dir
    
    current_dir="$BACKUP_DIR"
    
    new_dir=$(whiptail --title "Pengaturan Backup" --inputbox \
        "Direktori backup saat ini:\n${current_dir}\n\nMasukkan direktori backup baru:" \
        12 70 "$current_dir" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$new_dir" ]] && return
    
    # Validasi path
    if [[ "$new_dir" != /* ]]; then
        whiptail --msgbox "Path harus absolut (dimulai dengan /)!" 8 50
        return
    fi
    
    # Buat direktori jika belum ada
    if [[ ! -d "$new_dir" ]]; then
        if ! mkdir -p "$new_dir" 2>&1; then
            whiptail --msgbox "Gagal membuat direktori:\n${new_dir}" 8 60
            return
        fi
    fi
    
    # Update konfigurasi
    sed -i "s|^BACKUP_DIR=.*|BACKUP_DIR=\"${new_dir}\"|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    BACKUP_DIR="$new_dir"
    
    whiptail --msgbox "Direktori backup berhasil diubah!\n\n${new_dir}" 10 60
    log_activity "Mengubah direktori backup ke: ${new_dir}"
}

# -----------------------------------------------------------------------------
# Fungsi: set_rollback_duration
# Deskripsi: Mengubah durasi rollback
# -----------------------------------------------------------------------------
set_rollback_duration() {
    local current_duration new_duration
    
    current_duration="$ROLLBACK_DURATION"
    
    new_duration=$(whiptail --title "Pengaturan Rollback" --inputbox \
        "Durasi rollback saat ini: ${current_duration} detik\n\nMasukkan durasi rollback baru (detik):" \
        10 60 "$current_duration" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$new_duration" ]] && return
    
    # Validasi
    if ! [[ "$new_duration" =~ ^[0-9]+$ ]] || [[ "$new_duration" -lt 10 ]] || [[ "$new_duration" -gt 300 ]]; then
        whiptail --msgbox "Durasi harus antara 10-300 detik!" 8 50
        return
    fi
    
    # Update konfigurasi
    sed -i "s|^ROLLBACK_DURATION=.*|ROLLBACK_DURATION=${new_duration}|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    ROLLBACK_DURATION="$new_duration"
    
    whiptail --msgbox "Durasi rollback berhasil diubah!\n\n${new_duration} detik" 10 60
    log_activity "Mengubah durasi rollback ke: ${new_duration} detik"
}

# -----------------------------------------------------------------------------
# Fungsi: set_theme
# Deskripsi: Mengubah tema tampilan
# -----------------------------------------------------------------------------
set_theme() {
    local current_theme new_theme
    
    current_theme="$THEME"
    
    new_theme=$(whiptail --title "Pengaturan Tema" --menu \
        "Tema saat ini: ${current_theme}\n\nPilih tema:" \
        14 60 4 \
        "default" "Tema default" \
        "blue" "Tema biru" \
        "green" "Tema hijau" \
        "dark" "Tema gelap" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Update konfigurasi
    sed -i "s|^THEME=.*|THEME=\"${new_theme}\"|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    THEME="$new_theme"
    
    # Apply tema (placeholder - whiptail tidak support tema custom secara native)
    whiptail --msgbox "Tema berhasil diubah ke: ${new_theme^^}\n\n(Catatan: Tema akan diterapkan penuh pada versi berikutnya)" 10 60
    log_activity "Mengubah tema ke: ${new_theme}"
}

# -----------------------------------------------------------------------------
# Fungsi: configure_logging
# Deskripsi: Mengatur konfigurasi logging
# -----------------------------------------------------------------------------
configure_logging() {
    local choice
    
    while true; do
        choice=$(whiptail --title "Konfigurasi Log" --menu \
            "Pengaturan Log:\nLevel: ${LOG_LEVEL} | Status: ${LOG_ENABLED}" \
            14 60 4 \
            "1" "Level Log (DEBUG/INFO/WARNING/ERROR)" \
            "2" "Enable/Disable Log" \
            "3" "Maksimum Ukuran Log (MB)" \
            "4" "Maksimum Jumlah File Log" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) set_log_level ;;
            2) toggle_log ;;
            3) set_log_max_size ;;
            4) set_log_max_files ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: set_log_level
# Deskripsi: Mengubah level log
# -----------------------------------------------------------------------------
set_log_level() {
    local current_level new_level
    
    current_level="$LOG_LEVEL"
    
    new_level=$(whiptail --title "Level Log" --menu \
        "Level log saat ini: ${current_level}\n\nPilih level:" \
        14 60 4 \
        "DEBUG" "Semua pesan" \
        "INFO" "Pesan informasi (rekomendasi)" \
        "WARNING" "Hanya peringatan" \
        "ERROR" "Hanya error" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Update konfigurasi
    sed -i "s|^LOG_LEVEL=.*|LOG_LEVEL=\"${new_level}\"|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    LOG_LEVEL="$new_level"
    
    whiptail --msgbox "Level log berhasil diubah!\n\nLevel: ${new_level}" 10 60
    log_activity "Mengubah level log ke: ${new_level}"
}

# -----------------------------------------------------------------------------
# Fungsi: toggle_log
# Deskripsi: Enable/disable logging
# -----------------------------------------------------------------------------
toggle_log() {
    local current_status new_status
    
    current_status="$LOG_ENABLED"
    
    if [[ "$current_status" == "true" ]]; then
        new_status="false"
    else
        new_status="true"
    fi
    
    # Update konfigurasi
    sed -i "s|^LOG_ENABLED=.*|LOG_ENABLED=${new_status}|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    LOG_ENABLED="$new_status"
    
    if [[ "$new_status" == "true" ]]; then
        whiptail --msgbox "Logging DI AKTIFKAN." 8 50
        log_activity "Logging diaktifkan"
    else
        whiptail --msgbox "Logging DINONAKTIFKAN." 8 50
        log_activity "Logging dinonaktifkan"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: set_log_max_size
# Deskripsi: Mengubah maksimum ukuran log
# -----------------------------------------------------------------------------
set_log_max_size() {
    local current_size new_size
    
    current_size="$LOG_MAX_SIZE"
    
    new_size=$(whiptail --title "Ukuran Maksimum Log" --inputbox \
        "Ukuran maksimum saat ini: ${current_size} MB\n\nMasukkan ukuran baru (MB):" \
        10 60 "$current_size" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$new_size" ]] && return
    
    # Validasi
    if ! [[ "$new_size" =~ ^[0-9]+$ ]] || [[ "$new_size" -lt 1 ]] || [[ "$new_size" -gt 100 ]]; then
        whiptail --msgbox "Ukuran harus antara 1-100 MB!" 8 50
        return
    fi
    
    # Update konfigurasi
    sed -i "s|^LOG_MAX_SIZE=.*|LOG_MAX_SIZE=${new_size}|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    LOG_MAX_SIZE="$new_size"
    
    whiptail --msgbox "Ukuran maksimum log berhasil diubah!\n\n${new_size} MB" 10 60
    log_activity "Mengubah ukuran maksimum log ke: ${new_size} MB"
}

# -----------------------------------------------------------------------------
# Fungsi: set_log_max_files
# Deskripsi: Mengubah maksimum jumlah file log
# -----------------------------------------------------------------------------
set_log_max_files() {
    local current_files new_files
    
    current_files="$LOG_MAX_FILES"
    
    new_files=$(whiptail --title "Jumlah File Log Maksimum" --inputbox \
        "Jumlah maksimum saat ini: ${current_files}\n\nMasukkan jumlah baru (0 = unlimited):" \
        10 60 "$current_files" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$new_files" ]] && return
    
    # Validasi
    if ! [[ "$new_files" =~ ^[0-9]+$ ]] || [[ "$new_files" -gt 100 ]]; then
        whiptail --msgbox "Jumlah harus antara 0-100!" 8 50
        return
    fi
    
    # Update konfigurasi
    sed -i "s|^LOG_MAX_FILES=.*|LOG_MAX_FILES=${new_files}|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    LOG_MAX_FILES="$new_files"
    
    whiptail --msgbox "Jumlah file log maksimum berhasil diubah!\n\n${new_files}" 10 60
    log_activity "Mengubah jumlah file log maksimum ke: ${new_files}"
}

# -----------------------------------------------------------------------------
# Fungsi: set_default_security_preset
# Deskripsi: Mengubah preset keamanan default
# -----------------------------------------------------------------------------
set_default_security_preset() {
    local current_preset new_preset
    
    current_preset="$SECURITY_PRESET"
    
    new_preset=$(whiptail --title "Preset Keamanan Default" --menu \
        "Preset saat ini: ${current_preset}\n\nPilih preset default:" \
        14 60 3 \
        "basic" "Basic - Proteksi minimal" \
        "standard" "Standard - Rekomendasi" \
        "high" "High - Proteksi maksimum" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Update konfigurasi
    sed -i "s|^SECURITY_PRESET=.*|SECURITY_PRESET=\"${new_preset}\"|" "${CONFIG_DIR}/nft-manager.conf" 2>/dev/null
    
    # Reload variable
    SECURITY_PRESET="$new_preset"
    
    whiptail --msgbox "Preset keamanan default berhasil diubah!\n\nPreset: ${new_preset^^}" 10 60
    log_activity "Mengubah preset keamanan default ke: ${new_preset}"
}

# -----------------------------------------------------------------------------
# Fungsi: view_current_config
# Deskripsi: Menampilkan konfigurasi saat ini
# -----------------------------------------------------------------------------
view_current_config() {
    local config_text=""
    
    config_text+="KONFIGURASI SAAT INI\n"
    config_text+="========================================\n\n"
    
    config_text+="[ Direktori ]\n"
    config_text+="  Backup    : ${BACKUP_DIR}\n"
    config_text+="  Log       : ${LOG_FILE}\n"
    config_text+="  Config    : ${CONFIG_DIR}\n\n"
    
    config_text+="[ Rollback ]\n"
    config_text+="  Durasi    : ${ROLLBACK_DURATION} detik\n"
    config_text+="  Status    : ${ROLLBACK_ENABLED}\n\n"
    
    config_text+="[ Logging ]\n"
    config_text+="  Level     : ${LOG_LEVEL}\n"
    config_text+="  Status    : ${LOG_ENABLED}\n"
    config_text+="  Max Size  : ${LOG_MAX_SIZE} MB\n"
    config_text+="  Max Files : ${LOG_MAX_FILES}\n\n"
    
    config_text+="[ Keamanan ]\n"
    config_text+="  Preset    : ${SECURITY_PRESET}\n"
    config_text+="  SSH Rate  : ${SSH_RATE_LIMIT}\n"
    config_text+="  SYN Rate  : ${SYN_RATE_LIMIT}\n\n"
    
    config_text+="[ Tampilan ]\n"
    config_text+="  Tema      : ${THEME}\n\n"
    
    config_text+="========================================\n"
    
    whiptail --title "Konfigurasi Saat Ini" --msgbox --scrolltext "$config_text" 25 70
}
