#!/usr/bin/env bash
if pgrep -x "rofi" > /dev/null; then
    pkill rofi
else
    cliphist list | rofi -dmenu \
    -p "Clipboard" \
    -config ~/.config/rofi/config.rasi \
    -theme-str 'просмотр списка { columns: 1; spacing: 0px; }' \
    -theme-str 'элемент { orientation: horizontal; children: [ element-text ]; padding: 10px; }' \
    -theme-str 'элемент-текст { enabled: true; vertical-align: 0.5; horizontal-align: 0.0; margin: 0; text-color: inherit; }' \
    -theme-str 'значок элемента { enabled: false; }' \
    | cliphist decode | wl-copy
fi