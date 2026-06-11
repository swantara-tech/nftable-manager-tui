#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Port Management
# =============================================================================
# Mengelola port firewall: buka, tutup, batch operations
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_ports
# Deskripsi: Menu utama untuk manajemen port
# -----------------------------------------------------------------------------
manage_ports() {
    local choice
    while true; do
        choice=$(whiptail --title "Kelola Port Firewall" --menu \
            "Pilih operasi yang ingin dilakukan:" \
            15 60 6 \
            "1" "Buka port" \
            "2" "Tutup port" \
            "3" "Buka banyak port sekaligus" \
            "4" "Tutup banyak port sekaligus" \
            "5" "Lihat port yang diizinkan" \
            "6" "Reset semua rule port" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) open_port ;;
            2) close_port ;;
            3) open_ports_batch ;;
            4) close_ports_batch ;;
            5) list_allowed_ports ;;
            6) reset_port_rules ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: open_port
# Deskripsi: Membuka satu port
# -----------------------------------------------------------------------------
open_port() {
    local protocol port action
    
    # Pilih protokol
    protocol=$(whiptail --title "Buka Port" --menu \
        "Pilih protokol:" \
        12 50 2 \
        "tcp" "TCP" \
        "udp" "UDP" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input port
    port=$(whiptail --title "Buka Port" --inputbox \
        "Masukkan nomor port yang ingin dibuka (contoh: 80):" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Validasi port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        whiptail --msgbox "Port tidak valid! Harus angka antara 1-65535." 8 60
        log_activity "Gagal membuka port ${port}: Port tidak valid"
        return
    fi
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Yakin ingin membuka port ${protocol} ${port}?" 8 50; then
        return
    fi
    
    # Backup sebelum apply
    create_rollback_point
    
    # Buka port
    local nft_command="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ${protocol} dport ${port} accept"
    
    if eval "$nft_command" 2>&1; then
        whiptail --msgbox "Port ${protocol} ${port} berhasil dibuka!" 8 50
        log_activity "Membuka port ${protocol} ${port}"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal membuka port ${protocol} ${port}!" 8 50
        log_activity "Gagal membuka port ${protocol} ${port}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: close_port
# Deskripsi: Menutup satu port
# -----------------------------------------------------------------------------
close_port() {
    local protocol port
    
    # Pilih protokol
    protocol=$(whiptail --title "Tutup Port" --menu \
        "Pilih protokol:" \
        12 50 2 \
        "tcp" "TCP" \
        "udp" "UDP" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input port
    port=$(whiptail --title "Tutup Port" --inputbox \
        "Masukkan nomor port yang ingin ditutup (contoh: 80):" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Validasi port
    if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
        whiptail --msgbox "Port tidak valid! Harus angka antara 1-65535." 8 60
        log_activity "Gagal menutup port ${port}: Port tidak valid"
        return
    fi
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Yakin ingin menutup port ${protocol} ${port}?" 8 50; then
        return
    fi
    
    # Backup sebelum apply
    create_rollback_point
    
    # Tutup port
    local nft_command="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ${protocol} dport ${port} drop"
    
    if eval "$nft_command" 2>&1; then
        whiptail --msgbox "Port ${protocol} ${port} berhasil ditutup!" 8 50
        log_activity "Menutup port ${protocol} ${port}"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menutup port ${protocol} ${port}!" 8 50
        log_activity "Gagal menutup port ${protocol} ${port}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: open_ports_batch
# Deskripsi: Membuka banyak port sekaligus
# -----------------------------------------------------------------------------
open_ports_batch() {
    local protocol ports_input port ports_array success_count fail_count
    
    # Pilih protokol
    protocol=$(whiptail --title "Buka Banyak Port" --menu \
        "Pilih protokol:" \
        12 50 2 \
        "tcp" "TCP" \
        "udp" "UDP" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input banyak port
    ports_input=$(whiptail --title "Buka Banyak Port" --inputbox \
        "Masukkan nomor port dipisahkan koma atau spasi\nContoh: 80,443,8080 atau 80 443 8080" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ports_input" ]] && return
    
    # Parse port (ganti koma dengan spasi)
    ports_input="${ports_input//,/ }"
    read -ra ports_array <<< "$ports_input"
    
    success_count=0
    fail_count=0
    
    # Backup sebelum apply
    create_rollback_point
    
    # Proses setiap port
    for port in "${ports_array[@]}"; do
        # Trim whitespace
        port=$(echo "$port" | tr -d '[:space:]')
        
        # Validasi
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            whiptail --msgbox "Port ${port} tidak valid, dilewati." 8 50
            fail_count=$((fail_count + 1))
            continue
        fi
        
        # Buka port
        if nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ${protocol} dport ${port} accept 2>&1; then
            success_count=$((success_count + 1))
            log_activity "Membuka port ${protocol} ${port} (batch)"
        else
            fail_count=$((fail_count + 1))
            log_activity "Gagal membuka port ${protocol} ${port} (batch)"
        fi
    done
    
    # Ringkasan
    whiptail --msgbox "Proses selesai!\n\nBerhasil: ${success_count}\nGagal: ${fail_count}" 10 50
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: close_ports_batch
# Deskripsi: Menutup banyak port sekaligus
# -----------------------------------------------------------------------------
close_ports_batch() {
    local protocol ports_input port ports_array success_count fail_count
    
    # Pilih protokol
    protocol=$(whiptail --title "Tutup Banyak Port" --menu \
        "Pilih protokol:" \
        12 50 2 \
        "tcp" "TCP" \
        "udp" "UDP" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input banyak port
    ports_input=$(whiptail --title "Tutup Banyak Port" --inputbox \
        "Masukkan nomor port dipisahkan koma atau spasi\nContoh: 80,443,8080 atau 80 443 8080" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ports_input" ]] && return
    
    # Parse port
    ports_input="${ports_input//,/ }"
    read -ra ports_array <<< "$ports_input"
    
    success_count=0
    fail_count=0
    
    # Backup sebelum apply
    create_rollback_point
    
    # Proses setiap port
    for port in "${ports_array[@]}"; do
        port=$(echo "$port" | tr -d '[:space:]')
        
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            whiptail --msgbox "Port ${port} tidak valid, dilewati." 8 50
            fail_count=$((fail_count + 1))
            continue
        fi
        
        if nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ${protocol} dport ${port} drop 2>&1; then
            success_count=$((success_count + 1))
            log_activity "Menutup port ${protocol} ${port} (batch)"
        else
            fail_count=$((fail_count + 1))
            log_activity "Gagal menutup port ${protocol} ${port} (batch)"
        fi
    done
    
    whiptail --msgbox "Proses selesai!\n\nBerhasil: ${success_count}\nGagal: ${fail_count}" 10 50
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: list_allowed_ports
# Deskripsi: Menampilkan port yang diizinkan
# -----------------------------------------------------------------------------
list_allowed_ports() {
    local rules_output tcp_ports udp_ports
    
    rules_output=$(nft list chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca rule!" 8 50
        return
    fi
    
    # Ekstrak port TCP yang di-accept
    tcp_ports=$(echo "$rules_output" | grep "tcp dport" | grep "accept" | \
        awk '{for(i=1;i<=NF;i++) if($i=="dport") print $(i+1)}' | sort -n | uniq | tr '\n' ', ' | sed 's/,$//')
    
    # Ekstrak port UDP yang di-accept
    udp_ports=$(echo "$rules_output" | grep "udp dport" | grep "accept" | \
        awk '{for(i=1;i<=NF;i++) if($i=="dport") print $(i+1)}' | sort -n | uniq | tr '\n' ', ' | sed 's/,$//')
    
    local display_text="PORT YANG DIIZINKAN\n"
    display_text+="========================================\n\n"
    display_text+="TCP: ${tcp_ports:-Tidak ada}\n\n"
    display_text+="UDP: ${udp_ports:-Tidak ada}\n\n"
    display_text+="========================================\n"
    
    whiptail --title "Port yang Diizinkan" --msgbox --scrolltext "$display_text" 15 60
    log_activity "Melihat daftar port yang diizinkan"
}

# -----------------------------------------------------------------------------
# Fungsi: reset_port_rules
# Deskripsi: Reset semua rule port
# -----------------------------------------------------------------------------
reset_port_rules() {
    if ! whiptail --title "Konfirmasi Reset" --yesno \
        "Yakin ingin mereset SEMUA rule port?\nTindakan ini tidak dapat dibatalkan tanpa backup!" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Flush chain input
    if nft flush chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>&1; then
        whiptail --msgbox "Semua rule port berhasil direset!" 8 50
        log_activity "Reset semua rule port"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mereset rule port!" 8 50
        log_activity "Gagal mereset rule port"
    fi
}
