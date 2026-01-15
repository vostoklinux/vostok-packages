#!/bin/bash
# Генерация обоев для KDE Plasma

# Проверяем наличие ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Установите ImageMagick: xbps-install -S ImageMagick"
    exit 1
fi

# Создаем различные размеры обоев
SIZES="3840x2160 2560x1440 1920x1080 1366x768 1280x720"
OUTPUT_DIR="wallpapers"

mkdir -p "$OUTPUT_DIR"

for size in $SIZES; do
    echo "Генерация обоев размера $size..."
    convert -size "$size" gradient:#2563eb-#7c3aed \
            -fill white -pointsize $(( ${size%%x*} / 25 )) -gravity center \
            -draw "text 0,0 'Vostok Linux'" \
            -fill white -pointsize $(( ${size%%x*} / 50 )) -gravity center \
            -draw "text 0,$(( ${size%%x*} / 20 )) 'KDE Plasma Edition'" \
            "$OUTPUT_DIR/vostok-$size.png"
done

echo "Обои сгенерированы в папке $OUTPUT_DIR"
