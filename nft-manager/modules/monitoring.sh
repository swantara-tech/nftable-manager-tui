#!/usr/bin/env bash
# =============================================================================
# NFT Manager - Module Monitoring
# =============================================================================
# Menampilkan statistik dan monitoring firewall secara real-time
# =============================================================================

# -----------------------------------------------------------------------------
# Fungsi: show_monitoring
# Deskripsi: Menampilkan dashboard monitoring firewall
# -----------------------------------------------------------------------------
show_monitoring() {
    local monitoring_text=""
    
    monitoring_text+="========================================\n"
    monitoring_text+="   MONITORING FIREWALL - REALTIME\n"
    monitoring_text+="========================================\n\n"
    
    # Statistik paket dari ruleset
    monitoring_text+="[ STATISTIK PAKET ]\n"
    
    local rules_output
    rules_output=$(nft list ruleset 2>&1)
    
    if [[ $? -eq 0 && -n "$rules_output" ]]; then
        # Parse counter dari rules
        local packets_accepted packets_dropped packets_rejected bytes_accepted bytes_dropped bytes_rejected
        
        # Hitung berdasarkan kata kunci
        packets_accepted=$(echo "$rules_output" | grep -oP 'packets \K[0-9]+' | awk '{s+=$1} END {print s+0}')
        packets_dropped=$(echo "$rules_output" | grep -B2 "drop" | grep -oP 'packets \K[0-9]+' | awk '{s+=$1} END {print s+0}')
        packets_rejected=$(echo "$rules_output" | grep -B2 "reject" | grep -oP 'packets \K[0-9]+' | awk '{s+=$1} END {print s+0}')
        
        monitoring_text+="  Diterima  : ${packets_accepted:-0} paket\n"
        monitoring_text+="  Ditolak   : ${packets_dropped:-0} paket\n"
        monitoring_text+="  Dibuang   : ${packets_rejected:-0} paket\n"
    else
        monitoring_text+="  Tidak dapat membaca statistik\n"
    fi
    
    monitoring_text+="\n"
    
    # Statistik koneksi aktif
    monitoring_text+="[ KONEKSI AKTIF ]\n"
    
    if [[ -f /proc/net/nf_conntrack ]]; then
        local total_connections
        total_connections=$(wc -l < /proc/net/nf_conntrack 2>/dev/null || echo "0")
        
        local tcp_connections udp_connections
        tcp_connections=$(grep -c "tcp" /proc/net/nf_conntrack 2>/dev/null || echo "0")
        udp_connections=$(grep -c "udp" /proc/net/nf_conntrack 2>/dev/null || echo "0")
        
        monitoring_text+="  Total     : ${total_connections}\n"
        monitoring_text+="  TCP       : ${tcp_connections}\n"
        monitoring_text+="  UDP       : ${udp_connections}\n"
    else
        monitoring_text+="  Conntrack tidak tersedia\n"
    fi
    
    monitoring_text+="\n"
    
    # Top IP berdasarkan koneksi
    monitoring_text+="[ TOP ${MONITOR_TOP_IP_COUNT} IP AKTIF ]\n"
    
    if [[ -f /proc/net/nf_conntrack ]]; then
        local top_ips
        top_ips=$(awk '{print $9}' /proc/net/nf_conntrack 2>/dev/null | \
            grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' | \
            sort | uniq -c | sort -rn | head -n "$MONITOR_TOP_IP_COUNT")
        
        if [[ -n "$top_ips" ]]; then
            monitoring_text+="$top_ips\n"
        else
            monitoring_text+="  Tidak ada data\n"
        fi
    else
        monitoring_text+="  Conntrack tidak tersedia\n"
    fi
    
    monitoring_text+="\n"
    
    # Status service
    monitoring_text+="[ STATUS SERVICE ]\n"
    if systemctl is-active --quiet nftables 2>/dev/null; then
        monitoring_text+="  nftables  : ACTIVE\n"
    else
        monitoring_text+="  nftables  : INACTIVE\n"
    fi
    monitoring_text+="\n"
    
    # Informasi sistem
    monitoring_text+="[ INFORMASI SISTEM ]\n"
    local mem_total mem_used mem_percent
    mem_total=$(free -m | awk '/^Mem:/{print $2}')
    mem_used=$(free -m | awk '/^Mem:/{print $3}')
    mem_percent=$((mem_used * 100 / mem_total))
    
    local load_avg
    load_avg=$(cat /proc/loadavg 2>/dev/null | awk '{print $1", "$2", "$3}')
    
    monitoring_text+="  Memory    : ${mem_used}MB / ${mem_total}MB (${mem_percent}%)\n"
    monitoring_text+="  Load Avg  : ${load_avg}\n"
    monitoring_text+="\n"
    
    monitoring_text+="========================================\n"
    monitoring_text+=" Tekan ENTER untuk kembali\n"
    monitoring_text+="========================================"
    
    whiptail --title "Monitoring Firewall" --msgbox --scrolltext "$monitoring_text" 30 80
    log_activity "Melihat monitoring firewall"
}

# -----------------------------------------------------------------------------
# Fungsi: show_packet_statistics
# Deskripsi: Menampilkan statistik paket detail
# -----------------------------------------------------------------------------
show_packet_statistics() {
    local rules_output
    rules_output=$(nft list ruleset 2>&1)
    
    if [[ $? -ne 0 ]]; then
        whiptail --msgbox "Gagal membaca ruleset!" 8 50
        return
    fi
    
    local stats_text="STATISTIK PAKET DETAIL\n"
    stats_text+="========================================\n\n"
    
    # Ekstrak semua counter
    local counters
    counters=$(echo "$rules_output" | grep -E "packets [0-9]+ bytes [0-9]+")
    
    if [[ -n "$counters" ]]; then
        stats_text+="$counters\n"
    else
        stats_text+="Tidak ada counter yang ditemukan.\n"
    fi
    
    whiptail --title "Statistik Paket" --textbox --scrolltext <(echo "$stats_text") 25 80
}

# -----------------------------------------------------------------------------
# Fungsi: show_active_connections
# Deskripsi: Menampilkan koneksi aktif
# -----------------------------------------------------------------------------
show_active_connections() {
    if [[ ! -f /proc/net/nf_conntrack ]]; then
        whiptail --msgbox "Conntrack tidak tersedia.\nPastikan module nf_conntrack dimuat." 8 60
        return
    fi
    
    local connections
    connections=$(cat /proc/net/nf_conntrack 2>/dev/null | head -n 100)
    
    whiptail --title "Koneksi Aktif (100 pertama)" --textbox --scrolltext \
        <(echo "$connections") 25 90
    
    log_activity "Melihat koneksi aktif"
}

# -----------------------------------------------------------------------------
# Fungsi: watch_monitoring
# Deskripsi: Monitoring real-time dengan auto-refresh
# -----------------------------------------------------------------------------
watch_monitoring() {
    local running=true
    
    while $running; do
        # Clear screen
        clear
        
        echo "========================================"
        echo "   MONITORING REAL-TIME (Auto-refresh)"
        echo "   Tekan Ctrl+C untuk keluar"
        echo "========================================"
        echo ""
        
        # Tampilkan statistik singkat
        local rules_count
        rules_count=$(nft list ruleset 2>/dev/null | grep -c "rule" || echo "0")
        echo "Total Rules: ${rules_count}"
        
        if [[ -f /proc/net/nf_conntrack ]]; then
            local conn_count
            conn_count=$(wc -l < /proc/net/nf_conntrack 2>/dev/null || echo "0")
            echo "Active Connections: ${conn_count}"
        fi
        
        echo ""
        echo "Refresh dalam ${MONITOR_REFRESH_INTERVAL} detik..."
        
        sleep "$MONITOR_REFRESH_INTERVAL"
    done
}
