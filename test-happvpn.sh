#!/bin/bash
# test-happvpn.sh — Тестовый скрипт для запуска happvpn с новыми настройками
# Порты: 11808 (SOCKS5), 11809 (HTTP) — временно изменены для тестов
# Маршрутизация: .ru/.su домены и IP → direct, остальное → VPN

set -e

# Определяем домашнюю директорию (работает и с sudo и без)
if [ -n "$SUDO_USER" ]; then
    # Запущен с sudo — используем пользователя который вызвал sudo
    HOME_DIR="/home/$SUDO_USER"
else
    # Запущен без sudo — используем текущего пользователя
    HOME_DIR="$HOME"
fi

echo "=== Тест happvpn ==="
echo "Порты: 11808 (SOCKS5), 11809 (HTTP)"
echo "Маршрутизация: .ru/.su → direct, остальное → VPN"
echo "Рабочая директория: $HOME_DIR/happvpn"
echo ""

# 1. Обновить репозиторий
echo "📥 Обновление репозитория..."
cd "$HOME_DIR/happvpn" || { echo "❌ Папка $HOME_DIR/happvpn не найдена"; exit 1; }
git pull origin main || { echo "❌ Ошибка git pull"; exit 1; }

# 2. Остановить и удалить старый контейнер
echo "🛑 Остановка старого контейнера..."
sudo docker stop happvpn || true
sudo docker rm happvpn || true

# 3. Удалить старый образ
echo "🗑️  Удаление старого образа..."
sudo docker rmi happvpn:latest || true

# 4. Пересобрать образ без кэша
echo "🔨 Пересборка образа (--no-cache)..."
sudo docker build --no-cache -t happvpn:latest . || { echo "❌ Ошибка сборки"; exit 1; }

# 5. Запустить новый контейнер
echo "🚀 Запуск контейнера..."
sudo docker run -d \
    --name happvpn \
    --restart unless-stopped \
    --cap-add NET_ADMIN \
    --cap-add NET_RAW \
    -p 11808:11808 \
    -p 11809:11809 \
    -v /var/log/happvpn:/var/log/happvpn \
    -e HAPP_PORT=11808 \
    happvpn:latest || { echo "❌ Ошибка запуска"; exit 1; }

# 6. Проверить статус
echo ""
echo "📊 Статус контейнера:"
sudo docker ps | grep happvpn || { echo "❌ Контейнер не запущен"; exit 1; }

# 7. Показать логи
echo ""
echo "📋 Логи (последние 20 строк):"
sudo docker logs --tail 20 happvpn

echo ""
echo "✅ Готово! Контейнер запущен."
echo "   SOCKS5: localhost:11808"
echo "   HTTP:   localhost:11809"
echo ""
echo "Для мониторинга логов в реальном времени:"
echo "  sudo docker logs -f happvpn"
