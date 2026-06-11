#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Dashboard
# =============================================================================
# Menampilkan informasi sistem dan status firewall secara menyeluruh
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: show_dashboard
# Deskripsi: Menampilkan dashboard utama dengan informasi sistem dan firewall
# -----------------------------------------------------------------------------
show_dashboard() {
    local dashboard_text=""
    
    # Header Dashboard
    dashboard_text+="========================================\n"
    dashboard_text+="   NFT MANAGER - DASHBOARD FIREWALL\n"
    dashboard_text+="========================================\n\n"
    
    # Status nftables
    dashboard_text+="[ STATUS NFTables ]\n"
    if command -v nft &>/dev/null; then
        if nft list ruleset &>/dev/null 2>&1; then
            dashboard_text+="  Status    : AKTIF\n"
            dashboard_text+="  Versi     : $(nft --version 2>/dev/null | awk '{print $2}' || 'Tidak diketahui')\n"
        else
            dashboard_text+="  Status    : TIDAK AKTIF\n"
        fi
    else
        dashboard_text+="  Status    : TIDAK TERINSTAL\n"
    fi
    dashboard_text+="\n"
    
    # Status service nftables
    dashboard_text+="[ STATUS SERVICE ]\n"
    if systemctl is-active --quiet nftables 2>/dev/null; then
        dashboard_text+="  Service   : ACTIVE (running)\n"
    else
        dashboard_text+="  Service   : INACTIVE\n"
    fi
    dashboard_text+="\n"
    
    # Statistik tabel, chain, dan rule
    dashboard_text+="[ STATISTIK FIREWALL ]\n"
    local table_count=0
    local chain_count=0
    local rule_count=0
    
    if nft list ruleset &>/dev/null 2>&1; then
        table_count=$(nft list tables 2>/dev/null | wc -l)
        chain_count=$(nft list chains 2>/dev/null | grep -c "chain" || echo "0")
        rule_count=$(nft list ruleset 2>/dev/null | grep -c "^[[:space:]]*rule" || echo "0")
    fi
    
    dashboard_text+="  Tabel     : ${table_count}\n"
    dashboard_text+="  Chain     : ${chain_count}\n"
    dashboard_text+="  Rule      : ${rule_count}\n"
    dashboard_text+="\n"
    
    # Interface aktif
    dashboard_text+="[ INTERFACE AKTIF ]\n"
    local interfaces
    interfaces=$(ip -o link show up 2>/dev/null | awk -F': ' '{print $2}' | grep -v lo | tr '\n' ', ' | sed 's/,$//')
    if [[ -n "$interfaces" ]]; then
        dashboard_text+="  Interface : ${interfaces}\n"
    else
        dashboard_text+="  Interface : Tidak ada\n"
    fi
    dashboard_text+="\n"
    
    # Informasi IP
    dashboard_text+="[ INFORMASI IP ]\n"
    local local_ip
    local_ip=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "Tidak diketahui")
    local public_ip
    public_ip=$(curl -s --connect-timeout 3 --max-time 5 https://api.ipify.org 2>/dev/null || echo "Tidak dapat diakses")
    
    dashboard_text+="  IP Lokal  : ${local_ip}\n"
    dashboard_text+="  IP Publik : ${public_ip}\n"
    dashboard_text+="\n"
    
    # Informasi sistem
    dashboard_text+="[ INFORMASI SISTEM ]\n"
    local hostname_info
    hostname_info=$(hostname 2>/dev/null || echo "Tidak diketahui")
    local kernel_info
    kernel_info=$(uname -r 2>/dev/null || echo "Tidak diketahui")
    local os_info
    os_info=$(cat /etc/os-release 2>/dev/null | grep "PRETTY_NAME" | cut -d'"' -f2 || echo "Tidak diketahui")
    
    dashboard_text+="  Hostname  : ${hostname_info}\n"
    dashboard_text+="  OS        : ${os_info}\n"
    dashboard_text+="  Kernel    : ${kernel_info}\n"
    dashboard_text+="\n"
    
    # Waktu dan uptime
    dashboard_text+="[ WAKTU SISTEM ]\n"
    local current_time
    current_time=$(date '+%d %B %Y, %H:%M:%S' 2>/dev/null || echo "Tidak diketahui")
    local uptime_info
    uptime_info=$(uptime -p 2>/dev/null || echo "Tidak diketahui")
    
    dashboard_text+="  Waktu     : ${current_time}\n"
    dashboard_text+="  Uptime    : ${uptime_info}\n"
    dashboard_text+="\n"
    
    # Ringkasan kebijakan firewall
    dashboard_text+="[ KEBIJAKAN FIREWALL ]\n"
    dashboard_text+="  Input     : ${NFT_POLICY_INPUT^^}\n"
    dashboard_text+="  Forward   : ${NFT_POLICY_FORWARD^^}\n"
    dashboard_text+="  Output    : ${NFT_POLICY_OUTPUT^^}\n"
    dashboard_text+="\n"
    
    dashboard_text+="========================================\n"
    dashboard_text+=" Tekan ENTER untuk kembali ke menu utama\n"
    dashboard_text+="========================================"
    
    whiptail --title "Dashboard NFT Manager" --msgbox --scrolltext "$dashboard_text" 30 80
}

# -----------------------------------------------------------------------------
# Fungsi: get_system_info
# Deskripsi: Mengambil informasi sistem untuk dashboard
# Output: String berisi informasi sistem
# -----------------------------------------------------------------------------
get_system_info() {
    local info=""
    info+="Hostname: $(hostname 2>/dev/null || echo 'N/A')\n"
    info+="OS: $(cat /etc/os-release 2>/dev/null | grep 'PRETTY_NAME' | cut -d'\"' -f2 || echo 'N/A')\n"
    info+="Kernel: $(uname -r 2>/dev/null || echo 'N/A')\n"
    info+="Arch: $(uname -m 2>/dev/null || echo 'N/A')\n"
    echo -e "$info"
}

# -----------------------------------------------------------------------------
# Fungsi: get_firewall_summary
# Deskripsi: Mendapatkan ringkasan status firewall
# Output: String berisi ringkasan firewall
# -----------------------------------------------------------------------------
get_firewall_summary() {
    local summary=""
    
    if nft list ruleset &>/dev/null 2>&1; then
        local tables chains rules
        tables=$(nft list tables 2>/dev/null | wc -l)
        chains=$(nft list chains 2>/dev/null | grep -c "chain" || echo "0")
        rules=$(nft list ruleset 2>/dev/null | grep -c "^[[:space:]]*rule" || echo "0")
        
        summary+="Status: ACTIVE\n"
        summary+="Tables: ${tables}\n"
        summary+="Chains: ${chains}\n"
        summary+="Rules: ${rules}"
    else
        summary+="Status: INACTIVE"
    fi
    
    echo -e "$summary"
}
