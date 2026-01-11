#!/bin/bash

################################################################################
# LFCS PLATFORM - MASTER DEPLOYMENT SCRIPT
# This script orchestrates the complete installation
################################################################################

set -e

DOMAIN="velocitylab.co.za"
SERVER_IP="4.221.152.28"
INSTALL_DIR="/opt/lfcs-platform"
DB_PASSWORD="Superadmin@123"
ADMIN_PASSWORD="Superadmin@123"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

print_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║      LFCS LEARNING PLATFORM - COMPLETE DEPLOYMENT v1.0           ║
║                                                                   ║
║  • 125+ Exam-Accurate Questions                                  ║
║  • Real Terminal Simulator                                       ║
║  • Custom Lab Creator                                            ║
║  • Progress Tracking & Analytics                                 ║
║  • SSL/HTTPS Security                                            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo ""
}

log() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_step() {
    echo ""
    echo -e "${BLUE}═══ $1 ═══${NC}"
    echo ""
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

log_info() {
    echo -e "${YELLOW}[i]${NC} $1"
}

check_prerequisites() {
    log_step "Checking Prerequisites"
    
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
    log "Running as root"
    
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        log_error "No internet connection"
        exit 1
    fi
    log "Internet connection available"
    
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt 2 ]; then
        log_error "Insufficient RAM: ${total_ram}GB (minimum 2GB required)"
        exit 1
    fi
    log "RAM: ${total_ram}GB"
    
    available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt 10 ]; then
        log_error "Insufficient disk space: ${available_disk}GB (minimum 10GB required)"
        exit 1
    fi
    log "Disk space: ${available_disk}GB available"
}

install_system_dependencies() {
    log_step "Installing System Dependencies"
    
    if command -v apt-get &> /dev/null; then
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq
        apt-get install -y -qq \
            curl wget git build-essential software-properties-common \
            ca-certificates gnupg lsb-release ufw fail2ban nginx \
            certbot python3-certbot-nginx postgresql postgresql-contrib \
            &> /dev/null
    elif command -v dnf &> /dev/null; then
        dnf check-update || true
        dnf install -y curl wget git gcc gcc-c++ make nginx \
            postgresql-server postgresql-contrib certbot python3-certbot-nginx \
            &> /dev/null
    fi
    
    log "System packages installed"
}

install_nodejs() {
    log_step "Installing Node.js 20 LTS"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log "Node.js already installed: $(node --version)"
            return 0
        fi
    fi
    
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash - &> /dev/null
    apt-get install -y nodejs &> /dev/null
    npm install -g pnpm pm2 &> /dev/null
    
    log "Node.js $(node --version) installed"
    log "pnpm $(pnpm --version) installed"
}

setup_database() {
    log_step "Setting Up PostgreSQL Database"
    
    systemctl start postgresql
    systemctl enable postgresql
    
    sudo -u postgres psql > /dev/null 2>&1 <<EOF
DROP DATABASE IF EXISTS lfcs_platform;
DROP USER IF EXISTS lfcs_admin;
CREATE DATABASE lfcs_platform;
CREATE USER lfcs_admin WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE lfcs_platform TO lfcs_admin;
ALTER DATABASE lfcs_platform OWNER TO lfcs_admin;
\c lfcs_platform
GRANT ALL ON SCHEMA public TO lfcs_admin;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO lfcs_admin;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO lfcs_admin;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO lfcs_admin;
EOF
    
    log "Database 'lfcs_platform' created"
    
    # Import schema and questions
    cd "$(dirname "$0")/../database" || cd /root/lfcs-platform-complete/database
    
    for sql_file in 01-schema.sql 02-questions-operations.sql 03-questions-networking.sql 04-questions-storage-commands-users.sql; do
        if [ -f "$sql_file" ]; then
            PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -f "$sql_file" > /dev/null 2>&1
            log "Imported $(basename $sql_file)"
        fi
    done
    
    question_count=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -t -c "SELECT COUNT(*) FROM questions;" | tr -d ' ')
    log "Total questions loaded: $question_count"
}

create_application() {
    log_step "Creating Application Structure"
    
    mkdir -p "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    # Create package.json
    cat > package.json <<'PKGJSON'
{
  "name": "lfcs-platform",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start -p 3000",
    "lint": "next lint"
  },
  "dependencies": {
    "next": "14.2.18",
    "react": "^18.3.1",
    "react-dom": "^18.3.1",
    "typescript": "^5.6.3",
    "@types/node": "^22.9.3",
    "@types/react": "^18.3.12",
    "@types/react-dom": "^18.3.1",
    "pg": "^8.13.1",
    "bcryptjs": "^2.4.3",
    "jsonwebtoken": "^9.0.2",
    "xterm": "^5.3.0",
    "xterm-addon-fit": "^0.8.0",
    "xterm-addon-web-links": "^0.9.0",
    "zustand": "^4.5.5",
    "framer-motion": "^11.11.17",
    "lucide-react": "^0.263.1",
    "recharts": "^2.14.1"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.7",
    "@types/pg": "^8.11.10",
    "tailwindcss": "^3.4.15",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49",
    "eslint": "^8.57.1",
    "eslint-config-next": "14.2.18"
  }
}
PKGJSON
    
    log "package.json created"
    
    # Create environment file
    cat > .env.local <<ENVFILE
DATABASE_URL=postgresql://lfcs_admin:$DB_PASSWORD@localhost:5432/lfcs_platform
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://$DOMAIN
PORT=3000
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)
ADMIN_USERNAME=superadmin
ADMIN_PASSWORD=$ADMIN_PASSWORD
ENVFILE
    
    chmod 600 .env.local
    log "Environment configured"
    
    # Run the app file generator
    if [ -f "$(dirname "$0")/create-app-files.sh" ]; then
        bash "$(dirname "$0")/create-app-files.sh" "$INSTALL_DIR"
    fi
    
    log "Installing dependencies (this may take 5-10 minutes)..."
    pnpm install --silent > /dev/null 2>&1
    
    log "Building application..."
    pnpm build > /dev/null 2>&1
    
    log "Application built successfully"
}

configure_nginx() {
    log_step "Configuring Nginx"
    
    cat > /etc/nginx/sites-available/lfcs-platform <<NGINXCONF
upstream lfcs_app {
    server 127.0.0.1:3000;
    keepalive 64;
}

server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    
    add_header Strict-Transport-Security "max-age=31536000" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    
    client_max_body_size 10M;
    
    location / {
        proxy_pass http://lfcs_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
}
NGINXCONF
    
    rm -f /etc/nginx/sites-enabled/default
    ln -sf /etc/nginx/sites-available/lfcs-platform /etc/nginx/sites-enabled/
    
    log "Nginx configured"
}

setup_ssl() {
    log_step "Setting Up SSL Certificate"
    
    systemctl stop nginx
    
    if certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN \
        --non-interactive --agree-tos --email admin@$DOMAIN > /dev/null 2>&1; then
        log "SSL certificate installed"
        
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        log "Auto-renewal configured"
    else
        log_error "SSL certificate installation failed"
        log_info "You may need to configure DNS first, then run: certbot --nginx -d $DOMAIN"
    fi
    
    systemctl start nginx
    systemctl enable nginx
}

configure_firewall() {
    log_step "Configuring Firewall"
    
    ufw --force enable
    ufw allow 22/tcp
    ufw allow 80/tcp
    ufw allow 443/tcp
    ufw reload > /dev/null 2>&1
    
    log "Firewall configured"
}

create_systemd_service() {
    log_step "Creating System Service"
    
    cat > /etc/systemd/system/lfcs-platform.service <<SERVICECONF
[Unit]
Description=LFCS Learning Platform
After=network.target postgresql.service

[Service]
Type=simple
User=root
WorkingDirectory=$INSTALL_DIR
Environment=NODE_ENV=production
ExecStart=/usr/bin/pnpm start
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
SERVICECONF
    
    systemctl daemon-reload
    systemctl enable lfcs-platform
    systemctl start lfcs-platform
    
    log "Service created and started"
}

create_management_scripts() {
    log_step "Creating Management Scripts"
    
    cat > /usr/local/bin/lfcs-start <<'CMD'
#!/bin/bash
systemctl start lfcs-platform
systemctl status lfcs-platform --no-pager
CMD
    
    cat > /usr/local/bin/lfcs-stop <<'CMD'
#!/bin/bash
systemctl stop lfcs-platform
CMD
    
    cat > /usr/local/bin/lfcs-restart <<'CMD'
#!/bin/bash
systemctl restart lfcs-platform
systemctl status lfcs-platform --no-pager
CMD
    
    cat > /usr/local/bin/lfcs-status <<'CMD'
#!/bin/bash
echo "=== LFCS Platform Status ==="
echo ""
systemctl status lfcs-platform --no-pager
CMD
    
    cat > /usr/local/bin/lfcs-logs <<'CMD'
#!/bin/bash
journalctl -u lfcs-platform -f
CMD
    
    cat > /usr/local/bin/lfcs-backup <<BACKUP
#!/bin/bash
BACKUP_DIR="$INSTALL_DIR/backups"
mkdir -p "\$BACKUP_DIR"
DATE=\$(date +%Y%m%d_%H%M%S)
PGPASSWORD="$DB_PASSWORD" pg_dump -h localhost -U lfcs_admin lfcs_platform | gzip > "\$BACKUP_DIR/db_\$DATE.sql.gz"
ls -t "\$BACKUP_DIR"/db_*.sql.gz | tail -n +8 | xargs rm -f 2>/dev/null || true
echo "Backup created: db_\$DATE.sql.gz"
BACKUP
    
    chmod +x /usr/local/bin/lfcs-{start,stop,restart,status,logs,backup}
    
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/lfcs-backup") | crontab -
    
    log "Management scripts created"
}

print_success() {
    echo ""
    echo -e "${GREEN}"
    cat << 'SUCCESS'
╔═══════════════════════════════════════════════════════════════════╗
║                                                                   ║
║            🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉            ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
SUCCESS
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}Your LFCS Learning Platform is now live!${NC}"
    echo ""
    echo -e "${CYAN}🌐 Access URL:${NC}"
    echo -e "   ${WHITE}https://$DOMAIN${NC}"
    echo ""
    echo -e "${CYAN}👤 Admin Login:${NC}"
    echo -e "   Username: ${WHITE}superadmin${NC}"
    echo -e "   Password: ${WHITE}$ADMIN_PASSWORD${NC}"
    echo ""
    echo -e "${CYAN}📊 Database:${NC}"
    echo -e "   Questions: ${WHITE}125+${NC}"
    echo -e "   Domains: ${WHITE}5${NC}"
    echo ""
    echo -e "${CYAN}🛠️  Management Commands:${NC}"
    echo -e "   ${WHITE}lfcs-start${NC}      - Start the platform"
    echo -e "   ${WHITE}lfcs-stop${NC}       - Stop the platform"
    echo -e "   ${WHITE}lfcs-restart${NC}    - Restart the platform"
    echo -e "   ${WHITE}lfcs-status${NC}     - Check status"
    echo -e "   ${WHITE}lfcs-logs${NC}       - View logs"
    echo -e "   ${WHITE}lfcs-backup${NC}     - Create database backup"
    echo ""
    echo -e "${YELLOW}⚠️  IMPORTANT:${NC}"
    echo -e "   1. Change admin password after first login"
    echo -e "   2. Backups run daily at 2 AM"
    echo -e "   3. SSL certificate renews automatically"
    echo ""
    echo -e "${CYAN}📚 Documentation:${NC} See /root/lfcs-platform-complete/docs/"
    echo ""
}

main() {
    print_banner
    check_prerequisites
    install_system_dependencies
    install_nodejs
    setup_database
    create_application
    configure_nginx
    setup_ssl
    configure_firewall
    create_systemd_service
    create_management_scripts
    print_success
}

main "$@"
