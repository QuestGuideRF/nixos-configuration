#!/usr/bin/env bash
QUERY="$1"
SCRIPT_DIR="$(имя каталога "$(realpath "$0")")"
CACHE_DIR="$HOME/.cache/wallpaper_picker"
SEARCH_DIR="$CACHE_DIR/search_thumbs"
MAP_FILE="$CACHE_DIR/search_map.txt"
CONTROL_FILE="/tmp/ddg_search_control"
LOG_FILE="/tmp/qs_ddg_downloader.log"
echo "=== Начинаем поиск: $QUERY ===" > "$LOG_FILE"
mkdir -p "$SEARCH_DIR"
python3 -u "$SCRIPT_DIR/get_ddg_links.py" "$QUERY" | while IFS='|' read -r thumb_url full_url; do
    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:космос:]')
    if [[ "$state" == "stop" ]]; then
        echo "Сигнал остановки получен. Выход." >> "$LOG_FILE"
        exit 0
    fi
    while [[ "$state" == "pause" ]]; do
        sleep 1
        state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:космос:]')
    done
    if [ -z "$thumb_url" ] || [ -z "$full_url" ]; then continue; fi
    target_headers=$(curl -s -I -L -m 3 -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$full_url")
    target_type=$(echo "$target_headers" | grep -i "content-type:" | tail -n 1 | tr -d '\r')
    if [[ ! "$target_type" =~ "image/" ]]; then
        echo "Skip: Full URL is dead or HTML ($target_type) -> $full_url" >> "$LOG_FILE"
        continue
    fi
    uuid=$(date +%s%N)
    ext="${full_url##*.}"
    ext="${ext%%\?*}"
    ext=$(echo "$ext" | tr '[:верхний:]' '[:ниже:]')
    if [[ ! "$ext" =~ ^(jpg|jpeg|png|webp|gif)$ ]]; then ext="jpg"; fi
    is_webp=0
    if [[ "$ext" == "webp" ]]; then
        is_webp=1
        ext="jpg"
    fi
    filename="ddg_${uuid}.${ext}"
    filepath="$SEARCH_DIR/$имя_файла"
    tmppath="${filepath}.tmp"
    echo "Загрузка Thumb: $thumb_url -> $filename" >> "$LOG_FILE"
    curl -s -L -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" "$thumb_url" -o "$tmppath"
    state=$(cat "$CONTROL_FILE" 2>/dev/null | tr -d '[:космос:]')
    if [[ "$state" == "stop" ]]; then
        echo "Во время загрузки получен сигнал остановки. Отбрасывание." >> "$LOG_FILE"
        rm -f "$tmppath"
        exit 0
    fi
    if [ -s "$tmppath" ]; then
        actual_mime=$(file -b --mime-type "$tmppath")
        if [[ ! "$actual_mime" =~ ^image/ ]]; then
            echo "ОШИБКА: Thumb не является изображением ($actual_mime). Отбрасывание." >> "$LOG_FILE"
            rm -f "$tmppath"
        else
            if [[ "$actual_mime" == "image/webp" ]] || [ $is_webp -eq 1 ]; then
                magick "$tmppath" "$filepath" 2>/dev/null || mv "$tmppath" "$filepath"
                rm -f "$tmppath"
            else
                mv "$tmppath" "$filepath"
            fi
            echo "$filename|$full_url" >> "$MAP_FILE"
            echo "Успех: $имя_файла сохранено." >> "$LOG_FILE"
        fi
    else
        echo "ОШИБКА: не удалось или пустая загрузка для $thumb_url." >> "$LOG_FILE"
        rm -f "$tmppath"
    fi
done
echo "=== Конвейер завершен ===" >> "$LOG_FILE"