# Implementation Plan — Работоспособный VPN

**Date:** 2026-04-22  
**Priority:** P0 — работоспособный VPN  
**Status:** Ready to implement

---

## Decision Summary

На основе ответов Олега:

| Вопрос | Ответ | Влияние |
|--------|-------|---------|
| Q1: Доступ к GUI? | Нет (возможно в будущем) | Используем Xray-core напрямую |
| Q2: Ротация серверов? | Нет | Один сервер, failover при падении |
| Q3: Тестировать happd API? | Пока нет | Используем документированный Xray |
| Q4: Приоритет? | Работоспособный VPN | Минимальное рабочее решение |

---

## Implementation Strategy

### Approach: Xray-core Direct Configuration

**Почему:**
- ✅ Полностью документировано
- ✅ Не требует reverse engineering happd
- ✅ Гарантированная работоспособность
- ✅ Позволяет легко добавить ротацию позже

**Архитектура:**
```
Xray-core (config.json)
    ↓
SOCKS5 proxy (port 10808)
    ↓
VLESS → server from key.txt
```

---

## Tasks

### Task 1: Создать Xray конфигурацию

**Цель:** Простой config.json с одним сервером

**Действия:**
1. Выбрать первый сервер из key.txt
2. Создать `scripts/xray-config.json`
3. Добавить health check через observatory

**Формат:**
```json
{
  "inbounds": [{
    "port": 10808,
    "protocol": "socks",
    "settings": {"auth": "noauth"}
  }],
  "outbounds": [{
    "protocol": "vless",
    "settings": {
      "vnext": [{
        "address": "cdn1-08.vk-cdnvideo.com",
        "port": 8443,
        "users": [{"id": "UUID", "encryption": "none"}]
      }]
    },
    "streamSettings": {
      "network": "tcp",
      "security": "tls",
      "tlsSettings": {"alpn": ["h2"]}
    }
  }]
}
```

---

### Task 2: Обновить Dockerfile

**Цель:** Запускать Xray вместо Happ

**Изменения:**
1. Установить xray-core в образ
2. Копировать config.json
3. Запускать xray как main process

**Команды:**
```dockerfile
# Установить xray
RUN curl -L https://github.com/XTLS/Xray-core/releases/download/v24.7.9/Xray-linux-64.zip -o xray.zip && \
    unzip xray.zip && \
    mv xray /usr/local/bin/ && \
    chmod +x /usr/local/bin/xray

# Копировать конфиг
COPY scripts/xray-config.json /etc/xray/config.json

# Запуск
ENTRYPOINT ["/usr/local/bin/xray", "-config", "/etc/xray/config.json"]
```

---

### Task 3: Создать скрипт выбора сервера

**Цель:** Простой скрипт для выбора сервера из key.txt

**Функционал:**
- Читать key.txt
- Выбирать сервер по индексу (или случайный)
- Генерировать config.json
- Перезапускать xray

**Пример:**
```bash
#!/bin/bash
# scripts/select-server.sh

KEY_FILE="/opt/happvpn/key.txt"
CONFIG_FILE="/etc/xray/config.json"
INDEX=${1:-0}  # По умолчанию первый сервер

# Выбрать строку из key.txt
SERVER_URL=$(sed -n "$((INDEX+1))p" "$KEY_FILE")

# Парсить URL и генерировать config.json
# (логика парсинга vless://URL)

# Перезапустить xray
killall xray
xray -config "$CONFIG_FILE" &
```

---

### Task 4: Тестирование

**Цель:** Убедиться что VPN работает

**Шаги:**
1. Собрать образ: `docker build -t happvpn:test .`
2. Запустить контейнер: `docker run -d --name vpn happvpn:test`
3. Проверить порт: `docker exec vpn netstat -tlnp | grep 10808`
4. Протестировать соединение: `curl --socks5-hostname 127.0.0.1:10808 https://ifconfig.me`

---

## Rollout Plan

### Phase 1: MVP (сегодня)
- [ ] Task 1: Создать xray-config.json
- [ ] Task 2: Обновить Dockerfile
- [ ] Task 4: Тестирование

### Phase 2: Улучшения (если Phase 1 работает)
- [ ] Task 3: Скрипт выбора сервера
- [ ] Добавить failover логику
- [ ] Добавить метрики

### Phase 3: Опционально (в будущем)
- [ ] Интеграция с Happ GUI
- [ ] Ротация серверов
- [ ] CLI управление через happd socket

---

## Success Criteria

**VPN считается рабочим если:**
1. Контейнер запускается без ошибок
2. Порт 10808 слушает
3. `curl --socks5-hostname 127.0.0.1:10808 https://ifconfig.me` возвращает внешний IP
4. Лог xray не содержит ошибок

---

## Risk Mitigation

| Риск | Решение |
|------|---------|
| Xray не запускается | Проверить версию, права доступа, логи |
| Сервер из key.txt не работает | Попробовать другой сервер из списка |
| TLS ошибки | Проверить сертификаты, alpn настройки |
| Порт занят | Сменить порт в конфиге |

---

## Next Action

**Следующий шаг:** Task 1 — Создать xray-config.json с первым сервером из key.txt

**Оценка времени:** 30-60 минут

**Блокирует:** Нет — все ответы получены

---

*Created: 2026-04-22T21:34:00Z*
