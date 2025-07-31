#!/bin/bash

# Tornado - Anonymous IP Rotation Toolkit
# Developed by ZAIN NADEEM

CONTROL_PORT="9051"
TORRC_FILE="/etc/tor/torrc"

# === Ensure Script Runs as Root ===
if [[ $EUID -ne 0 ]]; then
    echo -e "\n\e[1m[!] This script must be run as root.\n\e[0m" | lolcat
    exit 1
fi

# === Banner ===
clear
figlet "TORNADO" | lolcat
echo -e "\e[1mAnonymous IP Rotation Toolkit\e[0m" | lolcat
echo -e "\e[1mDeveloped by ZAIN NADEEM\e[0m" | lolcat
echo -e "\e[1m════════════════════════════════════════════════════\n\e[0m" | lolcat

# === Dependency Check ===
echo -e "\e[1m[↻] Checking dependencies...\e[0m" | lolcat
for pkg in tor curl jq netcat figlet lolcat; do
    if ! command -v "$pkg" > /dev/null 2>&1; then
        echo -e "\e[1m[!] $pkg not found. Installing...\e[0m" | lolcat
        apt install -y "$pkg" > /dev/null 2>&1
    fi
done

# === Start or Restart TOR ===
echo -e "\e[1m[~] Checking TOR service status...\e[0m" | lolcat
if systemctl is-active --quiet tor; then
    echo -e "\e[1m[~] TOR is already running. Restarting...\e[0m" | lolcat
    systemctl restart tor
else
    echo -e "\e[1m[~] Starting TOR service...\e[0m" | lolcat
    systemctl start tor
fi

sleep 3

# === Ensure control port is configured ===
if ! grep -q "ControlPort $CONTROL_PORT" "$TORRC_FILE"; then
    echo "ControlPort $CONTROL_PORT" >> "$TORRC_FILE"
    echo "CookieAuthentication 1" >> "$TORRC_FILE"
    echo "CookieAuthFileGroupReadable 1" >> "$TORRC_FILE"
    echo -e "\e[1m[+] TOR control port configuration updated.\e[0m" | lolcat
    systemctl restart tor
    sleep 3
fi

# === Get User Settings ===
read -p "$(echo -e '\e[1m[?] Enter IP rotation interval (minimum 3s): \e[0m' | lolcat)" interval
if [[ $interval -lt 3 ]]; then
    echo -e "\e[1m[!] Minimum interval is 3 seconds.\e[0m" | lolcat
    interval=3
fi
read -p "$(echo -e '\e[1m[?] Number of rotations (0 = infinite): \e[0m' | lolcat)" rotations

# === IP Info Retrieval ===
last_ip=""

get_ip_info() {
    local ip=$(curl -s --socks5 127.0.0.1:9050 https://api.ipify.org)
    if [[ -z "$ip" ]]; then
        echo -e "\e[1m[!] Failed to retrieve IP. TOR may not be working.\e[0m" | lolcat
        return
    fi
    if [[ "$ip" == "$last_ip" ]]; then
        sleep 2
        ip=$(curl -s --socks5 127.0.0.1:9050 https://api.ipify.org)
    fi
    last_ip="$ip"
    local info=$(curl -s "https://ipinfo.io/${ip}/json")
    local city=$(echo "$info" | jq -r .city)
    local country=$(echo "$info" | jq -r .country)
    local org=$(echo "$info" | jq -r .org)

    echo -e "\n\e[1m═══════════════════════════════════════════════════════════════════════════\e[0m" | lolcat
    echo -e "\e[1;36m[+] IP Changed: $ip | $city, $country | $org\e[0m" | lolcat
    echo -e "\e[1m═══════════════════════════════════════════════════════════════════════════\e[0m" | lolcat
}

# === New Identity Function ===
request_new_identity() {
    echo -e "\e[1m[~] Requesting new identity from TOR...\e[0m" | lolcat
    printf 'AUTHENTICATE\r\nSIGNAL NEWNYM\r\nQUIT\r\n' | nc 127.0.0.1 $CONTROL_PORT > /dev/null 2>&1
    sleep 2
    get_ip_info
}

# === Start Rotation ===
echo -e "\e[1m[*] Launching Tornado...\e[0m" | lolcat
count=0

while true; do
    request_new_identity
    ((count++))
    if [[ $rotations -ne 0 && $count -ge $rotations ]]; then
        echo -e "\e[1m[✓] Completed $rotations rotations. Exiting.\e[0m" | lolcat
        break
    fi
    sleep "$interval"
done
