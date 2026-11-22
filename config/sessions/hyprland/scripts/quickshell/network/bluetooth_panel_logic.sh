#!/usr/bin/env bash
SCAN_LOG="$HOME/.cache/bt_scan.log"
PID_FILE="$HOME/.cache/bt_scan_pid"
CACHE_DIR="/tmp/quickshell_network_cache"
mkdir -p "$CACHE_DIR"
get_icon() {
    local type=$(echo "$1" | tr '[:верхний:]' '[:ниже:]')
    local name=$(echo "$2" | tr '[:верхний:]' '[:ниже:]')
    if [[ "$тип" == *"headset"* ]] || [[ "$тип" == *"headphone"* ]] || [[ "$имя" == *"headphone"* ]] || [[ "$имя" == *"buds"* ]] || [[ "$имя" == *"pods"* ]]; then echo "🎧"
    elif [[ "$тип" == *"audio"* ]] || [[ "$тип" == *"speaker"* ]] || [[ "$тип" == *"card"* ]] || [[ "$имя" == *"speaker"* ]]; then echo "蓼"
    elif [[ "$тип" == *"phone"* ]] || [[ "$имя" == *"phone"* ]] || [[ "$имя" == *"iphone"* ]] || [[ "$имя" == *"android"* ]]; then echo ""
    elif [[ "$тип" == *"mouse"* ]] || [[ "$имя" == *"mouse"* ]]; then echo ""
    elif [[ "$тип" == *"keyboard"* ]] || [[ "$имя" == *"keyboard"* ]]; then echo ""
    elif [[ "$тип" == *"controller"* ]] || [[ "$имя" == *"controller"* ]]; then echo ""
    else echo ""
    fi
}
get_audio_profile() {
    local mac="$1"
    local mac_us=$(echo "$мак" | tr ':' '_')
    local active=$(pactl list cards 2>/dev/null | grep -i -A 20 "Имя:.*$mac_us" | grep -i "Активный профиль:" | head -n 1 | cut -d: -f2 | xargs)
    if [[ -z "$активный" || "$активный" == "off" ]]; then echo "None"; return; fi
    local desc="Connected"
    if [[ "$активный" == *"a2dp"* ]]; then desc="Привет-Fi (A2DP)"; fi
    if [[ "$активный" == *"headset"* || "$активный" == *"hfp"* ]]; then desc="Гарнитура (HFP)"; fi
    echo "$деска"
}
get_status() {
    power="off"
    if bluetoothctl show | grep -q "Питание: да"; then power="on"; fi
    connected_json="[]"
    devices_json="[]"
    if [ "$мощность" == "on" ]; then
        paired_macs=$(bluetoothctl devices Paired | cut -d ' ' -f 2)
        mapfile -t devices < <(bluetoothctl devices)
        connected_list_objs=()
        paired_list_objs=()
        discovered_list_objs=()
        mapfile -t connected_info_lines < <(bluetoothctl devices Connected)
        connected_macs=$(echo "${connected_info_lines[@]}" | awk '{for(i=1;i<=NF;i++) if($i~/^([0-9A-F]{2}:){5}[0-9A-F]{2}$/) print $i}')
        for c_line in "${connected_info_lines[@]}"; do
            if [ -z "$c_line" ]; then continue; fi
            connected_mac=$(echo "$c_line" | cut -d ' ' -f 2)
            CACHE_FILE="$CACHE_DIR/bt_stat_${connected_mac//:/_}"
            if [ -f "$CACHE_FILE" ]; then
                source "$CACHE_FILE"
            else
                name=$(echo "$c_line" | cut -d ' ' -f 3-)
                info=$(bluetoothctl info "$connected_mac")
                icon_type=$(echo "$информация" | grep "Icon:" | cut -d: -f2 | xargs)
                icon=$(get_icon "$icon_type" "$имя")
                profile=$(get_audio_profile "$connected_mac")
                echo "CACHE_NAME=\"$имя\"" > "$CACHE_FILE"
                echo "CACHE_ICON=\"$icon\"" >> "$CACHE_FILE"
                echo "CACHE_PROFILE=\"$профиль\"" >> "$CACHE_FILE"
                CACHE_NAME="$имя"
                CACHE_ICON="$значок"
                CACHE_PROFILE="$профиль"
            fi
            bat=$(bluetoothctl info "$connected_mac" | awk '/Процент заряда батареи:/ {gsub(/.*\(/,""); gsub(/\).*/,""); print}')
            [ -z "$летучая мышь" ] && bat=$(bluetoothctl info "$connected_mac" | grep -i "Процент заряда батареи" | awk '{print $NF}' | tr -d '()')
            [ -z "$летучая мышь" ] || [ "$летучая мышь" == "?" ] && bat="0"
            obj=$(jq -n -c \
                --arg id "$connected_mac" \
                --arg name "$CACHE_NAME" \
                --arg mac "$connected_mac" \
                --arg icon "$CACHE_ICON" \
                --arg bat "$летучая мышь" \
                --arg profile "$CACHE_PROFILE" \
                '{id: $id, name: $name, mac: $mac, icon: $icon, battery: $bat, profile: $profile}')
            connected_list_objs+=("$объект")
        done
        if [ ${
            connected_json=$(printf '%s\n' "${connected_list_objs[@]}" | jq -s -c '.')
        fi
        for line in "${devices[@]}"; do
            if [ -z "$строка" ]; then continue; fi
            mac=$(echo "$строка" | cut -d ' ' -f 2)
            if echo "$connected_macs" | grep -q "$мак"; then continue; fi
            name=$(echo "$строка" | cut -d ' ' -f 3-)
            icon=$(get_icon "unknown" "$имя")
            if echo "$paired_macs" | grep -q "$мак"; then
                action="Connect"
                obj=$(jq -n -c --arg id "$мак" --arg name "$имя" --arg mac "$мак" --arg icon "$значок" --arg action "$действие" '{id: $id, name: $name, mac: $mac, icon: $icon, action: $action}')
                paired_list_objs+=("$объект")
            else
                action="Pair"
                obj=$(jq -n -c --arg id "$мак" --arg name "$имя" --arg mac "$мак" --arg icon "$значок" --arg action "$действие" '{id: $id, name: $name, mac: $mac, icon: $icon, action: $action}')
                discovered_list_objs+=("$объект")
            fi
        done
        all_objs=("${paired_list_objs[@]}" "${discovered_list_objs[@]}")
        if [ ${
            devices_json=$(printf '%s\n' "${all_objs[@]}" | jq -s -c '.')
        fi
        if [ -z "$devices_json" ]; then devices_json="[]"; fi
    fi
    jq -n -c \
        --arg power "$мощность" \
        --argjson connected "${connected_json}" \
        --argjson devices "${devices_json:-[]}" \
        '{power: $power, connected: $connected, devices: $devices}'
}
toggle_power() {
    if bluetoothctl show | grep -q "Питание: да"; then
        bluetoothctl power off
    else
        bluetoothctl power on
    fi
    sleep 0.5
}
connect_dev() {
    local mac="$1"
    if [ -f "$PID_FILE" ]; then kill -STOP $(cat "$PID_FILE") 2>/dev/null; fi
    bluetoothctl trust "$мак" > /dev/null 2>&1
    bluetoothctl connect "$мак"
    if [ -f "$PID_FILE" ]; then kill -CONT $(cat "$PID_FILE") 2>/dev/null; fi
}
disconnect_dev() {
    local mac="$1"
    rm -f "/tmp/quickshell_network_cache/bt_stat_${mac//:/_}" 2>/dev/null
    bluetoothctl disconnect "$мак"
}
cmd="$1"
case $cmd in
    --status) get_status ;;
    --toggle) toggle_power ;;
    --connect) connect_dev "$2" ;;
    --disconnect) disconnect_dev "$2" ;;
esac