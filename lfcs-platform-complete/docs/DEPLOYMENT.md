# LFCS Platform - Deployment Guide

## Server Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04 LTS or later (or RHEL/CentOS 8+)
- **RAM**: 2GB minimum, 4GB recommended
- **Disk**: 10GB minimum, 20GB recommended
- **CPU**: 2 cores minimum
- **Network**: Public IP address, Domain name

### Required Ports
- 22 (SSH)
- 80 (HTTP - redirects to HTTPS)
- 443 (HTTPS)
- 5432 (PostgreSQL - localhost only)

## Pre-Installation Checklist

1. ✅ Server with root access
2. ✅ Domain name (velocitylab.co.za) pointing to server IP
3. ✅ DNS A record configured
4. ✅ SSH access configured
5. ✅ Fresh server recommended (or existing services backed up)

## Installation Steps

### Step 1: Server Preparation

```bash
# Update system
apt update && apt upgrade -y

# Set hostname
hostnamectl set-hostname lfcs-platform

# Set timezone (optional)
timedatectl set-timezone Africa/Johannesburg
```

### Step 2: Upload Platform Files

From your local machine:
```bash
# Create archive
tar -czf lfcs-platform.tar.gz lfcs-platform-complete/

# Upload to server
scp lfcs-platform.tar.gz root@4.221.152.28:/root/

# Or use SFTP, rsync, etc.
```

On the server:
```bash
cd /root
tar -xzf lfcs-platform.tar.gz
cd lfcs-platform-complete/scripts
```

### Step 3: Run Installer

```bash
chmod +x lfcs-platform-installer.sh
./lfcs-platform-installer.sh
```

The installer will:
1. Check system requirements
2. Install dependencies (Node.js, PostgreSQL, Nginx)
3. Create database and import questions
4. Configure web server
5. Set up SSL certificates
6. Configure firewall
7. Create systemd services
8. Start the application

**Installation time**: 10-20 minutes depending on server speed

### Step 4: Verify Installation

```bash
# Check application status
lfcs-status

# Check if site is accessible
curl -I https://velocitylab.co.za

# Check database
sudo -u postgres psql -d lfcs_platform -c "SELECT COUNT(*) FROM questions;"
# Should return 125
```

### Step 5: First Login

1. Navigate to `https://velocitylab.co.za`
2. Log in with:
   - Username: `superadmin`
   - Password: `Superadmin@123`
3. **IMPORTANT**: Change password immediately!

## Post-Installation Configuration

### 1. Change Admin Password

After first login, go to Settings → Change Password

### 2. Configure Email (Optional)

Edit `/opt/lfcs-platform/.env.local`:
```bash
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASS=your-app-password
```

Restart: `lfcs-restart`

### 3. Customize Branding (Optional)

Edit `/opt/lfcs-platform/public/` for logos and images

### 4. SSL Certificate Auto-Renewal

Verify auto-renewal is configured:
```bash
certbot renew --dry-run
```

## Troubleshooting

### Issue: Site not accessible

**Check DNS:**
```bash
nslookup velocitylab.co.za
# Should return 4.221.152.28
```

**Check Nginx:**
```bash
systemctl status nginx
nginx -t  # Test configuration
```

**Check Firewall:**
```bash
ufw status
# Should show 80/tcp and 443/tcp as ALLOW
```

### Issue: Database connection failed

**Check PostgreSQL:**
```bash
systemctl status postgresql
sudo -u postgres psql -l  # List databases
```

**Test connection:**
```bash
PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin -d lfcs_platform -c "SELECT 1;"
```

### Issue: Application won't start

**Check logs:**
```bash
lfcs-logs
journalctl -u lfcs-platform -n 50
```

**Check Node.js:**
```bash
node --version  # Should be v20.x
npm --version
```

**Rebuild application:**
```bash
cd /opt/lfcs-platform
pnpm install
pnpm build
lfcs-restart
```

### Issue: SSL certificate errors

**Manual certificate installation:**
```bash
certbot certonly --nginx -d velocitylab.co.za -d www.velocitylab.co.za
systemctl restart nginx
```

## Maintenance

### Daily Backups

Automatic backups run at 2 AM. Check:
```bash
ls -lh /opt/lfcs-platform/backups/
```

### Manual Backup

```bash
lfcs-backup
```

### Restore from Backup

```bash
cd /opt/lfcs-platform/backups
gunzip < db_YYYYMMDD_HHMMSS.sql.gz | \
  PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin lfcs_platform
```

### Update Application

```bash
cd /opt/lfcs-platform
git pull  # If using git
pnpm install
pnpm build
lfcs-restart
```

### Monitor Logs

```bash
# Application logs
lfcs-logs

# Nginx access logs
tail -f /var/log/nginx/lfcs-platform-access.log

# Nginx error logs
tail -f /var/log/nginx/lfcs-platform-error.log

# PostgreSQL logs
tail -f /var/log/postgresql/postgresql-15-main.log
```

## Performance Tuning

### PostgreSQL

Edit `/etc/postgresql/15/main/postgresql.conf`:
```conf
max_connections = 100
shared_buffers = 256MB
effective_cache_size = 1GB
work_mem = 16MB
```

Restart: `systemctl restart postgresql`

### Nginx

Edit `/etc/nginx/nginx.conf`:
```nginx
worker_processes auto;
worker_connections 1024;
```

Restart: `systemctl restart nginx`

### Node.js

Adjust PM2 instances (if using PM2):
```bash
pm2 scale lfcs-platform 2  # Run 2 instances
```

## Security Best Practices

1. **Change default passwords immediately**
2. **Keep system updated:**
   ```bash
   apt update && apt upgrade -y
   ```
3. **Monitor fail2ban:**
   ```bash
   fail2ban-client status
   ```
4. **Review firewall rules:**
   ```bash
   ufw status verbose
   ```
5. **Check SSL certificate expiry:**
   ```bash
   certbot certificates
   ```
6. **Regular backups verification**
7. **Monitor disk space:**
   ```bash
   df -h
   ```

## Scaling

### Vertical Scaling
- Increase server RAM/CPU
- Adjust PostgreSQL configuration
- Add more Node.js workers

### Horizontal Scaling
- Load balancer (HAProxy/Nginx)
- Multiple application servers
- PostgreSQL replication
- Redis caching layer

## Support

For installation issues:
1. Check `/var/log/lfcs-installer.log`
2. Run `lfcs-status`
3. Review error messages carefully
4. Ensure all prerequisites met

---

**Last Updated:** January 2026  
**Platform Version:** 1.0
