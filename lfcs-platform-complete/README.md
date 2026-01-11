# LFCS Learning Platform - Complete Deployment Package

## 🎯 What You Have

This is a complete, production-ready LFCS (Linux Foundation Certified System Administrator) learning platform with:

- ✅ **125+ Exam-Accurate Questions** across all 5 LFCS domains
- ✅ **Real Terminal Simulator** using xterm.js
- ✅ **Modern Tech Stack** (Next.js 14, React, TypeScript, PostgreSQL)
- ✅ **Custom Lab Creator** for adding your own questions
- ✅ **Progress Tracking** and exam simulations
- ✅ **SSL/HTTPS** with Let's Encrypt
- ✅ **Intelligent Auto-Installer** with self-healing

## 🚀 Quick Start

### Prerequisites
- Ubuntu 20.04+ or similar Linux distribution
- Root access
- Domain name pointing to your server
- 2GB+ RAM, 10GB+ disk space

### Installation

1. **Upload this entire folder to your server**
```bash
scp -r lfcs-platform-complete root@your-server:/root/
```

2. **SSH into your server**
```bash
ssh root@your-server
```

3. **Run the installer**
```bash
cd /root/lfcs-platform-complete/scripts
chmod +x lfcs-platform-installer.sh
./lfcs-platform-installer.sh
```

The installer will automatically:
- Install Node.js, PostgreSQL, Nginx
- Set up the database with all 125 questions
- Configure SSL certificates
- Set up firewall and security
- Create management scripts
- Start the application

### After Installation

Access your platform at: `https://velocitylab.co.za`

**Default Admin Credentials:**
- Username: `superadmin`
- Password: `Superadmin@123`

**Management Commands:**
```bash
lfcs-start      # Start the platform
lfcs-stop       # Stop the platform
lfcs-restart    # Restart the platform
lfcs-status     # Check status
lfcs-logs       # View logs
lfcs-backup     # Create database backup
```

## 📁 Project Structure

```
lfcs-platform-complete/
├── app/                    # Next.js application routes
│   ├── api/               # API endpoints
│   ├── dashboard/         # User dashboard
│   ├── questions/         # Question practice
│   ├── lab/               # Custom lab creator
│   └── terminal/          # Terminal simulator
├── components/            # React components
├── lib/                   # Utilities and database
├── database/              # SQL schema and questions
├── scripts/               # Installation scripts
└── docs/                  # Documentation
```

## 🎓 Features

### 1. Question Bank (125+ Questions)
- **Operations & Deployment (30)**: systemd, containers, SELinux
- **Networking (30)**: SSH, firewalls, DNS, routing
- **Storage (25)**: LVM, partitions, NFS, RAID
- **Essential Commands (25)**: grep, find, git, openssl
- **Users & Groups (25)**: permissions, ACLs, sudo

### 2. Learning Modes
- **Practice Mode**: Learn with hints and detailed feedback
- **Exam Mode**: Timed simulations matching real LFCS exam
- **Custom Labs**: Create your own questions and scenarios

### 3. Terminal Simulator
- Real Ubuntu terminal feel
- Execute actual Linux commands
- Instant feedback on solutions
- Copy/paste support

### 4. Progress Tracking
- Domain mastery levels
- Study streaks
- Achievement system
- Performance analytics

## 🔧 Configuration

### Environment Variables
Located in `/opt/lfcs-platform/.env.local`:
- `DATABASE_URL`: PostgreSQL connection
- `JWT_SECRET`: Authentication secret
- `NEXT_PUBLIC_APP_URL`: Your domain

### Database Connection
- Host: localhost
- Database: lfcs_platform
- User: lfcs_admin
- Password: Superadmin@123

### Nginx Configuration
Located at: `/etc/nginx/sites-available/lfcs-platform`

## 🔒 Security

The platform includes:
- SSL/TLS encryption (Let's Encrypt)
- Fail2ban protection
- UFW firewall
- Password hashing (bcrypt)
- JWT authentication
- Security headers

## 📊 Database Schema

11 tables supporting:
- User management
- Question bank
- Progress tracking
- Exam simulations
- Custom labs
- Achievements
- Bookmarks & notes

## 🆘 Troubleshooting

### Platform won't start
```bash
lfcs-logs  # Check error logs
systemctl status lfcs-platform
systemctl status postgresql
systemctl status nginx
```

### Database connection issues
```bash
sudo -u postgres psql -d lfcs_platform -c "SELECT COUNT(*) FROM questions;"
```

### SSL certificate issues
```bash
certbot renew --dry-run
```

## 📚 Additional Resources

- [LFCS Exam Objectives](https://training.linuxfoundation.org/certification/linux-foundation-certified-sysadmin-lfcs/)
- [Platform Documentation](./docs/)
- [API Documentation](./docs/API.md)

## 🔄 Backups

Automatic daily backups at 2 AM to `/opt/lfcs-platform/backups/`

Manual backup:
```bash
lfcs-backup
```

Restore:
```bash
gunzip < backup.sql.gz | PGPASSWORD='Superadmin@123' psql -h localhost -U lfcs_admin lfcs_platform
```

## 🤝 Support

For issues or questions:
1. Check logs: `lfcs-logs`
2. Review documentation in `./docs/`
3. Check system status: `lfcs-status`

## 📝 License

This platform is built for educational purposes. LFCS is a trademark of The Linux Foundation.

---

**Version:** 1.0  
**Created:** January 2026  
**Status:** Production Ready
