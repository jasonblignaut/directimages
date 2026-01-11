#!/bin/bash

################################################################################
# LFCS Platform - Database Import Script
# Imports 125+ exam questions into PostgreSQL
################################################################################

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear
echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   LFCS PLATFORM - DATABASE IMPORT                        ║${NC}"
echo -e "${BLUE}║   125+ Professional Exam Questions                        ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if running as correct user
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}Warning: Running as root. Will use sudo -u postgres for PostgreSQL commands.${NC}"
    echo ""
fi

# Check if PostgreSQL is running
if ! systemctl is-active --quiet postgresql; then
    echo -e "${YELLOW}PostgreSQL is not running. Starting it...${NC}"
    sudo systemctl start postgresql
    sleep 2
fi

echo -e "${GREEN}✓ PostgreSQL is running${NC}"
echo ""

# Get database password
echo -e "${YELLOW}Enter database password for lfcs_admin:${NC}"
read -sp "Password: " DB_PASSWORD
echo ""
echo ""

# Create database and user
echo -e "${BLUE}Creating database and user...${NC}"

sudo -u postgres psql > /dev/null 2>&1 << EOF
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

echo -e "${GREEN}✓ Database created${NC}"
echo ""

# Import schema
echo -e "${BLUE}Importing database schema...${NC}"
if [ -f "database/01-schema.sql" ]; then
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -f database/01-schema.sql > /dev/null 2>&1
    echo -e "${GREEN}✓ Schema imported${NC}"
else
    echo -e "${RED}✗ Schema file not found: database/01-schema.sql${NC}"
    exit 1
fi

# Import questions
echo -e "${BLUE}Importing questions...${NC}"

if [ -f "database/02-questions-operations.sql" ]; then
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -f database/02-questions-operations.sql > /dev/null 2>&1
    echo -e "${GREEN}✓ Operations & Deployment questions (30)${NC}"
else
    echo -e "${YELLOW}⚠ Operations questions file not found${NC}"
fi

if [ -f "database/03-questions-networking.sql" ]; then
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -f database/03-questions-networking.sql > /dev/null 2>&1
    echo -e "${GREEN}✓ Networking questions (30)${NC}"
else
    echo -e "${YELLOW}⚠ Networking questions file not found${NC}"
fi

if [ -f "database/04-questions-storage-commands-users.sql" ]; then
    PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -f database/04-questions-storage-commands-users.sql > /dev/null 2>&1
    echo -e "${GREEN}✓ Storage/Commands/Users questions (65)${NC}"
else
    echo -e "${YELLOW}⚠ Storage/Commands/Users questions file not found${NC}"
fi

echo ""

# Verify import
echo -e "${BLUE}Verifying import...${NC}"
QUESTION_COUNT=$(PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform -t -c "SELECT COUNT(*) FROM questions;" | tr -d ' ')

echo -e "${GREEN}✓ Total questions loaded: $QUESTION_COUNT${NC}"
echo ""

# Show breakdown
echo -e "${BLUE}Questions by domain:${NC}"
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U lfcs_admin -d lfcs_platform << 'EOF'
SELECT 
    d.name as "Domain",
    COUNT(q.id) as "Questions"
FROM domains d
LEFT JOIN questions q ON d.id = q.domain_id
GROUP BY d.id, d.name
ORDER BY d.id;
EOF

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   DATABASE IMPORT COMPLETE!                              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Connection details:${NC}"
echo -e "  Database: lfcs_platform"
echo -e "  User: lfcs_admin"
echo -e "  Host: localhost"
echo -e "  Port: 5432"
echo ""
echo -e "${BLUE}Test connection:${NC}"
echo -e "  PGPASSWORD='your_password' psql -h localhost -U lfcs_admin -d lfcs_platform"
echo ""
echo -e "${BLUE}Create backup:${NC}"
echo -e "  PGPASSWORD='your_password' pg_dump -h localhost -U lfcs_admin lfcs_platform | gzip > backup.sql.gz"
echo ""
