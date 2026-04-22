# QUICKSTART.md — Быстрый старт happvpn

## Установка за 5 минут

### Шаг 1: Скачивание проекта

```bash
git clone https://github.com/your-username/happvpn.git
cd happvpn
```

### Шаг 2: Проверка зависимостей

```bash
# Проверить наличие Docker
docker --version

# Проверить наличие Happ клиента (включён в репозиторий как Happ.linux.x64.deb)
ls -lh Happ.linux.x64.deb
```

### Шаг 3: Сборка Docker образа

```bash
docker build -t happvpn:latest .
```

### Шаг 4: Запуск контейнера

```bash
docker run -d \
  --name happvpn \
  --restart unless-stopped \
  --cap-add NET_ADMIN \
  -v /var/log/happvpn:/var/log/happvpn \
  -e HAPP_PORT=10808 \
  -e ENABLE_IPTABLES=false \
  happvpn:latest
```

### Шаг 5: Проверка статуса

```bash
# Посмотреть логи
docker logs -f happvpn

# Проверить статус прокси
docker exec happvpn ./scripts/happ-proxy-manager.sh status
```

### Шаг 6: Управление прокси

```bash
# Включить proxy
docker exec happvpn ./scripts/happ-proxy-manager.sh on

# Выключить proxy
docker exec happvpn ./scripts/happ-proxy-manager.sh off

# Проверить статус
docker exec happvpn ./scripts/happ-proxy-manager.sh status
```

---

## Альтернативная установка: systemd (без Docker)

### Шаг 1: Установка Happ клиента

```bash
sudo dpkg -i Happ.linux.x64.deb
```

### Шаг 2: Копирование скриптов

```bash
mkdir -p ~/.local/bin ~/.local/share/happvpn
cp scripts/happ-proxy-manager.sh ~/.local/bin/
cp scripts/happ-monitor.sh ~/.local/bin/
chmod +x ~/.local/bin/happ-proxy-manager.sh ~/.local/bin/happ-monitor.sh
```

### Шаг 3: Установка systemd service

```bash
sudo cp systemd/happ-monitor.service /etc/systemd/system/
sudo systemctl daemon-reload
```

### Шаг 4: Запуск мониторинга

```bash
systemctl --user start happ-monitor
systemctl --user enable happ-monitor
systemctl --user status happ-monitor
```

### Шаг 5: Проверка

```bash
# Посмотреть логи
journalctl --user -u happ-monitor -f

# Проверить статус прокси
~/.local/bin/happ-proxy-manager.sh status
```

---

## Конфигурация

Переменные окружения:

| Переменная | Значение по умолчанию | Описание |
|------------|----------------------|----------|
| `HAPP_PORT` | `10808` | Порт SOCKS5 прокси |
| `HAPP_DIR` | `/opt/happvpn` | Рабочая директория |
| `ENABLE_IPTABLES` | `false` | Включить управление iptables |

Задержки (в скрипте `happ-monitor.sh`):

| Параметр | Значение | Описание |
|----------|----------|----------|
| `DOWN_DELAY` | `420` (7 мин) | Задержка перед переключением в OFF |
| `UP_DELAY` | `120` (2 мин) | Задержка перед переключением в ON |

---

## Диагностика

### Проверка процесса Happ

```bash
docker exec happvpn pgrep -f Happ
# или
pgrep -f Happ
```

### Проверка порта

```bash
docker exec happvpn netstat -tlnp \| grep 10808
# или
ss -tlnp \| grep 10808
```

### Просмотр логов

```bash
# Docker
docker logs --tail 100 happvpn

# systemd
journalctl --user -u happ-monitor --since "1 hour ago"
```

### Проверка состояния

```bash
# Docker
docker exec happvpn cat /opt/happvpn/state.json

# systemd
cat ~/.local/share/happvpn/state.json
```

---

## Troubleshooting

### Проблема: Контейнер не запускается

**Решение:** Проверить права доступа и наличие ключей

```bash
docker exec happvpn ls -la /opt/happvpn/key.txt
docker exec happvpn ls -la /opt/happvpn/config.yaml
```

### Проблема: Happ процесс не найден

**Решение:** Проверить извлечение DEB пакета

```bash
docker exec happvpn ls -la /opt/happvpn/opt/happ/bin/Happ
```

### Проблема: Порт не открывается

**Решение:** Проверить firewall и конфликты портов

```bash
sudo iptables -L -n \| grep 10808
sudo netstat -tlnp \| grep 10808
```

### Проблема: Мониторинг не переключает статус

**Решение:** Проверить логи и таймеры

```bash
docker logs happvpn \| grep -E "turning|delay|exceeded"
cat /opt/happvpn/state.json.down_start
cat /opt/happvpn/state.json.up_start
```

---

## Контакты

При проблемах:
1. Проверить логи (`docker logs` или `journalctl`)
2. Проверить статус (`systemctl --user status happ-monitor`)
3. Создать issue с полным логом и версией системы
