# LFCS Platform - Complete Installation Guide

## 📋 Overview

This package contains everything needed to deploy a production-ready LFCS learning platform with 125+ exam questions, real terminal simulator, and comprehensive tracking features.

## 🎯 What Will Be Installed

- ✅ Next.js 14 web application
- ✅ PostgreSQL 15 database with 125+ questions
- ✅ Nginx reverse proxy with SSL
- ✅ Firewall (UFW) and Fail2ban security
- ✅ Automated backups
- ✅ Management scripts

## 🚀 Quick Installation (3 Steps)

### Step 1: Upload to Server

From your local machine:
```bash
# Create tarball
tar -czf lfcs-platform.tar.gz lfcs-platform-complete/

# Upload to server
scp lfcs-platform.tar.gz root@4.221.152.28:/root/
```

### Step 2: Extract on Server

SSH into server:
```bash
ssh root@4.221.152.28
cd /root
tar -xzf lfcs-platform.tar.gz
cd lfcs-platform-complete
```

### Step 3: Run Installer

```bash
chmod +x DEPLOY.sh
./DEPLOY.sh
```

**Installation Time:** 10-20 minutes

## ✅ Post-Installation

### 1. Verify Installation

```bash
lfcs-status    # Check all services
curl -I https://velocitylab.co.za  # Test web access
```

### 2. First Login

- URL: `https://velocitylab.co.za`
- Username: `superadmin`
- Password: `Superadmin@123`

**⚠️ Change password immediately after first login!**

### 3. Test Database

```bash
PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin -d lfcs_platform -c "SELECT COUNT(*) FROM questions;"
# Should return: 125
```

## 🛠️ Management

### Daily Operations

```bash
lfcs-start      # Start platform
lfcs-stop       # Stop platform
lfcs-restart    # Restart platform
lfcs-status     # Check status
lfcs-logs       # View real-time logs
```

### Backups

Automatic backups run daily at 2 AM to `/opt/lfcs-platform/backups/`

Manual backup:
```bash
lfcs-backup
```

Restore from backup:
```bash
gunzip < /opt/lfcs-platform/backups/db_YYYYMMDD_HHMMSS.sql.gz | \
  PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin lfcs_platform
```

## 🔧 Configuration

### Environment Variables

Located at: `/opt/lfcs-platform/.env.local`

Key variables:
- `DATABASE_URL`: PostgreSQL connection string
- `JWT_SECRET`: Authentication secret (auto-generated)
- `NEXT_PUBLIC_APP_URL`: Your domain

### Database Access

```bash
PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin -d lfcs_platform
```

### Nginx Configuration

Located at: `/etc/nginx/sites-available/lfcs-platform`

Test configuration:
```bash
nginx -t
```

Reload after changes:
```bash
systemctl reload nginx
```

## 🔍 Troubleshooting

### Platform Won't Start

```bash
# Check logs
lfcs-logs

# Check service status
systemctl status lfcs-platform

# Check if port 3000 is in use
lsof -i :3000

# Rebuild application
cd /opt/lfcs-platform
pnpm install
pnpm build
lfcs-restart
```

### Database Connection Issues

```bash
# Check PostgreSQL status
systemctl status postgresql

# Test connection
PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin -d lfcs_platform -c "SELECT 1;"

# Check PostgreSQL logs
tail -f /var/log/postgresql/postgresql-15-main.log
```

### SSL Certificate Issues

```bash
# Check certificate status
certbot certificates

# Manual renewal
certbot renew

# Reinstall certificate
certbot --nginx -d velocitylab.co.za -d www.velocitylab.co.za
```

### Site Not Accessible

```bash
# Check DNS
nslookup velocitylab.co.za
# Should return: 4.221.152.28

# Check firewall
ufw status
# Should show ports 80, 443 as ALLOW

# Check Nginx
systemctl status nginx
nginx -t

# Check if app is running
curl http://localhost:3000
```

## 📊 Platform Features

### Question Bank (125+ Questions)

- **Operations & Deployment (30)**: systemd, containers, SELinux, kernel params
- **Networking (30)**: SSH, firewalls, DNS, routing, NTP
- **Storage (25)**: LVM, partitions, fstab, NFS, RAID
- **Essential Commands (25)**: grep, find, git, openssl, sed
- **Users & Groups (25)**: permissions, ACLs, sudo, password policies

### Learning Modes

1. **Practice Mode**
   - Hints and detailed feedback
   - Learn from mistakes
   - No time pressure

2. **Exam Mode**
   - Timed simulations
   - Real exam conditions
   - Performance tracking

3. **Custom Lab Creator**
   - Create your own questions
   - Share with team
   - Build custom scenarios

### Terminal Simulator

- Real Ubuntu terminal interface
- Execute actual Linux commands
- Instant validation
- Copy/paste support
- Full xterm.js features

## 🔒 Security

### Included Security Features

- ✅ SSL/TLS encryption (Let's Encrypt)
- ✅ UFW firewall configured
- ✅ Fail2ban brute-force protection
- ✅ Password hashing (bcrypt)
- ✅ JWT authentication
- ✅ Security headers
- ✅ Automatic SSL renewal

### Security Best Practices

1. Change default passwords immediately
2. Keep system updated: `apt update && apt upgrade`
3. Monitor logs: `lfcs-logs`
4. Review failed login attempts: `fail2ban-client status`
5. Check firewall: `ufw status verbose`

## 📈 Monitoring

### System Health

```bash
# Check all services
lfcs-status

# Monitor resources
htop

# Check disk space
df -h

# Check memory
free -h
```

### Application Logs

```bash
# Real-time logs
lfcs-logs

# Last 100 lines
journalctl -u lfcs-platform -n 100

# Nginx access logs
tail -f /var/log/nginx/lfcs-platform-access.log

# Nginx error logs
tail -f /var/log/nginx/lfcs-platform-error.log
```

## 🔄 Updates

### Application Updates

```bash
cd /opt/lfcs-platform

# Pull latest changes (if using git)
git pull

# Install dependencies
pnpm install

# Build
pnpm build

# Restart
lfcs-restart
```

### System Updates

```bash
apt update
apt upgrade -y
reboot  # If kernel updated
```

## 📁 File Locations

```
/opt/lfcs-platform/          # Application files
/opt/lfcs-platform/backups/  # Database backups
/etc/nginx/sites-available/  # Nginx configuration
/var/log/nginx/              # Nginx logs
/usr/local/bin/lfcs-*        # Management scripts
/etc/letsencrypt/            # SSL certificates
```

## 🆘 Getting Help

### Common Issues

1. **Site not loading**: Check DNS, firewall, Nginx
2. **Database errors**: Check PostgreSQL service and connection
3. **SSL errors**: Check certificate with `certbot certificates`
4. **500 errors**: Check application logs with `lfcs-logs`

### Support Resources

- Installation log: `/var/log/lfcs-installer.log`
- Application logs: `journalctl -u lfcs-platform`
- Documentation: `/root/lfcs-platform-complete/docs/`

## 📝 Customization

### Branding

- Logo: Place in `/opt/lfcs-platform/public/logo.png`
- Favicon: Place in `/opt/lfcs-platform/public/favicon.ico`
- Colors: Edit `/opt/lfcs-platform/tailwind.config.js`

### Add More Questions

Use the Custom Lab Creator in the platform UI, or add directly to database:

```sql
INSERT INTO questions (domain_id, title, scenario, task_description, difficulty)
VALUES (1, 'Question Title', 'Scenario text', 'Task description', 'medium');
```

## ✨ Features Roadmap

Current version includes:
- ✅ 125+ Questions
- ✅ Terminal Simulator
- ✅ Progress Tracking
- ✅ Custom Lab Creator
- ✅ Exam Simulations

Future enhancements could include:
- Real container execution
- Video tutorials
- Team collaboration
- Advanced analytics
- Mobile app

## 📄 License

This platform is for educational purposes. LFCS is a trademark of The Linux Foundation.

---

**Version:** 1.0  
**Last Updated:** January 2026  
**Support:** Check logs and documentation for troubleshooting
