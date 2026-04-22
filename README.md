# Happ VPN Auto-Switch

## Описание

Решение для автоматического переключения proxy‑client Happ в зависимости от его доступности и состояния.

**По умолчанию:** Happ работает в режиме **включён**, но при падении или отсутствии соединения необходимо переключить в **выключен**, с запасом в 7 минут перед переключением, и 2‑минутной проверкой восстановления перед возвратом.

## Структура проекта

```
happvpn/
├── README.md               # Этот файл
├── QUICKSTART.md           # Быстрый старт
├── STATE.yaml              # Текущее состояние (auto‑switch logic)
├── scripts/
│   ├── happ-monitor.sh     # Мониторинг состояния Happ
│   └── happ-proxy-manager.sh # Управление прокси (on/off/status)
└── systemd/
    └── happ-monitor.service   # systemd юнит для автоматизации
```

## Ключевые особенности

- ✅ Автоматический мониторинг (каждые 60 сек) доступности Happ.
- ✅ Задержка 7 минут при потере до переключения в OFF.
- ✅ 2‑минутная проверка стабильности перед возвратом в ON.
- ✅ Управление через systemd EnvironmentFile.
- ✅ Автоматический rollback при ошибках.
- ✅ Подробное логирование.
- ✅ Поддержка Linux (DEB/RPM) и возможность упаковки.

## Быстрый старт (Linux)

### Установка

```bash
# Скачиваем последнюю версию
wget https://github.com/Happ-proxy/happ-desktop/releases/latest/download/Happ.linux.x64.deb -O happ.deb
sudo dpkg -i happ.deb
# либо rpm: sudo rpm -i Happ.linux.x64.rpm

# Скачиваем скрипты
mkdir -p ~/.local/bin
cp /home/ironman/.openclaw/projects/happvpn/scripts/happ-proxy-manager.sh ~/.local/bin/
cp /home/ironman/.openclaw/projects/happvpn/scripts/happ-monitor.sh ~/.local/bin/
chmod +x ~/.local/bin/happ-proxy-manager.sh ~/.local/bin/happ-monitor.sh
```

### Запуск мониторинга

```bash
systemctl --user start happ-monitor
systemctl --user enable happ-monitor
systemctl --user status happ-monitor
```

### Управление прокси

```bash
# Включить proxy
~/.local/bin/happ-proxy-manager.sh on

# Выключить proxy
~/.local/bin/happ-proxy-manager.sh off

# Показать статус
~/.local/bin/happ-proxy-manager.sh status
```

## Логи

- `~/.local/share/happvpn/happ-monitor.log`
- `~/.local/share/happvpn/happ-proxy-manager.log`

## Диагностика

Для проверки состояния:

```bash
cat ~/.local/share/happvpn/state.yaml
# или
systemctl --user status happ-monitor
```

## Контакты

При проблемах смотрите логи и выполните `systemctl --user status happ-monitor`.
