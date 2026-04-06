#!/bin/bash

# WhatsApp Proxy Auto-Deployment Script
# Использует официальный прокси от Meta (WhatsApp/proxy)

set -e  # Остановка при любой ошибке

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Функции для вывода
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "========================================="
    echo -e "${GREEN}$1${NC}"
    echo "========================================="
}

# Проверка прав root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "Этот скрипт должен запускаться с правами root"
        echo "Используйте: sudo $0"
        exit 1
    fi
}

# Проверка и установка Docker
install_docker() {
    print_info "Проверка установки Docker..."
    
    if command -v docker &> /dev/null; then
        print_success "Docker уже установлен: $(docker --version)"
    else
        print_warning "Docker не найден. Установка Docker..."
        curl -fsSL https://get.docker.com -o get-docker.sh
        sh get-docker.sh
        rm get-docker.sh
        print_success "Docker установлен"
    fi
    
    # Запуск Docker сервиса
    systemctl enable docker
    systemctl start docker
}

# Установка Docker Compose
install_docker_compose() {
    print_info "Проверка установки Docker Compose..."
    
    if command -v docker-compose &> /dev/null; then
        print_success "Docker Compose уже установлен: $(docker-compose --version)"
        return 0
    fi
    
    # Проверка плагина Docker Compose (новая версия Docker)
    if docker compose version &> /dev/null; then
        print_success "Docker Compose плагин уже установлен: $(docker compose version)"
        # Создаем alias для совместимости
        alias docker-compose='docker compose'
        # Добавляем alias в .bashrc для постоянного использования
        if ! grep -q "alias docker-compose='docker compose'" ~/.bashrc 2>/dev/null; then
            echo "alias docker-compose='docker compose'" >> ~/.bashrc
        fi
        return 0
    fi
    
    print_warning "Docker Compose не найден. Установка..."
    
    # Определение архитектуры
    ARCH=$(uname -m)
    if [ "$ARCH" = "x86_64" ]; then
        DOCKER_COMPOSE_ARCH="x86_64"
    elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
        DOCKER_COMPOSE_ARCH="aarch64"
    else
        DOCKER_COMPOSE_ARCH="x86_64"
    fi
    
    # Скачивание последней версии Docker Compose
    LATEST_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    if [ -z "$LATEST_VERSION" ]; then
        LATEST_VERSION="v2.24.0"  # Fallback версия
    fi
    
    curl -L "https://github.com/docker/compose/releases/download/${LATEST_VERSION}/docker-compose-$(uname -s)-${DOCKER_COMPOSE_ARCH}" -o /usr/local/bin/docker-compose
    
    if [ $? -eq 0 ]; then
        chmod +x /usr/local/bin/docker-compose
        print_success "Docker Compose установлен: $(docker-compose --version)"
    else
        print_error "Не удалось установить Docker Compose"
        print_info "Попытка установки через apt (Debian/Ubuntu)..."
        
        if command -v apt &> /dev/null; then
            apt update
            apt install -y docker-compose
            if command -v docker-compose &> /dev/null; then
                print_success "Docker Compose установлен через apt"
            else
                print_error "Не удалось установить Docker Compose"
                exit 1
            fi
        else
            print_error "Не удалось установить Docker Compose"
            exit 1
        fi
    fi
}

# Запрос порта у пользователя
get_custom_port() {
    local default_port=$1
    local service_name=$2
    
    read -p "Введите порт для $service_name [по умолчанию $default_port]: " custom_port
    if [[ -z "$custom_port" ]]; then
        echo "$default_port"
    elif [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
        echo "$custom_port"
    else
        print_error "Неверный номер порта. Использую порт по умолчанию $default_port"
        echo "$default_port"
    fi
}

# Настройка портов
configure_ports() {
    print_header "Настройка портов прокси"
    
    echo "WhatsApp Proxy использует следующие порты:"
    echo "  80    - HTTP трафик"
    echo "  443   - HTTPS трафик (основной для WhatsApp чатов)"
    echo "  5222  - Jabber/XMPP протокол"
    echo "  8080  - HTTP с PROXY протоколом"
    echo "  8443  - HTTPS с PROXY протоколом"
    echo "  8222  - Jabber с PROXY протоколом"
    echo "  8199  - Статистика HAProxy"
    echo "  587   - Медиа порт (для передачи фото/видео)"
    echo "  7777  - Альтернативный медиа порт (рекомендуется)"
    echo ""
    echo "💡 ВАЖНО: Для работы медиафайлов (фото, видео) используются порты 587 и 7777"
    echo ""
    
    read -p "Использовать стандартные порты? (y/n) [y]: " use_default
    use_default=${use_default:-y}
    
    if [[ "$use_default" =~ ^[Yy]$ ]]; then
        # Стандартные порты
        PORT_80=80
        PORT_443=443
        PORT_5222=5222
        PORT_8080=8080
        PORT_8443=8443
        PORT_8222=8222
        PORT_8199=8199
        PORT_587=587
        PORT_7777=7777
        print_info "Используются стандартные порты"
    else
        print_info "Введите пользовательские порты (нажмите Enter для пропуска, будет использован стандартный порт)"
        PORT_80=$(get_custom_port 80 "HTTP (обычный)")
        PORT_443=$(get_custom_port 443 "HTTPS (основной для чатов)")
        PORT_5222=$(get_custom_port 5222 "Jabber/XMPP")
        PORT_8080=$(get_custom_port 8080 "HTTP + PROXY")
        PORT_8443=$(get_custom_port 8443 "HTTPS + PROXY")
        PORT_8222=$(get_custom_port 8222 "Jabber + PROXY")
        PORT_8199=$(get_custom_port 8199 "Статистика HAProxy")
        PORT_587=$(get_custom_port 587 "Медиа порт (фото/видео)")
        PORT_7777=$(get_custom_port 7777 "Альтернативный медиа порт")
    fi
}

# Открытие портов в firewall
configure_firewall() {
    print_header "Настройка файрвола"
    
    # Определение активного файрвола
    if command -v ufw &> /dev/null && ufw status | grep -q "active"; then
        print_info "Обнаружен UFW. Открытие портов..."
        
        # Открываем выбранные порты
        ufw allow $PORT_80/tcp comment 'WhatsApp Proxy HTTP'
        ufw allow $PORT_443/tcp comment 'WhatsApp Proxy HTTPS Chat'
        ufw allow $PORT_5222/tcp comment 'WhatsApp Proxy Jabber'
        ufw allow $PORT_8080/tcp comment 'WhatsApp Proxy HTTP+PROXY'
        ufw allow $PORT_8443/tcp comment 'WhatsApp Proxy HTTPS+PROXY'
        ufw allow $PORT_8222/tcp comment 'WhatsApp Proxy Jabber+PROXY'
        ufw allow $PORT_8199/tcp comment 'WhatsApp Proxy Statistics'
        ufw allow $PORT_587/tcp comment 'WhatsApp Proxy Media'
        ufw allow $PORT_7777/tcp comment 'WhatsApp Proxy Alternative Media'
        
        print_success "Порты открыты в UFW"
        
    elif command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
        print_info "Обнаружен firewalld. Открытие портов..."
        
        firewall-cmd --permanent --add-port=$PORT_80/tcp
        firewall-cmd --permanent --add-port=$PORT_443/tcp
        firewall-cmd --permanent --add-port=$PORT_5222/tcp
        firewall-cmd --permanent --add-port=$PORT_8080/tcp
        firewall-cmd --permanent --add-port=$PORT_8443/tcp
        firewall-cmd --permanent --add-port=$PORT_8222/tcp
        firewall-cmd --permanent --add-port=$PORT_8199/tcp
        firewall-cmd --permanent --add-port=$PORT_587/tcp
        firewall-cmd --permanent --add-port=$PORT_7777/tcp
        firewall-cmd --reload
        
        print_success "Порты открыты в firewalld"
    else
        print_warning "Активный файрвол не обнаружен. Убедитесь, что порты открыты вручную"
    fi
}

# Получение публичного IP
get_public_ip() {
    print_info "Определение публичного IP адреса..."
    
    # Пробуем разные сервисы
    PUBLIC_IP=$(curl -s --max-time 5 https://api.ipify.org 2>/dev/null)
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s --max-time 5 https://icanhazip.com 2>/dev/null | tr -d '[:space:]')
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        PUBLIC_IP=$(curl -s --max-time 5 https://ifconfig.me 2>/dev/null)
    fi
    
    if [ -z "$PUBLIC_IP" ]; then
        print_warning "Не удалось автоматически определить публичный IP"
        read -p "Введите публичный IP адрес сервера вручную: " PUBLIC_IP
    else
        print_success "Публичный IP: $PUBLIC_IP"
        read -p "Это правильный IP? (y/n) [y]: " ip_correct
        if [[ ! "$ip_correct" =~ ^[Yy]$ ]] && [ -n "$ip_correct" ]; then
            read -p "Введите правильный IP адрес: " PUBLIC_IP
        fi
    fi
}

# Запуск прокси контейнера
run_proxy() {
    print_header "Запуск WhatsApp Proxy контейнера"
    
    CONTAINER_NAME="whatsapp-proxy"
    
    # Остановка и удаление существующего контейнера если есть
    if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME$"; then
        print_info "Остановка и удаление существующего контейнера..."
        docker stop $CONTAINER_NAME 2>/dev/null || true
        docker rm $CONTAINER_NAME 2>/dev/null || true
    fi
    
    # Создание docker-compose.yml
    print_info "Создание docker-compose.yml..."
    
    mkdir -p /opt/whatsapp-proxy
    
    cat > /opt/whatsapp-proxy/docker-compose.yml << EOF
services:
  whatsapp-proxy:
    image: facebook/whatsapp_proxy:latest
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "${PORT_80}:80"
      - "${PORT_443}:443"
      - "${PORT_5222}:5222"
      - "${PORT_8080}:8080"
      - "${PORT_8443}:8443"
      - "${PORT_8222}:8222"
      - "${PORT_8199}:8199"
      - "${PORT_587}:587"
      - "${PORT_7777}:7777"
    environment:
      - PUBLIC_IP=${PUBLIC_IP}
    networks:
      - whatsapp-network

networks:
  whatsapp-network:
    driver: bridge
EOF
    
    # Запуск контейнера через docker-compose (с поддержкой разных версий)
    cd /opt/whatsapp-proxy
    
    print_info "Скачивание образа и запуск контейнера..."
    
    # Пробуем использовать docker compose (плагин) или docker-compose (отдельный)
    if docker compose version &> /dev/null; then
        docker compose up -d
    elif command -v docker-compose &> /dev/null; then
        docker-compose up -d
    else
        # Fallback: запуск напрямую через docker run
        print_warning "Docker Compose не найден, запуск через docker run..."
        
        docker run -d \
            --name $CONTAINER_NAME \
            --restart unless-stopped \
            -p ${PORT_80}:80 \
            -p ${PORT_443}:443 \
            -p ${PORT_5222}:5222 \
            -p ${PORT_8080}:8080 \
            -p ${PORT_8443}:8443 \
            -p ${PORT_8222}:8222 \
            -p ${PORT_8199}:8199 \
            -p ${PORT_587}:587 \
            -p ${PORT_7777}:7777 \
            -e PUBLIC_IP=${PUBLIC_IP} \
            facebook/whatsapp_proxy:latest
    fi
    
    if [ $? -eq 0 ]; then
        print_success "WhatsApp Proxy успешно запущен!"
    else
        print_error "Ошибка при запуске контейнера"
        exit 1
    fi
}

# Проверка статуса
check_status() {
    print_header "Проверка статуса"
    
    # Проверка контейнера
    if docker ps --format '{{.Names}}' | grep -q "whatsapp-proxy"; then
        print_success "Контейнер whatsapp-proxy запущен"
        
        # Получение информации о контейнере
        CONTAINER_ID=$(docker ps --filter "name=whatsapp-proxy" --format "{{.ID}}")
        print_info "Container ID: $CONTAINER_ID"
        
        # Проверка статистики HAProxy
        sleep 5
        if curl -s --max-time 3 "http://localhost:${PORT_8199}" &>/dev/null; then
            print_success "HAProxy статистика доступна на порту ${PORT_8199}"
        else
            print_warning "HAProxy статистика пока не доступна (может потребоваться несколько секунд)"
        fi
        
        # Показываем последние логи
        print_info "Последние логи контейнера:"
        docker logs whatsapp-proxy --tail 10
    else
        print_error "Контейнер не запущен"
        docker logs whatsapp-proxy --tail 20 2>/dev/null || true
        exit 1
    fi
}

# Вывод инструкции
print_instructions() {
    print_header "WhatsApp Proxy успешно развернут!"
    
    echo ""
    echo "📱 ИНСТРУКЦИЯ ПО ПОДКЛЮЧЕНИЮ:"
    echo ""
    echo "1. Откройте WhatsApp на вашем устройстве"
    echo "2. Перейдите в Настройки → Хранилище и данные → Прокси"
    echo "3. Включите 'Использовать прокси'"
    echo "4. Нажмите 'Настроить прокси'"
    echo "5. Введите данные:"
    echo ""
    echo "   🔹 Хост прокси:     ${PUBLIC_IP}"
    echo "   🔹 Порт для чата:   ${PORT_443}"
    echo "   🔹 Порт для медиа:  ${PORT_7777} (рекомендуется) или ${PORT_587}"
    echo ""
    echo "🔧 ПОЛЕЗНЫЕ КОМАНДЫ:"
    echo ""
    echo "   Просмотр логов:        docker logs -f whatsapp-proxy"
    echo "   Статистика HAProxy:    http://${PUBLIC_IP}:${PORT_8199}"
    echo "   Остановка прокси:      docker stop whatsapp-proxy"
    echo "   Запуск прокси:         docker start whatsapp-proxy"
    echo "   Перезапуск прокси:     docker restart whatsapp-proxy"
    echo "   Статус контейнера:     docker ps | grep whatsapp-proxy"
    echo "   Удаление прокси:       docker rm -f whatsapp-proxy"
    echo ""
    
    if [ "$PORT_443" != "443" ]; then
        print_warning "ВНИМАНИЕ: Вы используете нестандартный порт HTTPS (${PORT_443})"
        echo "При подключении указывайте адрес с портом: ${PUBLIC_IP}:${PORT_443}"
    fi
    
    echo "📊 ИНФОРМАЦИЯ О ПОРТАХ:"
    echo "   Основной HTTPS (чат):   ${PORT_443}"
    echo "   Медиа порт:             ${PORT_7777} (рекомендуемый)"
    echo "   Альтернативный медиа:   ${PORT_587}"
    echo "   HTTP порт:              ${PORT_80}"
    echo "   Статистика:             ${PORT_8199}"
    echo ""
    echo "💡 СОВЕТ: Если медиа (фото/видео) не работают, попробуйте:"
    echo "   - Использовать порт ${PORT_7777} для медиа"
    echo "   - Перезапустить WhatsApp после смены порта"
    echo "   - Проверить открыты ли порты ${PORT_7777} и ${PORT_587} на сервере"
    echo ""
    echo "========================================="
}

# Создание сервиса systemd (опционально)
create_systemd_service() {
    print_header "Создание systemd сервиса для автозапуска"
    
    read -p "Создать systemd сервис для автоматического запуска при загрузке системы? (y/n) [y]: " create_service
    create_service=${create_service:-y}
    
    if [[ "$create_service" =~ ^[Yy]$ ]]; then
        cat > /etc/systemd/system/whatsapp-proxy.service << EOF
[Unit]
Description=WhatsApp Proxy Container
Requires=docker.service
After=docker.service

[Service]
Restart=always
ExecStart=/usr/bin/docker start -a whatsapp-proxy
ExecStop=/usr/bin/docker stop -t 10 whatsapp-proxy

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable whatsapp-proxy.service
        print_success "Systemd сервис создан и включен"
        print_info "Прокси будет автоматически запускаться при загрузке системы"
    fi
}

# Главная функция
main() {
    print_header "WhatsApp Proxy Auto-Deployment Script"
    echo "Этот скрипт автоматически развернет официальный прокси WhatsApp в Docker"
    echo "Включая поддержку медиафайлов (фото, видео)"
    echo ""
    
    # Проверка root прав
    check_root
    
    # Создание директории для прокси
    mkdir -p /opt/whatsapp-proxy
    
    # Установка Docker если нужно
    install_docker
    
    # Установка Docker Compose
    install_docker_compose
    
    # Настройка портов
    configure_ports
    
    # Открытие портов в firewall
    configure_firewall
    
    # Получение публичного IP
    get_public_ip
    
    # Запуск прокси
    run_proxy
    
    # Проверка статуса
    check_status
    
    # Создание systemd сервиса
    create_systemd_service
    
    # Вывод инструкции
    print_instructions
}

# Запуск скрипта
main