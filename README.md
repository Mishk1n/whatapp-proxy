# WhatsApp Proxy Auto-Deployment Script
Автоматический скрипт развертывания официального прокси-сервера WhatsApp в Docker.

## 📋 Описание
Этот bash-скрипт автоматически разворачивает официальный прокси WhatsApp от Meta (Facebook) в Docker-контейнере. Прокси позволяет подключаться к WhatsApp в регионах с ограничениями доступа.

## ✨ Возможности
- ✅ Автоматическая установка Docker и Docker Compose
- ✅ Настройка пользовательских портов
- ✅ Автоматическое открытие портов в файрволе (UFW/firewalld)
- ✅ Определение публичного IP сервера
- ✅ Создание systemd сервиса для автозапуска
- ✅ Подробная инструкция по подключению
- ✅ Мониторинг через HAProxy статистику

## 🔧 Требования
- ОС: Linux (Ubuntu, Debian, CentOS, RHEL)
- Права: root (sudo)
- Интернет: для скачивания Docker-образа
- Ресурсы: минимум 512 MB RAM, 1 GB диска

## 🚀 Быстрый старт
1. Cоздайте вручную
```bash
nano deploy_whatsapp_proxy.sh
```
2. Сделайте исполняемым
```bash
chmod +x deploy_whatsapp_proxy.sh
```
3. Запустите с правами root
```bash
sudo ./deploy_whatsapp_proxy.sh
```

4. Следуйте инструкциям
Скрипт запросит:
- Использовать стандартные порты или настроить свои
- Подтверждение публичного IP
- Создание systemd сервиса (опционально)

## 📱 Подключение к прокси
Настройка в WhatsApp:
1. Откройте WhatsApp → Настройки → Хранилище и данные → Прокси
2. Включите "Использовать прокси"
3. Введите IP-адрес вашего сервера

## 🛠 Управление прокси
```bash
# Просмотр логов
docker logs -f whatsapp-proxy
# Статистика HAProxy
http://ВАШ_IP:8199
# Остановка прокси
docker stop whatsapp-proxy
# Запуск прокси
docker start whatsapp-proxy
# Перезапуск
docker restart whatsapp-proxy
# Статус контейнера
docker ps | grep whatsapp-proxy
# Полное удаление
docker rm -f whatsapp-proxy
```
Если установлен systemd сервис
```bash
# Управление через systemd
systemctl status whatsapp-proxy
systemctl start whatsapp-proxy
systemctl stop whatsapp-proxy
systemctl restart whatsapp-proxy
```
## 🐛 Устранение проблем

### Проблема: "pull rate limit exceeded"
Решение: Авторизуйтесь в Docker Hub:
```bash 
docker login
# Введите логин и пароль от hub.docker.com
docker compose up -d
```
### Проблема: Прокси не работает
Проверьте открыты ли порты в файрволе:
```bash
ufw status  # для UFW
firewall-cmd --list-ports  # для firewalld
# Проверьте логи:
docker logs whatsapp-proxy --tail 50
# Проверьте доступность портов:
netstat -tulpn | grep -E ":(443|80|5222)"
```

## 📁 Структура установки
```
/opt/whatsapp-proxy/
├── docker-compose.yml    # Конфигурация Docker Compose
Контейнер: whatsapp-proxy
```

## 🔒 Безопасность
- Прокси работает через официальный образ от Meta
- Все порты можно изменить на нестандартные
- Рекомендуется ограничить доступ к порту 8199 (статистика)
- Используйте firewall для дополнительной защиты

## 📊 Мониторинг
http://ВАШ_IP:8199

Здесь можно увидеть:
- Количество активных соединений
- Статистику по протоколам
- Ошибки и производительность

Команды мониторинга
```bash 
# Использование ресурсов
docker stats whatsapp-proxy
# Логи в реальном времени
docker logs -f whatsapp-proxy --tail 100
# Проверка работоспособности
curl -I http://localhost:80
curl -I https://localhost:443 -k
```

## 🗑 Удаление прокси
```bash 
# Остановить и удалить контейнер
docker rm -f whatsapp-proxy
# Удалить директорию
rm -rf /opt/whatsapp-proxy
# Удалить systemd сервис (если создавался)
systemctl disable whatsapp-proxy
rm /etc/systemd/system/whatsapp-proxy.service
systemctl daemon-reload
# Удалить образ (опционально)
docker rmi facebook/whatsapp_proxy:latest
```
## ⚠️ Отказ от ответственности
Данный скрипт предназначен только для легального использования. Пользователь несет ответственность за соблюдение законов своей страны и условий использования WhatsApp.
