#!/bin/bash
# install-vpn.sh — Установка happvpn на сервере
# Запуск: bash install-vpn.sh

set -e

echo "=== Установка happvpn ==="

# Проверка что мы в правильном каталоге
if [ ! -f "Dockerfile" ]; then
    echo "❌ Ошибка: запустите этот скрипт в директории ~/happvpn"
    exit 1
fi

# Шаг 1: Скачать Happ.deb
echo "📥 Скачивание Happ.linux.x64.deb..."
if [ ! -f "Happ.linux.x64.deb" ]; then
    curl -L -o Happ.linux.x64.deb 'https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb'
    if [ ! -f "Happ.linux.x64.deb" ]; then
        echo "❌ Ошибка: не удалось скачать Happ.linux.x64.deb"
        exit 1
    fi
else
    echo "✅ Happ.linux.x64.deb уже существует"
fi

# Проверка размера файла (~71MB)
FILE_SIZE=$(stat -c%s Happ.linux.x64.deb)
if [ "$FILE_SIZE" -lt 50000000 ]; then
    echo "❌ Ошибка: файл слишком маленький ($FILE_SIZE bytes), возможно скачивание не завершилось"
    exit 1
fi
echo "✅ Файл скачан: $FILE_SIZE bytes"

# Шаг 2: Установить зависимости для распаковки
echo "📦 Установка зависимостей..."
sudo apt-get update -qq
sudo apt-get install -y -qq dpkg-deb > /dev/null

# Шаг 3: Распаковать deb пакет
echo "📦 Распаковка Happ.linux.x64.deb..."
if [ -d "extracted" ]; then
    echo "⚠️  Папка extracted уже существует, удаляю..."
    rm -rf extracted
fi

dpkg-deb -x Happ.linux.x64.deb extracted/

if [ ! -f "extracted/opt/happ/bin/happd" ]; then
    echo "❌ Ошибка: не удалось распаковать Happ.linux.x64.deb"
    exit 1
fi

echo "✅ Распаковка завершена"
echo "   Файлы в extracted/:"
du -sh extracted/

# Шаг 4: Проверить что есть key.txt
if [ ! -f "key.txt" ]; then
    echo "❌ Ошибка: файл key.txt не найден"
    echo "   Скопируйте key.txt в эту директорию"
    exit 1
fi

# Шаг 5: Собрать Docker образ
echo "🐳 Сборка Docker образа..."
sudo docker build -t happvpn:latest .

if [ $? -ne 0 ]; then
    echo "❌ Ошибка: не удалось собрать Docker образ"
    exit 1
fi

echo "✅ Docker образ собран: happvpn:latest"

# Шаг 6: Остановить старый контейнер (если есть)
echo "🛑 Остановка старого контейнера vanyavpn (если запущен)..."
if sudo docker ps -q --filter "name=vanyavpn" | grep -q .; then
    sudo docker stop vanyavpn || true
    sudo docker rm vanyavpn || true
    echo "✅ Старый контейнер остановлен"
else
    echo "ℹ️  Старый контейнер не найден"
fi

# Шаг 7: Запустить новый контейнер
echo "🚀 Запуск контейнера happvpn..."
sudo docker run -d \
    --name happvpn \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    -p 10808:10808 \
    -p 10809:10809 \
    -v /var/log/happvpn:/var/log/happvpn \
    -e HAPP_PORT=10808 \
    -e ENABLE_IPTABLES=false \
    happvpn:latest

if [ $? -ne 0 ]; then
    echo "❌ Ошибка: не удалось запустить контейнер"
    exit 1
fi

echo "✅ Контейнер запущен"

# Шаг 8: Проверка запуска
echo "🔍 Проверка запуска..."
sleep 3

# Проверить что контейнер работает
if ! sudo docker ps --filter "name=happvpn" --format "{{.Status}}" | grep -q "Up"; then
    echo "❌ Ошибка: контейнер не работает"
    echo "Логи:"
    sudo docker logs --tail 50 happvpn
    exit 1
fi

# Проверить что порты слушают
if ! sudo netstat -tlnp 2>/dev/null | grep -q "10808" && \
   ! sudo ss -tlnp 2>/dev/null | grep -q "10808"; then
    echo "⚠️  Предупреждение: порт 10808 не слушает"
    echo "Логи:"
    sudo docker logs --tail 50 happvpn
else
    echo "✅ Порт 10808 слушает"
fi

# Шаг 9: Тестирование
echo "🧪 Тестирование VPN..."
if command -v curl &> /dev/null; then
    EXTERNAL_IP=$(curl --socks5-hostname 127.0.0.1:10808 --connect-timeout 10 https://ifconfig.me/ip 2>/dev/null || echo "FAILED")
    if [ "$EXTERNAL_IP" != "FAILED" ] && [ -n "$EXTERNAL_IP" ]; then
        echo "✅ VPN работает! Внешний IP: $EXTERNAL_IP"
    else
        echo "⚠️  Предупреждение: не удалось проверить внешний IP"
        echo "   Возможно curl не настроен или VPN требует времени на подключение"
    fi
else
    echo "ℹ️  curl не установлен, пропуск теста"
fi

echo ""
echo "=== Установка завершена! ==="
echo ""
echo "📊 Статус:"
echo "  Контейнер: happvpn"
echo "  SOCKS5: 127.0.0.1:10808"
echo "  HTTP: 127.0.0.1:10809"
echo "  Логи: sudo docker logs -f happvpn"
echo ""
echo "🔧 Управление:"
echo "  Остановить: sudo docker stop happvpn"
echo "  Запустить: sudo docker start happvpn"
echo "  Перезапустить: sudo docker restart happvpn"
echo "  Логи: sudo docker logs -f happvpn"
echo ""
