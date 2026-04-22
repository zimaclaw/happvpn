# CLI API Research Report

**Date:** 2026-04-22  
**Author:** Friday (AI Assistant)  
**Status:** Research Complete — Awaiting User Input

---

## Executive Summary

Исследование CLI API для Happ VPN клиента завершено. Найден локальный демон `happd` с Unix socket интерфейсом для управления. Однако формат API команд не документирован — требуется тестирование.

---

## Key Findings

### 1. Архитектура Happ

```
Happ (GUI) ↔ happd (daemon) ↔ Xray-core
    ↓            ↓              ↓
 Qt6      /tmp/happd.sock   Внутренний движок
```

**Компоненты:**
- **Happ** — GUI приложение на Qt6 (требует libGLX.so.0, не запускается в headless)
- **happd** — локальный демон, управляет Xray-core через Unix socket
- **Xray-core** — фактический VPN движок (подтверждено в `extracted/opt/happ/bin/core/README.md`)

### 2. happd — CLI daemon

**Бинарник:** `extracted/opt/happ/bin/happd`  
**Тип:** ELF 64-bit LSB pie executable, dynamically linked  
**Статус:** not stripped (есть символы для анализа)

**CLI опции:**
```bash
./happd --help

Usage: ./happd [options]
Happ Proxy Client Service

Options:
  -h, --help     Displays help on commandline options.
  --help-all     Displays help, including generic Qt options.
  -v, --version  Displays version information.
```

**Unix socket:**
- **Путь:** `/tmp/happd.sock` (найден через strings analysis)
- **Тип:** QLocalServer (Qt)
- **Лог:** `/var/log/happd.log`

**Найденные функции в бинарнике:**
```
HappDaemon
configureWorker
updateConfig
CommunicationServer
handleClientMessage
onClientConnected
broadcastClientShutdown
```

### 3. Xray-core интеграция

**Доказательства:**
- Файл `extracted/opt/happ/bin/core/README.md` ссылается на Xray-core
- Поддерживаемые протоколы: VLESS, VMess, Trojan, Shadowsocks, Socks
- Формат конфигурации: JSON (`inbounds`, `outbounds`, `routing`, `observatory`)

**Документация Xray:**
- [Official docs](https://xtls.github.io/config/)
- [Observatory API](https://xtls.github.io/config/observatory.html) — для health check серверов

### 4. Формат ключей

**Файл:** `key.txt` (~60 серверов)  
**Формат:** VLESS URL

```
vless://UUID@cdn*-*.vk-cdnvideo.com:8443?type=tcp&path=%2F&security=tls&alpn=h2#Extra
```

**Структура:**
- **Протокол:** VLESS
- **Transport:** TCP
- **Security:** TLS
- **ALPN:** h2
- **Порт:** 8443
- **Домены:** cdn*-*.vk-cdnvideo.com

---

## CLI Management Options

### Вариант 1: Прямая конфигурация Xray

**Преимущества:**
- Полная документация API
- Стандартный JSON формат
- Поддержка observatory (автоматический health check)
- Не зависит от Happ GUI

**Недостатки:**
- Требует написания config.json с нуля
- Теряется интеграция с Happ GUI
- Нужно управлять процессом Xray напрямую

**Пример config.json:**
```json
{
  "inbounds": [{
    "port": 10808,
    "protocol": "socks",
    "settings": {
      "auth": "noauth"
    }
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "cdn1-08.vk-cdnvideo.com",
        "port": 8443,
        "users": [{
          "id": "UUID",
          "encryption": "none"
        }]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {
        "alpn": ["h2"]
      }
    }
  }],
  "observatory": {
    "probeUrl": "https://www.google.com/generate_204",
    "probeInterval": "10s",
    "subjectSelector": ["all"]
  }
}
```

### Вариант 2: Управление через happd socket

**Преимущества:**
- Использует существующую инфраструктуру Happ
- Сохраняет интеграцию с GUI
- Возможно управление через скрипты

**Недостатки:**
- API не документирован
- Требует reverse engineering формата команд
- Зависит от работы happd

**Гипотеза формата команд:**
```bash
# Подключение к сокету
echo '{"action":"list_servers"}' | socat - /tmp/happd.sock

# Переключение сервера
echo '{"action":"switch_server","index":5}' | socat - /tmp/happd.sock

# Проверка статуса
echo '{"action":"status"}' | socat - /tmp/happd.sock
```

**Инструменты для тестирования:**
```bash
# socat (установить)
sudo apt install socat

# nc (netcat)
sudo apt install netcat-openbsd

# python3 (socket module)
python3 -c "import socket; s=socket.socket(socket.AF_UNIX); s.connect('/tmp/happd.sock')"
```

### Вариант 3: Использовать встроенную логику Happ

**Преимущества:**
- Минимальные изменения
- Работает "из коробки"

**Недостатки:**
- Нет контроля над выбором сервера
- Непредсказуемое поведение
- Нет документации

---

## Open Questions (Блокируют дальнейшую работу)

### Q1: Доступ к Happ GUI

**Вопрос:** Есть ли у тебя доступ к Happ GUI на рабочем устройстве?

**Почему важно:** Можно посмотреть:
- Есть ли настройки ротации серверов
- Как Happ читает key.txt (один сервер или все)
- Есть ли встроенная логика выбора сервера

**Действие:** Запустить Happ GUI и исследовать настройки.

---

### Q2: Требования к ротации серверов

**Вопрос:** Нужна ли автоматическая ротация между серверами?

**Варианты:**
1. **Нет ротации** — один сервер до падения, потом переключение на другой
2. **Периодическая ротация** — переключение каждые N часов
3. **По доступности** — всегда использовать самый быстрый/доступный сервер
4. **Round-robin** — последовательное переключение по списку

**Влияние на реализацию:**
- Вариант 1: Простой health check + failover
- Вариант 2: Cron job + скрипт выбора
- Вариант 3: Observatory API Xray + load balancing
- Вариант 4: Скрипт ротации + state tracking

---

### Q3: Тестирование happd socket API

**Вопрос:** Хочешь ли протестировать happd socket API?

**Что нужно:**
1. Запустить happd в контейнере
2. Подключиться к `/tmp/happd.sock`
3. Отправить тестовые команды
4. Проанализировать ответы

**Риски:**
- API может быть бинарным (не JSON)
- Формат команд неизвестен
- Может потребоваться аутентификация

**План тестирования:**
```bash
# 1. Запустить контейнер
docker run -d --name happvpn-test happvpn:latest

# 2. Проверить сокет
docker exec happvpn-test ls -la /tmp/happd.sock

# 3. Отправить тестовую команду
docker exec happvpn-test bash -c 'echo "test" | socat - /tmp/happd.sock'

# 4. Проверить логи
docker exec happvpn-test cat /var/log/happd.log
```

---

### Q4: Приоритет задач

**Вопрос:** Что важнее?

**Варианты:**
1. **Сделать работоспособный VPN** — даже без ротации, главное чтобы работал
2. **Идеальная ротация серверов** — автоматический выбор лучшего сервера
3. **CLI управление** — возможность управлять через скрипты/terminal
4. **Интеграция с Happ GUI** — сохранить совместимость с десктоп приложением

---

## Recommended Next Steps

### Immediate (сегодня)

**Если есть доступ к Happ GUI:**
1. Запустить Happ на рабочем устройстве
2. Добавить серверы из key.txt
3. Проверить есть ли ротация в настройках
4. Скриншоты настроек → документация

**Если нет GUI:**
1. Запустить контейнер в тестовом режиме
2. Проверить создаёт ли happd сокет
3. Попробовать отправить команды через socat
4. Записать результаты

### Short-term (завтра)

1. **Выбрать вариант реализации** на основе ответов на вопросы
2. **Написать скрипт** для выбранного подхода
3. **Протестировать** в изолированной среде
4. **Документировать** API и поведение

### Long-term

1. Добавить метрики (uptime, switch counts, latency)
2. Реализовать алертинг при сбоях
3. Добавить CI/CD для тестирования
4. Создать comprehensive documentation

---

## Technical Appendix

### File Locations

```
happvpn/
├── extracted/opt/happ/bin/
│   ├── Happ              # GUI (Qt6, требует libGLX)
│   ├── happd             # Daemon (Unix socket: /tmp/happd.sock)
│   ├── happ-tcping       # TCP ping utility
│   └── core/README.md    # Xray-core documentation
├── key.txt               # ~60 VLESS server configs
└── scripts/
    ├── happ-monitor.sh   # Мониторинг состояния
    └── happ-proxy-manager.sh # Управление прокси
```

### Strings Analysis Results

**happd (important strings):**
```
HappDaemon
/tmp/%1.sock
/var/log/happd.log
QLocalServer
handleClientMessage
updateConfig
configureWorker
Failed to start communication server
Local socket server started:
```

**Характеристики бинарников:**
```
Happ:        stripped (нет символов)
happd:       not stripped (есть символы)
happ-tcping: not stripped (есть символы)
```

### Xray-core Documentation Links

- [Official docs](https://xtls.github.io/config/)
- [Observatory API](https://xtls.github.io/config/observatory.html)
- [GitHub repo](https://github.com/XTLS/Xray-core)
- [Examples](https://github.com/XTLS/Xray-examples)

---

## Conclusion

Исследование показало что Happ имеет CLI интерфейс через Unix socket, но API не документирован. Два основных пути:
1. **Использовать Xray-core напрямую** — полностью документировано, но требует переписывания конфигурации
2. **Reverse engineer happd API** — сохраняет интеграцию с Happ, но требует тестирования

**Рекомендую:** Начать с тестирования happd socket API (Вариант 2). Если не получится — fallback на прямую конфигурацию Xray (Вариант 1).

---

**Next action:** Ожидание ответов на Open Questions от Олега.  
**Status:** ⏳ Blocked — awaiting user input  
**Updated:** 2026-04-22T21:24:00Z
