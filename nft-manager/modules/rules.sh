#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Rule Management
# =============================================================================
# Mengelola rule nftables: tambah, edit, hapus, cari, aktif/nonaktif
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_rules
# Deskripsi: Menu utama untuk manajemen rule
# -----------------------------------------------------------------------------
manage_rules() {
    local choice
    while true; do
        choice=$(whiptail --title "Kelola Rule Firewall" --menu \
            "Pilih operasi yang ingin dilakukan:" \
            15 60 7 \
            "1" "Lihat seluruh rule" \
            "2" "Tambah rule baru" \
            "3" "Edit rule" \
            "4" "Hapus rule" \
            "5" "Cari rule" \
            "6" "Aktifkan rule" \
            "7" "Nonaktifkan rule" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) list_rules ;;
            2) add_rule ;;
            3) edit_rule ;;
            4) delete_rule ;;
            5) search_rule ;;
            6) enable_rule ;;
            7) disable_rule ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: list_rules
# Deskripsi: Menampilkan seluruh rule yang ada
# -----------------------------------------------------------------------------
list_rules() {
    local rules_output
    rules_output=$(nft list ruleset 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca rule nftables:\n${rules_output}" 10 60
        return 1
    fi
    
    if [[ -z "$rules_output" ]]; then
        whiptail --msgbox "Tidak ada rule yang dikonfigurasi." 8 50
        return 0
    fi
    
    whiptail --title "Daftar Rule Firewall" --textbox --scrolltext <(echo "$rules_output") 25 90
    log_activity "Melihat seluruh rule firewall"
}

# -----------------------------------------------------------------------------
# Fungsi: add_rule
# Deskripsi: Menambahkan rule baru
# -----------------------------------------------------------------------------
add_rule() {
    local chain protocol port action ip_source custom_rule
    
    # Pilih chain
    chain=$(whiptail --title "Tambah Rule" --menu \
        "Pilih chain target:" \
        12 50 4 \
        "input" "Chain Input ( trafic masuk)" \
        "forward" "Chain Forward (trafic diteruskan)" \
        "output" "Chain Output (trafic keluar)" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Pilih protokol
    protocol=$(whiptail --title "Tambah Rule" --menu \
        "Pilih protokol:" \
        12 50 4 \
        "tcp" "TCP" \
        "udp" "UDP" \
        "icmp" "ICMP" \
        "custom" "Custom/Manual" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Jika custom, minta rule lengkap
    if [[ "$protocol" == "custom" ]]; then
        custom_rule=$(whiptail --title "Tambah Rule Custom" --inputbox \
            "Masukkan rule lengkap (contoh: tcp dport 8080 accept):" \
            10 60 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        [[ -z "$custom_rule" ]] && {
            whiptail --msgbox "Rule tidak boleh kosong!" 8 50
            return
        }
        
        # Backup sebelum apply
        create_rollback_point
        
        # Apply rule
        if nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${chain} ${custom_rule} 2>&1; then
            whiptail --msgbox "Rule berhasil ditambahkan!\n\nRule: ${custom_rule}" 10 60
            log_activity "Menambahkan rule custom ke chain ${chain}: ${custom_rule}"
            confirm_or_rollback
        else
            whiptail --msgbox "Gagal menambahkan rule!" 8 50
            log_activity "Gagal menambahkan rule custom ke chain ${chain}"
        fi
        return
    fi
    
    # Untuk protokol non-custom, minta port (kecuali ICMP)
    if [[ "$protocol" != "icmp" ]]; then
        port=$(whiptail --title "Tambah Rule" --inputbox \
            "Masukkan nomor port (contoh: 80, 443, 8080):" \
            10 60 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        # Validasi port
        if ! [[ "$port" =~ ^[0-9]+$ ]] || [[ "$port" -lt 1 ]] || [[ "$port" -gt 65535 ]]; then
            whiptail --msgbox "Port tidak valid! Harus angka antara 1-65535." 8 60
            return
        fi
    fi
    
    # Pilih aksi
    action=$(whiptail --title "Tambah Rule" --menu \
        "Pilih aksi:" \
        12 50 4 \
        "accept" "Izinkan trafic" \
        "drop" "Buang trafic (tanpa respon)" \
        "reject" "Tolak trafic (dengan respon)" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Opsional: IP sumber
    ip_source=$(whiptail --title "Tambah Rule" --inputbox \
        "IP sumber (kosongkan untuk semua IP, atau isi CIDR: 192.168.1.0/24):" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Validasi IP jika diisi
    if [[ -n "$ip_source" ]]; then
        if ! validate_ip_or_cidr "$ip_source"; then
            whiptail --msgbox "Format IP/CIDR tidak valid!" 8 50
            return
        fi
    fi
    
    # Backup sebelum apply
    create_rollback_point
    
    # Bangun command nft
    local nft_command="nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${chain}"
    [[ -n "$ip_source" ]] && nft_command+=" ip saddr ${ip_source}"
    nft_command+=" ${protocol}"
    [[ "$protocol" != "icmp" && -n "$port" ]] && nft_command+=" dport ${port}"
    nft_command+=" ${action}"
    
    # Eksekusi
    if eval "$nft_command" 2>&1; then
        whiptail --msgbox "Rule berhasil ditambahkan!\n\nCommand: ${nft_command}" 10 70
        log_activity "Menambahkan rule: ${nft_command}"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menambahkan rule!" 8 50
        log_activity "Gagal menambahkan rule: ${nft_command}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: edit_rule
# Deskripsi: Mengedit rule yang sudah ada
# -----------------------------------------------------------------------------
edit_rule() {
    local rules_output handle choice new_rule chain
    
    # Tampilkan rule dengan handle
    rules_output=$(nft -a list ruleset 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca rule!" 8 50
        return
    fi
    
    # Minta user memilih handle
    local handle_input
    handle_input=$(whiptail --title "Edit Rule" --inputbox \
        "Masukkan handle rule yang ingin diedit:\n\n${rules_output:0:1000}..." \
        20 80 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$handle_input" ]] && return
    
    # Validasi handle
    if ! [[ "$handle_input" =~ ^[0-9]+$ ]]; then
        whiptail --msgbox "Handle harus berupa angka!" 8 50
        return
    fi
    
    # Pilih chain
    chain=$(whiptail --title "Edit Rule" --menu \
        "Pilih chain:" \
        12 50 3 \
        "input" "Chain Input" \
        "forward" "Chain Forward" \
        "output" "Chain Output" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Rule baru
    new_rule=$(whiptail --title "Edit Rule" --inputbox \
        "Masukkan rule baru (tanpa chain):" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$new_rule" ]] && return
    
    # Backup
    create_rollback_point
    
    # Hapus rule lama dan tambah yang baru
    if nft delete rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${chain} handle ${handle_input} 2>&1 && \
       nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${chain} ${new_rule} 2>&1; then
        whiptail --msgbox "Rule berhasil diedit!" 8 50
        log_activity "Mengedit rule handle ${handle_input} di chain ${chain}: ${new_rule}"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal mengedit rule!" 8 50
        log_activity "Gagal mengedit rule handle ${handle_input}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: delete_rule
# Deskripsi: Menghapus rule
# -----------------------------------------------------------------------------
delete_rule() {
    local rules_output handle chain
    
    # Tampilkan rule dengan handle
    rules_output=$(nft -a list ruleset 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca rule!" 8 50
        return
    fi
    
    # Tampilkan rule untuk referensi
    whiptail --title "Daftar Rule (dengan handle)" --textbox --scrolltext \
        <(echo "$rules_output") 20 80
    
    # Minta handle
    handle=$(whiptail --title "Hapus Rule" --inputbox \
        "Masukkan handle rule yang ingin dihapus:" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$handle" ]] && return
    
    # Validasi
    if ! [[ "$handle" =~ ^[0-9]+$ ]]; then
        whiptail --msgbox "Handle harus berupa angka!" 8 50
        return
    fi
    
    # Pilih chain
    chain=$(whiptail --title "Hapus Rule" --menu \
        "Pilih chain:" \
        12 50 3 \
        "input" "Chain Input" \
        "forward" "Chain Forward" \
        "output" "Chain Output" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Konfirmasi
    if ! whiptail --title "Konfirmasi Hapus" --yesno \
        "Yakin ingin menghapus rule dengan handle ${handle} di chain ${chain}?" 8 60; then
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Hapus
    if nft delete rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${chain} handle ${handle} 2>&1; then
        whiptail --msgbox "Rule berhasil dihapus!" 8 50
        log_activity "Menghapus rule handle ${handle} di chain ${chain}"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menghapus rule!" 8 50
        log_activity "Gagal menghapus rule handle ${handle}"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: search_rule
# Deskripsi: Mencari rule berdasarkan keyword
# -----------------------------------------------------------------------------
search_rule() {
    local keyword rules_output search_result
    
    keyword=$(whiptail --title "Cari Rule" --inputbox \
        "Masukkan kata kunci pencarian (contoh: port, accept, drop, IP):" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$keyword" ]] && return
    
    rules_output=$(nft list ruleset 2>&1)
    search_result=$(echo "$rules_output" | grep -i "$keyword")
    
    if [[ $? -ne 0 || -z "$search_result" ]]; then
        whiptail --msgbox "Tidak ditemukan rule dengan keyword: ${keyword}" 8 60
        return
    fi
    
    whiptail --title "Hasil Pencarian: ${keyword}" --textbox --scrolltext \
        <(echo "$search_result") 20 80
    
    log_activity "Mencari rule dengan keyword: ${keyword}"
}

# -----------------------------------------------------------------------------
# Fungsi: enable_rule
# Deskripsi: Mengaktifkan rule (menambahkan comment)
# -----------------------------------------------------------------------------
enable_rule() {
    whiptail --msgbox "Fitur ini memerlukan konfigurasi comment pada rule.\nGunakan 'Tambah Rule' dengan parameter comment." 10 60
    log_activity "Mencoba mengaktifkan rule"
}

# -----------------------------------------------------------------------------
# Fungsi: disable_rule
# Deskripsi: Menonaktifkan rule (menghapus atau comment)
# -----------------------------------------------------------------------------
disable_rule() {
    whiptail --msgbox "Fitur ini memerlukan konfigurasi comment pada rule.\nGunakan 'Hapus Rule' untuk menghapus rule." 10 60
    log_activity "Mencoba menonaktifkan rule"
}

# -----------------------------------------------------------------------------
# Fungsi: validate_ip_or_cidr
# Deskripsi: Validasi format IP atau CIDR IPv4
# Argumen: $1 = IP atau CIDR yang akan divalidasi
# Return: 0 jika valid, 1 jika tidak valid
# -----------------------------------------------------------------------------
validate_ip_or_cidr() {
    local ip_cidr="$1"
    local ip cidr
    
    # Pisahkan IP dan CIDR
    if [[ "$ip_cidr" == */* ]]; then
        ip="${ip_cidr%/*}"
        cidr="${ip_cidr#*/}"
        
        # Validasi CIDR
        if ! [[ "$cidr" =~ ^[0-9]+$ ]] || [[ "$cidr" -lt 0 ]] || [[ "$cidr" -gt 32 ]]; then
            return 1
        fi
    else
        ip="$ip_cidr"
    fi
    
    # Validasi IP IPv4
    local IFS='.'
    local -a octets
    read -ra octets <<< "$ip"
    
    if [[ ${#octets[@]} -ne 4 ]]; then
        return 1
    fi
    
    for octet in "${octets[@]}"; do
        if ! [[ "$octet" =~ ^[0-9]+$ ]] || [[ "$octet" -lt 0 ]] || [[ "$octet" -gt 255 ]]; then
            return 1
        fi
    done
    
    return 0
}
