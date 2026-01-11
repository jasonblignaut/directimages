-- ============================================================================
-- LFCS LEARNING PLATFORM - DATABASE SCHEMA
-- Complete schema for all tables
-- ============================================================================

-- Drop existing tables if they exist
DROP TABLE IF EXISTS user_notes CASCADE;
DROP TABLE IF EXISTS user_bookmarks CASCADE;
DROP TABLE IF EXISTS achievements CASCADE;
DROP TABLE IF EXISTS study_sessions CASCADE;
DROP TABLE IF EXISTS exam_simulation_questions CASCADE;
DROP TABLE IF EXISTS exam_simulations CASCADE;
DROP TABLE IF EXISTS custom_exam_templates CASCADE;
DROP TABLE IF EXISTS user_attempts CASCADE;
DROP TABLE IF EXISTS user_progress CASCADE;
DROP TABLE IF EXISTS common_mistakes CASCADE;
DROP TABLE IF EXISTS man_page_references CASCADE;
DROP TABLE IF EXISTS hints CASCADE;
DROP TABLE IF EXISTS answers CASCADE;
DROP TABLE IF EXISTS questions CASCADE;
DROP TABLE IF EXISTS domains CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- ============================================================================
-- USERS TABLE
-- ============================================================================
CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_login TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    study_streak_days INTEGER DEFAULT 0,
    total_study_time INTEGER DEFAULT 0,
    theme_preference VARCHAR(20) DEFAULT 'dark'
);

-- ============================================================================
-- DOMAINS TABLE - 5 LFCS Exam Domains
-- ============================================================================
CREATE TABLE domains (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    weight INTEGER NOT NULL,
    color VARCHAR(20),
    exam_percentage INTEGER NOT NULL,
    total_questions INTEGER DEFAULT 0
);

-- Insert the 5 LFCS domains
INSERT INTO domains (name, description, weight, color, exam_percentage) VALUES
(
    'Operations & Deployment',
    'System services (systemd), logging (journald, rsyslog), process management, package management, container basics (podman/docker), SELinux basics, kernel parameters, boot process',
    25,
    '#FF6B6B',
    25
),
(
    'Networking',
    'Network configuration (nmcli, ip), SSH configuration and hardening, firewall configuration (firewalld, ufw, iptables), DNS/hostname configuration, routing, reverse proxy (nginx), time synchronization (chrony/NTP)',
    25,
    '#4ECDC4',
    25
),
(
    'Storage',
    'Partition management (fdisk, parted), LVM (physical volumes, volume groups, logical volumes), fstab configuration, swap configuration, NFS client/server, RAID basics, disk quotas, filesystem performance',
    20,
    '#FFE66D',
    20
),
(
    'Essential Commands',
    'Text processing (grep, sed, awk, cut, sort, uniq), file operations (find, tar, gzip), git version control, SSL/TLS certificates (openssl), text editors (vim, nano), shell scripting basics',
    20,
    '#95E1D3',
    20
),
(
    'Users & Groups',
    'User and group management (useradd, usermod, groupadd), file permissions and ownership, ACLs (Access Control Lists), sudo configuration, password policies (chage), LDAP authentication basics',
    10,
    '#C7CEEA',
    10
);

-- ============================================================================
-- QUESTIONS TABLE
-- ============================================================================
CREATE TABLE questions (
    id SERIAL PRIMARY KEY,
    domain_id INTEGER REFERENCES domains(id),
    title VARCHAR(255) NOT NULL,
    scenario TEXT NOT NULL,
    task_description TEXT NOT NULL,
    difficulty VARCHAR(20) CHECK (difficulty IN ('easy', 'medium', 'hard')),
    points INTEGER DEFAULT 5,
    time_estimate INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- ANSWERS TABLE - Multiple correct variations
-- ============================================================================
CREATE TABLE answers (
    id SERIAL PRIMARY KEY,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    command_text TEXT NOT NULL,
    explanation TEXT,
    step_number INTEGER DEFAULT 1,
    is_primary BOOLEAN DEFAULT false,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- HINTS TABLE - 3 levels of progressive hints
-- ============================================================================
CREATE TABLE hints (
    id SERIAL PRIMARY KEY,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    hint_level INTEGER CHECK (hint_level IN (1, 2, 3)),
    hint_text TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- COMMON MISTAKES TABLE
-- ============================================================================
CREATE TABLE common_mistakes (
    id SERIAL PRIMARY KEY,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    mistake_description TEXT NOT NULL,
    why_wrong TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- MAN PAGE REFERENCES TABLE
-- ============================================================================
CREATE TABLE man_page_references (
    id SERIAL PRIMARY KEY,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    man_page VARCHAR(100) NOT NULL,
    section VARCHAR(50),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- USER ATTEMPTS TABLE - Learning mode practice
-- ============================================================================
CREATE TABLE user_attempts (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    attempt_number INTEGER DEFAULT 1,
    user_answer TEXT,
    is_correct BOOLEAN,
    hints_used INTEGER DEFAULT 0,
    time_spent INTEGER,
    attempted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- CUSTOM EXAM TEMPLATES TABLE
-- ============================================================================
CREATE TABLE custom_exam_templates (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    template_name VARCHAR(255) NOT NULL,
    description TEXT,
    domain_selections JSONB NOT NULL,
    difficulty_filter VARCHAR(20),
    question_count INTEGER NOT NULL,
    time_limit INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_public BOOLEAN DEFAULT false
);

-- ============================================================================
-- EXAM SIMULATIONS TABLE
-- ============================================================================
CREATE TABLE exam_simulations (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    simulation_number INTEGER,
    template_id INTEGER REFERENCES custom_exam_templates(id),
    exam_type VARCHAR(20) DEFAULT 'standard',
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP,
    total_time INTEGER,
    score INTEGER,
    passed BOOLEAN,
    questions_attempted INTEGER,
    questions_correct INTEGER
);

-- ============================================================================
-- EXAM SIMULATION QUESTIONS TABLE
-- ============================================================================
CREATE TABLE exam_simulation_questions (
    id SERIAL PRIMARY KEY,
    simulation_id INTEGER REFERENCES exam_simulations(id) ON DELETE CASCADE,
    question_id INTEGER REFERENCES questions(id),
    user_answer TEXT,
    is_correct BOOLEAN,
    question_order INTEGER,
    time_spent INTEGER
);

-- ============================================================================
-- USER PROGRESS TABLE - Domain mastery tracking
-- ============================================================================
CREATE TABLE user_progress (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    domain_id INTEGER REFERENCES domains(id),
    questions_attempted INTEGER DEFAULT 0,
    questions_correct INTEGER DEFAULT 0,
    mastery_level INTEGER DEFAULT 0,
    last_practiced TIMESTAMP,
    UNIQUE(user_id, domain_id)
);

-- ============================================================================
-- STUDY SESSIONS TABLE
-- ============================================================================
CREATE TABLE study_sessions (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    started_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    ended_at TIMESTAMP,
    questions_attempted INTEGER DEFAULT 0,
    questions_correct INTEGER DEFAULT 0,
    domains_practiced JSONB
);

-- ============================================================================
-- ACHIEVEMENTS TABLE
-- ============================================================================
CREATE TABLE achievements (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    achievement_type VARCHAR(50) NOT NULL,
    achievement_name VARCHAR(100) NOT NULL,
    description TEXT,
    earned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    metadata JSONB
);

-- ============================================================================
-- USER BOOKMARKS TABLE
-- ============================================================================
CREATE TABLE user_bookmarks (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    question_id INTEGER REFERENCES questions(id) ON DELETE CASCADE,
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(user_id, question_id)
);

-- ============================================================================
-- USER NOTES TABLE
-- ============================================================================
CREATE TABLE user_notes (
    id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES users(id) ON DELETE CASCADE,
    domain_id INTEGER REFERENCES domains(id),
    note_title VARCHAR(255),
    note_content TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================================
-- INDEXES FOR PERFORMANCE
-- ============================================================================
CREATE INDEX idx_questions_domain ON questions(domain_id);
CREATE INDEX idx_questions_difficulty ON questions(difficulty);
CREATE INDEX idx_user_attempts_user ON user_attempts(user_id);
CREATE INDEX idx_user_attempts_question ON user_attempts(question_id);
CREATE INDEX idx_exam_simulations_user ON exam_simulations(user_id);
CREATE INDEX idx_user_progress_user ON user_progress(user_id);
CREATE INDEX idx_user_progress_domain ON user_progress(domain_id);
CREATE INDEX idx_custom_exam_templates_user ON custom_exam_templates(user_id);
