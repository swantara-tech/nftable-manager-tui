#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Security
# =============================================================================
# Mengelola proteksi keamanan: anti brute force, flood protection, rate limit
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_security
# Deskripsi: Menu utama untuk manajemen keamanan
# -----------------------------------------------------------------------------
manage_security() {
    local choice
    while true; do
        choice=$(whiptail --title "Keamanan Firewall" --menu \
            "Pilih fitur keamanan yang ingin dikonfigurasi:" \
            16 60 8 \
            "1" "Proteksi SSH Brute Force" \
            "2" "Proteksi SYN Flood" \
            "3" "Proteksi ICMP Flood" \
            "4" "Proteksi UDP Flood" \
            "5" "Rate Limit Koneksi" \
            "6" "Preset Keamanan" \
            "7" "Lihat Rule Keamanan" \
            "8" "Reset Rule Keamanan" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) enable_ssh_protection ;;
            2) enable_syn_flood_protection ;;
            3) enable_icmp_flood_protection ;;
            4) enable_udp_flood_protection ;;
            5) enable_rate_limit ;;
            6) apply_security_preset ;;
            7) view_security_rules ;;
            8) reset_security_rules ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: enable_ssh_protection
# Deskripsi: Mengaktifkan proteksi SSH brute force
# -----------------------------------------------------------------------------
enable_ssh_protection() {
    local port rate_limit
    
    port=$(whiptail --title "Proteksi SSH" --inputbox \
        "Port SSH (default: 22):" \
        10 60 "22" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$port" ]] && port="22"
    
    rate_limit=$(whiptail --title "Proteksi SSH" --inputbox \
        "Rate limit (default: ${SSH_RATE_LIMIT}):\nContoh: 5/minute" \
        12 60 "${SSH_RATE_LIMIT}" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$rate_limit" ]] && rate_limit="${SSH_RATE_LIMIT}"
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Aktifkan proteksi SSH brute force?\n\nPort: ${port}\nRate Limit: ${rate_limit}" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Buat set untuk tracking SSH connections
    if ! nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ssh_bruteforce &>/dev/null; then
        nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ssh_bruteforce { type ipv4_addr\; timeout 60s\; flags dynamic\; } 2>/dev/null
    fi
    
    # Tambahkan rule proteksi SSH
    local rule1="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport ${port} ct state new limit rate ${rate_limit} accept"
    local rule2="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport ${port} ct state new add @ssh_bruteforce { ip saddr } drop"
    
    if eval "$rule1" 2>&1 && eval "$rule2" 2>&1; then
        whiptail --msgbox "Proteksi SSH berhasil diaktifkan!\n\nPort: ${port}\nRate Limit: ${rate_limit}" 10 60
        log_activity "Mengaktifkan proteksi SSH brute force (port ${port}, rate ${rate_limit})"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengaktifkan proteksi SSH!" 8 50
        log_activity "Gagal mengaktifkan proteksi SSH"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: enable_syn_flood_protection
# Deskripsi: Mengaktifkan proteksi SYN flood
# -----------------------------------------------------------------------------
enable_syn_flood_protection() {
    local rate_limit
    
    rate_limit=$(whiptail --title "Proteksi SYN Flood" --inputbox \
        "Rate limit untuk SYN flood (default: ${SYN_RATE_LIMIT}):\nContoh: 10/second" \
        12 60 "${SYN_RATE_LIMIT}" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$rate_limit" ]] && rate_limit="${SYN_RATE_LIMIT}"
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Aktifkan proteksi SYN flood?\n\nRate Limit: ${rate_limit}" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan rule SYN flood protection
    local rule="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp flags syn limit rate ${rate_limit} accept"
    
    if eval "$rule" 2>&1; then
        whiptail --msgbox "Proteksi SYN flood berhasil diaktifkan!\n\nRate Limit: ${rate_limit}" 10 60
        log_activity "Mengaktifkan proteksi SYN flood (rate ${rate_limit})"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengaktifkan proteksi SYN flood!" 8 50
        log_activity "Gagal mengaktifkan proteksi SYN flood"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: enable_icmp_flood_protection
# Deskripsi: Mengaktifkan proteksi ICMP flood
# -----------------------------------------------------------------------------
enable_icmp_flood_protection() {
    local rate_limit
    
    rate_limit=$(whiptail --title "Proteksi ICMP Flood" --inputbox \
        "Rate limit untuk ICMP flood (default: ${ICMP_RATE_LIMIT}):\nContoh: 5/second" \
        12 60 "${ICMP_RATE_LIMIT}" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$rate_limit" ]] && rate_limit="${ICMP_RATE_LIMIT}"
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Aktifkan proteksi ICMP flood?\n\nRate Limit: ${rate_limit}" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan rule ICMP flood protection
    local rule="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} icmp type echo-request limit rate ${rate_limit} accept"
    
    if eval "$rule" 2>&1; then
        whiptail --msgbox "Proteksi ICMP flood berhasil diaktifkan!\n\nRate Limit: ${rate_limit}" 10 60
        log_activity "Mengaktifkan proteksi ICMP flood (rate ${rate_limit})"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengaktifkan proteksi ICMP flood!" 8 50
        log_activity "Gagal mengaktifkan proteksi ICMP flood"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: enable_udp_flood_protection
# Deskripsi: Mengaktifkan proteksi UDP flood
# -----------------------------------------------------------------------------
enable_udp_flood_protection() {
    local rate_limit
    
    rate_limit=$(whiptail --title "Proteksi UDP Flood" --inputbox \
        "Rate limit untuk UDP flood (default: ${UDP_RATE_LIMIT}):\nContoh: 20/second" \
        12 60 "${UDP_RATE_LIMIT}" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$rate_limit" ]] && rate_limit="${UDP_RATE_LIMIT}"
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Aktifkan proteksi UDP flood?\n\nRate Limit: ${rate_limit}" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan rule UDP flood protection
    local rule="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} udp limit rate ${rate_limit} accept"
    
    if eval "$rule" 2>&1; then
        whiptail --msgbox "Proteksi UDP flood berhasil diaktifkan!\n\nRate Limit: ${rate_limit}" 10 60
        log_activity "Mengaktifkan proteksi UDP flood (rate ${rate_limit})"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengaktifkan proteksi UDP flood!" 8 50
        log_activity "Gagal mengaktifkan proteksi UDP flood"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: enable_rate_limit
# Deskripsi: Mengaktifkan rate limit umum
# -----------------------------------------------------------------------------
enable_rate_limit() {
    local protocol port rate_limit
    
    protocol=$(whiptail --title "Rate Limit" --menu \
        "Pilih protokol:" \
        12 50 2 \
        "tcp" "TCP" \
        "udp" "UDP" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    port=$(whiptail --title "Rate Limit" --inputbox \
        "Port yang ingin di-rate-limit:" \
        10 60 "80" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$port" ]] && return
    
    rate_limit=$(whiptail --title "Rate Limit" --inputbox \
        "Rate limit (contoh: 50/second, 100/minute):" \
        10 60 "50/second" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$rate_limit" ]] && return
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Aktifkan rate limit?\n\nProtokol: ${protocol}\nPort: ${port}\nRate: ${rate_limit}" 12 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan rule rate limit
    local rule="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ${protocol} dport ${port} limit rate ${rate_limit} accept"
    
    if eval "$rule" 2>&1; then
        whiptail --msgbox "Rate limit berhasil diaktifkan!\n\n${protocol} port ${port}: ${rate_limit}" 10 60
        log_activity "Mengaktifkan rate limit (${protocol} port ${port}, rate ${rate_limit})"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengaktifkan rate limit!" 8 50
        log_activity "Gagal mengaktifkan rate limit"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: apply_security_preset
# Deskripsi: Menerapkan preset keamanan (Basic, Standard, High)
# -----------------------------------------------------------------------------
apply_security_preset() {
    local preset
    
    preset=$(whiptail --title "Preset Keamanan" --menu \
        "Pilih tingkat keamanan:" \
        14 60 3 \
        "basic" "Dasar - Proteksi minimal" \
        "standard" "Standar - Rekomendasi (default)" \
        "high" "Tinggi - Proteksi maksimum" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi" --yesno \
        "Terapkan preset keamanan: ${preset^^}?\n\nSemua rule keamanan akan dikonfigurasi ulang." 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    case "$preset" in
        basic)
            apply_preset_basic
            ;;
        standard)
            apply_preset_standard
            ;;
        high)
            apply_preset_high
            ;;
    esac
}

# -----------------------------------------------------------------------------
# Fungsi: apply_preset_basic
# Deskripsi: Menerapkan preset keamanan basic
# -----------------------------------------------------------------------------
apply_preset_basic() {
    whiptail --infobox "Menerapkan preset BASIC..." 5 50
    
    # SSH protection only
    nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ssh_bruteforce { type ipv4_addr\; timeout 60s\; flags dynamic\; } 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new limit rate 5/minute accept 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new add @ssh_bruteforce { ip saddr } drop 2>/dev/null
    
    log_activity "Menerapkan preset keamanan: BASIC"
    whiptail --msgbox "Preset BASIC berhasil diterapkan!\n\nFitur:\n- Proteksi SSH Brute Force (5/minute)" 12 60
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: apply_preset_standard
# Deskripsi: Menerapkan preset keamanan standard
# -----------------------------------------------------------------------------
apply_preset_standard() {
    whiptail --infobox "Menerapkan preset STANDARD..." 5 50
    
    # SSH protection
    nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ssh_bruteforce { type ipv4_addr\; timeout 60s\; flags dynamic\; } 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new limit rate 5/minute accept 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new add @ssh_bruteforce { ip saddr } drop 2>/dev/null
    
    # SYN flood protection
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp flags syn limit rate 10/second accept 2>/dev/null
    
    # ICMP flood protection
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} icmp type echo-request limit rate 5/second accept 2>/dev/null
    
    log_activity "Menerapkan preset keamanan: STANDARD"
    whiptail --msgbox "Preset STANDARD berhasil diterapkan!\n\nFitur:\n- Proteksi SSH Brute Force (5/minute)\n- Proteksi SYN Flood (10/second)\n- Proteksi ICMP Flood (5/second)" 14 60
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: apply_preset_high
# Deskripsi: Menerapkan preset keamanan high
# -----------------------------------------------------------------------------
apply_preset_high() {
    whiptail --infobox "Menerapkan preset HIGH..." 5 50
    
    # SSH protection (strict)
    nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ssh_bruteforce { type ipv4_addr\; timeout 120s\; flags dynamic\; } 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new limit rate 3/minute accept 2>/dev/null
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp dport 22 ct state new add @ssh_bruteforce { ip saddr } drop 2>/dev/null
    
    # SYN flood protection (strict)
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} tcp flags syn limit rate 5/second accept 2>/dev/null
    
    # ICMP flood protection (strict)
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} icmp type echo-request limit rate 2/second accept 2>/dev/null
    
    # UDP flood protection
    nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} udp limit rate 20/second accept 2>/dev/null
    
    log_activity "Menerapkan preset keamanan: HIGH"
    whiptail --msgbox "Preset HIGH berhasil diterapkan!\n\nFitur:\n- Proteksi SSH Brute Force (3/minute, timeout 120s)\n- Proteksi SYN Flood (5/second)\n- Proteksi ICMP Flood (2/second)\n- Proteksi UDP Flood (20/second)" 15 60
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: view_security_rules
# Deskripsi: Melihat rule keamanan yang aktif
# -----------------------------------------------------------------------------
view_security_rules() {
    local rules_output security_rules
    
    rules_output=$(nft list chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca ruleset!" 8 50
        return
    fi
    
    # Filter rule keamanan
    security_rules=$(echo "$rules_output" | grep -E "(limit rate|bruteforce|flood)" || echo "Tidak ada rule keamanan yang ditemukan.")
    
    whiptail --title "Rule Keamanan Aktif" --textbox --scrolltext \
        <(echo "$security_rules") 20 80
    
    log_activity "Melihat rule keamanan aktif"
}

# -----------------------------------------------------------------------------
# Fungsi: reset_security_rules
# Deskripsi: Mereset semua rule keamanan
# -----------------------------------------------------------------------------
reset_security_rules() {
    if ! whiptail --title "Konfirmasi Reset" --yesno \
        "Yakin ingin mereset SEMUA rule keamanan?\nTindakan ini akan menghapus proteksi yang aktif!" 10 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Flush chain dan buat ulang dengan policy default
    if nft flush chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>&1; then
        whiptail --msgbox "Semua rule keamanan berhasil direset!" 8 50
        log_activity "Reset semua rule keamanan"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mereset rule keamanan!" 8 50
        log_activity "Gagal mereset rule keamanan"
    fi
}
