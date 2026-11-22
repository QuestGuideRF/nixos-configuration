#!/usr/bin/env bash
cache_dir="$HOME/.cache/quickshell/weather"
json_file="${cache_dir}/weather.json"
view_file="${cache_dir}/view_id"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"
if [ -f "$(имя каталога "$0")/.env" ]; then
    export $(grep -v '^#' "$(имя каталога "$0")/.env" | xargs)
fi
KEY="$OPENWEATHER_KEY"
ID="$OPENWEATHER_CITY_ID"
UNIT="${OPENWEATHER_UNIT:-metric}"
mkdir -p "${cache_dir}"
get_icon() {
    case $1 in
        "50d"|"50n") icon=""; quote="Mist" ;;
        "01d") icon=""; quote="Sunny" ;;
        "01n") icon=""; quote="Clear" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") icon=""; quote="Cloudy" ;;
        "09d"|"09n"|"10d"|"10n") icon=""; quote="Rainy" ;;
        "11d"|"11n") icon=""; quote="Storm" ;;
        "13d"|"13n") icon=""; quote="Snow" ;;
        *) icon=""; quote="Unknown" ;;
    esac
    echo "$значок|$цитата"
}
get_hex() {
    case $1 in
        "50d"|"50n") echo "#84афдб" ;;
        "01d") echo "#f9e2af" ;;
        "01n") echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n") echo "#74c7ec" ;;
        "11d"|"11n") echo "#f9e2af" ;;
        "13d"|"13n") echo "#cdd6f4" ;;
        *) echo "#cdd6f4" ;;
    esac
}
get_data() {
    if [[ -z "$KEY" || "$KEY" == "Skipped" || "$KEY" == "OPENWEATHER_KEY" ]]; then
        final_json="["
        for i in {0..4}; do
            future_date=$(date -d "+$i дней")
            f_day=$(date -d "$future_date" "+%a")
            f_full_day=$(date -d "$future_date" "+%A")
            f_date_num=$(date -d "$future_date" "+%d %b")
            final_json="${final_json} {
                \"id\": \"${i}\",
                \"day\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"date\": \"${f_date_num}\",
                \"max\": \"0.0\",
                \"min\": \"0.0\",
                \"feels_like\": \"0.0\",
                \"wind\": \"0\",
                \"humidity\": \"0\",
                \"pop\": \"0\",
                \"icon\": \"\",
                \"hex\": \"
                \"desc\": \"No API Key\",
                \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"\", \"hex\": \"
            },"
        done
        final_json="${final_json%,}]"
        echo "{ \"прогноз\": ${final_json} }" > "${json_file}"
        return
    fi
    forecast_url="http://api.openweathermap.org/data/2.5/forecast?APPID=${KEY}&id=${ID}&units=${UNIT}"
    raw_api=$(curl -sf "$forecast_url")
    if [ -z "$raw_api" ]; then return; fi
    current_date=$(date +%Y-%m-%d)
    tomorrow_date=$(date -d "tomorrow" +%Y-%m-%d)
    if [ -f "$next_day_cache_file" ]; then
        precache_date=$(cat "$next_day_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$precache_date" == "$current_date" ]; then
            mv "$next_day_cache_file" "$daily_cache_file"
        fi
    fi
    api_today_items=$(echo "$raw_api" | jq -c ".список[] | select(.dt_txt | начинается с(\"$current_date\"))" | jq -s '.')
    if [ -f "$daily_cache_file" ]; then
        cached_date=$(cat "$daily_cache_file" | jq -r '.[0].dt_txt' | cut -d' ' -f1)
        if [ "$cached_date" == "$current_date" ]; then
            merged_today=$(echo "$api_today_items" | jq --slurpfile cache "$daily_cache_file" \
                '($cache[0] + .) | unique_by(.dt) | сортировка_по(.dt)')
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi
    echo "$merged_today" > "$daily_cache_file"
    api_tomorrow_items=$(echo "$raw_api" | jq -c ".список[] | select(.dt_txt | начинается с(\"$tomorrow_date\"))" | jq -s '.')
    echo "$api_tomorrow_items" > "$next_day_cache_file"
    processed_forecast=$(echo "$raw_api" | jq --argjson today "$merged_today" --arg date "$current_date" \
        '.list = ($today + [.list[] | select(.dt_txt | startswith($date) | not)])')
    if [ ! -z "$processed_forecast" ]; then
        dates=$(echo "$processed_forecast" | jq -r '.list[].dt_txt | разделить(" ")[0]' | uniq | head -n 5)
        final_json="["
        counter=0
        for d in $dates; do
            day_data=$(echo "$processed_forecast" | jq "[.список[] | select(.dt_txt | начинается с(\"$d\"))]")
            raw_max=$(echo "$day_data" | jq '[.[].main.temp_max] | Макс')
            f_max_temp=$(printf "%.1f" "$raw_max")
            raw_min=$(echo "$day_data" | jq '[.[].main.temp_min] | мин')
            f_min_temp=$(printf "%.1f" "$raw_min")
            raw_feels=$(echo "$day_data" | jq '[.[].main.feels_like] | Макс')
            f_feels_like=$(printf "%.1f" "$raw_feels")
            f_pop=$(echo "$day_data" | jq '[.[].pop] | Макс')
            f_pop_pct=$(echo "$f_pop * 100" | bc | cut -d. -f1)
            f_wind=$(echo "$day_data" | jq '[.[].скорость ветра] | Макс | круглый')
            f_hum=$(echo "$day_data" | jq '[.[].main.влажность] | добавить / длина | круглый')
            f_code=$(echo "$day_data" | jq -r '.[длина/2 | пол].weather[0].icon')
            f_desc=$(echo "$day_data" | jq -r '.[длина/2 | пол].погода[0].описание' | sed -e "s/\b\(.\)/\u\1/g")
            f_icon_data=$(get_icon "$f_code")
            f_icon=$(echo "$f_icon_data" | cut -d'|' -f1)
            f_hex=$(get_hex "$f_code")
            f_day=$(date -d "$d" "+%a")
            f_full_day=$(date -d "$d" "+%A")
            f_date_num=$(date -d "$d" "+%d %b")
            hourly_json="["
            count_slots=$(echo "$day_data" | jq '. | длина')
            count_slots=$((count_slots-1))
            for i in $(seq 0 1 $count_slots); do
                slot_item=$(echo "$day_data" | jq ".[$i]")
                raw_s_temp=$(echo "$slot_item" | jq ".main.temp")
                s_temp=$(printf "%.1f" "$raw_s_temp")
                s_dt=$(echo "$slot_item" | jq ".dt")
                s_time=$(date -d @$s_dt "+%H:%M")
                s_code=$(echo "$slot_item" | jq -r ".weather[0].icon")
                s_hex=$(get_hex "$s_code")
                s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
                hourly_json="${hourly_json} {\"время\": \"${s_time}\", \"temp\": \"${s_temp}\", \"значок\": \"${s_icon}\", \"шестнадцатеричный\": \"${s_hex}\"},"
            done
            hourly_json="${hourly_json%,}]"
            final_json="${final_json} {
                \"id\": \"${counter}\",
                \"день\": \"${f_day}\",
                \"day_full\": \"${f_full_day}\",
                \"дата\": \"${f_date_num}\",
                \"макс.\": \"${f_max_temp}\",
                \"мин\": \"${f_min_temp}\",
                \"feels_like\": \"${f_feels_like}\",
                \"ветер\": \"${f_wind}\",
                \"влажность\": \"${f_hum}\",
                \"поп\": \"${f_pop_pct}\",
                \"значок\": \"${f_icon}\",
                \"шестнадцатеричный\": \"${f_hex}\",
                \"desc\": \"${f_desc}\",
                «ежечасно»: ${hourly_json}
            },"
            ((counter++))
        done
        final_json="${final_json%,}]"
        echo "{ \"прогноз\": ${final_json} }" > "${json_file}"
    fi
}
if [[ "$1" == "--getdata" ]]; then
    get_data
elif [[ "$1" == "--json" ]]; then
    CACHE_LIMIT=900
    if [ -f "$json_file" ]; then
        file_time=$(stat -c %Y "$json_file")
        current_time=$(date +%s)
        diff=$((current_time - file_time))
        if [ $diff -gt $CACHE_LIMIT ]; then
            get_data &
        fi
        cat "$json_file"
    else
        get_data
        cat "$json_file"
    fi
elif [[ "$1" == "--view-listener" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    tail -F "$view_file"
elif [[ "$1" == "--nav" ]]; then
    if [ ! -f "$view_file" ]; then echo "0" > "$view_file"; fi
    current=$(cat "$view_file")
    direction=$2
    max_idx=4
    if [[ "$направление" == "next" ]]; then
        if [ "$текущий" -lt "$max_idx" ]; then
            new=$((current + 1))
            echo "$новый" > "$view_file"
        fi
    elif [[ "$направление" == "prev" ]]; then
        if [ "$текущий" -gt 0 ]; then
            new=$((current - 1))
            echo "$новый" > "$view_file"
        fi
    fi
elif [[ "$1" == "--icon" ]]; then
    cat "$json_file" | jq -r '.forecast[0].icon'
elif [[ "$1" == "--temp" ]]; then
    t=$(cat "$json_file" | jq -r '.forecast[0].max')
    echo "${t}°С"
elif [[ "$1" == "--hex" ]]; then
    cat "$json_file" | jq -r '.forecast[0].hex'
elif [[ "$1" == "--current-icon" ]]; then
    curr_time=$(date +%H:%M)
    cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | последний) // .forecast[0].hourly[0] | .икона'
elif [[ "$1" == "--current-temp" ]]; then
    curr_time=$(date +%H:%M)
    t=$(cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | последний) // .forecast[0].hourly[0] | .temp')
    echo "${t}°С"
elif [[ "$1" == "--current-hex" ]]; then
    curr_time=$(date +%H:%M)
    cat "$json_file" | jq -r --arg ct "$curr_time" '(.forecast[0].hourly | map(select(.time <= $ct)) | последний) // .forecast[0].hourly[0] | .шестнадцатеричный'
fi