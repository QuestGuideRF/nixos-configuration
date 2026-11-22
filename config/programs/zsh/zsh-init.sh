setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
cd() {
  builtin cd $@ &&
  ls
}
qcopy() {
    if ! command -v wl-copy &> /dev/null; then
        echo "Ошибка: «wl-copy» не установлен. Пожалуйста, установите wl-буфер обмена."
        return 1
    fi
    if ! command -v fzf &> /dev/null; then
        echo "Ошибка: «fzf» не установлен. Пожалуйста, установите fzf."
        return 1
    fi
    local PREVIEW_CMD="кот {}"
    if command -v bat &> /dev/null; then
        PREVIEW_CMD="летучая мышь --style=числа --color=всегда {}"
    elif command -v batcat &> /dev/null; then
        PREVIEW_CMD="batcat --style=numbers --color=always {}"
    fi
    local selected_files
    selected_files=$(find . -type f -not -path "*/\.git/*" 2>/dev/null | fzf --multi \
        --layout=reverse \
        --preview="$PREVIEW_CMD" \
        --preview-window=right:60%:wrap \
        --prompt="Выберите файлы > " \
        --header="Используйте клавиши со стрелками для навигации. Нажмите TAB, чтобы выбрать файлы, ENTER, чтобы скопировать в буфер обмена, ESC, чтобы отменить.")
    if [[ -z "$selected_files" ]]; then
        echo "Файлы не выбраны. Вышел из qcopy."
        return 0
    fi
    local temp_file
    temp_file=$(mktemp)
    while IFS= read -r file; do
        local clean_file="${file#./}"
        echo "имя файла: $clean_file" >> "$temp_file"
        echo "содержимое файла:" >> "$temp_file"
        cat "$файл" >> "$temp_file"
        echo -e "\n----------------------------------------\n" >> "$temp_file"
    done <<< "$selected_files"
    cat "$temp_file" | wl-copy
    local file_count=$(echo "$selected_files" | wc -l)
    echo "Успех! Скопировано файлов $file_count в буфер обмена Wayland. Готово для вставки в ваш LLM."
    rm -f "$temp_file"
}
function fetch() {
    local color_file="/tmp/qs_colors.json"
    local config_path="/tmp/qs_fastfetch.jsonc"
    if [ "$color_file" -nt "$config_path" ] || [ ! -f "$config_path" ]; then
        local c_blue=$(grep -E '"синий"\s*:\s*"[^"]+"' "$color_file" 2>/dev/null | cut -d '"' -f 4)
        c_blue=${c_blue:-"#89b4fa"}
        local c_sapphire=$(grep -E '"сапфир"\s*:\s*"[^"]+"' "$color_file" 2>/dev/null | cut -d '"' -f 4)
        c_sapphire=${c_sapphire:-"#74c7ec"}
        local c_teal=$(grep -E '"бирюзовый"\s*:\s*"[^"]+"' "$color_file" 2>/dev/null | cut -d '"' -f 4)
        c_teal=${c_teal:-"#94e2d5"}
        local c_mauve=$(grep -E '"фиолетовый"\s*:\s*"[^"]+"' "$color_file" 2>/dev/null | cut -d '"' -f 4)
        c_mauve=${c_mauve:-"#cba6f7"}
        local c_text=$(grep -E '"текст"\s*:\s*"[^"]+"' "$color_file" 2>/dev/null | cut -d '"' -f 4)
        c_text=${c_text:-"#cdd6f4"}
        local palette_hexes=()
        for col in red peach yellow green sapphire mauve pink; do
            local val=$(grep -E "\"$col\"\s*:\s*\"[^\"]+\"" "$color_file" 2>/dev/null | cut -d '"' -f 4)
            case $col in
                red) val=${val:-"#f38ba8"} ;;
                peach) val=${val:-"#fab387"} ;;
                yellow) val=${val:-"#f9e2af"} ;;
                green) val=${val:-"#a6e3a1"} ;;
                sapphire) val=${val:-"#74c7ec"} ;;
                mauve) val=${val:-"#cba6f7"} ;;
                pink) val=${val:-"#f5c2e7"} ;;
            esac
            palette_hexes+=("$вал")
        done
        local palette_str=""
        for hex in "${palette_hexes[@]}"; do
            hex="${hex//\#/}" # Удалить хеш
            local r=$((16
            local g=$((16
            local b=$((16
            palette_str+="\\\\e[38;2;${r};${g};${b}m● \\\\e[0m"
        done
        cat > "$config_path" <<EOF
{
  "\$схема": "https://github.com/fastfetch-cli/fastfetch/raw/master/doc/json_schema.json",
  "logo": {
    "source": "nixos_small",
    "color": {
      "1": "$c_blue",
      "2": "$c_sapphire"
    },
    "padding": {
      "top": 1,
      "left": 2,
      "right": 3
    }
  },
  "display": {
    "separator": "  ",
    "color": {
      "separator": "$c_text"
    }
  },
  "modules": [
    "break",
    {
      "type": "title",
      "format": "{1}",
      "color": {
        "user": "$c_blue"
      }
    },
    "break",
    {
      "type": "os",
      "key": "ⱄ os ",
      "keyColor": "$c_blue"
    },
    {
      "type": "cpu",
      "key": " процессор",
      "keyColor": "$c_sapphire"
    },
    {
      "type": "memory",
      "key": "Ⱈ баран",
      "keyColor": "$c_teal"
    },
    {
      "type": "shell",
      "key": " ш ",
      "keyColor": "$c_purple"
    },
    "break",
    {
      "type": "command",
      "key": " ",
      "text": "echo -e '$palette_str'"
    }
  ]
}
EOF
    fi
    fastfetch -c "$config_path"
}
pasteimg() {
    local name="${1:-clipboard.png}"
    [[ "$имя" != *.png ]] && name="$name.png"
    wl-paste --type image/png | sudo tee "$имя" > /dev/null
}
stsetup() {
    local proj_dir="$HOME/Проекты/стюарт-новый"
    if [[ ! -d "$proj_dir" ]]; then
        echo "Каталог $proj_dir не существует."
        return 1
    fi
    cd "$proj_dir" || return 1
    kitty --directory "$proj_dir" nix develop --command zsh -ic "псевдоним run='python main.py'; исполнительный зш" &
    sleep 0.5
    hyprctl dispatch splitratio -0.5
    nix develop --command zsh -ic "редактировать; исполнительный зш"
}
fetch