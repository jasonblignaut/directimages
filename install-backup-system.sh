#!/bin/bash
################################################################################
#                                                                              #
#   PROFESSIONAL BACKUP SYSTEM INSTALLER v2.0.0 — FINAL PRODUCTION VERSION    #
#                                                                              #
#   Full-featured cPanel → Local/Raspberry Pi Backup Solution                 #
#                                                                              #
#   Features: Fernet encryption · SSH key auth · Gunicorn/Nginx/SSL           #
#   Let's Encrypt (optional) · Systemd · Multi-tenant · Admin Panel           #
#   SMTP notifications · API tokens · Rate limiting · Health checks           #
#                                                                              #
################################################################################

set +e

# ─────────────────────────────────────────────────────────────────────────────
# CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
INSTALL_DIR="/opt/backup-system"
BACKUP_DIR="/backups"
LOG_FILE="/tmp/backup-system-install.log"
SCRIPT_VERSION="2.0.0"

CURRENT_USER=$(whoami)
SYSTEM_IP=$(hostname -I 2>/dev/null | awk '{print $1}')

# ─────────────────────────────────────────────────────────────────────────────
# COLORS
# ─────────────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'

# ─────────────────────────────────────────────────────────────────────────────
# HELPER FUNCTIONS
# ─────────────────────────────────────────────────────────────────────────────
log()            { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"; }
print_success()  { echo -e "${GREEN}  ✓ $1${NC}"; }
print_error()    { echo -e "${RED}  ✗ $1${NC}"; }
print_warning()  { echo -e "${YELLOW}  ⚠ $1${NC}"; }
print_info()     { echo -e "${BLUE}  ℹ $1${NC}"; }
print_phase()    { echo -e "\n${CYAN}╔══════════════════════════════════════════════════════════╗${NC}"; echo -e "${CYAN}║  $1${NC}"; echo -e "${CYAN}╚══════════════════════════════════════════════════════════╝${NC}\n"; }

check_root() {
    [ "$EUID" -eq 0 ] && { print_error "Do NOT run as root. Use a regular user."; exit 1; }
}

check_sudo() {
    sudo -n true 2>/dev/null && { print_success "Sudo access verified"; return 0; }
    print_warning "Testing sudo access..." ; sudo -v
    [ $? -ne 0 ] && { print_error "Sudo required. Run: sudo visudo"; exit 1; }
    print_success "Sudo access verified"
}

check_internet() {
    print_info "Checking internet connectivity..."
    for host in 8.8.8.8 1.1.1.1 208.67.222.222; do
        ping -c 1 -W 2 $host &>/dev/null && { print_success "Internet active"; return 0; }
    done
    print_error "No internet. Check network and retry."; exit 1
}

check_disk_space() {
    local avail=$(df /opt 2>/dev/null | awk 'NR==2{print int($4/1024)}')
    [ -z "$avail" ] && avail=$(df / | awk 'NR==2{print int($4/1024)}')
    [ "$avail" -lt 1000 ] && { print_error "Need 1GB+ free. Have ${avail}MB"; exit 1; }
    print_success "Disk space OK (${avail}MB available)"
}

detect_os() {
    print_info "Detecting OS..."
    [ -f /etc/os-release ] && { . /etc/os-release; print_success "Detected: $NAME $VERSION_ID"; } || print_warning "OS unknown"
}

install_package() {
    local pkg=$1 name=${2:-$1}
    echo -n "    $name... "
    (command -v $pkg &>/dev/null || dpkg -l 2>/dev/null | grep -q "^ii  $pkg ") && { echo -e "${GREEN}already installed${NC}"; return 0; }
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkg &>/dev/null && { echo -e "${GREEN}done${NC}"; return 0; }
    sudo apt-get update -qq &>/dev/null
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq $pkg &>/dev/null && { echo -e "${GREEN}done${NC}"; return 0; }
    echo -e "${RED}FAILED${NC}"; return 1
}

install_pip_package() {
    local pkg=$1 name=${2:-$1}
    echo -n "    $name... "
    pip3 list 2>/dev/null | grep -qi "^${pkg} " && { echo -e "${GREEN}already installed${NC}"; return 0; }
    pip3 install --break-system-packages -q $pkg &>/dev/null && { echo -e "${GREEN}done${NC}"; return 0; }
    pip3 install --user -q $pkg &>/dev/null && { echo -e "${GREEN}done${NC}"; return 0; }
    pip3 install -q $pkg &>/dev/null && { echo -e "${GREEN}done${NC}"; return 0; }
    echo -e "${RED}FAILED${NC}"; return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 1 — WELCOME
# ─────────────────────────────────────────────────────────────────────────────
phase_1_welcome() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║    ██████╗ ██╗   ██╗ ██╗ ██╗  ██╗ █████╗  ██████╗                      ║
║    ██╔══██╗██║   ██║██╔╝ ██║ ██╔╝██╔══██╗██╔════╝                      ║
║    ██║  ██║██║   ██║█████╔╝  █████╔╝███████║██║                         ║
║    ██║  ██║██║   ██║██╔═██╗  ██╔═██╗██╔══██║██║                         ║
║    ██████╔╝╚██████╔╝██║  ██╗ ██║  ██║██║  ██║╚██████╗                   ║
║    ╚═════╝  ╚═════╝ ╚═╝  ╚═╝ ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝                   ║
║                                                                          ║
║              Professional Backup & Recovery System v2.0                   ║
║                    Production Installation                                ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
BANNER
    echo -e "${NC}"

    echo "  This installer sets up a complete backup solution:"
    echo "    • Automated cPanel → local SFTP backups (LFTP)"
    echo "    • Web dashboard with admin panel & analytics"
    echo "    • Secure credential encryption (Fernet AES-128)"
    echo "    • SMTP email notifications & storage alerts"
    echo "    • SSL (self-signed or Let's Encrypt), Nginx, Gunicorn"
    echo "    • API tokens, user management, log viewer"
    echo ""
    echo -e "  ${YELLOW}Estimated install time: 10–15 minutes${NC}"
    echo ""
    echo "  System:"
    echo "    User : $CURRENT_USER"
    echo "    IP   : $SYSTEM_IP"
    echo "    Path : $INSTALL_DIR"
    echo ""

    # Check for existing installation
    if [ -d "$INSTALL_DIR" ] && [ -f "$INSTALL_DIR/config/system.conf" ]; then
        echo -e "  ${YELLOW}⚠ Existing installation detected!${NC}"
        echo "    1) Re-install (overwrites config, keeps backups)"
        echo "    2) Uninstall"
        echo "    3) Cancel"
        read -p "  Choice [1]: " exist_choice
        exist_choice=${exist_choice:-1}
        case $exist_choice in
            2) uninstall_system; exit 0 ;;
            3) echo "Cancelled."; exit 0 ;;
            1) print_warning "Proceeding with re-install..." ;;
            *) echo "Cancelled."; exit 0 ;;
        esac
        echo ""
    fi

    read -p "  Continue with installation? (yes/no): " confirm
    [ "$confirm" != "yes" ] && { echo "  Cancelled."; exit 0; }
    log "Installation v$SCRIPT_VERSION started by $CURRENT_USER"
}

uninstall_system() {
    echo ""
    read -p "  This will remove the backup system (backups are KEPT). Continue? (yes/no): " uconfirm
    [ "$uconfirm" != "yes" ] && return
    echo -n "  Uninstalling..."
    sudo systemctl stop backup-dashboard 2>/dev/null; sudo systemctl disable backup-dashboard 2>/dev/null
    sudo rm -f /etc/systemd/system/backup-dashboard.service
    sudo rm -f /etc/nginx/sites-available/backup-dashboard /etc/nginx/sites-enabled/backup-dashboard
    sudo systemctl daemon-reload 2>/dev/null; sudo nginx -s reload 2>/dev/null
    sudo rm -rf "$INSTALL_DIR"
    echo -e " ${GREEN}done${NC}"
    echo -e "  ${GREEN}✓ Uninstalled. Backups preserved in $BACKUP_DIR${NC}"
    log "System uninstalled"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 2 — PRE-FLIGHT
# ─────────────────────────────────────────────────────────────────────────────
phase_2_preflight() {
    print_phase "PHASE 1: Pre-flight Checks"
    check_root; check_sudo; check_internet; check_disk_space; detect_os
    print_success "All pre-flight checks passed"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 3 — DEPENDENCIES
# ─────────────────────────────────────────────────────────────────────────────
phase_3_dependencies() {
    print_phase "PHASE 2: Installing Dependencies"
    print_info "Updating package lists..."
    sudo apt-get update -qq &>/dev/null
    print_success "Package lists updated"

    echo ""
    echo "  System packages:"
    install_package "python3"     "Python 3"
    install_package "python3-pip" "pip3"
    install_package "python3-venv" "venv"
    install_package "lftp"        "LFTP"
    install_package "sqlite3"     "SQLite3"
    install_package "nginx"       "Nginx"
    install_package "openssl"     "OpenSSL"
    install_package "curl"        "cURL"
    install_package "net-tools"   "Net Tools"
    install_package "certbot"     "Certbot"
    install_package "python3-certbot-nginx" "Certbot-Nginx"

    echo ""
    echo "  Python packages:"
    install_pip_package "gunicorn"          "Gunicorn"
    install_pip_package "flask"             "Flask"
    install_pip_package "flask-login"       "Flask-Login"
    install_pip_package "cryptography"      "Cryptography"
    install_pip_package "Pillow"            "Pillow"
    install_pip_package "requests"          "Requests"
    install_pip_package "werkzeug"          "Werkzeug"

    print_success "All dependencies installed"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 4 — CONFIGURATION
# ─────────────────────────────────────────────────────────────────────────────
phase_4_configuration() {
    print_phase "PHASE 3: Configuration"

    echo -e "  ${YELLOW}Company / Branding${NC}"
    read -p "    Company Name: " COMPANY_NAME
    while [ -z "$COMPANY_NAME" ]; do print_error "Cannot be empty"; read -p "    Company Name: " COMPANY_NAME; done

    echo ""
    echo -e "  ${YELLOW}cPanel Server${NC}"
    read -p "    Hostname (e.g. cp71.domains.co.za): " CPANEL_HOST
    while [ -z "$CPANEL_HOST" ]; do print_error "Cannot be empty"; read -p "    Hostname: " CPANEL_HOST; done
    read -p "    Username: " CPANEL_USER
    while [ -z "$CPANEL_USER" ]; do print_error "Cannot be empty"; read -p "    Username: " CPANEL_USER; done
    read -sp "    Password: " CPANEL_PASS; echo ""
    while [ -z "$CPANEL_PASS" ]; do print_error "Cannot be empty"; read -sp "    Password: " CPANEL_PASS; echo ""; done
    read -p "    SFTP Port [22000]: " CPANEL_PORT; CPANEL_PORT=${CPANEL_PORT:-22000}

    echo ""
    echo -e "  ${YELLOW}Backup Schedule${NC}"
    echo "    1) Daily at 2 AM   2) Daily at 3 AM   3) Daily at 4 AM"
    echo "    4) Every 6 hours   5) Weekly Mon 3AM   6) Custom"
    read -p "    Choice [2]: " SCH; SCH=${SCH:-2}
    case $SCH in
        1) CRON_SCHEDULE="0 2 * * *";   SCHEDULE_DESC="Daily at 2 AM"      ;;
        2) CRON_SCHEDULE="0 3 * * *";   SCHEDULE_DESC="Daily at 3 AM"      ;;
        3) CRON_SCHEDULE="0 4 * * *";   SCHEDULE_DESC="Daily at 4 AM"      ;;
        4) CRON_SCHEDULE="0 */6 * * *"; SCHEDULE_DESC="Every 6 hours"      ;;
        5) CRON_SCHEDULE="0 3 * * 1";   SCHEDULE_DESC="Weekly Mon 3 AM"    ;;
        6) read -p "    Cron (min hr dom mon dow): " CRON_SCHEDULE; SCHEDULE_DESC="Custom: $CRON_SCHEDULE" ;;
        *) CRON_SCHEDULE="0 3 * * *";   SCHEDULE_DESC="Daily at 3 AM"      ;;
    esac

    echo ""
    echo -e "  ${YELLOW}SSL Certificate${NC}"
    echo "    1) Self-signed (instant, works on LAN)"
    echo "    2) Let's Encrypt (requires public domain + internet)"
    read -p "    Choice [1]: " SSL_CHOICE; SSL_CHOICE=${SSL_CHOICE:-1}
    USE_LETSENCRYPT=false
    if [ "$SSL_CHOICE" = "2" ]; then
        read -p "    Domain name: " LE_DOMAIN
        while [ -z "$LE_DOMAIN" ]; do print_error "Domain required"; read -p "    Domain: " LE_DOMAIN; done
        read -p "    Email (for LE): " LE_EMAIL
        USE_LETSENCRYPT=true
    fi

    echo ""
    echo -e "  ${YELLOW}Dashboard Administrator${NC}"
    read -p "    Admin Username [admin]: " ADMIN_USER; ADMIN_USER=${ADMIN_USER:-admin}
    read -sp "    Admin Password: " ADMIN_PASS; echo ""
    while [ -z "$ADMIN_PASS" ]; do print_error "Cannot be empty"; read -sp "    Admin Password: " ADMIN_PASS; echo ""; done
    read -sp "    Confirm Password: " ADMIN_PASS2; echo ""
    while [ "$ADMIN_PASS" != "$ADMIN_PASS2" ]; do
        print_error "Passwords don't match"
        read -sp "    Admin Password: " ADMIN_PASS; echo ""
        read -sp "    Confirm Password: " ADMIN_PASS2; echo ""
    done
    read -p "    Admin Email: " ADMIN_EMAIL

    echo ""
    echo -e "  ${GREEN}━━━ Configuration Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "    Company  : $COMPANY_NAME"
    echo "    cPanel   : $CPANEL_USER@$CPANEL_HOST:$CPANEL_PORT"
    echo "    Schedule : $SCHEDULE_DESC"
    echo "    SSL      : $([ "$USE_LETSENCRYPT" = true ] && echo "Let's Encrypt ($LE_DOMAIN)" || echo "Self-signed")"
    echo "    Dashboard: https://$SYSTEM_IP:8443"
    echo "    Admin    : $ADMIN_USER"
    echo -e "  ${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    read -p "  Proceed? (yes/no): " CONFIRM_CFG
    [ "$CONFIRM_CFG" != "yes" ] && { echo "  Cancelled."; exit 0; }
    log "Configuration complete: $COMPANY_NAME / $CPANEL_HOST"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 5 — DIRECTORY STRUCTURE
# ─────────────────────────────────────────────────────────────────────────────
phase_5_directories() {
    print_phase "PHASE 4: Directory Structure"
    sudo mkdir -p "$INSTALL_DIR"/{config,scripts,dashboard,.ssh}
    sudo mkdir -p "$INSTALL_DIR/dashboard"/{templates,static/{css,js,uploads}}
    sudo mkdir -p "$BACKUP_DIR"/{cpanel,logs}
    sudo chown -R $CURRENT_USER:$CURRENT_USER "$INSTALL_DIR" "$BACKUP_DIR"
    chmod 700 "$INSTALL_DIR/config" "$INSTALL_DIR/.ssh"
    chmod 755 "$INSTALL_DIR/scripts" "$INSTALL_DIR/dashboard"

    cat > "$INSTALL_DIR/config/system.conf" << SYSCONF
# Backup System Configuration — generated $(date)
COMPANY_NAME="$COMPANY_NAME"
CPANEL_HOST="$CPANEL_HOST"
CPANEL_USER="$CPANEL_USER"
CPANEL_PORT="$CPANEL_PORT"
ADMIN_USER="$ADMIN_USER"
ADMIN_EMAIL="$ADMIN_EMAIL"
INSTALL_DIR="$INSTALL_DIR"
BACKUP_DIR="$BACKUP_DIR"
CRON_SCHEDULE="$CRON_SCHEDULE"
SCHEDULE_DESC="$SCHEDULE_DESC"
USE_LETSENCRYPT="$USE_LETSENCRYPT"
LE_DOMAIN="$LE_DOMAIN"
INSTALLED_DATE="$(date '+%Y-%m-%d %H:%M:%S')"
INSTALLED_BY="$CURRENT_USER"
SYSTEM_IP="$SYSTEM_IP"
SYSCONF
    chmod 600 "$INSTALL_DIR/config/system.conf"
    print_success "Directory structure & config saved"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 6 — SSH KEYS
# ─────────────────────────────────────────────────────────────────────────────
phase_6_ssh_keys() {
    print_phase "PHASE 5: SSH Key Configuration"
    SSH_KEY_PATH="$INSTALL_DIR/.ssh/id_rsa"
    SSH_KEY_AUTHORIZED=false

    if [ -f ~/.ssh/cpanel_backup ]; then
        read -p "  Reuse existing ~/.ssh/cpanel_backup key? [yes]: " REUSE; REUSE=${REUSE:-yes}
        if [ "$REUSE" = "yes" ]; then
            cp ~/.ssh/cpanel_backup "$SSH_KEY_PATH"
            cp ~/.ssh/cpanel_backup.pub "$SSH_KEY_PATH.pub" 2>/dev/null
            chmod 600 "$SSH_KEY_PATH"; print_success "Existing key copied"
        else
            ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "backup@$(echo $COMPANY_NAME | tr ' ' '_')" &>/dev/null
            print_success "New 4096-bit RSA key generated"
        fi
    else
        print_info "Generating SSH key pair..."
        ssh-keygen -t rsa -b 4096 -f "$SSH_KEY_PATH" -N "" -C "backup@$(echo $COMPANY_NAME | tr ' ' '_')" &>/dev/null
        print_success "New 4096-bit RSA key generated"
    fi

    print_info "Testing SFTP connection to $CPANEL_HOST:$CPANEL_PORT ..."
    if timeout 10 sftp -i "$SSH_KEY_PATH" -P "$CPANEL_PORT" \
        -o StrictHostKeyChecking=no -o ConnectTimeout=5 \
        "$CPANEL_USER@$CPANEL_HOST" <<< "ls" &>/dev/null; then
        print_success "SFTP connection successful — key authorized"
        SSH_KEY_AUTHORIZED=true
    else
        print_warning "SFTP not yet authorized (expected — key needs adding to cPanel)"
    fi

    SSH_PUBLIC_KEY=$(cat "$SSH_KEY_PATH.pub")
    log "SSH key configured. Authorized=$SSH_KEY_AUTHORIZED"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 7 — CREDENTIAL ENCRYPTION
# ─────────────────────────────────────────────────────────────────────────────
phase_7_encryption() {
    print_phase "PHASE 6: Encrypting Credentials"
    print_info "Generating Fernet encryption key..."
    ENCRYPTION_KEY=$(python3 -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())")
    echo "$ENCRYPTION_KEY" > "$INSTALL_DIR/config/.key"
    chmod 600 "$INSTALL_DIR/config/.key"
    print_success "Encryption key generated"

    print_info "Encrypting cPanel password..."
    python3 -c "
from cryptography.fernet import Fernet
key = b'${ENCRYPTION_KEY}'
cipher = Fernet(key)
encrypted = cipher.encrypt(b'${CPANEL_PASS}')
print(encrypted.decode())
" > "$INSTALL_DIR/config/credentials.enc"
    chmod 600 "$INSTALL_DIR/config/credentials.enc"

    # Generate Flask secret key
    python3 -c "import secrets; print(secrets.token_hex(64))" > "$INSTALL_DIR/config/.secret_key"
    chmod 600 "$INSTALL_DIR/config/.secret_key"

    print_success "All credentials encrypted & secured"
    log "Encryption phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 8 — BACKUP SCRIPTS
# ─────────────────────────────────────────────────────────────────────────────
phase_8_backup_scripts() {
    print_phase "PHASE 7: Creating Backup Scripts"

    # ── backup.sh ──────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/scripts/backup.sh" << 'BKPSCRIPT'
#!/bin/bash
################################################################################
# Production Backup Script v2.0 — auto-generated
################################################################################
INST="__INSTALL_DIR__"
BK="__BACKUP_DIR__"
source "$INST/config/system.conf"

DATE=$(date +%Y%m%d_%H%M%S)
BPATH="$BK/cpanel/$DATE"
LOGF="$BK/logs/backup_$DATE.log"
SSHK="$INST/.ssh/id_rsa"

mkdir -p "$BPATH"/{website,mail,databases,ssl,etc}

log()  { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGF"; }
notify_db() {
    python3 -c "
import sqlite3
conn = sqlite3.connect('$INST/config/dashboard.db')
conn.execute('INSERT INTO notifications (type, message) VALUES (?, ?)', ('$1', '$2'))
conn.commit(); conn.close()
" 2>/dev/null
}

# Decrypt password
DPASS=$(python3 -c "
from cryptography.fernet import Fernet
with open('$INST/config/.key') as f:  key = f.read().strip().encode()
with open('$INST/config/credentials.enc') as f:  enc = f.read().strip().encode()
print(Fernet(key).decrypt(enc).decode())
")

log "========== BACKUP STARTED =========="
log "Company: $COMPANY_NAME | Host: $CPANEL_HOST:$CPANEL_PORT | User: $CPANEL_USER"

LFTP_BASE="set sftp:auto-confirm yes
set sftp:connect-program 'ssh -a -x -i $SSHK -p $CPANEL_PORT -o StrictHostKeyChecking=no'
open -u $CPANEL_USER,$DPASS sftp://$CPANEL_HOST"

# Website
log "Backing up website files..."
lftp -c "$LFTP_BASE
mirror --verbose --delete --parallel=4 --exclude .ftpquota --exclude error_log --exclude cgi-bin public_html $BPATH/website
bye" >> "$LOGF" 2>&1
W_SIZE=$(du -sh "$BPATH/website" 2>/dev/null | cut -f1); W_FILES=$(find "$BPATH/website" -type f 2>/dev/null | wc -l)
log "✓ Website: $W_SIZE ($W_FILES files)"

# Email
log "Backing up email..."
lftp -c "$LFTP_BASE
mirror --verbose --parallel=2 mail $BPATH/mail
bye" >> "$LOGF" 2>&1
M_SIZE=$(du -sh "$BPATH/mail" 2>/dev/null | cut -f1); log "✓ Email: $M_SIZE"

# SSL
log "Backing up SSL..."
lftp -c "$LFTP_BASE
mirror --verbose ssl $BPATH/ssl
bye" >> "$LOGF" 2>&1
S_SIZE=$(du -sh "$BPATH/ssl" 2>/dev/null | cut -f1); log "✓ SSL: $S_SIZE"

# Config
log "Backing up config..."
lftp -c "$LFTP_BASE
mirror --verbose etc $BPATH/etc
bye" >> "$LOGF" 2>&1
E_SIZE=$(du -sh "$BPATH/etc" 2>/dev/null | cut -f1); log "✓ Config: $E_SIZE"

# Databases
log "Downloading database backups..."
lftp -c "$LFTP_BASE
mget -c -O $BPATH/databases database_backup_*.sql.gz
bye" >> "$LOGF" 2>&1
DB_CNT=$(ls -1 "$BPATH/databases/"*.sql.gz 2>/dev/null | wc -l)
DB_SIZE=$(du -sh "$BPATH/databases" 2>/dev/null | cut -f1)
[ $DB_CNT -gt 0 ] && log "✓ Databases: $DB_SIZE ($DB_CNT files)" || log "⚠ No database backups found"

TOTAL=$(du -sh "$BPATH" 2>/dev/null | cut -f1); TFILES=$(find "$BPATH" -type f 2>/dev/null | wc -l)
log "========== BACKUP COMPLETE =========="
log "Total: $TOTAL ($TFILES files) → $BPATH"

# Summary file
cat > "$BPATH/BACKUP_SUMMARY.txt" << EOF
Company : $COMPANY_NAME
Date    : $(date)
Total   : $TOTAL ($TFILES files)
Website : $W_SIZE ($W_FILES files)
Email   : $M_SIZE | SSL: $S_SIZE | Config: $E_SIZE
Databases: $DB_SIZE ($DB_CNT files)
EOF

# Retention cleanup (reads from DB, defaults to 30 days)
RETAIN=$(python3 -c "
import sqlite3
try:
    c = sqlite3.connect('$INST/config/dashboard.db').cursor()
    c.execute(\"SELECT value FROM settings WHERE key='retention_days'\")
    r = c.fetchone(); print(r[0] if r else '30')
except: print('30')
")
find "$BK/cpanel" -maxdepth 1 -type d -name "202*" -mtime +$RETAIN -exec rm -rf {} \; 2>/dev/null
log "Cleanup done (retention: ${RETAIN}d)"

# DB notification
notify_db "backup_completed" "Backup completed: $TOTAL ($TFILES files)"

# Email notification
python3 << 'PYNOTIFY'
import sqlite3, smtplib, os
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from cryptography.fernet import Fernet
try:
    inst = '__INSTALL_DIR__'
    db = sqlite3.connect(os.path.join(inst, 'config', 'dashboard.db'))
    db.row_factory = sqlite3.Row
    smtp = db.execute('SELECT * FROM smtp_config WHERE id=1').fetchone()
    if smtp and smtp['enabled']:
        with open(os.path.join(inst, 'config', '.key')) as f: key = f.read().strip().encode()
        pw = Fernet(key).decrypt(smtp['password_encrypted'].encode()).decode() if smtp['password_encrypted'] else ''
        admins = [r['email'] for r in db.execute("SELECT email FROM users WHERE role='admin' AND email!=''").fetchall()]
        if admins:
            msg = MIMEMultipart(); msg['From'] = f"{smtp['from_name']} <{smtp['from_email']}>"
            msg['To'] = ','.join(admins); msg['Subject'] = f"[{os.environ.get('COMPANY_NAME','Backup')}] Backup Completed"
            msg.attach(MIMEText('<h3>✓ Backup Completed</h3><p>Your scheduled backup finished successfully.</p>', 'html'))
            s = smtplib.SMTP(smtp['host'], smtp['port'] or 587, timeout=10); s.ehlo()
            if smtp['use_tls']: s.starttls()
            if smtp['username']: s.login(smtp['username'], pw)
            s.sendmail(smtp['from_email'], admins, msg.as_string()); s.close()
except: pass
PYNOTIFY

exit 0
BKPSCRIPT
    sed -i "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "$INSTALL_DIR/scripts/backup.sh"
    sed -i "s|__BACKUP_DIR__|${BACKUP_DIR}|g" "$INSTALL_DIR/scripts/backup.sh"
    chmod +x "$INSTALL_DIR/scripts/backup.sh"
    print_success "backup.sh created"

    # ── health_check.sh ────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/scripts/health_check.sh" << 'HEALTHCK'
#!/bin/bash
INST="__INSTALL_DIR__"; BK="__BACKUP_DIR__"
OK=0; WARN=0; CRIT=0
chk() { echo "  [$1] $2"; }
# Dashboard service
systemctl is-active --quiet backup-dashboard && chk "OK  " "Dashboard service" || { chk "CRIT" "Dashboard service DOWN"; ((CRIT++)); }
# Nginx
systemctl is-active --quiet nginx && chk "OK  " "Nginx" || { chk "WARN" "Nginx not running"; ((WARN++)); }
# Backup directory
[ -d "$BK/cpanel" ] && chk "OK  " "Backup directory" || { chk "CRIT" "Backup directory missing"; ((CRIT++)); }
# Last backup age
LAST=$(ls -td "$BK"/cpanel/202* 2>/dev/null | head -1)
if [ -n "$LAST" ]; then
    AGE=$(( ($(date +%s) - $(stat -c %Y "$LAST")) / 3600 ))
    [ $AGE -lt 48 ] && chk "OK  " "Last backup ${AGE}h ago" || { chk "WARN" "Last backup ${AGE}h ago (>48h)"; ((WARN++)); }
else chk "WARN" "No backups found"; ((WARN++)); fi
# Disk space
PCT=$(df "$BK" | awk 'NR==2{gsub(/%/,""); print $5}')
[ "$PCT" -lt 80 ] && chk "OK  " "Disk usage ${PCT}%" || { [ "$PCT" -lt 90 ] && { chk "WARN" "Disk ${PCT}%"; ((WARN++)); } || { chk "CRIT" "Disk CRITICAL ${PCT}%"; ((CRIT++)); }; }
# Summary
echo ""
[ $CRIT -gt 0 ] && { echo "STATUS: CRITICAL"; exit 2; }
[ $WARN -gt 0 ] && { echo "STATUS: WARNING"; exit 1; }
echo "STATUS: HEALTHY"; exit 0
HEALTHCK
    sed -i "s|__INSTALL_DIR__|${INSTALL_DIR}|g" "$INSTALL_DIR/scripts/health_check.sh"
    sed -i "s|__BACKUP_DIR__|${BACKUP_DIR}|g" "$INSTALL_DIR/scripts/health_check.sh"
    chmod +x "$INSTALL_DIR/scripts/health_check.sh"
    print_success "health_check.sh created"
    log "Backup scripts phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 9 — DATABASE
# ─────────────────────────────────────────────────────────────────────────────
phase_9_database() {
    print_phase "PHASE 8: Database Setup"
    print_info "Initializing SQLite database..."

    INSTALL_DIR="$INSTALL_DIR" ADMIN_USER="$ADMIN_USER" ADMIN_PASS="$ADMIN_PASS" \
    ADMIN_EMAIL="$ADMIN_EMAIL" COMPANY_NAME="$COMPANY_NAME" \
    CRON_SCHEDULE="$CRON_SCHEDULE" SCHEDULE_DESC="$SCHEDULE_DESC" \
    python3 << 'PYDBEOF'
import sqlite3, os
from werkzeug.security import generate_password_hash

d = os.environ['INSTALL_DIR']
db = sqlite3.connect(f'{d}/config/dashboard.db')
c = db.cursor()

c.executescript('''
CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    username TEXT UNIQUE NOT NULL,
    password_hash TEXT NOT NULL,
    email TEXT DEFAULT '',
    role TEXT DEFAULT 'user',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP
);
CREATE TABLE IF NOT EXISTS settings (
    key TEXT PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS smtp_config (
    id INTEGER PRIMARY KEY,
    host TEXT DEFAULT '',
    port INTEGER DEFAULT 587,
    username TEXT DEFAULT '',
    password_encrypted TEXT DEFAULT '',
    use_tls INTEGER DEFAULT 1,
    from_email TEXT DEFAULT '',
    from_name TEXT DEFAULT 'Backup System',
    enabled INTEGER DEFAULT 0
);
CREATE TABLE IF NOT EXISTS api_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    token TEXT UNIQUE NOT NULL,
    name TEXT DEFAULT '',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    FOREIGN KEY(user_id) REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS notifications (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    type TEXT DEFAULT '',
    message TEXT DEFAULT '',
    read INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
''')

# Admin user
pw_hash = generate_password_hash(os.environ['ADMIN_PASS'], method='pbkdf2:sha256')
c.execute('INSERT OR REPLACE INTO users (id,username,password_hash,email,role) VALUES (1,?,?,?,?)',
          (os.environ['ADMIN_USER'], pw_hash, os.environ.get('ADMIN_EMAIL',''), 'admin'))

# Default settings
defaults = {
    'company_name': os.environ['COMPANY_NAME'],
    'retention_days': '30',
    'notify_success': '1', 'notify_failure': '1', 'notify_storage': '1',
    'storage_alert_threshold': '80',
    'cron_schedule': os.environ.get('CRON_SCHEDULE','0 3 * * *'),
    'schedule_desc': os.environ.get('SCHEDULE_DESC','Daily at 3 AM'),
}
for k,v in defaults.items():
    c.execute('INSERT OR IGNORE INTO settings (key,value) VALUES (?,?)', (k,v))

# Default SMTP row
c.execute('INSERT OR IGNORE INTO smtp_config (id) VALUES (1)')

db.commit(); db.close()
print("OK")
PYDBEOF
    chmod 600 "$INSTALL_DIR/config/dashboard.db"
    print_success "Database initialized (users, settings, smtp, tokens, notifications)"
    log "Database phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 10 — FLASK APPLICATION
# ─────────────────────────────────────────────────────────────────────────────
phase_10_flask_app() {
    print_phase "PHASE 9: Flask Dashboard Application"
    print_info "Writing app.py..."

    cat > "$INSTALL_DIR/dashboard/app.py" << 'FLASKAPP'
#!/usr/bin/env python3
"""Professional Backup Dashboard v2.0 — Multi-tenant, secure, production-ready"""
import os, sys, sqlite3, glob, subprocess, secrets, hashlib, json, smtplib, logging
from datetime import datetime, timedelta
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from functools import wraps
from contextlib import contextmanager
from flask import Flask, render_template, request, redirect, url_for, jsonify, send_file
from flask_login import LoginManager, UserMixin, login_user, logout_user, login_required, current_user
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.utils import secure_filename
from cryptography.fernet import Fernet

# ── Config ─────────────────────────────────────────────────────────────────
INST  = os.environ.get('INSTALL_DIR', '/opt/backup-system')
BK    = os.environ.get('BACKUP_DIR', '/backups')
DBPATH = os.path.join(INST, 'config', 'dashboard.db')
KEYPATH = os.path.join(INST, 'config', '.key')
UPLOADS = os.path.join(INST, 'dashboard', 'static', 'uploads')
LOGDIR = os.path.join(BK, 'logs')
ALLOWED_EXT = {'png','jpg','jpeg','gif','svg'}

# ── App Init ───────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['UPLOAD_FOLDER'] = UPLOADS
app.config['MAX_CONTENT_LENGTH'] = 2*1024*1024

logging.basicConfig(
    filename=os.path.join(LOGDIR,'dashboard.log') if os.path.isdir(LOGDIR) else '/tmp/dash.log',
    level=logging.INFO, format='%(asctime)s [%(levelname)s] %(message)s')
log = logging.getLogger(__name__)

sk_path = os.path.join(INST,'config','.secret_key')
app.secret_key = open(sk_path).read().strip() if os.path.exists(sk_path) else secrets.token_hex(64)
app.config.update(
    SESSION_COOKIE_SECURE=True, SESSION_COOKIE_HTTPONLY=True, SESSION_COOKIE_SAMESITE='Lax',
    REMEMBER_COOKIE_DURATION=timedelta(days=30), REMEMBER_COOKIE_SECURE=True, REMEMBER_COOKIE_HTTPONLY=True)

# ── Database ───────────────────────────────────────────────────────────────
@contextmanager
def db():
    c = sqlite3.connect(DBPATH); c.row_factory = sqlite3.Row; c.execute("PRAGMA foreign_keys=ON")
    try:
        yield c; c.commit()
    except:
        c.rollback(); raise
    finally:
        c.close()

def enc(data):
    with open(KEYPATH) as f: k = f.read().strip().encode()
    return Fernet(k).encrypt(data.encode()).decode()

def dec(data):
    with open(KEYPATH) as f: k = f.read().strip().encode()
    return Fernet(k).decrypt(data.encode()).decode()

def cfg(key, default=None):
    try:
        with db() as c:
            r = c.execute('SELECT value FROM settings WHERE key=?',(key,)).fetchone()
            return r['value'] if r else default
    except: return default

def set_cfg(key, val):
    with db() as c: c.execute('INSERT OR REPLACE INTO settings(key,value,updated_at) VALUES(?,?,?)',(key,val,datetime.utcnow().isoformat()))

def add_notif(ntype, msg):
    try:
        with db() as c: c.execute('INSERT INTO notifications(type,message) VALUES(?,?)',(ntype,msg))
    except: pass

# ── User Model ─────────────────────────────────────────────────────────────
class User(UserMixin):
    def __init__(self, id, username, email, role):
        self.id=id; self.username=username; self.email=email; self.role=role
    @property
    def is_admin(self): return self.role=='admin'

lm = LoginManager(); lm.init_app(app); lm.login_view='login'; lm.login_message=None

@lm.user_loader
def load_user(uid):
    with db() as c:
        u = c.execute('SELECT id,username,email,role FROM users WHERE id=?',(uid,)).fetchone()
        return User(u['id'],u['username'],u['email'],u['role']) if u else None

def admin_required(f):
    @wraps(f)
    def w(*a,**kw):
        if not current_user.is_admin: return redirect(url_for('index'))
        return f(*a,**kw)
    return w

def tctx():
    logo = '/static/uploads/logo.png' if os.path.exists(os.path.join(UPLOADS,'logo.png')) else None
    return {'company_name':cfg('company_name','Backup System'),'logo_path':logo,'now':datetime.now()}

def get_smtp():
    with db() as c:
        r = c.execute('SELECT * FROM smtp_config WHERE id=1').fetchone()
        if r:
            d = dict(r)
            if d.get('password_encrypted'):
                try: d['password']=dec(d['password_encrypted'])
                except: d['password']=''
            return d
    return None

def parse_backups():
    folders = sorted(glob.glob(f'{BK}/cpanel/202*'), reverse=True)
    result = []
    for f in folders:
        try:
            fn = os.path.basename(f); ds=fn[:8]; ts=fn[9:15]
            bdate = datetime.strptime(ds+ts,'%Y%m%d%H%M%S')
            sr = subprocess.run(['du','-sh',f],capture_output=True,text=True,timeout=5)
            size = sr.stdout.split()[0] if sr.returncode==0 else 'N/A'
            sb = subprocess.run(['du','-sb',f],capture_output=True,text=True,timeout=5)
            sbytes = int(sb.stdout.split()[0]) if sb.returncode==0 else 0
            comps={}
            for comp in ['website','mail','ssl','etc','databases']:
                cp = os.path.join(f,comp)
                if os.path.exists(cp):
                    cr = subprocess.run(['du','-sh',cp],capture_output=True,text=True,timeout=3)
                    comps[comp]=cr.stdout.split()[0] if cr.returncode==0 else '0'
                else: comps[comp]='0'
            dbp=os.path.join(f,'databases'); dbf=[x for x in os.listdir(dbp) if x.endswith('.sql.gz')] if os.path.isdir(dbp) else []
            fc = subprocess.run(['find',f,'-type','f'],capture_output=True,text=True,timeout=5)
            result.append({'folder':fn,'date':bdate.strftime('%Y-%m-%d %H:%M:%S'),'_date':bdate,
                          'size':size,'size_bytes':sbytes,'components':comps,'db_files':dbf,
                          'has_database':len(dbf)>0,'file_count':len(fc.stdout.strip().split('\n')) if fc.returncode==0 else 0})
        except Exception as e:
            log.error(f"Parse error {f}: {e}"); continue
    return result

# ── AUTH ROUTES ────────────────────────────────────────────────────────────
@app.route('/login', methods=['GET','POST'])
def login():
    if current_user.is_authenticated: return redirect(url_for('index'))
    error=None
    if request.method=='POST':
        uname=request.form.get('username','').strip(); pwd=request.form.get('password','')
        remember=request.form.get('remember')=='on'
        with db() as c:
            u = c.execute('SELECT * FROM users WHERE username=?',(uname,)).fetchone()
        if u and check_password_hash(u['password_hash'], pwd):
            login_user(User(u['id'],u['username'],u['email'],u['role']), remember=remember)
            with db() as c: c.execute('UPDATE users SET last_login=? WHERE id=?',(datetime.utcnow().isoformat(),u['id']))
            log.info(f"Login: {uname}")
            return redirect(url_for('index'))
        error='Invalid credentials'; log.warning(f"Failed login: {uname}")
    ctx=tctx(); ctx['error']=error
    return render_template('login.html',**ctx)

@app.route('/logout')
@login_required
def logout():
    logout_user(); return redirect(url_for('login'))

# ── PAGE ROUTES ────────────────────────────────────────────────────────────
@app.route('/')
@login_required
def index():
    ctx=tctx(); ctx['active']='dashboard'; return render_template('dashboard.html',**ctx)

@app.route('/backups')
@login_required
def backups_page():
    ctx=tctx(); ctx['active']='backups'; return render_template('backups.html',**ctx)

@app.route('/admin')
@login_required
@admin_required
def admin_page():
    ctx=tctx(); ctx['active']='admin'
    with db() as c: ctx['users']=c.execute('SELECT * FROM users ORDER BY created_at DESC').fetchall()
    ctx['smtp']=get_smtp() or {}
    cf=os.path.join(INST,'config','system.conf'); ctx['sys_cfg']={}
    if os.path.exists(cf):
        for line in open(cf):
            if '=' in line and not line.startswith('#'):
                k,v=line.strip().split('=',1); ctx['sys_cfg'][k]=v.strip('"')
    return render_template('admin.html',**ctx)

@app.route('/settings')
@login_required
def settings_page():
    ctx=tctx(); ctx['active']='settings'
    with db() as c: ctx['tokens']=c.execute('SELECT * FROM api_tokens WHERE user_id=? ORDER BY created_at DESC',(current_user.id,)).fetchall()
    ctx['retention']=cfg('retention_days','30'); ctx['n_success']=cfg('notify_success','1')
    ctx['n_failure']=cfg('notify_failure','1'); ctx['n_storage']=cfg('notify_storage','1')
    ctx['s_threshold']=cfg('storage_alert_threshold','80')
    return render_template('settings.html',**ctx)

# ── API ROUTES ─────────────────────────────────────────────────────────────
@app.route('/api/overview')
@login_required
def api_overview():
    bks=parse_backups(); latest=bks[0] if bks else None
    du,dub=None,None
    try:
        r=subprocess.run(['df','-h',BK],capture_output=True,text=True,timeout=5); ls=r.stdout.strip().split('\n')
        if len(ls)>=2:
            p=ls[1].split(); du={'total':p[1],'used':p[2],'available':p[3],'percent':p[4].replace('%','')}
        r2=subprocess.run(['df','-B1',BK],capture_output=True,text=True,timeout=5); ls2=r2.stdout.strip().split('\n')
        if len(ls2)>=2:
            p2=ls2[1].split(); dub={'total':int(p2[1]),'used':int(p2[2]),'available':int(p2[3])}
    except: pass
    nc=0
    try:
        with db() as c: nc=c.execute('SELECT COUNT(*) as n FROM notifications WHERE read=0').fetchone()['n']
    except: pass
    lat=None
    if latest:
        lat={k:v for k,v in latest.items() if k!='_date'}
    return jsonify(total_backups=len(bks),latest=lat,disk=du,disk_bytes=dub,
                   schedule=cfg('schedule_desc','Check cron'),notif_count=nc)

@app.route('/api/backups')
@login_required
def api_backups():
    period=request.args.get('period','month'); bks=parse_backups()
    now=datetime.now()
    cuts={'today':now-timedelta(days=1),'week':now-timedelta(weeks=1),
          'month':now-timedelta(days=30),'all':datetime(2000,1,1)}
    cut=cuts.get(period,cuts['month'])
    out=[{k:v for k,v in b.items() if k!='_date'} for b in bks if b['_date']>=cut]
    return jsonify(backups=out)

@app.route('/api/trend')
@login_required
def api_trend():
    bks=parse_backups()
    return jsonify(trend=[{'date':b['date'][:10],'bytes':b['size_bytes'],'size':b['size']} for b in reversed(bks[-30:])])

@app.route('/api/notifications')
@login_required
def api_notifs():
    with db() as c: ns=c.execute('SELECT * FROM notifications ORDER BY created_at DESC LIMIT 20').fetchall()
    return jsonify(notifications=[dict(n) for n in ns])

@app.route('/api/notifications/read', methods=['POST'])
@login_required
def mark_read():
    with db() as c: c.execute('UPDATE notifications SET read=1')
    return jsonify(ok=True)

# ── DOWNLOAD ROUTES ────────────────────────────────────────────────────────
@app.route('/download/full/<folder>')
@login_required
def dl_full(folder):
    p=os.path.join(BK,'cpanel',folder)
    if not os.path.isdir(p): return jsonify(error='Not found'),404
    out=f'/tmp/{folder}_full.tar.gz'
    try:
        subprocess.run(['tar','-czf',out,'-C',f'{BK}/cpanel',folder],check=True,timeout=600)
        return send_file(out,as_attachment=True,download_name=f'{folder}_FULL.tar.gz',mimetype='application/gzip')
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/download/files/<folder>')
@login_required
def dl_files(folder):
    p=os.path.join(BK,'cpanel',folder,'website')
    if not os.path.isdir(p): return jsonify(error='Not found'),404
    out=f'/tmp/{folder}_files.tar.gz'
    try:
        subprocess.run(['tar','-czf',out,'-C',os.path.join(BK,'cpanel',folder),'website'],check=True,timeout=600)
        return send_file(out,as_attachment=True,download_name=f'{folder}_FILES.tar.gz',mimetype='application/gzip')
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/download/database/<folder>/<fname>')
@login_required
def dl_db(folder,fname):
    if not fname.endswith('.sql.gz'): return jsonify(error='Invalid'),400
    p=os.path.join(BK,'cpanel',folder,'databases',fname)
    if not os.path.isfile(p): return jsonify(error='Not found'),404
    return send_file(p,as_attachment=True,download_name=fname)

@app.route('/download/log/<fname>')
@login_required
@admin_required
def dl_log(fname):
    if not fname.endswith('.log'): return jsonify(error='Invalid'),400
    p=os.path.join(LOGDIR,fname)
    if not os.path.isfile(p): return jsonify(error='Not found'),404
    return send_file(p,as_attachment=True,download_name=fname)

# ── BACKUP MANAGEMENT ──────────────────────────────────────────────────────
@app.route('/api/backup/delete/<folder>', methods=['POST'])
@login_required
@admin_required
def del_backup(folder):
    import shutil
    p=os.path.join(BK,'cpanel',folder)
    if not os.path.isdir(p): return jsonify(error='Not found'),404
    if len(glob.glob(f'{BK}/cpanel/202*'))<=1: return jsonify(error='Cannot delete last backup'),400
    try:
        shutil.rmtree(p); add_notif('deleted',f'Backup {folder} deleted by {current_user.username}')
        log.info(f"Deleted {folder}"); return jsonify(ok=True)
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/api/backup/trigger', methods=['POST'])
@login_required
@admin_required
def trigger_backup():
    script=os.path.join(INST,'scripts','backup.sh')
    if not os.path.isfile(script): return jsonify(error='Script missing'),500
    try:
        p=subprocess.Popen([script],stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        add_notif('triggered',f'Manual backup by {current_user.username} (PID {p.pid})')
        log.info(f"Backup triggered PID={p.pid}")
        return jsonify(ok=True,message='Backup started in background')
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/api/restore/<folder>')
@login_required
def restore_info(folder):
    p=os.path.join(BK,'cpanel',folder)
    if not os.path.isdir(p): return jsonify(error='Not found'),404
    return jsonify(instructions=f"""RESTORE GUIDE — {folder}
═══════════════════════════════════════
1. WEBSITE: Download "Files Only" → extract → upload website/ contents to public_html/ via cPanel File Manager or SFTP.
2. DATABASE: Download .sql.gz → gunzip → cPanel MySQL → phpMyAdmin Import. Update wp-config.php if DB name/user changed.
3. EMAIL: From Full Backup, upload mail/ directory contents to cPanel mail path via SFTP.
4. SSL: From Full Backup, upload ssl/ certificates via cPanel SSL Manager.
5. EMERGENCY FULL RESTORE: Download Full Backup → extract → restore each component above → verify → update DNS if needed.
⚠ Always test in staging first. Back up current files before restoring.""")

# ── ADMIN ROUTES ───────────────────────────────────────────────────────────
@app.route('/admin/users/add', methods=['POST'])
@login_required
@admin_required
def add_user():
    un=request.form.get('username','').strip(); em=request.form.get('email','').strip()
    role=request.form.get('role','user'); pw=request.form.get('password','')
    if not un or not pw: return jsonify(error='Username & password required'),400
    if len(pw)<6: return jsonify(error='Password min 6 chars'),400
    try:
        with db() as c:
            if c.execute('SELECT id FROM users WHERE username=?',(un,)).fetchone():
                return jsonify(error='Username exists'),400
            c.execute('INSERT INTO users(username,password_hash,email,role) VALUES(?,?,?,?)',
                     (un,generate_password_hash(pw,method='pbkdf2:sha256'),em,role))
        return jsonify(ok=True)
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/admin/users/delete/<int:uid>', methods=['POST'])
@login_required
@admin_required
def del_user(uid):
    if uid==current_user.id: return jsonify(error='Cannot delete yourself'),400
    with db() as c:
        u=c.execute('SELECT * FROM users WHERE id=?',(uid,)).fetchone()
        if not u: return jsonify(error='Not found'),404
        if u['role']=='admin':
            ac=c.execute("SELECT COUNT(*) as n FROM users WHERE role='admin'").fetchone()['n']
            if ac<=1: return jsonify(error='Cannot delete last admin'),400
        c.execute('DELETE FROM users WHERE id=?',(uid,))
    return jsonify(ok=True)

@app.route('/admin/users/password', methods=['POST'])
@login_required
@admin_required
def chg_pw():
    uid=request.form.get('user_id',type=int); pw=request.form.get('password','')
    if not pw or len(pw)<6: return jsonify(error='Min 6 chars'),400
    with db() as c: c.execute('UPDATE users SET password_hash=? WHERE id=?',
                              (generate_password_hash(pw,method='pbkdf2:sha256'),uid))
    return jsonify(ok=True)

@app.route('/admin/smtp/save', methods=['POST'])
@login_required
@admin_required
def save_smtp():
    f=request.form; host=f.get('host','').strip(); port=f.get('port',587,type=int)
    user=f.get('user','').strip(); pw=f.get('password','').strip()
    tls=1 if f.get('tls')=='on' else 0; frm=f.get('from_email','').strip()
    frm_name=f.get('from_name','').strip(); enabled=1 if f.get('enabled')=='on' else 0
    enc_pw=''
    if pw: enc_pw=enc(pw)
    elif host:
        s=get_smtp()
        if s and s.get('password_encrypted'): enc_pw=s['password_encrypted']
    with db() as c:
        c.execute('INSERT OR REPLACE INTO smtp_config(id,host,port,username,password_encrypted,use_tls,from_email,from_name,enabled) VALUES(1,?,?,?,?,?,?,?,?)',
                 (host,port,user,enc_pw,tls,frm,frm_name,enabled))
    return jsonify(ok=True)

@app.route('/admin/smtp/test', methods=['POST'])
@login_required
@admin_required
def test_smtp():
    s=get_smtp()
    if not s or not s.get('host'): return jsonify(error='SMTP not configured'),400
    try:
        msg=MIMEMultipart(); msg['From']=f"{s.get('from_name','')} <{s['from_email']}>"
        msg['To']=s['from_email']; msg['Subject']='SMTP Test — Backup System'
        msg.attach(MIMEText('<h3>✓ SMTP Test Successful</h3><p>Email notifications are working.</p>','html'))
        srv=smtplib.SMTP(s['host'],s.get('port',587),timeout=10); srv.ehlo()
        if s.get('use_tls'): srv.starttls()
        if s.get('username'): srv.login(s['username'],s.get('password',''))
        srv.sendmail(s['from_email'],[s['from_email']],msg.as_string()); srv.close()
        return jsonify(ok=True,message='Test email sent!')
    except Exception as e: return jsonify(error=f'SMTP failed: {e}'),500

@app.route('/admin/logo/upload', methods=['POST'])
@login_required
@admin_required
def upload_logo():
    if 'logo' not in request.files: return jsonify(error='No file'),400
    f=request.files['logo']
    if f.filename=='' or '.' not in f.filename: return jsonify(error='Invalid file'),400
    if f.filename.rsplit('.',1)[1].lower() not in ALLOWED_EXT: return jsonify(error='Bad type'),400
    try: f.save(os.path.join(UPLOADS,'logo.png')); return jsonify(ok=True)
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/admin/logo/delete', methods=['POST'])
@login_required
@admin_required
def del_logo():
    p=os.path.join(UPLOADS,'logo.png')
    if os.path.exists(p): os.remove(p)
    return jsonify(ok=True)

@app.route('/admin/schedule/save', methods=['POST'])
@login_required
@admin_required
def save_schedule():
    cron=request.form.get('cron','').strip()
    if not cron or len(cron.split())!=5: return jsonify(error='Invalid cron (5 fields needed)'),400
    try:
        cf=os.path.join(INST,'config','system.conf'); lines=open(cf).readlines()
        with open(cf,'w') as fh:
            for l in lines:
                fh.write(f'CRON_SCHEDULE="{cron}"\n' if l.startswith('CRON_SCHEDULE=') else l)
        script=os.path.join(INST,'scripts','backup.sh'); logf=os.path.join(BK,'logs','cron.log')
        r=subprocess.run(['crontab','-l'],capture_output=True,text=True)
        lines=[l for l in (r.stdout if r.returncode==0 else '').split('\n') if script not in l and l.strip()]
        lines.append(f'{cron} {script} >> {logf} 2>&1'); lines.append('')
        p=subprocess.Popen(['crontab','-'],stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE)
        p.communicate(input='\n'.join(lines).encode())
        set_cfg('cron_schedule',cron)
        return jsonify(ok=True)
    except Exception as e: return jsonify(error=str(e)),500

@app.route('/admin/logs')
@login_required
@admin_required
def get_logs():
    logs=[]
    if os.path.isdir(LOGDIR):
        for lf in sorted(glob.glob(f'{LOGDIR}/*.log'),reverse=True)[:15]:
            logs.append({'name':os.path.basename(lf),'size':os.path.getsize(lf),
                        'modified':datetime.fromtimestamp(os.path.getmtime(lf)).strftime('%Y-%m-%d %H:%M')})
    return jsonify(logs=logs)

@app.route('/admin/logs/<fname>')
@login_required
@admin_required
def log_content(fname):
    if not fname.endswith('.log'): return jsonify(error='Invalid'),400
    p=os.path.join(LOGDIR,fname)
    if not os.path.isfile(p): return jsonify(error='Not found'),404
    try:
        r=subprocess.run(['tail','-n','500',p],capture_output=True,text=True,timeout=5)
        return jsonify(content=r.stdout)
    except Exception as e: return jsonify(error=str(e)),500

# ── SETTINGS ROUTES ────────────────────────────────────────────────────────
@app.route('/settings/save', methods=['POST'])
@login_required
def save_settings():
    f=request.form
    set_cfg('retention_days',f.get('retention','30'))
    set_cfg('notify_success','1' if f.get('n_success')=='on' else '0')
    set_cfg('notify_failure','1' if f.get('n_failure')=='on' else '0')
    set_cfg('notify_storage','1' if f.get('n_storage')=='on' else '0')
    set_cfg('storage_alert_threshold',f.get('s_threshold','80'))
    return jsonify(ok=True)

@app.route('/settings/tokens/create', methods=['POST'])
@login_required
def create_token():
    name=request.form.get('name','').strip()
    if not name: return jsonify(error='Name required'),400
    token=secrets.token_urlsafe(32); thash=hashlib.sha256(token.encode()).hexdigest()
    exp=(datetime.utcnow()+timedelta(days=request.form.get('days',30,type=int))).isoformat()
    with db() as c: c.execute('INSERT INTO api_tokens(user_id,token,name,expires_at) VALUES(?,?,?,?)',
                              (current_user.id,thash,name,exp))
    return jsonify(ok=True,token=token,warning='Save this token — it will not be shown again')

@app.route('/settings/tokens/delete/<int:tid>', methods=['POST'])
@login_required
def del_token(tid):
    with db() as c: c.execute('DELETE FROM api_tokens WHERE id=? AND user_id=?',(tid,current_user.id))
    return jsonify(ok=True)

# ── HEALTH ─────────────────────────────────────────────────────────────────
@app.route('/api/health')
def health():
    checks={'app':'ok','db':'ok','backup_dir':'ok'}
    try:
        with db() as c: c.execute('SELECT 1')
    except: checks['db']='error'
    if not os.path.isdir(BK): checks['backup_dir']='error'
    st='healthy' if all(v=='ok' for v in checks.values()) else 'degraded'
    return jsonify(status=st,checks=checks)

if __name__=='__main__':
    app.run(host='0.0.0.0', port=int(os.environ.get('PORT',8080)), debug=False)
FLASKAPP
    chmod +x "$INSTALL_DIR/dashboard/app.py"
    print_success "Flask application created"
    log "Flask app phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 11 — TEMPLATES
# ─────────────────────────────────────────────────────────────────────────────
phase_11_templates() {
    print_phase "PHASE 10: Dashboard Templates"

    # ── base.html ──────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/base.html" << 'BASHTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>{{ company_name }} — {% block title %}Dashboard{% endblock %}</title>
<link rel="stylesheet" href="/static/css/style.css">
{% block extra_css %}{% endblock %}
</head>
<body>
<aside class="sidebar">
  <div class="sidebar-head">
    {% if logo_path %}<img src="{{ logo_path }}" alt="Logo" class="logo-img">{% else %}<div class="logo-icon">B</div>{% endif %}
    <span class="logo-txt">{{ company_name }}</span>
  </div>
  <nav class="sidebar-nav">
    <a href="/" class="nav-item {% if active=='dashboard' %}active{% endif %}"><span class="ni">⊞</span> Dashboard</a>
    <a href="/backups" class="nav-item {% if active=='backups' %}active{% endif %}"><span class="ni">⬛</span> Backups</a>
    {% if current_user.is_admin %}
    <a href="/admin" class="nav-item {% if active=='admin' %}active{% endif %}"><span class="ni">⚙</span> Admin</a>
    {% endif %}
    <a href="/settings" class="nav-item {% if active=='settings' %}active{% endif %}"><span class="ni">☰</span> Settings</a>
  </nav>
  <div class="sidebar-foot">
    <div class="user-bar">
      <span class="u-name">{{ current_user.username }}</span>
      <span class="u-role badge-{{ current_user.role }}">{{ current_user.role }}</span>
    </div>
    <a href="/logout" class="logout-btn">Logout</a>
  </div>
</aside>
<main class="main">
  <header class="topbar">
    <div class="top-left">{% block breadcrumb %}{% endblock %}</div>
    <div class="top-right">
      <button class="notif-btn" onclick="toggleNotifs()" id="notif-btn"><span class="bell">🔔</span><span class="nbadge" id="nbadge" style="display:none">0</span></button>
    </div>
  </header>
  <div class="notif-panel" id="notif-panel">
    <div class="notif-header"><span>Notifications</span><button onclick="markRead()" class="btn-sm">Mark all read</button></div>
    <div class="notif-list" id="notif-list"><p class="notif-empty">No notifications</p></div>
  </div>
  <section class="content">{% block content %}{% endblock %}</section>
</main>
<div class="toast-wrap" id="toasts"></div>
<div class="modal-overlay" id="modal-overlay" onclick="closeModal()"></div>
<div class="modal" id="modal"><div class="modal-head"><h3 id="modal-title"></h3><button onclick="closeModal()" class="modal-close">×</button></div><div class="modal-body" id="modal-body"></div></div>
<script src="/static/js/app.js"></script>
{% block extra_js %}{% endblock %}
</body>
</html>
BASHTML
    print_success "base.html"

    # ── login.html ─────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/login.html" << 'LOGINHTML'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>{{ company_name }} — Login</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:linear-gradient(135deg,#0f1117 0%,#1a1d2e 50%,#161928 100%);min-height:100vh;display:flex;align-items:center;justify-content:center;color:#e2e8f0}
.card{background:#1a1d2e;border:1px solid #2d3150;border-radius:20px;padding:48px 40px;width:100%;max-width:400px;box-shadow:0 30px 80px rgba(0,0,0,0.5)}
.logo-wrap{text-align:center;margin-bottom:28px}
.logo-wrap .l-icon{width:72px;height:72px;margin:0 auto 16px;background:linear-gradient(135deg,#6c63ff,#8b5cf6);border-radius:16px;display:flex;align-items:center;justify-content:center;font-size:36px;font-weight:700;color:#fff}
.logo-wrap .l-icon img{width:100%;height:100%;object-fit:cover;border-radius:16px}
.logo-wrap h1{font-size:24px;font-weight:600;color:#fff}
.logo-wrap p{color:#8892b0;font-size:13px;margin-top:4px}
.form-g{margin-bottom:20px}
.form-g label{display:block;color:#c4cce0;font-size:13px;font-weight:500;margin-bottom:6px}
.form-g input[type=text],.form-g input[type=password]{width:100%;padding:12px 16px;background:#222639;border:1.5px solid #2d3150;border-radius:10px;color:#e2e8f0;font-size:14px;outline:none;transition:.2s}
.form-g input:focus{border-color:#6c63ff;box-shadow:0 0 0 3px rgba(108,99,255,.15)}
.remember{display:flex;align-items:center;gap:8px;margin-bottom:24px}
.remember input[type=checkbox]{accent-color:#6c63ff;width:16px;height:16px}
.remember label{color:#8892b0;font-size:13px;cursor:pointer}
.btn-login{width:100%;padding:13px;background:linear-gradient(135deg,#6c63ff,#8b5cf6);border:none;border-radius:10px;color:#fff;font-size:15px;font-weight:600;cursor:pointer;transition:.2s;box-shadow:0 4px 16px rgba(108,99,255,.4)}
.btn-login:hover{transform:translateY(-1px);box-shadow:0 6px 24px rgba(108,99,255,.5)}
.err{background:rgba(231,76,60,.1);border:1px solid #e74c3c;color:#f1948a;padding:12px 16px;border-radius:8px;margin-bottom:20px;font-size:13px;text-align:center}
</style>
</head>
<body>
<div class="card">
  <div class="logo-wrap">
    {% if logo_path %}<div class="l-icon"><img src="{{ logo_path }}" alt="Logo"></div>{% else %}<div class="l-icon">B</div>{% endif %}
    <h1>{{ company_name }}</h1>
    <p>Backup & Recovery System</p>
  </div>
  {% if error %}<div class="err">{{ error }}</div>{% endif %}
  <form method="POST" action="/login">
    <div class="form-g"><label>Username</label><input type="text" name="username" autofocus required></div>
    <div class="form-g"><label>Password</label><input type="password" name="password" required></div>
    <div class="remember"><input type="checkbox" id="rem" name="remember"><label for="rem">Remember me (30 days)</label></div>
    <button type="submit" class="btn-login">Log In</button>
  </form>
</div>
</body>
</html>
LOGINHTML
    print_success "login.html"

    # ── dashboard.html ─────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/dashboard.html" << 'DASHHTML'
{% extends 'base.html' %}
{% block title %}Dashboard{% endblock %}
{% block breadcrumb %}<h2 class="page-title">Dashboard</h2>{% endblock %}
{% block content %}
<div class="stats-grid">
  <div class="stat-card"><div class="stat-label">Total Backups</div><div class="stat-val" id="s-total">—</div></div>
  <div class="stat-card"><div class="stat-label">Latest Backup</div><div class="stat-val stat-sm" id="s-latest">—</div></div>
  <div class="stat-card"><div class="stat-label">Storage Used</div><div class="stat-val stat-sm" id="s-storage">—</div></div>
  <div class="stat-card"><div class="stat-label">Next Backup</div><div class="stat-val stat-sm" id="s-next">—</div></div>
</div>
<div class="action-bar">
  <button class="btn btn-primary btn-lg" onclick="triggerBackup()">▶ Run Backup Now</button>
  <span class="action-info" id="last-size"></span>
</div>
<div class="charts-grid">
  <div class="chart-card"><h3 class="chart-title">Storage Usage</h3><div class="chart-wrap"><canvas id="storageChart"></canvas></div><div class="chart-legend" id="storage-legend"></div></div>
  <div class="chart-card"><h3 class="chart-title">Backup Size Trend (30d)</h3><div class="chart-wrap"><canvas id="trendChart"></canvas></div></div>
</div>
<div class="chart-card"><h3 class="chart-title">Latest Backup — Component Breakdown</h3><div class="chart-wrap" style="height:180px"><canvas id="compChart"></canvas></div></div>
{% endblock %}
{% block extra_js %}
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
<script>
let storageC=null, trendC=null, compC=null;
const darkGrid='rgba(45,49,80,0.6)', darkText='#8892b0';
function fmtBytes(b){if(!b)return'0';const u=['B','KB','MB','GB','TB'];let i=0;while(b>=1024&&i<u.length-1){b/=1024;i++}return b.toFixed(1)+' '+u[i]}

async function loadDash(){
  const ov=await(await fetch('/api/overview')).json();
  document.getElementById('s-total').textContent=ov.total_backups;
  if(ov.latest){
    document.getElementById('s-latest').textContent=ov.latest.date;
    document.getElementById('last-size').textContent=`Size: ${ov.latest.size} · ${ov.latest.file_count} files`;
    renderComps(ov.latest.components);
  }
  if(ov.disk){
    document.getElementById('s-storage').textContent=`${ov.disk.used} / ${ov.disk.total} (${ov.disk.percent}%)`;
    renderStorage(ov.disk_bytes);
  }
  document.getElementById('s-next').textContent=ov.schedule||'—';
  updateBadge(ov.notif_count);
  const tr=await(await fetch('/api/trend')).json();
  renderTrend(tr.trend);
}

function renderStorage(d){
  if(!d)return;
  const ctx=document.getElementById('storageChart').getContext('2d');
  const data={labels:['Used','Available'],datasets:[{data:[d.used,d.available],backgroundColor:['#6c63ff','#2d3150'],borderWidth:0}]};
  if(storageC){storageC.data=data;storageC.update();}
  else storageC=new Chart(ctx,{type:'doughnut',data,options:{responsive:true,maintainAspectRatio:false,cutout:'65%',
    plugins:{legend:{display:false}}}});
  document.getElementById('storage-legend').innerHTML=`<span style="color:#6c63ff">■</span> Used ${fmtBytes(d.used)} &nbsp; <span style="color:#2d3150">■</span> Free ${fmtBytes(d.available)}`;
}

function renderTrend(trend){
  if(!trend||!trend.length)return;
  const ctx=document.getElementById('trendChart').getContext('2d');
  const labels=trend.map(t=>t.date), vals=trend.map(t=>t.bytes);
  const data={labels,datasets:[{label:'Size',data:vals,borderColor:'#6c63ff',backgroundColor:'rgba(108,99,255,0.08)',fill:true,tension:0.4,pointRadius:2,pointHoverRadius:5}]};
  const opts={responsive:true,maintainAspectRatio:false,scales:{x:{ticks:{color:darkText,maxTicksLimit:6},grid:{color:darkGrid}},y:{ticks:{color:darkText,callback:fmtBytes},grid:{color:darkGrid}}},plugins:{legend:{display:false}}};
  if(trendC){trendC.data=data;trendC.update();}
  else trendC=new Chart(ctx,{type:'line',data,options:opts});
}

function renderComps(c){
  if(!c)return;
  const ctx=document.getElementById('compChart').getContext('2d');
  const map=function(s){if(!s||s=='0')return 0;const m={KB:1024,MB:1048576,GB:1073741824,TB:1099511627776};const n=parseFloat(s);const u=s.replace(/[0-9.]/g,'').trim();return n*(m[u]||1)};
  const labels=['Website','Email','SSL','Config','Databases'];
  const colors=['#6c63ff','#4a90d9','#4caf7c','#f5a623','#e74c3c'];
  const vals=[map(c.website),map(c.mail),map(c.ssl),map(c.etc),map(c.databases)];
  const data={labels,datasets:[{data:vals,backgroundColor:colors,borderRadius:4,borderWidth:0}]};
  const opts={indexAxis:'y',responsive:true,maintainAspectRatio:false,scales:{x:{ticks:{color:darkText,callback:fmtBytes},grid:{color:darkGrid}},y:{ticks:{color:darkText}}},plugins:{legend:{display:false}}};
  if(compC){compC.data=data;compC.update();}
  else compC=new Chart(ctx,{type:'bar',data,options:opts});
}

async function triggerBackup(){
  showToast('Triggering backup...','info');
  const r=await fetch('/api/backup/trigger',{method:'POST'});
  const d=await r.json();
  showToast(d.message||d.error, r.ok?'success':'error');
}

loadDash(); setInterval(loadDash,60000);
</script>
{% endblock %}
DASHHTML
    print_success "dashboard.html"

    # ── backups.html ───────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/backups.html" << 'BKPHTML'
{% extends 'base.html' %}
{% block title %}Backups{% endblock %}
{% block breadcrumb %}<h2 class="page-title">Backups</h2>{% endblock %}
{% block content %}
<div class="toolbar">
  <select id="period-filter" onchange="loadBackups()" class="select">
    <option value="today">Today</option><option value="week">This Week</option>
    <option value="month" selected>This Month</option><option value="all">All Time</option>
  </select>
  <span class="toolbar-info" id="bk-count"></span>
</div>
<div class="table-wrap">
  <table class="data-table">
    <thead><tr><th>Date & Time</th><th>Size</th><th>Components</th><th>Actions</th></tr></thead>
    <tbody id="bk-tbody"><tr><td colspan="4" class="empty-cell">Loading…</td></tr></tbody>
  </table>
</div>
{% endblock %}
{% block extra_js %}
<script>
async function loadBackups(){
  const period=document.getElementById('period-filter').value;
  const r=await(await fetch('/api/backups?period='+period)).json();
  const tbody=document.getElementById('bk-tbody');
  document.getElementById('bk-count').textContent=`${r.backups.length} backup(s)`;
  if(!r.backups.length){tbody.innerHTML='<tr><td colspan="4" class="empty-cell">No backups in this period</td></tr>';return;}
  tbody.innerHTML=r.backups.map(b=>`
    <tr>
      <td class="date-cell">${b.date}</td>
      <td><span class="size-badge">${b.size}</span><br><small class="text-muted">${b.file_count} files</small></td>
      <td class="comp-cell">
        <span class="comp-tag">💻 ${b.components.website||'0'}</span>
        <span class="comp-tag">📧 ${b.components.mail||'0'}</span>
        ${b.has_database?`<span class="comp-tag db-tag">🗄️ DB(${b.db_files.length})</span>`:''}
      </td>
      <td class="actions-cell">
        <button class="btn btn-sm" onclick="window.location='/download/full/${b.folder}'">Full</button>
        <button class="btn btn-sm btn-secondary" onclick="window.location='/download/files/${b.folder}'">Files</button>
        ${b.has_database?`<button class="btn btn-sm btn-db" onclick="dlDb('${b.folder}',${JSON.stringify(b.db_files)})">DB</button>`:''}
        <button class="btn btn-sm btn-ghost" onclick="showRestore('${b.folder}')">Restore</button>
        {% if current_user.is_admin %}<button class="btn btn-sm btn-danger" onclick="deleteBackup('${b.folder}')">✕</button>{% endif %}
      </td>
    </tr>`).join('');
}

function dlDb(folder,files){
  if(files.length===1){window.location='/download/database/'+folder+'/'+files[0];return;}
  let html='<h4 style="margin-bottom:12px">Select database file:</h4>';
  files.forEach(f=>{html+=`<a href="/download/database/${folder}/${f}" class="db-link">${f}</a>`});
  openModal('Download Database',html);
}

async function showRestore(folder){
  const r=await(await fetch('/api/restore/'+folder)).json();
  openModal('Restore Instructions',`<pre class="restore-pre">${r.instructions}</pre>`);
}

async function deleteBackup(folder){
  if(!confirm('Delete this backup permanently?'))return;
  const r=await fetch('/api/backup/delete/'+folder,{method:'POST'});
  const d=await r.json();
  showToast(d.ok?'Backup deleted':'Error: '+d.error, d.ok?'success':'error');
  if(d.ok)loadBackups();
}

loadBackups();
</script>
{% endblock %}
BKPHTML
    print_success "backups.html"

    # ── admin.html ─────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/admin.html" << 'ADMINHTML'
{% extends 'base.html' %}
{% block title %}Admin Panel{% endblock %}
{% block breadcrumb %}<h2 class="page-title">Admin Panel</h2>{% endblock %}
{% block content %}
<div class="tabs">
  <button class="tab-btn active" onclick="switchTab('users')">Users</button>
  <button class="tab-btn" onclick="switchTab('smtp')">SMTP</button>
  <button class="tab-btn" onclick="switchTab('company')">Company</button>
  <button class="tab-btn" onclick="switchTab('schedule')">Schedule</button>
  <button class="tab-btn" onclick="switchTab('alerts')">Alerts</button>
  <button class="tab-btn" onclick="switchTab('logs')">Logs</button>
</div>

<!-- USERS TAB -->
<div class="tab-panel active" id="tab-users">
  <div class="panel-header"><h3>User Management</h3></div>
  <div class="add-form">
    <input type="text" id="u-name" placeholder="Username" class="input-sm">
    <input type="email" id="u-email" placeholder="Email">
    <select id="u-role" class="select-sm"><option value="user">User</option><option value="admin">Admin</option></select>
    <input type="password" id="u-pass" placeholder="Password (min 6)">
    <button class="btn btn-primary btn-sm" onclick="addUser()">Add User</button>
  </div>
  <table class="data-table">
    <thead><tr><th>Username</th><th>Email</th><th>Role</th><th>Last Login</th><th>Actions</th></tr></thead>
    <tbody>
    {% for u in users %}
    <tr>
      <td>{{ u.username }}{% if u.id == current_user.id %} <span class="you-badge">you</span>{% endif %}</td>
      <td>{{ u.email or '—' }}</td>
      <td><span class="badge-{{ u.role }}">{{ u.role }}</span></td>
      <td>{{ u.last_login or 'Never' }}</td>
      <td>
        <button class="btn btn-sm btn-ghost" onclick="pwModal({{ u.id }})">Password</button>
        {% if u.id != current_user.id %}<button class="btn btn-sm btn-danger" onclick="delUser({{ u.id }},'{{ u.username }}')">✕</button>{% endif %}
      </td>
    </tr>{% endfor %}
    </tbody>
  </table>
</div>

<!-- SMTP TAB -->
<div class="tab-panel" id="tab-smtp">
  <div class="panel-header"><h3>SMTP Email Configuration</h3><p class="text-muted">Configure email for backup notifications and alerts</p></div>
  <form id="smtp-form" class="settings-form">
    <div class="form-row">
      <div class="form-g"><label>SMTP Host</label><input type="text" name="host" value="{{ smtp.host or '' }}" placeholder="smtp.gmail.com"></div>
      <div class="form-g"><label>Port</label><input type="number" name="port" value="{{ smtp.port or 587 }}" style="width:100px"></div>
    </div>
    <div class="form-row">
      <div class="form-g"><label>Username</label><input type="text" name="user" value="{{ smtp.username or '' }}" placeholder="your@email.com"></div>
      <div class="form-g"><label>Password</label><input type="password" name="password" placeholder="{{ '••••••••' if smtp.password_encrypted else 'Enter password' }}"></div>
    </div>
    <div class="form-row">
      <div class="form-g"><label>From Email</label><input type="email" name="from_email" value="{{ smtp.from_email or '' }}"></div>
      <div class="form-g"><label>From Name</label><input type="text" name="from_name" value="{{ smtp.from_name or 'Backup System' }}"></div>
    </div>
    <div class="checks-row">
      <label class="chk"><input type="checkbox" name="tls" {% if smtp.use_tls %}checked{% endif %}><span>Use TLS</span></label>
      <label class="chk"><input type="checkbox" name="enabled" {% if smtp.enabled %}checked{% endif %}><span>Enable notifications</span></label>
    </div>
    <div class="btn-row">
      <button type="button" class="btn btn-primary" onclick="saveSMTP()">Save</button>
      <button type="button" class="btn btn-secondary" onclick="testSMTP()">Test Email</button>
    </div>
  </form>
</div>

<!-- COMPANY TAB -->
<div class="tab-panel" id="tab-company">
  <div class="panel-header"><h3>Company Branding</h3></div>
  <div class="logo-upload-area">
    <div class="logo-preview" id="logo-preview">
      {% if logo_path %}<img src="{{ logo_path }}" alt="Logo">{% else %}<span class="logo-placeholder">No logo</span>{% endif %}
    </div>
    <div class="logo-actions">
      <label class="btn btn-secondary btn-sm file-label"><input type="file" id="logo-file" accept=".png,.jpg,.jpeg,.gif,.svg" style="display:none" onchange="uploadLogo(this)">Upload Logo</label>
      {% if logo_path %}<button class="btn btn-danger btn-sm" onclick="deleteLogo()">Remove</button>{% endif %}
      <p class="text-muted">Recommended: 64×64px PNG with transparency. Max 2MB.</p>
    </div>
  </div>
</div>

<!-- SCHEDULE TAB -->
<div class="tab-panel" id="tab-schedule">
  <div class="panel-header"><h3>Backup Schedule</h3></div>
  <div class="schedule-form">
    <div class="presets">
      <button class="preset-btn" onclick="setCron('0 2 * * *')">Daily 2AM</button>
      <button class="preset-btn" onclick="setCron('0 3 * * *')">Daily 3AM</button>
      <button class="preset-btn" onclick="setCron('0 4 * * *')">Daily 4AM</button>
      <button class="preset-btn" onclick="setCron('0 */6 * * *')">Every 6h</button>
      <button class="preset-btn" onclick="setCron('0 3 * * 1')">Weekly Mon</button>
    </div>
    <div class="form-g">
      <label>Custom Cron Expression</label>
      <input type="text" id="cron-input" value="{{ sys_cfg.CRON_SCHEDULE or '0 3 * * *' }}" placeholder="minute hour day month weekday" class="input-sm" style="width:300px">
      <small class="text-muted">Current: {{ sys_cfg.SCHEDULE_DESC or 'unknown' }}</small>
    </div>
    <button class="btn btn-primary btn-sm" onclick="saveSchedule()">Save Schedule</button>
  </div>
</div>

<!-- ALERTS TAB -->
<div class="tab-panel" id="tab-alerts">
  <div class="panel-header"><h3>Storage Alerts & Notifications</h3></div>
  <div class="settings-form">
    <div class="form-g">
      <label>Storage Warning Threshold (%)</label>
      <input type="range" id="alert-threshold" min="50" max="95" value="{{ s_threshold or 80 }}" oninput="document.getElementById('thresh-val').textContent=this.value+'%'">
      <span id="thresh-val">{{ s_threshold or 80 }}%</span>
    </div>
    <div class="checks-row">
      <label class="chk"><input type="checkbox" id="chk-success" {% if n_success=='1' %}checked{% endif %}><span>Notify on backup success</span></label>
      <label class="chk"><input type="checkbox" id="chk-failure" {% if n_failure=='1' %}checked{% endif %}><span>Notify on backup failure</span></label>
      <label class="chk"><input type="checkbox" id="chk-storage" {% if n_storage=='1' %}checked{% endif %}><span>Notify on storage warning</span></label>
    </div>
    <p class="text-muted" style="margin-top:8px">Notifications are sent via SMTP (configure in SMTP tab).</p>
    <button class="btn btn-primary btn-sm" onclick="saveAlerts()">Save Alerts</button>
  </div>
</div>

<!-- LOGS TAB -->
<div class="tab-panel" id="tab-logs">
  <div class="panel-header"><h3>System Logs</h3></div>
  <div class="logs-layout">
    <div class="log-list" id="log-list"><p class="text-muted">Loading…</p></div>
    <div class="log-content"><pre id="log-view" class="log-pre">Select a log file to view</pre></div>
  </div>
</div>
{% endblock %}
{% block extra_js %}
<script>
function switchTab(name){
  document.querySelectorAll('.tab-btn').forEach(b=>b.classList.remove('active'));
  document.querySelectorAll('.tab-panel').forEach(p=>p.classList.remove('active'));
  event.target.classList.add('active');
  document.getElementById('tab-'+name).classList.add('active');
  if(name==='logs')loadLogs();
}

async function addUser(){
  const un=document.getElementById('u-name').value.trim();
  const em=document.getElementById('u-email').value.trim();
  const role=document.getElementById('u-role').value;
  const pw=document.getElementById('u-pass').value;
  const fd=new FormData(); fd.append('username',un); fd.append('email',em);
  fd.append('role',role); fd.append('password',pw);
  const r=await fetch('/admin/users/add',{method:'POST',body:fd});
  const d=await r.json();
  showToast(d.ok?'User added':'Error: '+d.error, d.ok?'success':'error');
  if(d.ok)location.reload();
}

async function delUser(id,name){
  if(!confirm(`Delete user "${name}"?`))return;
  const r=await fetch(`/admin/users/delete/${id}`,{method:'POST'});
  const d=await r.json();
  showToast(d.ok?'User deleted':'Error: '+d.error, d.ok?'success':'error');
  if(d.ok)location.reload();
}

function pwModal(uid){
  openModal('Change Password',`<div class="form-g"><label>New Password (min 6 chars)</label><input type="password" id="new-pw" class="input-sm"></div><button class="btn btn-primary btn-sm" onclick="submitPw(${uid})">Update</button>`);
}
async function submitPw(uid){
  const pw=document.getElementById('new-pw').value;
  const fd=new FormData(); fd.append('user_id',uid); fd.append('password',pw);
  const r=await fetch('/admin/users/password',{method:'POST',body:fd});
  const d=await r.json();
  showToast(d.ok?'Password updated':'Error: '+d.error, d.ok?'success':'error');
  if(d.ok)closeModal();
}

async function saveSMTP(){
  const fd=new FormData(document.getElementById('smtp-form'));
  const r=await fetch('/admin/smtp/save',{method:'POST',body:fd});
  const d=await r.json();
  showToast(d.ok?'SMTP saved':'Error: '+d.error, d.ok?'success':'error');
}
async function testSMTP(){
  showToast('Testing SMTP…','info');
  const r=await fetch('/admin/smtp/test',{method:'POST'});
  const d=await r.json();
  showToast(d.message||d.error, r.ok?'success':'error');
}

async function uploadLogo(input){
  if(!input.files[0])return;
  const fd=new FormData(); fd.append('logo',input.files[0]);
  const r=await fetch('/admin/logo/upload',{method:'POST',body:fd});
  const d=await r.json();
  showToast(d.ok?'Logo uploaded':'Error: '+d.error, d.ok?'success':'error');
  if(d.ok)location.reload();
}
async function deleteLogo(){
  await fetch('/admin/logo/delete',{method:'POST'});
  showToast('Logo removed','success'); location.reload();
}

function setCron(val){document.getElementById('cron-input').value=val;}
async function saveSchedule(){
  const cron=document.getElementById('cron-input').value.trim();
  const fd=new FormData(); fd.append('cron',cron);
  const r=await fetch('/admin/schedule/save',{method:'POST',body:fd});
  const d=await r.json();
  showToast(d.ok?'Schedule updated':'Error: '+d.error, d.ok?'success':'error');
}

async function saveAlerts(){
  const fd=new FormData(); fd.append('s_threshold',document.getElementById('alert-threshold').value);
  if(document.getElementById('chk-success').checked)fd.append('n_success','on');
  if(document.getElementById('chk-failure').checked)fd.append('n_failure','on');
  if(document.getElementById('chk-storage').checked)fd.append('n_storage','on');
  const r=await fetch('/settings/save',{method:'POST',body:fd});
  showToast((await r.json()).ok?'Alerts saved':'Save failed',r.ok?'success':'error');
}

async function loadLogs(){
  const r=await(await fetch('/admin/logs')).json();
  let html='';
  r.logs.forEach(l=>{html+=`<div class="log-item" onclick="viewLog('${l.name}')">${l.name} <small>${l.modified} · ${(l.size/1024).toFixed(1)}KB</small></div>`});
  document.getElementById('log-list').innerHTML=html||'<p class="text-muted">No logs</p>';
}
async function viewLog(name){
  document.querySelectorAll('.log-item').forEach(e=>e.classList.remove('active'));
  event.target.closest('.log-item').classList.add('active');
  const r=await(await fetch('/admin/logs/'+name)).json();
  document.getElementById('log-view').textContent=r.content||'Empty log';
}
</script>
{% endblock %}
ADMINHTML
    print_success "admin.html"

    # ── settings.html ──────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/templates/settings.html" << 'STTHTML'
{% extends 'base.html' %}
{% block title %}Settings{% endblock %}
{% block breadcrumb %}<h2 class="page-title">Settings</h2>{% endblock %}
{% block content %}
<!-- Retention & Notifications -->
<div class="chart-card">
  <h3 class="chart-title">Backup Retention & Notifications</h3>
  <div class="settings-form">
    <div class="form-row">
      <div class="form-g"><label>Retention Period (days)</label><input type="number" id="retention" value="{{ retention }}" min="1" max="365" class="input-sm" style="width:100px"></div>
      <div class="form-g"><label>Auto-cleanup</label><p class="text-muted">Old backups are automatically removed after retention period.</p></div>
    </div>
    <div class="checks-row" style="margin-top:16px">
      <label class="chk"><input type="checkbox" id="ns" {% if n_success=='1' %}checked{% endif %}><span>Email on success</span></label>
      <label class="chk"><input type="checkbox" id="nf" {% if n_failure=='1' %}checked{% endif %}><span>Email on failure</span></label>
      <label class="chk"><input type="checkbox" id="nst" {% if n_storage=='1' %}checked{% endif %}><span>Email on storage alert</span></label>
    </div>
    <div class="form-g" style="margin-top:16px">
      <label>Storage Alert Threshold (%)</label>
      <input type="range" id="sth" min="50" max="95" value="{{ s_threshold }}" oninput="document.getElementById('sthv').textContent=this.value+'%'">
      <span id="sthv">{{ s_threshold }}%</span>
    </div>
    <button class="btn btn-primary btn-sm" style="margin-top:12px" onclick="saveSettings()">Save Settings</button>
  </div>
</div>

<!-- API Tokens -->
<div class="chart-card" style="margin-top:20px">
  <h3 class="chart-title">API Access Tokens</h3>
  <p class="text-muted" style="margin-bottom:12px">Tokens are hashed (SHA-256) and shown only once at creation.</p>
  <div class="add-form">
    <input type="text" id="tk-name" placeholder="Token name" class="input-sm">
    <select id="tk-days" class="select-sm"><option value="7">7 days</option><option value="30" selected>30 days</option><option value="90">90 days</option><option value="365">1 year</option></select>
    <button class="btn btn-primary btn-sm" onclick="createToken()">Create Token</button>
  </div>
  <div id="new-token-alert" class="token-reveal" style="display:none"></div>
  <table class="data-table">
    <thead><tr><th>Name</th><th>Created</th><th>Expires</th><th></th></tr></thead>
    <tbody>
    {% for t in tokens %}
    <tr><td>{{ t.name }}</td><td>{{ t.created_at }}</td><td>{{ t.expires_at }}</td>
      <td><button class="btn btn-sm btn-danger" onclick="delToken({{ t.id }})">✕</button></td>
    </tr>{% endfor %}
    </tbody>
  </table>
</div>
{% endblock %}
{% block extra_js %}
<script>
async function saveSettings(){
  const fd=new FormData();
  fd.append('retention',document.getElementById('retention').value);
  fd.append('s_threshold',document.getElementById('sth').value);
  if(document.getElementById('ns').checked)fd.append('n_success','on');
  if(document.getElementById('nf').checked)fd.append('n_failure','on');
  if(document.getElementById('nst').checked)fd.append('n_storage','on');
  const r=await fetch('/settings/save',{method:'POST',body:fd});
  showToast((await r.json()).ok?'Settings saved':'Failed','success');
}

async function createToken(){
  const name=document.getElementById('tk-name').value.trim();
  const days=document.getElementById('tk-days').value;
  if(!name){showToast('Name required','error');return;}
  const fd=new FormData(); fd.append('name',name); fd.append('days',days);
  const r=await fetch('/settings/tokens/create',{method:'POST',body:fd});
  const d=await r.json();
  if(d.ok){
    document.getElementById('new-token-alert').style.display='block';
    document.getElementById('new-token-alert').innerHTML=`<strong>⚠ New Token:</strong><br><code>${d.token}</code><br><small>${d.warning}</small>`;
    showToast('Token created!','success'); location.reload();
  } else showToast('Error: '+d.error,'error');
}

async function delToken(id){
  if(!confirm('Delete this token?'))return;
  await fetch(`/settings/tokens/delete/${id}`,{method:'POST'});
  showToast('Token deleted','success'); location.reload();
}
</script>
{% endblock %}
STTHTML
    print_success "settings.html"
    log "Templates phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 12 — CSS + JS ASSETS
# ─────────────────────────────────────────────────────────────────────────────
phase_12_assets() {
    print_phase "PHASE 11: Static Assets"

    cat > "$INSTALL_DIR/dashboard/static/css/style.css" << 'CSSEOF'
/* ─── RESET & BASE ─────────────────────────────────────────────────────── */
*{margin:0;padding:0;box-sizing:border-box}
:root{--bg:#0b0d14;--sidebar:#12141c;--card:#1a1d2e;--card2:#202640;--border:#2d3150;--text:#e2e8f0;--muted:#8892b0;--accent:#6c63ff;--accent2:#8b5cf6;--success:#4caf7c;--danger:#e74c3c;--warning:#f5a623;--danger-dim:rgba(231,76,60,0.12)}
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:var(--bg);color:var(--text);min-height:100vh;display:flex;font-size:14px;line-height:1.5}

/* ─── SIDEBAR ──────────────────────────────────────────────────────────── */
.sidebar{width:240px;min-width:240px;background:var(--sidebar);display:flex;flex-direction:column;border-right:1px solid var(--border);height:100vh;position:fixed;top:0;left:0;z-index:100}
.sidebar-head{padding:28px 20px;display:flex;align-items:center;gap:12px;border-bottom:1px solid var(--border)}
.logo-icon{width:40px;height:40px;min-width:40px;background:linear-gradient(135deg,var(--accent),var(--accent2));border-radius:10px;display:flex;align-items:center;justify-content:center;font-size:20px;font-weight:700;color:#fff}
.logo-img{width:40px;height:40px;border-radius:10px;object-fit:cover}
.logo-txt{font-weight:600;font-size:15px;color:#fff;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.sidebar-nav{flex:1;padding:12px 10px;overflow-y:auto}
.nav-item{display:flex;align-items:center;gap:10px;padding:10px 14px;border-radius:8px;color:var(--muted);text-decoration:none;transition:.15s;font-size:14px;margin-bottom:2px}
.nav-item:hover{background:var(--card2);color:var(--text)}
.nav-item.active{background:rgba(108,99,255,.12);color:var(--accent);font-weight:600}
.ni{font-size:16px;width:20px;text-align:center}
.sidebar-foot{padding:16px 10px;border-top:1px solid var(--border)}
.user-bar{display:flex;align-items:center;gap:8px;padding:8px 12px;margin-bottom:6px}
.u-name{font-weight:500;color:var(--text);font-size:13px}
.badge-admin{background:rgba(108,99,255,.15);color:var(--accent);padding:2px 7px;border-radius:10px;font-size:10px;font-weight:600;text-transform:uppercase}
.badge-user{background:rgba(139,92,246,.12);color:var(--accent2);padding:2px 7px;border-radius:10px;font-size:10px;font-weight:600;text-transform:uppercase}
.logout-btn{display:block;padding:8px 12px;border-radius:6px;color:var(--muted);text-decoration:none;font-size:12px;transition:.15s}
.logout-btn:hover{background:var(--danger-dim);color:var(--danger)}

/* ─── MAIN ─────────────────────────────────────────────────────────────── */
.main{margin-left:240px;flex:1;display:flex;flex-direction:column;min-height:100vh}
.topbar{display:flex;align-items:center;justify-content:space-between;padding:14px 28px;background:var(--sidebar);border-bottom:1px solid var(--border);position:sticky;top:0;z-index:50}
.page-title{font-size:20px;font-weight:600;color:#fff}
.top-right{display:flex;align-items:center;gap:12px}
.notif-btn{background:none;border:1px solid var(--border);color:var(--muted);padding:8px 12px;border-radius:8px;cursor:pointer;position:relative;transition:.15s;font-size:15px}
.notif-btn:hover{border-color:var(--accent);color:var(--accent)}
.nbadge{position:absolute;top:-6px;right:-6px;background:var(--danger);color:#fff;border-radius:10px;padding:1px 6px;font-size:10px;font-weight:700}

/* ─── NOTIFICATIONS PANEL ──────────────────────────────────────────────── */
.notif-panel{position:absolute;top:56px;right:20px;width:340px;background:var(--card);border:1px solid var(--border);border-radius:12px;box-shadow:0 20px 60px rgba(0,0,0,.5);z-index:200;display:none;max-height:400px;overflow:hidden;flex-direction:column}
.notif-panel.open{display:flex}
.notif-header{display:flex;justify-content:space-between;align-items:center;padding:14px 16px;border-bottom:1px solid var(--border)}
.notif-header span{font-weight:600;color:#fff}
.notif-list{overflow-y:auto;flex:1}
.notif-item{padding:12px 16px;border-bottom:1px solid var(--border);font-size:13px;color:var(--muted)}
.notif-item.unread{background:rgba(108,99,255,.06);color:var(--text)}
.notif-item .nt{font-size:11px;color:var(--muted);margin-top:3px}
.notif-empty{padding:24px;text-align:center;color:var(--muted);font-size:13px}

/* ─── CONTENT ──────────────────────────────────────────────────────────── */
.content{padding:24px 28px;flex:1}

/* ─── STAT CARDS ───────────────────────────────────────────────────────── */
.stats-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(200px,1fr));gap:16px;margin-bottom:20px}
.stat-card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:20px;transition:.2s}
.stat-card:hover{border-color:var(--accent)}
.stat-label{color:var(--muted);font-size:12px;text-transform:uppercase;letter-spacing:.5px;margin-bottom:8px}
.stat-val{font-size:30px;font-weight:700;color:#fff}
.stat-sm{font-size:18px}

/* ─── ACTION BAR ───────────────────────────────────────────────────────── */
.action-bar{display:flex;align-items:center;gap:16px;margin-bottom:20px}
.action-info{color:var(--muted);font-size:13px}

/* ─── CHARTS ───────────────────────────────────────────────────────────── */
.charts-grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(320px,1fr));gap:16px;margin-bottom:16px}
.chart-card{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:20px}
.chart-title{color:#fff;font-size:15px;font-weight:600;margin-bottom:14px}
.chart-wrap{position:relative;height:220px}
.chart-legend{color:var(--muted);font-size:12px;margin-top:10px;text-align:center}

/* ─── TOOLBAR & TABLE ──────────────────────────────────────────────────── */
.toolbar{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.toolbar-info{color:var(--muted);font-size:13px;margin-left:auto}
.select{background:var(--card2);border:1px solid var(--border);color:var(--text);padding:8px 12px;border-radius:8px;font-size:13px;outline:none;cursor:pointer}
.table-wrap{background:var(--card);border:1px solid var(--border);border-radius:12px;overflow:hidden}
.data-table{width:100%;border-collapse:collapse}
.data-table th{background:var(--card2);color:var(--muted);font-size:11px;text-transform:uppercase;letter-spacing:.5px;padding:12px 16px;text-align:left;font-weight:600}
.data-table td{padding:12px 16px;border-bottom:1px solid var(--border);color:var(--text);font-size:13px}
.data-table tr:last-child td{border-bottom:none}
.data-table tr:hover td{background:rgba(108,99,255,.04)}
.empty-cell{text-align:center;color:var(--muted);padding:32px!important}
.date-cell{color:var(--muted);font-variant-numeric:tabular-nums}
.size-badge{background:var(--card2);color:var(--accent);padding:3px 8px;border-radius:6px;font-size:12px;font-weight:600}
.comp-cell{display:flex;flex-wrap:wrap;gap:4px}
.comp-tag{background:var(--card2);color:var(--muted);padding:2px 8px;border-radius:12px;font-size:11px}
.db-tag{background:rgba(76,175,124,.1);color:var(--success)}
.actions-cell{display:flex;gap:4px;flex-wrap:wrap}

/* ─── BUTTONS ──────────────────────────────────────────────────────────── */
.btn{padding:8px 16px;border-radius:7px;border:none;cursor:pointer;font-size:13px;font-weight:600;transition:.15s;white-space:nowrap}
.btn:hover{opacity:.85;transform:translateY(-1px)}
.btn-primary{background:var(--accent);color:#fff;box-shadow:0 3px 10px rgba(108,99,255,.3)}
.btn-secondary{background:var(--card2);color:var(--text);border:1px solid var(--border)}
.btn-ghost{background:transparent;color:var(--muted);border:1px solid var(--border)}
.btn-ghost:hover{border-color:var(--accent);color:var(--accent)}
.btn-danger{background:var(--danger);color:#fff}
.btn-db{background:rgba(76,175,124,.15);color:var(--success);border:1px solid rgba(76,175,124,.3)}
.btn-sm{padding:5px 10px;font-size:12px}
.btn-lg{padding:10px 22px;font-size:14px}
.btn-row{display:flex;gap:8px;margin-top:16px}

/* ─── TABS ─────────────────────────────────────────────────────────────── */
.tabs{display:flex;gap:4px;margin-bottom:20px;flex-wrap:wrap}
.tab-btn{background:transparent;border:1px solid var(--border);color:var(--muted);padding:8px 16px;border-radius:8px;cursor:pointer;font-size:13px;transition:.15s}
.tab-btn:hover{border-color:var(--accent);color:var(--accent)}
.tab-btn.active{background:rgba(108,99,255,.12);border-color:var(--accent);color:var(--accent);font-weight:600}
.tab-panel{display:none}
.tab-panel.active{display:block}

/* ─── FORMS ────────────────────────────────────────────────────────────── */
.settings-form,.schedule-form,.add-form{background:var(--card);border:1px solid var(--border);border-radius:12px;padding:24px}
.panel-header{margin-bottom:20px}
.panel-header h3{color:#fff;font-size:16px;margin-bottom:4px}
.text-muted{color:var(--muted);font-size:12px}
.form-row{display:flex;gap:16px;flex-wrap:wrap}
.form-row .form-g{flex:1;min-width:180px}
.form-g{margin-bottom:16px}
.form-g label{display:block;color:#c4cce0;font-size:12px;font-weight:600;margin-bottom:5px;text-transform:uppercase;letter-spacing:.3px}
.form-g input[type=text],.form-g input[type=password],.form-g input[type=email],.form-g input[type=number]{width:100%;padding:9px 12px;background:var(--card2);border:1.5px solid var(--border);border-radius:8px;color:var(--text);font-size:13px;outline:none;transition:.2s}
.form-g input:focus{border-color:var(--accent);box-shadow:0 0 0 3px rgba(108,99,255,.12)}
.input-sm{width:auto!important}
.select-sm{background:var(--card2);border:1px solid var(--border);color:var(--text);padding:7px 10px;border-radius:7px;font-size:12px;outline:none}
.checks-row{display:flex;flex-direction:column;gap:8px}
.chk{display:flex;align-items:center;gap:8px;cursor:pointer;color:var(--muted);font-size:13px}
.chk input[type=checkbox]{accent-color:var(--accent);width:15px;height:15px}
.add-form{display:flex;align-items:center;gap:8px;flex-wrap:wrap;margin-bottom:16px;padding:16px}

/* ─── ADMIN SPECIFIC ───────────────────────────────────────────────────── */
.you-badge{background:rgba(76,175,124,.12);color:var(--success);padding:1px 6px;border-radius:8px;font-size:10px}
.logo-upload-area{display:flex;gap:24px;align-items:flex-start}
.logo-preview{width:100px;height:100px;background:var(--card2);border:2px dashed var(--border);border-radius:12px;display:flex;align-items:center;justify-content:center;overflow:hidden}
.logo-preview img{width:100%;height:100%;object-fit:cover}
.logo-placeholder{color:var(--muted);font-size:12px}
.logo-actions{display:flex;flex-direction:column;gap:8px}
.file-label{cursor:pointer}
.presets{display:flex;gap:6px;margin-bottom:16px;flex-wrap:wrap}
.preset-btn{background:var(--card2);border:1px solid var(--border);color:var(--muted);padding:5px 10px;border-radius:6px;cursor:pointer;font-size:12px;transition:.15s}
.preset-btn:hover{border-color:var(--accent);color:var(--accent)}

/* ─── LOGS ─────────────────────────────────────────────────────────────── */
.logs-layout{display:grid;grid-template-columns:240px 1fr;gap:16px}
.log-list{background:var(--card2);border-radius:8px;overflow-y:auto;max-height:400px}
.log-item{padding:10px 14px;border-bottom:1px solid var(--border);cursor:pointer;font-size:12px;color:var(--muted);transition:.15s}
.log-item:hover,.log-item.active{background:rgba(108,99,255,.1);color:var(--accent)}
.log-content{overflow:auto}
.log-pre{background:var(--card2);border:1px solid var(--border);border-radius:8px;padding:16px;color:#7ec8e3;font-size:11px;white-space:pre-wrap;word-break:break-all;max-height:400px;overflow:auto;line-height:1.6}

/* ─── RESTORE ──────────────────────────────────────────────────────────── */
.restore-pre{background:var(--card2);color:var(--text);padding:16px;border-radius:8px;font-size:12px;white-space:pre-wrap;line-height:1.7}

/* ─── TOKEN ────────────────────────────────────────────────────────────── */
.token-reveal{background:rgba(76,175,124,.08);border:1px solid rgba(76,175,124,.3);border-radius:8px;padding:14px;margin:12px 0;font-size:12px}
.token-reveal code{display:block;background:var(--card2);padding:8px 12px;border-radius:6px;margin-top:6px;font-size:13px;word-break:break-all;color:var(--success)}

/* ─── DB LINKS ─────────────────────────────────────────────────────────── */
.db-link{display:block;padding:8px 12px;background:var(--card2);border-radius:8px;color:var(--accent);text-decoration:none;font-size:13px;margin-bottom:6px;transition:.15s}
.db-link:hover{background:rgba(108,99,255,.1)}

/* ─── TOAST ────────────────────────────────────────────────────────────── */
.toast-wrap{position:fixed;bottom:24px;right:24px;z-index:999;display:flex;flex-direction:column;gap:8px}
.toast{background:var(--card);border:1px solid var(--border);border-radius:10px;padding:12px 18px;color:var(--text);font-size:13px;box-shadow:0 8px 30px rgba(0,0,0,.4);animation:slideIn .25s ease;display:flex;align-items:center;gap:8px;max-width:320px}
.toast.success{border-color:rgba(76,175,124,.4);background:rgba(76,175,124,.08)}
.toast.error{border-color:rgba(231,76,60,.4);background:rgba(231,76,60,.08)}
.toast.info{border-color:rgba(74,144,217,.4);background:rgba(74,144,217,.08)}
@keyframes slideIn{from{opacity:0;transform:translateY(20px)}to{opacity:1;transform:translateY(0)}}

/* ─── MODAL ────────────────────────────────────────────────────────────── */
.modal-overlay{position:fixed;inset:0;background:rgba(0,0,0,.6);z-index:400;display:none}
.modal-overlay.open{display:block}
.modal{position:fixed;top:50%;left:50%;transform:translate(-50%,-50%);background:var(--card);border:1px solid var(--border);border-radius:14px;width:90%;max-width:520px;max-height:80vh;overflow-y:auto;z-index:500;display:none;box-shadow:0 40px 120px rgba(0,0,0,.6)}
.modal.open{display:block}
.modal-head{display:flex;justify-content:space-between;align-items:center;padding:20px 24px;border-bottom:1px solid var(--border)}
.modal-head h3{color:#fff;font-size:17px}
.modal-close{background:none;border:none;color:var(--muted);font-size:22px;cursor:pointer;padding:0 4px;line-height:1}
.modal-close:hover{color:#fff}
.modal-body{padding:24px}

/* ─── SCROLLBAR ────────────────────────────────────────────────────────── */
::-webkit-scrollbar{width:6px}
::-webkit-scrollbar-track{background:transparent}
::-webkit-scrollbar-thumb{background:var(--border);border-radius:3px}
::-webkit-scrollbar-thumb:hover{background:var(--muted)}
CSSEOF
    print_success "style.css"

    # ── app.js ─────────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/dashboard/static/js/app.js" << 'JSEOF'
/* ─── TOAST ──────────────────────────────────────────────────────────── */
function showToast(msg, type='info', dur=4000){
  const w=document.getElementById('toasts');
  const t=document.createElement('div'); t.className='toast '+type;
  const icons={success:'✓',error:'✗',info:'ℹ'};
  t.innerHTML=`<span>${icons[type]||''}</span><span>${msg}</span>`;
  w.appendChild(t); setTimeout(()=>t.remove(),dur);
}

/* ─── MODAL ──────────────────────────────────────────────────────────── */
function openModal(title,body){
  document.getElementById('modal-title').textContent=title;
  document.getElementById('modal-body').innerHTML=body;
  document.getElementById('modal').classList.add('open');
  document.getElementById('modal-overlay').classList.add('open');
}
function closeModal(){
  document.getElementById('modal').classList.remove('open');
  document.getElementById('modal-overlay').classList.remove('open');
}
document.addEventListener('keydown',e=>{if(e.key==='Escape')closeModal()});

/* ─── NOTIFICATIONS ──────────────────────────────────────────────────── */
let nOpen=false;
function toggleNotifs(){
  nOpen=!nOpen;
  document.getElementById('notif-panel').classList.toggle('open',nOpen);
  if(nOpen)loadNotifs();
}
document.addEventListener('click',e=>{
  if(nOpen&&!e.target.closest('.notif-btn')&&!e.target.closest('.notif-panel')){
    nOpen=false; document.getElementById('notif-panel').classList.remove('open');
  }
});
async function loadNotifs(){
  const r=await(await fetch('/api/notifications')).json();
  const el=document.getElementById('notif-list');
  if(!r.notifications.length){el.innerHTML='<p class="notif-empty">No notifications</p>';return;}
  el.innerHTML=r.notifications.map(n=>`<div class="notif-item ${n.read?'':'unread'}"><strong>${n.type}</strong> ${n.message}<div class="nt">${n.created_at}</div></div>`).join('');
}
async function markRead(){
  await fetch('/api/notifications/read',{method:'POST'});
  document.getElementById('nbadge').style.display='none';
  loadNotifs();
}
function updateBadge(count){
  const el=document.getElementById('nbadge');
  if(count>0){el.style.display='inline';el.textContent=count;}
  else el.style.display='none';
}
JSEOF
    print_success "app.js"
    log "Assets phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 13 — SSL
# ─────────────────────────────────────────────────────────────────────────────
phase_13_ssl() {
    print_phase "PHASE 12: SSL Certificate"

    if [ "$USE_LETSENCRYPT" = "true" ]; then
        print_info "Attempting Let's Encrypt for $LE_DOMAIN ..."

        # Temporarily start nginx on 80 for ACME challenge
        sudo tee /etc/nginx/sites-available/le-temp &>/dev/null << LETEMP
server { listen 80; server_name $LE_DOMAIN; root /tmp/le-root; location / { try_files \$uri =404; } }
LETEMP
        sudo mkdir -p /tmp/le-root
        sudo ln -sf /etc/nginx/sites-available/le-temp /etc/nginx/sites-enabled/le-temp
        sudo nginx -s reload 2>/dev/null || sudo nginx 2>/dev/null

        if sudo certbot certonly --nginx -d "$LE_DOMAIN" --email "$LE_EMAIL" --agree-tos --non-interactive &>/dev/null; then
            LE_CERT_PATH="/etc/letsencrypt/live/$LE_DOMAIN"
            SSL_CERT="$LE_CERT_PATH/fullchain.pem"
            SSL_KEY="$LE_CERT_PATH/privkey.pem"
            USE_LETSENCRYPT_OK=true

            # Auto-renewal hook
            sudo tee /etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh &>/dev/null << 'HOOK'
#!/bin/bash
systemctl reload nginx
HOOK
            sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/restart-nginx.sh
            print_success "Let's Encrypt certificate issued for $LE_DOMAIN"
            print_info "Auto-renewal configured via certbot"
        else
            print_warning "Let's Encrypt failed — falling back to self-signed"
            USE_LETSENCRYPT_OK=false
        fi

        # Remove temp nginx site
        sudo rm -f /etc/nginx/sites-enabled/le-temp /etc/nginx/sites-available/le-temp
    fi

    if [ "$USE_LETSENCRYPT" != "true" ] || [ "$USE_LETSENCRYPT_OK" != "true" ]; then
        print_info "Generating self-signed SSL (10-year validity)..."
        openssl req -x509 -nodes -days 3650 -newkey rsa:2048 \
            -keyout "$INSTALL_DIR/ssl/key.pem" \
            -out "$INSTALL_DIR/ssl/cert.pem" \
            -subj "/C=ZA/ST=Gauteng/L=Johannesburg/O=$(echo $COMPANY_NAME | sed 's/ /_/g')/CN=$SYSTEM_IP" &>/dev/null
        chmod 600 "$INSTALL_DIR/ssl/key.pem"
        chmod 644 "$INSTALL_DIR/ssl/cert.pem"
        SSL_CERT="$INSTALL_DIR/ssl/cert.pem"
        SSL_KEY="$INSTALL_DIR/ssl/key.pem"
        USE_LETSENCRYPT_OK=false
        print_success "Self-signed certificate generated"
        print_info "Browser will show warning — click Advanced → Proceed"
    fi

    log "SSL phase complete. LE=$USE_LETSENCRYPT_OK"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 14 — NGINX
# ─────────────────────────────────────────────────────────────────────────────
phase_14_nginx() {
    print_phase "PHASE 13: Nginx Reverse Proxy"

    sudo tee /etc/nginx/sites-available/backup-dashboard &>/dev/null << NGINXCFG
# Backup Dashboard — generated $(date)
# Rate limiting zones
limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone \$binary_remote_addr zone=api:10m rate=60r/m;

server {
    listen 8443 ssl;
    server_name $SYSTEM_IP$([ "$USE_LETSENCRYPT_OK" = true ] && echo " $LE_DOMAIN");

    # SSL
    ssl_certificate $SSL_CERT;
    ssl_certificate_key $SSL_KEY;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers 'ECDHE+AESGCM:ECDHE+AES256:!aNULL:!MD5';
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;

    # Security headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy strict-origin-when-cross-origin always;

    client_max_body_size 10M;
    keepalive_timeout 65;

    # Login — strict rate limit
    location /login {
        limit_req zone=login burst=3 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # API — moderate rate limit
    location /api/ {
        limit_req zone=api burst=10 nodelay;
        limit_req_status 429;
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Downloads — long timeout
    location /download/ {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 600s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
    }

    # Everything else
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

# HTTP → redirect if LE enabled
$([ "$USE_LETSENCRYPT_OK" = true ] && echo "
server {
    listen 80;
    server_name $LE_DOMAIN;
    return 301 https://\$host:8443\$request_uri;
}")
NGINXCFG

    sudo ln -sf /etc/nginx/sites-available/backup-dashboard /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default

    if sudo nginx -t &>/dev/null; then
        sudo systemctl restart nginx &>/dev/null
        print_success "Nginx configured & restarted"
    else
        print_warning "Nginx config test failed — check /etc/nginx/sites-available/backup-dashboard"
        sudo nginx -t 2>&1 | tail -5
    fi
    log "Nginx phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 15 — SYSTEMD
# ─────────────────────────────────────────────────────────────────────────────
phase_15_systemd() {
    print_phase "PHASE 14: Systemd Services"

    sudo tee /etc/systemd/system/backup-dashboard.service &>/dev/null << SVCEOF
[Unit]
Description=Backup System Dashboard (Gunicorn)
After=network.target nginx.service
Wants=nginx.service

[Service]
Type=simple
User=$CURRENT_USER
Group=$CURRENT_USER
WorkingDirectory=$INSTALL_DIR/dashboard
Environment="INSTALL_DIR=$INSTALL_DIR"
Environment="BACKUP_DIR=$BACKUP_DIR"
Environment="PORT=8080"
ExecStart=/usr/local/bin/gunicorn \
    --bind 127.0.0.1:8080 \
    --workers 2 \
    --timeout 600 \
    --graceful-timeout 30 \
    --access-logfile $BACKUP_DIR/logs/dashboard_access.log \
    --error-logfile $BACKUP_DIR/logs/dashboard_error.log \
    --loglevel info \
    app:app
Restart=always
RestartSec=5
LimitNOFILE=4096

# Security hardening
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=$INSTALL_DIR $BACKUP_DIR /tmp
PrivateTmp=false

[Install]
WantedBy=multi-user.target
SVCEOF

    sudo systemctl daemon-reload
    sudo systemctl enable backup-dashboard &>/dev/null
    sudo systemctl start backup-dashboard &>/dev/null
    sleep 3

    if sudo systemctl is-active --quiet backup-dashboard; then
        print_success "Dashboard service running"
    else
        print_error "Dashboard service failed to start"
        print_info "Check: sudo journalctl -u backup-dashboard -n 30"
        sudo journalctl -u backup-dashboard -n 10 --no-pager 2>/dev/null | tail -8
    fi

    # Health-check timer
    sudo tee /etc/systemd/system/backup-health.timer &>/dev/null << 'TIMEREOF'
[Unit]
Description=Run backup health check every 15 minutes

[Timer]
OnBootSec=60s
OnUnitActiveSec=15min

[Install]
WantedBy=timers.target
TIMEREOF

    sudo tee /etc/systemd/system/backup-health.service &>/dev/null << HEALTHSVC
[Unit]
Description=Backup System Health Check

[Service]
Type=oneshot
User=$CURRENT_USER
ExecStart=$INSTALL_DIR/scripts/health_check.sh
HEALTHSVC

    sudo systemctl daemon-reload
    sudo systemctl enable backup-health.timer &>/dev/null
    sudo systemctl start backup-health.timer &>/dev/null
    print_success "Health-check timer enabled (every 15 min)"
    log "Systemd phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 16 — CRON
# ─────────────────────────────────────────────────────────────────────────────
phase_16_cron() {
    print_phase "PHASE 15: Backup Scheduling"

    SCRIPT="$INSTALL_DIR/scripts/backup.sh"
    LOGF="$BACKUP_DIR/logs/cron.log"

    # Remove old entries for this script
    crontab -l 2>/dev/null | grep -v "$SCRIPT" | crontab - 2>/dev/null || true

    # Add new cron job
    (crontab -l 2>/dev/null; echo "$CRON_SCHEDULE $SCRIPT >> $LOGF 2>&1") | crontab -

    # Verify
    if crontab -l 2>/dev/null | grep -q "$SCRIPT"; then
        print_success "Cron job installed: $SCHEDULE_DESC"
    else
        print_error "Cron job installation may have failed"
    fi
    log "Cron phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 17 — TEST
# ─────────────────────────────────────────────────────────────────────────────
phase_17_test() {
    print_phase "PHASE 16: Testing"

    # Test dashboard responds
    print_info "Testing dashboard..."
    sleep 2
    if curl -sk --max-time 5 https://127.0.0.1:8443/api/health &>/dev/null; then
        print_success "Dashboard responding"
    else
        print_warning "Dashboard health check failed (may need a moment)"
    fi

    # Test backup if SSH key authorized
    if [ "$SSH_KEY_AUTHORIZED" = true ]; then
        print_info "Running test backup (may take a few minutes)..."
        "$INSTALL_DIR/scripts/backup.sh" &
        BPID=$!
        SECS=0
        while kill -0 $BPID 2>/dev/null; do
            [ $SECS -gt 600 ] && { kill $BPID 2>/dev/null; print_warning "Test backup timed out (10m)"; break; }
            sleep 3; ((SECS+=3)); echo -n "."
        done
        echo ""
        wait $BPID 2>/dev/null
        if [ $? -eq 0 ]; then
            LATEST=$(ls -t "$BACKUP_DIR/cpanel" 2>/dev/null | head -1)
            [ -n "$LATEST" ] && { SZ=$(du -sh "$BACKUP_DIR/cpanel/$LATEST" 2>/dev/null | cut -f1); print_success "Test backup OK: $LATEST ($SZ)"; } || print_success "Test backup completed"
        else
            print_warning "Test backup returned non-zero (check logs)"
        fi
    else
        print_warning "Skipping test backup — SSH key not yet authorized"
    fi
    log "Test phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 18 — FIREWALL
# ─────────────────────────────────────────────────────────────────────────────
phase_18_firewall() {
    print_phase "PHASE 17: Firewall"

    if command -v ufw &>/dev/null; then
        sudo ufw allow 8443/tcp comment 'Backup Dashboard HTTPS' &>/dev/null
        [ "$USE_LETSENCRYPT_OK" = true ] && sudo ufw allow 80/tcp comment 'HTTP (LE redirect)' &>/dev/null
        print_success "UFW rule: 8443/tcp allowed"
    else
        print_info "UFW not installed — skipping firewall config"
    fi
    log "Firewall phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# PHASE 19 — MANAGEMENT SCRIPTS & FINALIZE
# ─────────────────────────────────────────────────────────────────────────────
phase_19_finalize() {
    print_phase "PHASE 18: Finalizing"

    # ── manage.sh ────────────────────────────────────────────────────────
    cat > "$INSTALL_DIR/manage.sh" << 'MGMTEOF'
#!/bin/bash
# Backup System Management Tool
INST="$(cd "$(dirname "$0")" && pwd)"
source "$INST/config/system.conf" 2>/dev/null

RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
echo -e "${CYAN}Backup System — Management${NC}"

case "${1}" in
    status)
        echo ""
        echo "─── Services ───"
        for svc in backup-dashboard nginx; do
            if systemctl is-active --quiet $svc 2>/dev/null; then echo -e "  ${GREEN}✓${NC} $svc"; else echo -e "  ${RED}✗${NC} $svc"; fi
        done
        echo ""
        echo "─── Recent Backups ───"
        ls -td "$BACKUP_DIR"/cpanel/202* 2>/dev/null | head -5 | while read d; do echo "  $(basename $d)  $(du -sh "$d" | cut -f1)"; done
        echo ""
        echo "─── Disk ───"
        df -h "$BACKUP_DIR" | tail -1 | awk '{print "  Used: "$3" / "$2" ("$5")"}'
        echo ""
        echo "─── Health ───"
        bash "$INST/scripts/health_check.sh" 2>/dev/null | while read l; do echo "  $l"; done
        ;;
    backup)
        echo "Running backup now..."
        "$INST/scripts/backup.sh"
        ;;
    logs)
        echo "─── Latest backup log ───"
        ls -t "$BACKUP_DIR"/logs/backup_*.log 2>/dev/null | head -1 | xargs tail -40
        ;;
    restart)
        echo "Restarting dashboard..."
        sudo systemctl restart backup-dashboard
        systemctl is-active --quiet backup-dashboard && echo -e "  ${GREEN}✓ Running${NC}" || echo -e "  ${RED}✗ Failed${NC}"
        ;;
    stop)
        sudo systemctl stop backup-dashboard; echo "Dashboard stopped";;
    health)
        bash "$INST/scripts/health_check.sh" ;;
    test-smtp)
        echo "Testing SMTP via dashboard API..."
        curl -sk https://127.0.0.1:8443/admin/smtp/test -X POST -b /tmp/cookies 2>/dev/null || echo "  Must be logged in via browser to test SMTP."
        ;;
    version)
        echo "  Version: 2.0.0"
        echo "  Installed: ${INSTALLED_DATE}"
        echo "  Company: ${COMPANY_NAME}"
        ;;
    *)
        echo ""
        echo "  Usage: $(basename $0) <command>"
        echo ""
        echo "  Commands:"
        echo "    status       Show system status & health"
        echo "    backup       Run a backup now"
        echo "    logs         Show latest backup log"
        echo "    restart      Restart dashboard"
        echo "    stop         Stop dashboard"
        echo "    health       Run health check"
        echo "    version      Show version info"
        echo ""
        ;;
esac
MGMTEOF
    chmod +x "$INSTALL_DIR/manage.sh"
    print_success "manage.sh created"

    # ── INSTALLATION_INFO.txt ────────────────────────────────────────────
    cat > "$INSTALL_DIR/INSTALLATION_INFO.txt" << EOF
════════════════════════════════════════════════
  BACKUP SYSTEM v2.0.0 — Installation Summary
════════════════════════════════════════════════
Company     : $COMPANY_NAME
Installed   : $(date)
By          : $CURRENT_USER
System IP   : $SYSTEM_IP

── SERVER ──────────────────────────────────────
cPanel Host : $CPANEL_HOST
cPanel User : $CPANEL_USER
SFTP Port   : $CPANEL_PORT
SSH Key     : $INSTALL_DIR/.ssh/id_rsa
Key Status  : $([ "$SSH_KEY_AUTHORIZED" = true ] && echo "Authorized" || echo "NEEDS AUTHORIZATION")

── SCHEDULE ────────────────────────────────────
Cron        : $CRON_SCHEDULE
Description : $SCHEDULE_DESC
Backups     : $BACKUP_DIR/cpanel/

── DASHBOARD ───────────────────────────────────
URL         : https://$SYSTEM_IP:8443
$([ "$USE_LETSENCRYPT_OK" = true ] && echo "LE Domain   : https://$LE_DOMAIN:8443")
Admin User  : $ADMIN_USER
SSL         : $([ "$USE_LETSENCRYPT_OK" = true ] && echo "Let's Encrypt ($LE_DOMAIN)" || echo "Self-signed")

── SERVICES ────────────────────────────────────
Dashboard   : backup-dashboard.service (Gunicorn)
Proxy       : nginx.service
Health      : backup-health.timer (15 min)

── MANAGEMENT ──────────────────────────────────
manage.sh   : $INSTALL_DIR/manage.sh
  status    : Show full status
  backup    : Manual backup
  logs      : View latest log
  restart   : Restart dashboard
  health    : Run health check

── PATHS ───────────────────────────────────────
Install     : $INSTALL_DIR
Config      : $INSTALL_DIR/config/
Scripts     : $INSTALL_DIR/scripts/
Dashboard   : $INSTALL_DIR/dashboard/
Backups     : $BACKUP_DIR/cpanel/
Logs        : $BACKUP_DIR/logs/
════════════════════════════════════════════════
EOF
    chmod 600 "$INSTALL_DIR/INSTALLATION_INFO.txt"
    print_success "Installation info saved"
    log "Finalize phase complete"
}

# ─────────────────────────────────────────────────────────────────────────────
# COMPLETION SCREEN
# ─────────────────────────────────────────────────────────────────────────────
show_completion() {
    clear
    echo -e "${GREEN}"
    cat << 'DONEBAN'
╔══════════════════════════════════════════════════════════════════════════╗
║                                                                          ║
║                  ✓  INSTALLATION COMPLETE  ✓                             ║
║                                                                          ║
╚══════════════════════════════════════════════════════════════════════════╝
DONEBAN
    echo -e "${NC}"

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}SYSTEM INFO${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "    Company   : $COMPANY_NAME"
    echo "    cPanel    : $CPANEL_USER@$CPANEL_HOST:$CPANEL_PORT"
    echo "    Schedule  : $SCHEDULE_DESC"
    echo "    Retention : 30 days (configurable in Settings)"
    echo ""

    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}DASHBOARD ACCESS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "    URL      : ${GREEN}https://$SYSTEM_IP:8443${NC}"
    [ "$USE_LETSENCRYPT_OK" = true ] && echo "    LE URL   : ${GREEN}https://$LE_DOMAIN:8443${NC}"
    echo "    Username : ${GREEN}$ADMIN_USER${NC}"
    echo "    Password : ${GREEN}[as you entered]${NC}"
    echo ""
    if [ "$USE_LETSENCRYPT_OK" != true ]; then
        echo "    ${YELLOW}⚠ Self-signed SSL: click Advanced → Proceed to … in browser${NC}"
    fi
    echo ""

    # ── SSH KEY INSTRUCTIONS (if not authorized) ──────────────────────────
    if [ "$SSH_KEY_AUTHORIZED" != true ]; then
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "  ${RED}⚠  REQUIRED — ADD SSH KEY TO cPANEL  ⚠${NC}"
        echo -e "  ${RED}  Backups will NOT work until this is done!${NC}"
        echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "    STEP 1 — Login to cPanel"
        echo "            URL      : https://$CPANEL_HOST:2083"
        echo "            Username : $CPANEL_USER"
        echo ""
        echo "    STEP 2 — SSH Access"
        echo "            cPanel → Security → SSH Access → Manage SSH Keys"
        echo ""
        echo "    STEP 3 — Import Key"
        echo "            Click 'Import Key' → Name it 'backup'"
        echo "            Paste the PUBLIC KEY below:"
        echo ""
        echo "  ┌────────────────────────────────────────────────────────────────┐"
        echo "$SSH_PUBLIC_KEY" | fold -w 68 | sed 's/^/  │ /'
        echo "  └────────────────────────────────────────────────────────────────┘"
        echo ""
        echo "    STEP 4 — Authorize"
        echo "            Click 'Manage' next to the imported key → click 'Authorize'"
        echo ""
        echo "    STEP 5 — Verify"
        echo "            Run: $INSTALL_DIR/manage.sh backup"
        echo ""
    else
        echo -e "  ${GREEN}✓ SSH key already authorized${NC}"
        echo ""
    fi

    # ── DATABASE BACKUP SETUP ─────────────────────────────────────────────
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}DATABASE BACKUP SETUP (cPanel Side)${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  1. In cPanel → File Manager, create: ~/db_backup.sh"
    echo ""
    echo "  ┌────────────────────────────────────────────────────────────────┐"
    cat << 'DBSCRIPT' | sed 's/^/  │ /'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
# Replace these with your actual credentials:
DB_USER="your_db_user"
DB_PASS="your_db_pass"
DB_NAME="your_db_name"
mysqldump -h localhost -u"$DB_USER" -p"$DB_PASS" "$DB_NAME" | \
    gzip > ~/database_backup_$DATE.sql.gz
# Keep only last 3 backups
ls -t ~/database_backup_*.sql.gz | tail -n +4 | xargs rm -f 2>/dev/null
DBSCRIPT
    echo "  └────────────────────────────────────────────────────────────────┘"
    echo ""
    echo "  2. chmod +x ~/db_backup.sh"
    echo ""
    echo "  3. cPanel → Cron Jobs → Schedule 30 min BEFORE your backup time:"
    echo "     e.g., if backup runs at 3:00 AM, set cron to 2:30 AM"
    echo "     Command: /home/$CPANEL_USER/db_backup.sh"
    echo ""
    echo "  💡 TIP: For WordPress, you can auto-extract credentials:"
    echo '     DB_USER=$(grep DB_USER ~/public_html/wp-config.php | cut -d"'"'"'" -f4)'
    echo '     DB_PASS=$(grep DB_PASSWORD ~/public_html/wp-config.php | cut -d"'"'"'" -f4)'
    echo '     DB_NAME=$(grep DB_NAME ~/public_html/wp-config.php | cut -d"'"'"'" -f4)'
    echo ""

    # ── MANAGEMENT QUICK REF ──────────────────────────────────────────────
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}QUICK COMMANDS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "    $INSTALL_DIR/manage.sh status      # Full system status"
    echo "    $INSTALL_DIR/manage.sh backup      # Run backup now"
    echo "    $INSTALL_DIR/manage.sh logs        # Latest backup log"
    echo "    $INSTALL_DIR/manage.sh restart     # Restart dashboard"
    echo "    $INSTALL_DIR/manage.sh health      # Health check"
    echo ""
    echo "    sudo journalctl -u backup-dashboard -f    # Dashboard logs"
    echo "    sudo journalctl -u nginx -f               # Nginx logs"
    echo ""

    # ── NEXT STEPS ────────────────────────────────────────────────────────
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "  ${YELLOW}NEXT STEPS${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "    1. Add SSH public key to cPanel (see above)"
    echo "    2. Set up database backup cron in cPanel (see above)"
    echo "    3. Open dashboard: https://$SYSTEM_IP:8443"
    echo "    4. Login → Admin → SMTP → configure email notifications"
    echo "    5. Admin → Company → upload your company logo"
    echo "    6. First scheduled backup: $SCHEDULE_DESC"
    echo "       OR run now: $INSTALL_DIR/manage.sh backup"
    echo ""
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Install log : $LOG_FILE"
    echo "  System info : $INSTALL_DIR/INSTALLATION_INFO.txt"
    echo ""
    echo -e "  ${GREEN}Thank you for using Professional Backup System v2.0!${NC}"
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# MAIN
# ─────────────────────────────────────────────────────────────────────────────
main() {
    log "═══════════════════════════════════════════════════════════"
    log "Professional Backup System v$SCRIPT_VERSION — Install Start"
    log "═══════════════════════════════════════════════════════════"

    phase_1_welcome
    phase_2_preflight
    phase_3_dependencies
    phase_4_configuration
    phase_5_directories
    phase_6_ssh_keys
    phase_7_encryption
    phase_8_backup_scripts
    phase_9_database
    phase_10_flask_app
    phase_11_templates
    phase_12_assets
    phase_13_ssl
    phase_14_nginx
    phase_15_systemd
    phase_16_cron
    phase_17_test
    phase_18_firewall
    phase_19_finalize

    show_completion

    log "═══════════════════════════════════════════════════════════"
    log "Installation Complete"
    log "═══════════════════════════════════════════════════════════"
}

main
exit 0