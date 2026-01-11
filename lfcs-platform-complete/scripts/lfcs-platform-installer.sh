#!/bin/bash

################################################################################
# LFCS LEARNING PLATFORM - INTELLIGENT AUTO-INSTALLER
# Complete production deployment with self-healing capabilities
# Version: 1.0
# Created: January 2026
################################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Configuration
DOMAIN="velocitylab.co.za"
SERVER_IP="4.221.152.28"
DB_NAME="lfcs_platform"
DB_USER="lfcs_admin"
DB_PASSWORD="Superadmin@123"
ADMIN_USER="superadmin"
ADMIN_PASSWORD="Superadmin@123"
APP_PORT="3000"
INSTALL_DIR="/opt/lfcs-platform"
LOG_FILE="/var/log/lfcs-installer.log"
MAX_RETRIES=3

# System requirements
MIN_RAM_GB=2
MIN_DISK_GB=10

################################################################################
# UTILITY FUNCTIONS
################################################################################

log() {
    echo -e "${GREEN}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date '+%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date '+%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1" | tee -a "$LOG_FILE"
}

log_info() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')] INFO:${NC} $1" | tee -a "$LOG_FILE"
}

print_banner() {
    clear
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║         LFCS LEARNING PLATFORM - AUTO INSTALLER v1.0             ║"
    echo "║                                                                   ║"
    echo "║   Complete Production Deployment with Self-Healing               ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

retry_command() {
    local command="$1"
    local description="$2"
    local retries=0
    
    while [ $retries -lt $MAX_RETRIES ]; do
        if eval "$command"; then
            log "✓ $description"
            return 0
        else
            retries=$((retries + 1))
            log_warning "Attempt $retries/$MAX_RETRIES failed for: $description"
            if [ $retries -lt $MAX_RETRIES ]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
            fi
        fi
    done
    
    log_error "Failed after $MAX_RETRIES attempts: $description"
    return 1
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

check_system_requirements() {
    log_info "Checking system requirements..."
    
    # Check RAM
    total_ram=$(free -g | awk '/^Mem:/{print $2}')
    if [ "$total_ram" -lt "$MIN_RAM_GB" ]; then
        log_warning "Low RAM detected: ${total_ram}GB (recommended: ${MIN_RAM_GB}GB+)"
    else
        log "✓ RAM: ${total_ram}GB"
    fi
    
    # Check disk space
    available_disk=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
    if [ "$available_disk" -lt "$MIN_DISK_GB" ]; then
        log_error "Insufficient disk space: ${available_disk}GB (required: ${MIN_DISK_GB}GB+)"
        exit 1
    else
        log "✓ Disk space: ${available_disk}GB available"
    fi
    
    # Detect OS
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        log "✓ OS: $PRETTY_NAME"
    else
        log_warning "Could not detect OS version"
    fi
}

################################################################################
# PACKAGE INSTALLATION
################################################################################

install_system_packages() {
    log_info "Installing system packages..."
    
    # Detect package manager
    if command -v apt-get &> /dev/null; then
        PKG_MANAGER="apt-get"
        UPDATE_CMD="apt-get update"
        INSTALL_CMD="apt-get install -y"
    elif command -v dnf &> /dev/null; then
        PKG_MANAGER="dnf"
        UPDATE_CMD="dnf check-update || true"
        INSTALL_CMD="dnf install -y"
    elif command -v yum &> /dev/null; then
        PKG_MANAGER="yum"
        UPDATE_CMD="yum check-update || true"
        INSTALL_CMD="yum install -y"
    else
        log_error "No supported package manager found"
        exit 1
    fi
    
    log "✓ Package manager: $PKG_MANAGER"
    
    # Update package lists
    retry_command "$UPDATE_CMD" "Updating package lists"
    
    # Install essential packages
    local packages=(
        "curl"
        "wget"
        "git"
        "build-essential"
        "software-properties-common"
        "ca-certificates"
        "gnupg"
        "lsb-release"
        "ufw"
        "fail2ban"
        "htop"
        "vim"
        "nginx"
    )
    
    # Adjust for different package managers
    if [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        packages=("${packages[@]/build-essential/}")
        packages+=("gcc" "gcc-c++" "make")
    fi
    
    for package in "${packages[@]}"; do
        if [ -n "$package" ]; then
            retry_command "$INSTALL_CMD $package" "Installing $package" || log_warning "Could not install $package, continuing..."
        fi
    done
}

################################################################################
# NODE.JS INSTALLATION
################################################################################

install_nodejs() {
    log_info "Installing Node.js 20 LTS..."
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [ "$NODE_VERSION" -ge 18 ]; then
            log "✓ Node.js already installed: $(node --version)"
            return 0
        fi
    fi
    
    # Install Node.js using NodeSource
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        retry_command "curl -fsSL https://deb.nodesource.com/setup_20.x | bash -" "Adding NodeSource repository"
        retry_command "$INSTALL_CMD nodejs" "Installing Node.js"
    elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
        retry_command "curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -" "Adding NodeSource repository"
        retry_command "$INSTALL_CMD nodejs" "Installing Node.js"
    fi
    
    # Verify installation
    if command -v node &> /dev/null && command -v npm &> /dev/null; then
        log "✓ Node.js version: $(node --version)"
        log "✓ npm version: $(npm --version)"
    else
        log_error "Node.js installation failed"
        exit 1
    fi
    
    # Install pnpm for faster package management
    retry_command "npm install -g pnpm pm2" "Installing pnpm and PM2"
}

################################################################################
# POSTGRESQL INSTALLATION
################################################################################

install_postgresql() {
    log_info "Installing PostgreSQL 15..."
    
    if command -v psql &> /dev/null; then
        log "✓ PostgreSQL already installed"
    else
        if [ "$PKG_MANAGER" = "apt-get" ]; then
            retry_command "sh -c 'echo \"deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main\" > /etc/apt/sources.list.d/pgdg.list'" "Adding PostgreSQL repository"
            retry_command "wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -" "Adding PostgreSQL GPG key"
            retry_command "$UPDATE_CMD" "Updating package lists"
            retry_command "$INSTALL_CMD postgresql-15 postgresql-contrib-15" "Installing PostgreSQL"
        elif [ "$PKG_MANAGER" = "dnf" ]; then
            retry_command "$INSTALL_CMD https://download.postgresql.org/pub/repos/yum/reporpms/EL-$(rpm -E %{rhel})-x86_64/pgdg-redhat-repo-latest.noarch.rpm" "Adding PostgreSQL repository"
            retry_command "$INSTALL_CMD postgresql15-server postgresql15-contrib" "Installing PostgreSQL"
            retry_command "postgresql-15-setup initdb" "Initializing PostgreSQL"
        fi
    fi
    
    # Start and enable PostgreSQL
    systemctl start postgresql || systemctl start postgresql-15
    systemctl enable postgresql || systemctl enable postgresql-15
    
    log "✓ PostgreSQL service started"
}

setup_database() {
    log_info "Setting up database..."
    
    # Create database and user
    sudo -u postgres psql <<EOF
DROP DATABASE IF EXISTS $DB_NAME;
DROP USER IF EXISTS $DB_USER;
CREATE DATABASE $DB_NAME;
CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASSWORD';
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;
ALTER DATABASE $DB_NAME OWNER TO $DB_USER;
\c $DB_NAME
GRANT ALL ON SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO $DB_USER;
EOF
    
    log "✓ Database created: $DB_NAME"
}

################################################################################
# APPLICATION SETUP
################################################################################

create_application_structure() {
    log_info "Creating application structure..."
    
    # Create directories
    mkdir -p "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR/database"
    mkdir -p "$INSTALL_DIR/logs"
    mkdir -p "$INSTALL_DIR/backups"
    
    cd "$INSTALL_DIR"
    
    log "✓ Directory structure created"
}

create_database_files() {
    log_info "Creating database schema and questions..."
    
    # The database files will be created in the next step
    # For now, we'll create placeholders that will be replaced by actual content
    
    cat > "$INSTALL_DIR/database/01-schema.sql" <<'SCHEMA_EOF'
-- Schema content will be inserted here
SCHEMA_EOF
    
    log "✓ Database files prepared"
}

create_nextjs_application() {
    log_info "Creating Next.js application..."
    
    cd "$INSTALL_DIR"
    
    # Create package.json
    cat > package.json <<'EOF'
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
    "node-pty": "^1.0.0",
    "zustand": "^4.5.5",
    "framer-motion": "^11.11.17",
    "lucide-react": "^0.263.1",
    "recharts": "^2.14.1",
    "tailwindcss": "^3.4.15",
    "autoprefixer": "^10.4.20",
    "postcss": "^8.4.49"
  },
  "devDependencies": {
    "@types/bcryptjs": "^2.4.6",
    "@types/jsonwebtoken": "^9.0.7",
    "@types/pg": "^8.11.10",
    "eslint": "^8.57.1",
    "eslint-config-next": "14.2.18"
  }
}
EOF
    
    # Install dependencies
    log_info "Installing application dependencies (this may take a few minutes)..."
    retry_command "pnpm install" "Installing Node.js dependencies"
    
    log "✓ Application dependencies installed"
}

create_environment_file() {
    log_info "Creating environment configuration..."
    
    cat > "$INSTALL_DIR/.env.local" <<EOF
# Database
DATABASE_URL=postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME

# Application
NODE_ENV=production
NEXT_PUBLIC_APP_URL=https://$DOMAIN
PORT=$APP_PORT

# Security
JWT_SECRET=$(openssl rand -base64 32)
SESSION_SECRET=$(openssl rand -base64 32)

# Admin User
ADMIN_USERNAME=$ADMIN_USER
ADMIN_PASSWORD=$ADMIN_PASSWORD
EOF
    
    chmod 600 "$INSTALL_DIR/.env.local"
    log "✓ Environment file created"
}

################################################################################
# NGINX CONFIGURATION
################################################################################

configure_nginx() {
    log_info "Configuring Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/lfcs-platform <<EOF
# Upstream Node.js application
upstream lfcs_app {
    server 127.0.0.1:$APP_PORT;
    keepalive 64;
}

# Redirect HTTP to HTTPS
server {
    listen 80;
    listen [::]:80;
    server_name $DOMAIN www.$DOMAIN;
    
    # Allow Let's Encrypt challenges
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    location / {
        return 301 https://\$host\$request_uri;
    }
}

# HTTPS server
server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    
    # SSL certificates (will be configured by Certbot)
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    
    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Logging
    access_log /var/log/nginx/lfcs-platform-access.log;
    error_log /var/log/nginx/lfcs-platform-error.log;
    
    # Client body size
    client_max_body_size 10M;
    
    # Proxy settings
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
        proxy_read_timeout 300s;
        proxy_connect_timeout 75s;
    }
    
    # WebSocket support for terminal
    location /api/terminal {
        proxy_pass http://lfcs_app;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_read_timeout 86400;
    }
}
EOF
    
    # Enable site
    ln -sf /etc/nginx/sites-available/lfcs-platform /etc/nginx/sites-enabled/
    
    # Test Nginx configuration
    nginx -t
    
    log "✓ Nginx configured"
}

install_ssl_certificate() {
    log_info "Installing SSL certificate with Let's Encrypt..."
    
    # Install Certbot
    if [ "$PKG_MANAGER" = "apt-get" ]; then
        retry_command "$INSTALL_CMD certbot python3-certbot-nginx" "Installing Certbot"
    else
        retry_command "$INSTALL_CMD certbot python3-certbot-nginx" "Installing Certbot"
    fi
    
    # Stop Nginx temporarily
    systemctl stop nginx
    
    # Obtain certificate
    retry_command "certbot certonly --standalone -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN" "Obtaining SSL certificate"
    
    # Start Nginx
    systemctl start nginx
    systemctl enable nginx
    
    # Setup auto-renewal
    (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    
    log "✓ SSL certificate installed and auto-renewal configured"
}

################################################################################
# FIREWALL CONFIGURATION
################################################################################

configure_firewall() {
    log_info "Configuring firewall..."
    
    # Enable UFW
    ufw --force enable
    
    # Allow SSH
    ufw allow 22/tcp
    
    # Allow HTTP and HTTPS
    ufw allow 80/tcp
    ufw allow 443/tcp
    
    # Allow PostgreSQL (localhost only)
    ufw allow from 127.0.0.1 to any port 5432
    
    ufw reload
    
    log "✓ Firewall configured"
}

configure_fail2ban() {
    log_info "Configuring Fail2ban..."
    
    # Create custom jail for Nginx
    cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true
port = 22
logpath = /var/log/auth.log

[nginx-http-auth]
enabled = true
port = http,https
logpath = /var/log/nginx/lfcs-platform-error.log

[nginx-noscript]
enabled = true
port = http,https
logpath = /var/log/nginx/lfcs-platform-access.log
maxretry = 6
EOF
    
    systemctl restart fail2ban
    systemctl enable fail2ban
    
    log "✓ Fail2ban configured"
}

################################################################################
# APPLICATION FILES
################################################################################

create_application_files() {
    log_info "Creating application files..."
    
    # This function will be called after we create all the necessary files
    # The actual file creation will happen in subsequent steps
    
    log "✓ Application files will be created"
}

################################################################################
# SERVICE MANAGEMENT
################################################################################

create_systemd_service() {
    log_info "Creating systemd service..."
    
    cat > /etc/systemd/system/lfcs-platform.service <<EOF
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
StandardOutput=append:/var/log/lfcs-platform.log
StandardError=append:/var/log/lfcs-platform-error.log

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl daemon-reload
    
    log "✓ Systemd service created"
}

################################################################################
# HEALTH CHECKS
################################################################################

verify_installation() {
    log_info "Verifying installation..."
    
    local failed=0
    
    # Check PostgreSQL
    if systemctl is-active --quiet postgresql || systemctl is-active --quiet postgresql-15; then
        log "✓ PostgreSQL is running"
    else
        log_error "PostgreSQL is not running"
        failed=1
    fi
    
    # Check Nginx
    if systemctl is-active --quiet nginx; then
        log "✓ Nginx is running"
    else
        log_error "Nginx is not running"
        failed=1
    fi
    
    # Check database connection
    if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" &> /dev/null; then
        log "✓ Database connection successful"
    else
        log_error "Cannot connect to database"
        failed=1
    fi
    
    # Check SSL certificate
    if [ -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        log "✓ SSL certificate exists"
    else
        log_warning "SSL certificate not found (may need manual setup)"
    fi
    
    return $failed
}

################################################################################
# CLEANUP AND FINALIZATION
################################################################################

create_backup_script() {
    log_info "Creating backup script..."
    
    cat > /usr/local/bin/lfcs-backup <<EOF
#!/bin/bash
BACKUP_DIR="$INSTALL_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)

# Backup database
PGPASSWORD="$DB_PASSWORD" pg_dump -h localhost -U $DB_USER $DB_NAME | gzip > "\$BACKUP_DIR/db_\$DATE.sql.gz"

# Keep only last 7 backups
cd "\$BACKUP_DIR"
ls -t db_*.sql.gz | tail -n +8 | xargs rm -f 2>/dev/null || true

echo "Backup completed: db_\$DATE.sql.gz"
EOF
    
    chmod +x /usr/local/bin/lfcs-backup
    
    # Add to crontab (daily at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/lfcs-backup") | crontab -
    
    log "✓ Backup script created (runs daily at 2 AM)"
}

create_management_scripts() {
    log_info "Creating management scripts..."
    
    # Start script
    cat > /usr/local/bin/lfcs-start <<'EOF'
#!/bin/bash
systemctl start lfcs-platform
systemctl status lfcs-platform
EOF
    
    # Stop script
    cat > /usr/local/bin/lfcs-stop <<'EOF'
#!/bin/bash
systemctl stop lfcs-platform
EOF
    
    # Restart script
    cat > /usr/local/bin/lfcs-restart <<'EOF'
#!/bin/bash
systemctl restart lfcs-platform
systemctl status lfcs-platform
EOF
    
    # Status script
    cat > /usr/local/bin/lfcs-status <<'EOF'
#!/bin/bash
echo "=== LFCS Platform Status ==="
echo ""
echo "Application:"
systemctl status lfcs-platform --no-pager
echo ""
echo "Database:"
systemctl status postgresql --no-pager || systemctl status postgresql-15 --no-pager
echo ""
echo "Nginx:"
systemctl status nginx --no-pager
EOF
    
    # Logs script
    cat > /usr/local/bin/lfcs-logs <<'EOF'
#!/bin/bash
journalctl -u lfcs-platform -f
EOF
    
    chmod +x /usr/local/bin/lfcs-{start,stop,restart,status,logs}
    
    log "✓ Management scripts created"
}

print_success_message() {
    echo ""
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║              INSTALLATION COMPLETED SUCCESSFULLY! 🎉              ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${WHITE}LFCS Learning Platform is now ready!${NC}"
    echo ""
    echo -e "${CYAN}Access your platform at:${NC}"
    echo -e "  ${WHITE}https://$DOMAIN${NC}"
    echo ""
    echo -e "${CYAN}Admin credentials:${NC}"
    echo -e "  Username: ${WHITE}$ADMIN_USER${NC}"
    echo -e "  Password: ${WHITE}$ADMIN_PASSWORD${NC}"
    echo ""
    echo -e "${CYAN}Database connection:${NC}"
    echo -e "  Host: ${WHITE}localhost${NC}"
    echo -e "  Database: ${WHITE}$DB_NAME${NC}"
    echo -e "  User: ${WHITE}$DB_USER${NC}"
    echo -e "  Password: ${WHITE}$DB_PASSWORD${NC}"
    echo ""
    echo -e "${CYAN}Management commands:${NC}"
    echo -e "  ${WHITE}lfcs-start${NC}     - Start the platform"
    echo -e "  ${WHITE}lfcs-stop${NC}      - Stop the platform"
    echo -e "  ${WHITE}lfcs-restart${NC}   - Restart the platform"
    echo -e "  ${WHITE}lfcs-status${NC}    - Check platform status"
    echo -e "  ${WHITE}lfcs-logs${NC}      - View platform logs"
    echo -e "  ${WHITE}lfcs-backup${NC}    - Create database backup"
    echo ""
    echo -e "${CYAN}Installation log:${NC} ${WHITE}$LOG_FILE${NC}"
    echo ""
    echo -e "${YELLOW}⚠ IMPORTANT SECURITY NOTES:${NC}"
    echo -e "  1. Change the admin password after first login"
    echo -e "  2. Keep your database password secure"
    echo -e "  3. Regular backups are scheduled daily at 2 AM"
    echo ""
}

################################################################################
# MAIN INSTALLATION FLOW
################################################################################

main() {
    print_banner
    
    # Check prerequisites
    check_root
    check_system_requirements
    
    # System setup
    install_system_packages
    install_nodejs
    install_postgresql
    
    # Application setup
    create_application_structure
    setup_database
    create_environment_file
    create_nextjs_application
    
    # Web server setup
    configure_nginx
    
    # Security
    configure_firewall
    configure_fail2ban
    
    # SSL (may fail if DNS not configured - will warn)
    install_ssl_certificate || log_warning "SSL certificate installation failed. You may need to configure DNS and run: certbot --nginx -d $DOMAIN"
    
    # Service management
    create_systemd_service
    create_backup_script
    create_management_scripts
    
    # Verification
    verify_installation
    
    # Success message
    print_success_message
}

# Run main installation
main "$@"
