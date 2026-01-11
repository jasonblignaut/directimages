#!/bin/bash

################################################################################
# LFCS PLATFORM - COMPLETE APPLICATION GENERATOR
# This script generates all application files for the LFCS Learning Platform
# Run this after the main installer to create the full application
################################################################################

set -e

INSTALL_DIR="/opt/lfcs-platform"
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[GEN]${NC} $1"
}

cd "$INSTALL_DIR"

################################################################################
# NEXT.JS CONFIGURATION FILES
################################################################################

log "Creating Next.js configuration..."

cat > next.config.js <<'NEXTCONFIG'
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  poweredByHeader: false,
  compress: true,
  
  webpack: (config, { isServer }) => {
    if (!isServer) {
      config.resolve.fallback = {
        ...config.resolve.fallback,
        fs: false,
        net: false,
        tls: false,
      };
    }
    return config;
  },
  
  async headers() {
    return [
      {
        source: '/:path*',
        headers: [
          {
            key: 'X-DNS-Prefetch-Control',
            value: 'on'
          },
          {
            key: 'Strict-Transport-Security',
            value: 'max-age=31536000; includeSubDomains'
          },
          {
            key: 'X-Frame-Options',
            value: 'SAMEORIGIN'
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff'
          },
          {
            key: 'Referrer-Policy',
            value: 'origin-when-cross-origin'
          }
        ]
      }
    ];
  }
}

module.exports = nextConfig
NEXTCONFIG

cat > tsconfig.json <<'TSCONFIG'
{
  "compilerOptions": {
    "target": "ES2020",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
TSCONFIG

cat > tailwind.config.js <<'TAILWIND'
/** @type {import('tailwindcss').Config} */
module.exports = {
  content: [
    './pages/**/*.{js,ts,jsx,tsx,mdx}',
    './components/**/*.{js,ts,jsx,tsx,mdx}',
    './app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    extend: {
      colors: {
        'terminal': {
          'bg': '#0C0C0C',
          'fg': '#CCCCCC',
          'black': '#0C0C0C',
          'red': '#C50F1F',
          'green': '#13A10E',
          'yellow': '#C19C00',
          'blue': '#0037DA',
          'magenta': '#881798',
          'cyan': '#3A96DD',
          'white': '#CCCCCC',
          'brightBlack': '#767676',
          'brightRed': '#E74856',
          'brightGreen': '#16C60C',
          'brightYellow': '#F9F1A5',
          'brightBlue': '#3B78FF',
          'brightMagenta': '#B4009E',
          'brightCyan': '#61D6D6',
          'brightWhite': '#F2F2F2',
        },
        'linux': {
          'ubuntu-orange': '#E95420',
          'ubuntu-purple': '#772953',
          'dark-bg': '#1a1a1a',
          'dark-surface': '#2d2d2d',
        }
      },
      fontFamily: {
        'mono': ['Ubuntu Mono', 'Courier New', 'monospace'],
      }
    },
  },
  plugins: [],
}
TAILWIND

cat > postcss.config.js <<'POSTCSS'
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
POSTCSS

################################################################################
# DATABASE LIB
################################################################################

log "Creating database library..."

mkdir -p lib

cat > lib/db.ts <<'DBLIB'
import { Pool, PoolClient } from 'pg';

const pool = new Pool({
  connectionString: process.env.DATABASE_URL,
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

export async function query(text: string, params?: any[]) {
  const start = Date.now();
  const res = await pool.query(text, params);
  const duration = Date.now() - start;
  console.log('Executed query', { text, duration, rows: res.rowCount });
  return res;
}

export async function getClient(): Promise<PoolClient> {
  const client = await pool.connect();
  return client;
}

export default pool;
DBLIB

################################################################################
# AUTH LIB
################################################################################

log "Creating authentication library..."

cat > lib/auth.ts <<'AUTHLIB'
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';

const JWT_SECRET = process.env.JWT_SECRET || 'change-this-secret-key';

export interface User {
  id: number;
  username: string;
  email: string;
  full_name?: string;
  is_active: boolean;
}

export interface AuthToken {
  userId: number;
  username: string;
  email: string;
}

export async function hashPassword(password: string): Promise<string> {
  return bcrypt.hash(password, 10);
}

export async function comparePassword(password: string, hash: string): Promise<boolean> {
  return bcrypt.compare(password, hash);
}

export function generateToken(user: User): string {
  const payload: AuthToken = {
    userId: user.id,
    username: user.username,
    email: user.email,
  };
  
  return jwt.sign(payload, JWT_SECRET, { expiresIn: '7d' });
}

export function verifyToken(token: string): AuthToken | null {
  try {
    return jwt.verify(token, JWT_SECRET) as AuthToken;
  } catch (error) {
    return null;
  }
}
AUTHLIB

################################################################################
# APP LAYOUT
################################################################################

log "Creating app structure..."

mkdir -p app

cat > app/layout.tsx <<'LAYOUT'
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'LFCS Learning Platform - Master Linux System Administration',
  description: 'Comprehensive LFCS exam preparation platform with 125+ realistic questions, terminal simulator, and custom lab creator',
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="en" className="dark">
      <body className={inter.className}>{children}</body>
    </html>
  )
}
LAYOUT

cat > app/globals.css <<'GLOBALCSS'
@tailwind base;
@tailwind components;
@tailwind utilities;

:root {
  --foreground-rgb: 255, 255, 255;
  --background-start-rgb: 26, 26, 26;
  --background-end-rgb: 13, 13, 13;
}

body {
  color: rgb(var(--foreground-rgb));
  background: linear-gradient(
      to bottom,
      transparent,
      rgb(var(--background-end-rgb))
    )
    rgb(var(--background-start-rgb));
  min-height: 100vh;
}

/* Terminal styles */
.xterm {
  padding: 10px;
}

.xterm-viewport {
  overflow-y: scroll;
  background-color: #0C0C0C !important;
}

.xterm-screen {
  background-color: #0C0C0C !important;
}

/* Scrollbar styling */
::-webkit-scrollbar {
  width: 10px;
}

::-webkit-scrollbar-track {
  background: #1a1a1a;
}

::-webkit-scrollbar-thumb {
  background: #4a4a4a;
  border-radius: 5px;
}

::-webkit-scrollbar-thumb:hover {
  background: #666;
}
GLOBALCSS

cat > app/page.tsx <<'HOMEPAGE'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { Terminal, BookOpen, Target, Trophy, PlusCircle } from 'lucide-react';

export default function Home() {
  const [stats, setStats] = useState({
    totalQuestions: 125,
    domains: 5,
    users: 0
  });

  return (
    <main className="min-h-screen bg-gradient-to-b from-gray-900 to-black text-white">
      {/* Header */}
      <header className="border-b border-gray-800">
        <div className="container mx-auto px-4 py-4 flex items-center justify-between">
          <div className="flex items-center space-x-2">
            <Terminal className="text-linux-ubuntu-orange" size={32} />
            <h1 className="text-2xl font-bold">LFCS Platform</h1>
          </div>
          <nav className="flex space-x-4">
            <Link href="/login" className="px-4 py-2 rounded hover:bg-gray-800 transition">
              Login
            </Link>
            <Link href="/register" className="px-4 py-2 bg-linux-ubuntu-orange rounded hover:bg-orange-600 transition">
              Sign Up
            </Link>
          </nav>
        </div>
      </header>

      {/* Hero Section */}
      <section className="container mx-auto px-4 py-20 text-center">
        <h1 className="text-5xl font-bold mb-6">
          Master the <span className="text-linux-ubuntu-orange">LFCS Exam</span>
        </h1>
        <p className="text-xl text-gray-400 mb-8 max-w-2xl mx-auto">
          The most comprehensive Linux Foundation Certified System Administrator preparation platform
          with realistic exam simulations and hands-on terminal practice
        </p>
        <div className="flex justify-center space-x-4">
          <Link href="/register" className="px-8 py-3 bg-linux-ubuntu-orange text-white rounded-lg text-lg font-semibold hover:bg-orange-600 transition">
            Start Learning Free
          </Link>
          <Link href="/demo" className="px-8 py-3 border border-gray-600 rounded-lg text-lg font-semibold hover:bg-gray-800 transition">
            Try Demo
          </Link>
        </div>
      </section>

      {/* Stats Section */}
      <section className="container mx-auto px-4 py-12">
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
          <div className="bg-gray-800 rounded-lg p-6 text-center border border-gray-700">
            <BookOpen className="mx-auto mb-3 text-linux-ubuntu-orange" size={40} />
            <div className="text-3xl font-bold mb-2">{stats.totalQuestions}+</div>
            <div className="text-gray-400">Exam Questions</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-6 text-center border border-gray-700">
            <Target className="mx-auto mb-3 text-green-500" size={40} />
            <div className="text-3xl font-bold mb-2">{stats.domains}</div>
            <div className="text-gray-400">LFCS Domains</div>
          </div>
          <div className="bg-gray-800 rounded-lg p-6 text-center border border-gray-700">
            <Trophy className="mx-auto mb-3 text-yellow-500" size={40} />
            <div className="text-3xl font-bold mb-2">100%</div>
            <div className="text-gray-400">Exam Coverage</div>
          </div>
        </div>
      </section>

      {/* Features Section */}
      <section className="container mx-auto px-4 py-20">
        <h2 className="text-4xl font-bold text-center mb-12">Platform Features</h2>
        <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
          <div className="bg-gray-800 rounded-lg p-8 border border-gray-700">
            <Terminal className="text-linux-ubuntu-orange mb-4" size={40} />
            <h3 className="text-2xl font-bold mb-3">Real Terminal Simulator</h3>
            <p className="text-gray-400">
              Practice with an authentic Ubuntu terminal experience. Execute real Linux commands
              and see immediate feedback on your solutions.
            </p>
          </div>

          <div className="bg-gray-800 rounded-lg p-8 border border-gray-700">
            <BookOpen className="text-blue-500 mb-4" size={40} />
            <h3 className="text-2xl font-bold mb-3">125+ Exam Questions</h3>
            <p className="text-gray-400">
              Comprehensive question bank covering all 5 LFCS domains with multiple correct answer
              variations, hints, and detailed explanations.
            </p>
          </div>

          <div className="bg-gray-800 rounded-lg p-8 border border-gray-700">
            <Target className="text-green-500 mb-4" size={40} />
            <h3 className="text-2xl font-bold mb-3">Exam Simulations</h3>
            <p className="text-gray-400">
              Take full-length timed exams that mirror the real LFCS certification test.
              Track your progress and identify weak areas.
            </p>
          </div>

          <div className="bg-gray-800 rounded-lg p-8 border border-gray-700">
            <PlusCircle className="text-purple-500 mb-4" size={40} />
            <h3 className="text-2xl font-bold mb-3">Custom Lab Creator</h3>
            <p className="text-gray-400">
              Create your own practice questions and labs. Perfect for team training
              and collaborative learning.
            </p>
          </div>
        </div>
      </section>

      {/* Domains Section */}
      <section className="container mx-auto px-4 py-20">
        <h2 className="text-4xl font-bold text-center mb-12">LFCS Exam Domains</h2>
        <div className="space-y-4 max-w-3xl mx-auto">
          {[
            { name: 'Operations & Deployment', weight: '25%', color: 'bg-red-500' },
            { name: 'Networking', weight: '25%', color: 'bg-cyan-500' },
            { name: 'Storage', weight: '20%', color: 'bg-yellow-500' },
            { name: 'Essential Commands', weight: '20%', color: 'bg-green-500' },
            { name: 'Users & Groups', weight: '10%', color: 'bg-purple-500' }
          ].map((domain) => (
            <div key={domain.name} className="bg-gray-800 rounded-lg p-4 border border-gray-700 flex items-center justify-between">
              <div className="flex items-center space-x-4">
                <div className={`w-3 h-3 rounded-full ${domain.color}`}></div>
                <span className="text-lg font-semibold">{domain.name}</span>
              </div>
              <span className="text-gray-400">{domain.weight}</span>
            </div>
          ))}
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-gray-800 py-8">
        <div className="container mx-auto px-4 text-center text-gray-500">
          <p>© 2026 LFCS Learning Platform. Built for system administrators.</p>
        </div>
      </footer>
    </main>
  );
}
HOMEPAGE

################################################################################
# API ROUTES
################################################################################

log "Creating API routes..."

mkdir -p app/api/{auth,questions,domains,terminal}

cat > app/api/auth/login/route.ts <<'LOGINAPI'
import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { comparePassword, generateToken } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const { username, password } = await request.json();

    if (!username || !password) {
      return NextResponse.json(
        { error: 'Username and password are required' },
        { status: 400 }
      );
    }

    const result = await query(
      'SELECT * FROM users WHERE username = $1 AND is_active = true',
      [username]
    );

    if (result.rows.length === 0) {
      return NextResponse.json(
        { error: 'Invalid credentials' },
        { status: 401 }
      );
    }

    const user = result.rows[0];
    const isValidPassword = await comparePassword(password, user.password_hash);

    if (!isValidPassword) {
      return NextResponse.json(
        { error: 'Invalid credentials' },
        { status: 401 }
      );
    }

    // Update last login
    await query(
      'UPDATE users SET last_login = CURRENT_TIMESTAMP WHERE id = $1',
      [user.id]
    );

    const token = generateToken(user);

    return NextResponse.json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        full_name: user.full_name,
      },
    });
  } catch (error) {
    console.error('Login error:', error);
    return NextResponse.json(
      { error: 'An error occurred during login' },
      { status: 500 }
    );
  }
}
LOGINAPI

cat > app/api/auth/register/route.ts <<'REGISTERAPI'
import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';
import { hashPassword, generateToken } from '@/lib/auth';

export async function POST(request: NextRequest) {
  try {
    const { username, email, password, full_name } = await request.json();

    if (!username || !email || !password) {
      return NextResponse.json(
        { error: 'Username, email, and password are required' },
        { status: 400 }
      );
    }

    // Check if user exists
    const existingUser = await query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );

    if (existingUser.rows.length > 0) {
      return NextResponse.json(
        { error: 'Username or email already exists' },
        { status: 409 }
      );
    }

    // Hash password
    const password_hash = await hashPassword(password);

    // Create user
    const result = await query(
      'INSERT INTO users (username, email, password_hash, full_name) VALUES ($1, $2, $3, $4) RETURNING *',
      [username, email, password_hash, full_name || null]
    );

    const user = result.rows[0];

    // Initialize user progress for all domains
    await query(
      'INSERT INTO user_progress (user_id, domain_id, mastery_level) SELECT $1, id, 0 FROM domains',
      [user.id]
    );

    const token = generateToken(user);

    return NextResponse.json({
      success: true,
      token,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        full_name: user.full_name,
      },
    });
  } catch (error) {
    console.error('Registration error:', error);
    return NextResponse.json(
      { error: 'An error occurred during registration' },
      { status: 500 }
    );
  }
}
REGISTERAPI

cat > app/api/domains/route.ts <<'DOMAINSAPI'
import { NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET() {
  try {
    const result = await query(`
      SELECT 
        d.*,
        COUNT(q.id) as question_count
      FROM domains d
      LEFT JOIN questions q ON d.id = q.domain_id
      GROUP BY d.id
      ORDER BY d.id
    `);

    return NextResponse.json({ domains: result.rows });
  } catch (error) {
    console.error('Error fetching domains:', error);
    return NextResponse.json(
      { error: 'Failed to fetch domains' },
      { status: 500 }
    );
  }
}
DOMAINSAPI

cat > app/api/questions/route.ts <<'QUESTIONSAPI'
import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(request: NextRequest) {
  try {
    const searchParams = request.nextUrl.searchParams;
    const domain_id = searchParams.get('domain_id');
    const difficulty = searchParams.get('difficulty');
    const limit = searchParams.get('limit') || '10';

    let sql = `
      SELECT 
        q.*,
        d.name as domain_name,
        d.color as domain_color,
        (SELECT COUNT(*) FROM answers WHERE question_id = q.id) as answer_count,
        (SELECT COUNT(*) FROM hints WHERE question_id = q.id) as hint_count
      FROM questions q
      JOIN domains d ON q.domain_id = d.id
      WHERE 1=1
    `;
    
    const params: any[] = [];
    let paramCount = 1;

    if (domain_id) {
      sql += ` AND q.domain_id = $${paramCount}`;
      params.push(domain_id);
      paramCount++;
    }

    if (difficulty) {
      sql += ` AND q.difficulty = $${paramCount}`;
      params.push(difficulty);
      paramCount++;
    }

    sql += ` ORDER BY RANDOM() LIMIT $${paramCount}`;
    params.push(limit);

    const result = await query(sql, params);

    return NextResponse.json({ questions: result.rows });
  } catch (error) {
    console.error('Error fetching questions:', error);
    return NextResponse.json(
      { error: 'Failed to fetch questions' },
      { status: 500 }
    );
  }
}
QUESTIONSAPI

cat > app/api/questions/[id]/route.ts <<'QUESTIONDETAILAPI'
import { NextRequest, NextResponse } from 'next/server';
import { query } from '@/lib/db';

export async function GET(
  request: NextRequest,
  { params }: { params: { id: string } }
) {
  try {
    const questionId = params.id;

    // Get question details
    const questionResult = await query(
      `SELECT q.*, d.name as domain_name, d.color as domain_color
       FROM questions q
       JOIN domains d ON q.domain_id = d.id
       WHERE q.id = $1`,
      [questionId]
    );

    if (questionResult.rows.length === 0) {
      return NextResponse.json(
        { error: 'Question not found' },
        { status: 404 }
      );
    }

    const question = questionResult.rows[0];

    // Get answers
    const answersResult = await query(
      'SELECT * FROM answers WHERE question_id = $1 ORDER BY step_number, is_primary DESC',
      [questionId]
    );

    // Get hints
    const hintsResult = await query(
      'SELECT * FROM hints WHERE question_id = $1 ORDER BY hint_level',
      [questionId]
    );

    // Get common mistakes
    const mistakesResult = await query(
      'SELECT * FROM common_mistakes WHERE question_id = $1',
      [questionId]
    );

    // Get man pages
    const manPagesResult = await query(
      'SELECT * FROM man_page_references WHERE question_id = $1',
      [questionId]
    );

    return NextResponse.json({
      question: {
        ...question,
        answers: answersResult.rows,
        hints: hintsResult.rows,
        common_mistakes: mistakesResult.rows,
        man_pages: manPagesResult.rows,
      },
    });
  } catch (error) {
    console.error('Error fetching question details:', error);
    return NextResponse.json(
      { error: 'Failed to fetch question details' },
      { status: 500 }
    );
  }
}
QUESTIONDETAILAPI

log "Application files generated successfully!"
log "Run: cd $INSTALL_DIR && pnpm build && systemctl start lfcs-platform"
