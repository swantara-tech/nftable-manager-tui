#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Rollback
# =============================================================================
# Mekanisme rollback otomatis untuk keamanan server produksi
# =============================================================================

# Variabel global untuk rollback
ROLLBACK_TEMP_FILE=""

# -----------------------------------------------------------------------------
# Fungsi: create_rollback_point
# Deskripsi: Membuat titik rollback sebelum perubahan
# -----------------------------------------------------------------------------
create_rollback_point() {
    if [[ "$ROLLBACK_ENABLED" != "true" ]]; then
        return 0
    fi
    
    # Buat file temporary untuk menyimpan state saat ini
    ROLLBACK_TEMP_FILE=$(mktemp /tmp/nft-rollback-XXXXXX)
    
    # Simpan ruleset saat ini
    if nft list ruleset > "$ROLLBACK_TEMP_FILE" 2>&1; then
        log_activity "Rollback point dibuat: $(basename "$ROLLBACK_TEMP_FILE")"
        return 0
    else
        log_activity "Gagal membuat rollback point"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: execute_rollback
# Deskripsi: Melakukan rollback ke state sebelumnya
# -----------------------------------------------------------------------------
execute_rollback() {
    if [[ "$ROLLBACK_ENABLED" != "true" ]]; then
        whiptail --msgbox "Rollback dinonaktifkan dalam konfigurasi." 8 50
        return 1
    fi
    
    if [[ -z "$ROLLBACK_TEMP_FILE" || ! -f "$ROLLBACK_TEMP_FILE" ]]; then
        whiptail --msgbox "Tidak ada rollback point yang tersedia!" 8 50
        log_activity "Gagal rollback: Tidak ada rollback point"
        return 1
    fi
    
    # Validasi konfigurasi rollback
    if ! nft -c -f "$ROLLBACK_TEMP_FILE" 2>&1; then
        whiptail --msgbox "VALIDASI ROLLBACK GAGAL!\n\nFile rollback tidak valid." 10 60
        log_activity "Gagal rollback: Validasi file rollback gagal"
        return 1
    fi
    
    # Apply rollback
    if nft -f "$ROLLBACK_TEMP_FILE" 2>&1; then
        whiptail --msgbox "ROLLBACK BERHASIL!\n\nKonfigurasi telah dikembalikan ke state sebelumnya." 10 60
        log_activity "Rollback berhasil dilakukan"
        
        # Cleanup
        rm -f "$ROLLBACK_TEMP_FILE" 2>/dev/null
        ROLLBACK_TEMP_FILE=""
        
        return 0
    else
        whiptail --msgbox "ROLLBACK GAGAL!\n\nTidak dapat mengembalikan konfigurasi." 10 60
        log_activity "Rollback gagal"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: confirm_or_rollback
# Deskripsi: Meminta konfirmasi, jika timeout/tidak = rollback otomatis
# -----------------------------------------------------------------------------
confirm_or_rollback() {
    if [[ "$ROLLBACK_ENABLED" != "true" ]]; then
        return 0
    fi
    
    if [[ -z "$ROLLBACK_TEMP_FILE" || ! -f "$ROLLBACK_TEMP_FILE" ]]; then
        log_activity "Tidak ada rollback point, konfirmasi dilewati"
        return 0
    fi
    
    local confirmation
    confirmation=$(whiptail --title "Konfirmasi Perubahan" --yes-button "Terapkan" --no-button "Rollback" \
        --yesno "Perubahan telah diterapkan.\n\nSimpan perubahan atau rollback?\n\nTimeout: ${ROLLBACK_DURATION} detik" \
        --timeout "$ROLLBACK_DURATION" 12 60 3>&1 1>&2 2>&3)
    
    local exit_code=$?
    
    # Exit code 0 = Yes (Terapkan)
    # Exit code 1 = No (Rollback)
    # Exit code 255 = Timeout (Rollback)
    # Exit code 127 = whiptail tidak ada
    
    if [[ $exit_code -eq 0 ]]; then
        # User memilih Terapkan
        whiptail --msgbox "Perubahan disimpan." 8 40
        log_activity "Perubahan dikonfirmasi dan disimpan"
        
        # Cleanup rollback point
        rm -f "$ROLLBACK_TEMP_FILE" 2>/dev/null
        ROLLBACK_TEMP_FILE=""
        
        return 0
    elif [[ $exit_code -eq 1 ]]; then
        # User memilih Rollback
        whiptail --msgbox "Melakukan rollback..." 5 40
        log_activity "User meminta rollback"
        execute_rollback
        return 0
    elif [[ $exit_code -eq 255 ]]; then
        # Timeout - rollback otomatis
        whiptail --msgbox "TIMEOUT!\n\nTidak ada konfirmasi dalam ${ROLLBACK_DURATION} detik.\nMelakukan rollback otomatis..." 10 60
        log_activity "Timeout konfirmasi (${ROLLBACK_DURATION}s), rollback otomatis"
        execute_rollback
        return 0
    else
        # whiptail tidak tersedia atau error
        log_activity "whiptail error (exit code: $exit_code), melewatkan konfirmasi"
        rm -f "$ROLLBACK_TEMP_FILE" 2>/dev/null
        ROLLBACK_TEMP_FILE=""
        return 0
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: cleanup_rollback
# Deskripsi: Membersihkan file rollback (cleanup)
# -----------------------------------------------------------------------------
cleanup_rollback() {
    if [[ -n "$ROLLBACK_TEMP_FILE" && -f "$ROLLBACK_TEMP_FILE" ]]; then
        rm -f "$ROLLBACK_TEMP_FILE" 2>/dev/null
        log_activity "Cleanup rollback point: $(basename "$ROLLBACK_TEMP_FILE")"
        ROLLBACK_TEMP_FILE=""
    fi
}

# -----------------------------------------------------------------------------
# Trap untuk cleanup saat script exit
# -----------------------------------------------------------------------------
trap cleanup_rollback EXIT
