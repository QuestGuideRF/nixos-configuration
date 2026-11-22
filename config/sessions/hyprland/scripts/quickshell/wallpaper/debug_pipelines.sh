#!/usr/bin/env bash
MASTER_LOG="/tmp/ddg_pipeline_master_debug.log"
> "$MASTER_LOG"
exec > >(tee -a "$MASTER_LOG") 2>&1
echo "======================================================================"
echo "  [СТАРТ] ДИАГНОСТИЧЕСКИЙ ЗАПУСК ТРУБОПРОВОДА DDG"
echo "  Время: $(дата)"
echo "======================================================================"
SCRIPT_DIR="$(имя каталога "$(realpath "$0")")"
PY_SCRIPT="$SCRIPT_DIR/get_ddg_links.py"
SH_SCRIPT="$SCRIPT_DIR/ddg_search.sh"
CACHE_DIR="$HOME/.cache/wallpaper_picker"
SEARCH_DIR="$CACHE_DIR/search_thumbs"
MAP_FILE="$CACHE_DIR/search_map.txt"
CONTROL_FILE="/tmp/ddg_search_control"
PY_LOG="/tmp/qs_python_scraper.log"
SH_LOG="/tmp/qs_ddg_downloader.log"
TEST_QUERY="тест отладки характер"
echo -e "\n--- ЭТАП 1: ПРОВЕРКА СИСТЕМЫ И ЗАВИСИМОСТЕЙ ---"
commands=("python3" "curl" "bash")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" >/dev/null 2>&1; then
        echo "[ОК] Найдена команда: $cmd ($(команда -v "$cmd"))"
    else
        echo "[FAIL] Отсутствует необходимая команда: $cmd"
        exit 1
    fi
done
if curl -s -I "https://duckduckgo.com" > /dev/null; then
    echo "[OK] Интернет-соединение с сайтомuckduckgo.com проверено."
else
    echo "[FAIL] Невозможно связаться сuckduckgo.com. Проблема с сетью?"
fi
if [ -f "$PY_SCRIPT" ]; then
    echo "[ОК] Скрипт Python найден в $PY_SCRIPT."
    [ -x "$PY_SCRIPT" ] || chmod +x "$PY_SCRIPT"
else
    echo "[FAIL] Скрипт Python не найден в $PY_SCRIPT"
    exit 1
fi
if [ -f "$SH_SCRIPT" ]; then
    echo "[ОК] Скрипт Bash найден в $SH_SCRIPT."
    [ -x "$SH_SCRIPT" ] || chmod +x "$SH_SCRIPT"
else
    echo "[FAIL] Сценарий Bash не найден в $SH_SCRIPT"
    exit 1
fi
echo -e "\n--- ЭТАП 2: ОЧИСТКА ОКРУЖАЮЩЕЙ СРЕДЫ ---"
echo "Очистка старого кэша и журналов для обеспечения нового теста..."
rm -rf "$SEARCH_DIR"
rm -f "$MAP_FILE" "$CONTROL_FILE" "$PY_LOG" "$SH_LOG"
echo "[ОК] Старые файлы удалены."
echo "run" > "$CONTROL_FILE"
echo "[ОК] Управляющий файл инициализирован с помощью команды «Выполнить»."
echo -e "\n--- ЭТАП 3: ИСПЫТАНИЕ ИЗОЛИРОВАННОГО СКРЕБКА PYTHON ---"
echo "Запуск get_ddg_links.py напрямую с запросом: '$TEST_QUERY'..."
echo "Получение только первых трех результатов для проверки формата стандартного вывода..."
PY_OUTPUT=$(timeout 15s python3 "$PY_SCRIPT" "$TEST_QUERY" | head -n 3)
PY_EXIT=$?
if [ $PY_EXIT -eq 124 ]; then
    echo "[ВНИМАНИЕ] Тайм-аут скрипта Python истек через 15 секунд."
elif [ -n "$PY_OUTPUT" ]; then
    echo "[ОК] Скрипт Python сгенерировал выходные данные:"
    echo "$PY_OUTPUT" | while read -r line; do
        echo "  -> $строка"
    done
else
    echo "[FAIL] Скрипт Python не вернул стандартный вывод."
fi
echo -e "\n--- ЭТАП 4: ПОЛНОЕ ИНТЕГРАЦИОННОЕ ТЕСТИРОВАНИЕ ---"
echo "Запуск ddg_search.sh в фоновом режиме..."
rm -f "$CONTROL_FILE"; echo "run" > "$CONTROL_FILE"
"$SH_SCRIPT" "$TEST_QUERY" &
SH_PID=$!
echo "[ИНФО] Скрипт Bash запущен с PID: $SH_PID"
echo "Ожидание 10 секунд, чтобы разрешить загрузку..."
sleep 10
echo "pause" > "$CONTROL_FILE"
echo "[ИНФО] Отправлен сигнал «пауза» через управляющий файл. Ожидание 3 секунды..."
sleep 3
echo "stop" > "$CONTROL_FILE"
echo "[ИНФО] Отправлен сигнал «стоп» через управляющий файл. Ожидание завершения процесса..."
wait $SH_PID 2>/dev/null
echo "[OK] Конвейерный процесс ($SH_PID) завершен."
echo -e "\n--- ЭТАП 5: СПРАВОЧНИК И АНАЛИЗ ВЫХОДНЫХ ПРОДУКТОВ ---"
echo "Проверка выходных каталогов..."
if [ -d "$SEARCH_DIR" ]; then
    FILE_COUNT=$(find "$SEARCH_DIR" -maxdepth 1 -type f | wc -l)
    echo "[OK] Каталог кэша существует: $SEARCH_DIR"
    echo "[INFO] Скачано изображений: $FILE_COUNT."
    ls -lh "$SEARCH_DIR" | awk '{print "  -> " $9, $5}' | grep -v "^\s*->\s*$"
else
    echo "[FAIL] Каталог кэша не создан: $SEARCH_DIR"
fi
echo "Проверка файла карты ($MAP_FILE)..."
if [ -f "$MAP_FILE" ]; then
    LINE_COUNT=$(wc -l < "$MAP_FILE")
    echo "[ОК] Файл карты существует. Содержит $LINE_COUNT записей."
    head -n 5 "$MAP_FILE" | awk '{print "  -> " $0}'
else
    echo "[FAIL] Файл карты не существует."
fi
echo -e "\n--- ЭТАП 6: ПОЛНЫЙ ДАМП ЖУРНАЛА ---"
echo ">>> СБРОС ЖУРНАЛА PYTHON: $PY_LOG <<<"
if [ -f "$PY_LOG" ]; then
    cat "$PY_LOG"
else
    echo "[ФАЙЛ ЖУРНАЛА НЕ НАЙДЕН В $PY_LOG]"
fi
echo ">>> КОНЕЦ ЖУРНАЛА PYTHON <<<"
echo ""
echo ">>> СБРОС ЖУРНАЛА BASH: $SH_LOG <<<"
if [ -f "$SH_LOG" ]; then
    cat "$SH_LOG"
else
    echo "[ФАЙЛ ЖУРНАЛА НЕ НАЙДЕН В $SH_LOG]"
fi
echo ">>> КОНЕЦ ЖУРНАЛА BASH <<<"
echo "======================================================================"
echo "  [ФИНИШ] ДИАГНОСТИЧЕСКИЙ ПРОПУСК ЗАВЕРШЕН"
echo "  Весь вывод сохранен в: $MASTER_LOG."
echo "======================================================================"