#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module IPSet Management (Whitelist & Blacklist)
# =============================================================================
# Mengelola whitelist dan blacklist IP menggunakan nft sets
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: manage_ipsets
# Deskripsi: Menu utama untuk manajemen IPSet
# -----------------------------------------------------------------------------
manage_ipsets() {
    local choice
    while true; do
        choice=$(whiptail --title "Whitelist & Blacklist IP" --menu \
            "Pilih operasi yang ingin dilakukan:" \
            16 60 8 \
            "1" "Tambah IP whitelist" \
            "2" "Hapus IP whitelist" \
            "3" "Tambah IP blacklist" \
            "4" "Hapus IP blacklist" \
            "5" "Lihat whitelist" \
            "6" "Lihat blacklist" \
            "7" "Import dari file" \
            "8" "Export ke file" 3>&1 1>&2 2>&3)
        
        [[ $? -ne 0 ]] && return
        
        case "$choice" in
            1) add_to_whitelist ;;
            2) remove_from_whitelist ;;
            3) add_to_blacklist ;;
            4) remove_from_blacklist ;;
            5) view_whitelist ;;
            6) view_blacklist ;;
            7) import_ipset ;;
            8) export_ipset ;;
            *) whiptail --msgbox "Pilihan tidak valid!" 8 40 ;;
        esac
    done
}

# -----------------------------------------------------------------------------
# Fungsi: ensure_sets_exist
# Deskripsi: Memastikan set whitelist dan blacklist sudah ada
# -----------------------------------------------------------------------------
ensure_sets_exist() {
    # Buat set whitelist jika belum ada
    if ! nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} &>/dev/null; then
        nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} { type ipv4_addr\; flags interval\; } 2>/dev/null
        log_activity "Membuat set ${IPSET_WHITELIST_NAME}"
    fi
    
    # Buat set blacklist jika belum ada
    if ! nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} &>/dev/null; then
        nft add set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} { type ipv4_addr\; flags interval\; } 2>/dev/null
        log_activity "Membuat set ${IPSET_BLACKLIST_NAME}"
    fi
    
    # Pastikan rule menggunakan set sudah ada
    if ! nft list chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>/dev/null | grep -q "${IPSET_WHITELIST_NAME}"; then
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ip saddr @${IPSET_WHITELIST_NAME} accept 2>/dev/null
        log_activity "Menambahkan rule whitelist ke chain input"
    fi
    
    if ! nft list chain ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} 2>/dev/null | grep -q "${IPSET_BLACKLIST_NAME}"; then
        nft add rule ${NFT_TABLE} ${NFT_TABLE_NAME} ${NFT_CHAIN_INPUT} ip saddr @${IPSET_BLACKLIST_NAME} drop 2>/dev/null
        log_activity "Menambahkan rule blacklist ke chain input"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: add_to_whitelist
# Deskripsi: Menambahkan IP ke whitelist
# -----------------------------------------------------------------------------
add_to_whitelist() {
    ensure_sets_exist
    
    local ip_input
    
    ip_input=$(whiptail --title "Tambah Whitelist" --inputbox \
        "Masukkan IP atau CIDR yang diizinkan:\nContoh: 192.168.1.100 atau 10.0.0.0/8" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ip_input" ]] && return
    
    # Validasi IP/CIDR
    if ! validate_ip_or_cidr "$ip_input"; then
        whiptail --msgbox "Format IP/CIDR tidak valid!" 8 50
        log_activity "Gagal menambah whitelist ${ip_input}: Format tidak valid"
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan ke set
    if nft add element ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} { ${ip_input} } 2>&1; then
        whiptail --msgbox "IP ${ip_input} berhasil ditambahkan ke whitelist!" 8 50
        log_activity "Menambahkan IP ${ip_input} ke whitelist"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menambahkan IP ke whitelist!\nMungkin IP sudah ada." 8 50
        log_activity "Gagal menambahkan IP ${ip_input} ke whitelist"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: remove_from_whitelist
# Deskripsi: Menghapus IP dari whitelist
# -----------------------------------------------------------------------------
remove_from_whitelist() {
    ensure_sets_exist
    
    local ip_input
    
    # Tampilkan whitelist saat ini
    local current_list
    current_list=$(nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} 2>&1)
    
    ip_input=$(whiptail --title "Hapus Whitelist" --inputbox \
        "Whitelist saat ini:\n${current_list}\n\nMasukkan IP/CIDR yang ingin dihapus:" \
        15 70 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ip_input" ]] && return
    
    # Validasi
    if ! validate_ip_or_cidr "$ip_input"; then
        whiptail --msgbox "Format IP/CIDR tidak valid!" 8 50
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Hapus dari set
    if nft delete element ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} { ${ip_input} } 2>&1; then
        whiptail --msgbox "IP ${ip_input} berhasil dihapus dari whitelist!" 8 50
        log_activity "Menghapus IP ${ip_input} dari whitelist"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menghapus IP dari whitelist!\nMungkin IP tidak ada." 8 50
        log_activity "Gagal menghapus IP ${ip_input} dari whitelist"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: add_to_blacklist
# Deskripsi: Menambahkan IP ke blacklist
# -----------------------------------------------------------------------------
add_to_blacklist() {
    ensure_sets_exist
    
    local ip_input
    
    ip_input=$(whiptail --title "Tambah Blacklist" --inputbox \
        "Masukkan IP atau CIDR yang diblokir:\nContoh: 203.0.113.50 atau 198.51.100.0/24" \
        10 60 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ip_input" ]] && return
    
    # Validasi
    if ! validate_ip_or_cidr "$ip_input"; then
        whiptail --msgbox "Format IP/CIDR tidak valid!" 8 50
        log_activity "Gagal menambah blacklist ${ip_input}: Format tidak valid"
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Tambahkan ke set
    if nft add element ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} { ${ip_input} } 2>&1; then
        whiptail --msgbox "IP ${ip_input} berhasil ditambahkan ke blacklist!" 8 50
        log_activity "Menambahkan IP ${ip_input} ke blacklist"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menambahkan IP ke blacklist!\nMungkin IP sudah ada." 8 50
        log_activity "Gagal menambahkan IP ${ip_input} ke blacklist"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: remove_from_blacklist
# Deskripsi: Menghapus IP dari blacklist
# -----------------------------------------------------------------------------
remove_from_blacklist() {
    ensure_sets_exist
    
    local ip_input
    
    # Tampilkan blacklist saat ini
    local current_list
    current_list=$(nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} 2>&1)
    
    ip_input=$(whiptail --title "Hapus Blacklist" --inputbox \
        "Blacklist saat ini:\n${current_list}\n\nMasukkan IP/CIDR yang ingin dihapus:" \
        15 70 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$ip_input" ]] && return
    
    # Validasi
    if ! validate_ip_or_cidr "$ip_input"; then
        whiptail --msgbox "Format IP/CIDR tidak valid!" 8 50
        return
    fi
    
    # Backup
    create_rollback_point
    
    # Hapus dari set
    if nft delete element ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} { ${ip_input} } 2>&1; then
        whiptail --msgbox "IP ${ip_input} berhasil dihapus dari blacklist!" 8 50
        log_activity "Menghapus IP ${ip_input} dari blacklist"
        confirm_or_rollback
    else
        whiptail --msgbox "Gagal menghapus IP dari blacklist!\nMungkin IP tidak ada." 8 50
        log_activity "Gagal menghapus IP ${ip_input} dari blacklist"
    fi
}

# -----------------------------------------------------------------------------
# Fungsi: view_whitelist
# Deskripsi: Melihat isi whitelist
# -----------------------------------------------------------------------------
view_whitelist() {
    ensure_sets_exist
    
    local whitelist_content
    whitelist_content=$(nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_WHITELIST_NAME} 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca whitelist!" 8 50
        return
    fi
    
    whiptail --title "Daftar Whitelist" --textbox --scrolltext \
        <(echo "$whitelist_content") 20 70
    
    log_activity "Melihat daftar whitelist"
}

# -----------------------------------------------------------------------------
# Fungsi: view_blacklist
# Deskripsi: Melihat isi blacklist
# -----------------------------------------------------------------------------
view_blacklist() {
    ensure_sets_exist
    
    local blacklist_content
    blacklist_content=$(nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${IPSET_BLACKLIST_NAME} 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca blacklist!" 8 50
        return
    fi
    
    whiptail --title "Daftar Blacklist" --textbox --scrolltext \
        <(echo "$blacklist_content") 20 70
    
    log_activity "Melihat daftar blacklist"
}

# -----------------------------------------------------------------------------
# Fungsi: import_ipset
# Deskripsi: Import IP dari file
# -----------------------------------------------------------------------------
import_ipset() {
    ensure_sets_exist
    
    local target_file
    
    # Pilih target
    target_file=$(whiptail --title "Import IP" --menu \
        "Import ke:" \
        12 50 2 \
        "whitelist" "Import ke Whitelist" \
        "blacklist" "Import ke Blacklist" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input file path
    local file_path
    file_path=$(whiptail --title "Import IP" --inputbox \
        "Masukkan path file (satu IP per baris):" \
        10 60 "/tmp/ips.txt" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$file_path" ]] && return
    
    # Cek file ada
    if [[ ! -f "$file_path" ]]; then
        whiptail --msgbox "File tidak ditemukan: ${file_path}" 8 60
        return
    fi
    
    # Backup
    create_rollback_point
    
    local success=0 fail=0 line_count=0
    local set_name
    
    if [[ "$target_file" == "whitelist" ]]; then
        set_name="${IPSET_WHITELIST_NAME}"
    else
        set_name="${IPSET_BLACKLIST_NAME}"
    fi
    
    # Baca file per baris
    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip komentar dan baris kosong
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Trim whitespace
        line=$(echo "$line" | tr -d '[:space:]')
        line_count=$((line_count + 1))
        
        # Validasi
        if ! validate_ip_or_cidr "$line"; then
            fail=$((fail + 1))
            continue
        fi
        
        # Tambahkan ke set
        if nft add element ${NFT_TABLE} ${NFT_TABLE_NAME} ${set_name} { ${line} } 2>/dev/null; then
            success=$((success + 1))
        else
            fail=$((fail + 1))
        fi
    done < "$file_path"
    
    whiptail --msgbox "Import selesai!\n\nTotal: ${line_count}\nBerhasil: ${success}\nGagal: ${fail}" 10 50
    log_activity "Import ${line_count} IP ke ${set_name} dari ${file_path} (berhasil: ${success})"
    confirm_or_rollback
}

# -----------------------------------------------------------------------------
# Fungsi: export_ipset
# Deskripsi: Export IP ke file
# -----------------------------------------------------------------------------
export_ipset() {
    ensure_sets_exist
    
    local source_file
    
    # Pilih source
    source_file=$(whiptail --title "Export IP" --menu \
        "Export dari:" \
        12 50 2 \
        "whitelist" "Export dari Whitelist" \
        "blacklist" "Export dari Blacklist" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    
    # Input file path
    local file_path
    file_path=$(whiptail --title "Export IP" --inputbox \
        "Masukkan path file output:" \
        10 60 "/tmp/exported_ips.txt" 3>&1 1>&2 2>&3)
    
    [[ $? -ne 0 ]] && return
    [[ -z "$file_path" ]] && return
    
    # Ambil data dari set
    local set_name set_content
    if [[ "$source_file" == "whitelist" ]]; then
        set_name="${IPSET_WHITELIST_NAME}"
    else
        set_name="${IPSET_BLACKLIST_NAME}"
    fi
    
    set_content=$(nft list set ${NFT_TABLE} ${NFT_TABLE_NAME} ${set_name} 2>&1)
    
    # Ekstrak IP
    echo "$set_content" | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}(/[0-9]+)?' > "$file_path" 2>/dev/null
    
    local count
    count=$(wc -l < "$file_path")
    
    whiptail --msgbox "Export berhasil!\n${count} IP diekspor ke:\n${file_path}" 10 60
    log_activity "Export ${count} IP dari ${set_name} ke ${file_path}"
}
