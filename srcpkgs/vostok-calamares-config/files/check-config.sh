#!/bin/sh
# Проверка конфигурации Calamares с реальными фото

CONFIG_DIR="/usr/share/calamares"

echo "=== Проверка конфигурации Calamares для Vostok Linux ==="
echo "Директория конфигурации: $CONFIG_DIR"

echo ""
echo "1. Проверка наличия конфигурационных файлов:"
for file in settings.conf branding.conf locale.conf partition.conf users.conf packages.conf; do
    if [ -f "$CONFIG_DIR/$file" ]; then
        echo "   ✓ $file найден"
    else
        echo "   ✗ $file ОТСУТСТВУЕТ!"
    fi
done

echo ""
echo "2. Проверка наличия изображений:"
for img in vostok-logo.png vostok-icon.png vostok-welcome.png; do
    if [ -f "$CONFIG_DIR/$img" ]; then
        # Проверяем размер файла
        size=$(stat -c%s "$CONFIG_DIR/$img" 2>/dev/null || echo "0")
        if [ "$size" -gt 100 ]; then
            echo "   ✓ $img найден (размер: $size байт)"
        else
            echo "   ⚠ $img найден, но очень маленький ($size байт)"
        fi
    else
        echo "   ✗ $img ОТСУТСТВУЕТ!"
    fi
done

echo ""
echo "3. Проверка ссылок в branding.conf:"
if [ -f "$CONFIG_DIR/branding.conf" ]; then
    echo "   Проверка ссылок на изображения:"
    grep -E "productLogo|productIcon|productWelcome" "$CONFIG_DIR/branding.conf" || echo "   Не найдены ссылки на изображения в branding.conf"
    
    echo "   Проверка формата файла (YAML):"
    if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_DIR/branding.conf'))" 2>/dev/null; then
        echo "   ✓ branding.conf - валидный YAML"
    else
        echo "   ✗ branding.conf - ошибка в YAML формате"
    fi
else
    echo "   ✗ branding.conf не найден!"
fi

echo ""
echo "4. Проверка симлинка настроек:"
if [ -L "/etc/calamares/settings.conf" ]; then
    echo "   ✓ /etc/calamares/settings.conf является симлинком"
    if [ -f "$(readlink -f /etc/calamares/settings.conf)" ]; then
        echo "   ✓ Целевой файл существует"
    else
        echo "   ✗ Целевой файл не существует!"
    fi
else
    echo "   ✗ /etc/calamares/settings.conf не является симлинком"
fi

echo ""
echo "5. Общая информация:"
echo "   Всего файлов в $CONFIG_DIR:"
ls -la "$CONFIG_DIR" | wc -l

echo ""
echo "=== Для теста запустите: calamares -d ==="
echo "=== Для запуска установки: sudo calamares ==="
