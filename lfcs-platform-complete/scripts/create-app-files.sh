#!/bin/bash
# Creates all application code files

INSTALL_DIR=${1:-"/opt/lfcs-platform"}

echo "Creating application files in $INSTALL_DIR..."

mkdir -p "$INSTALL_DIR"/{app/{api/{auth/{login,register},questions,domains,exam,terminal},dashboard,practice,exam,lab},components/{terminal,quiz,layout},lib,public,styles}

# Terminal Component
cat > "$INSTALL_DIR/components/terminal/TerminalEmulator.tsx" << 'TERMCOMP'
'use client';

import { useEffect, useRef, useState } from 'react';
import { Terminal } from 'xterm';
import { FitAddon } from 'xterm-addon-fit';
import { WebLinksAddon } from 'xterm-addon-web-links';
import 'xterm/css/xterm.css';

interface TerminalEmulatorProps {
  onCommand?: (command: string) => void;
  readonly?: boolean;
}

export default function TerminalEmulator({ onCommand, readonly = false }: TerminalEmulatorProps) {
  const terminalRef = useRef<HTMLDivElement>(null);
  const xtermRef = useRef<Terminal | null>(null);
  const fitAddonRef = useRef<FitAddon | null>(null);
  const [currentCommand, setCurrentCommand] = useState('');

  useEffect(() => {
    if (!terminalRef.current) return;

    // Initialize terminal
    const term = new Terminal({
      cursorBlink: true,
      fontSize: 14,
      fontFamily: '"Ubuntu Mono", "Courier New", monospace',
      theme: {
        background: '#0C0C0C',
        foreground: '#CCCCCC',
        cursor: '#CCCCCC',
        black: '#0C0C0C',
        red: '#C50F1F',
        green: '#13A10E',
        yellow: '#C19C00',
        blue: '#0037DA',
        magenta: '#881798',
        cyan: '#3A96DD',
        white: '#CCCCCC',
        brightBlack: '#767676',
        brightRed: '#E74856',
        brightGreen: '#16C60C',
        brightYellow: '#F9F1A5',
        brightBlue: '#3B78FF',
        brightMagenta: '#B4009E',
        brightCyan: '#61D6D6',
        brightWhite: '#F2F2F2',
      },
      cols: 80,
      rows: 24,
    });

    const fitAddon = new FitAddon();
    const webLinksAddon = new WebLinksAddon();
    
    term.loadAddon(fitAddon);
    term.loadAddon(webLinksAddon);
    
    term.open(terminalRef.current);
    fitAddon.fit();

    xtermRef.current = term;
    fitAddonRef.current = fitAddon;

    // Write welcome message
    term.writeln('\x1b[1;32mLFCS Terminal Simulator\x1b[0m');
    term.writeln('\x1b[36mUbuntu 22.04 LTS - Practice Environment\x1b[0m');
    term.writeln('');
    term.write('superadmin@lfcs-lab:~$ ');

    let command = '';

    term.onData((data) => {
      if (readonly) return;

      const code = data.charCodeAt(0);

      if (code === 13) { // Enter
        term.write('\r\n');
        if (command.trim() && onCommand) {
          onCommand(command.trim());
        }
        setCurrentCommand('');
        command = '';
        term.write('superadmin@lfcs-lab:~$ ');
      } else if (code === 127) { // Backspace
        if (command.length > 0) {
          command = command.slice(0, -1);
          term.write('\b \b');
          setCurrentCommand(command);
        }
      } else if (code >= 32) { // Printable characters
        command += data;
        term.write(data);
        setCurrentCommand(command);
      }
    });

    // Handle window resize
    const handleResize = () => {
      fitAddon.fit();
    };

    window.addEventListener('resize', handleResize);

    return () => {
      window.removeEventListener('resize', handleResize);
      term.dispose();
    };
  }, [onCommand, readonly]);

  return (
    <div 
      ref={terminalRef} 
      className="w-full h-full bg-terminal-bg rounded-lg"
      style={{ minHeight: '400px' }}
    />
  );
}
TERMCOMP

# Practice Page
cat > "$INSTALL_DIR/app/practice/page.tsx" << 'PRACTICEPAGE'
'use client';

import { useState, useEffect } from 'react';
import dynamic from 'next/dynamic';
import { BookOpen, Clock, Target, Lightbulb } from 'lucide-react';

const TerminalEmulator = dynamic(
  () => import('@/components/terminal/TerminalEmulator'),
  { ssr: false }
);

export default function PracticePage() {
  const [question, setQuestion] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [hintLevel, setHintLevel] = useState(0);
  const [userCommand, setUserCommand] = useState('');

  useEffect(() => {
    loadRandomQuestion();
  }, []);

  const loadRandomQuestion = async () => {
    setLoading(true);
    try {
      const res = await fetch('/api/questions?limit=1');
      const data = await res.json();
      if (data.questions && data.questions.length > 0) {
        const questionId = data.questions[0].id;
        const detailRes = await fetch(\`/api/questions/\${questionId}\`);
        const detail = await detailRes.json();
        setQuestion(detail.question);
      }
    } catch (error) {
      console.error('Failed to load question:', error);
    } finally {
      setLoading(false);
    }
  };

  const handleCommand = (cmd: string) => {
    setUserCommand(cmd);
    // TODO: Validate command against answers
  };

  const showHint = () => {
    if (question && hintLevel < 3) {
      setHintLevel(hintLevel + 1);
    }
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">Loading question...</div>
      </div>
    );
  }

  if (!question) {
    return (
      <div className="min-h-screen bg-gray-900 flex items-center justify-center">
        <div className="text-white text-xl">No questions available</div>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <div className="container mx-auto px-4 py-8">
        <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
          {/* Question Panel */}
          <div className="space-y-6">
            <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
              <div className="flex items-center justify-between mb-4">
                <div className="flex items-center space-x-2">
                  <div 
                    className="w-3 h-3 rounded-full" 
                    style={{ backgroundColor: question.domain_color }}
                  />
                  <span className="text-sm text-gray-400">{question.domain_name}</span>
                </div>
                <div className="flex items-center space-x-4 text-sm text-gray-400">
                  <div className="flex items-center space-x-1">
                    <Target size={16} />
                    <span>{question.difficulty}</span>
                  </div>
                  <div className="flex items-center space-x-1">
                    <Clock size={16} />
                    <span>{Math.floor(question.time_estimate / 60)} min</span>
                  </div>
                </div>
              </div>

              <h2 className="text-2xl font-bold mb-4">{question.title}</h2>

              <div className="space-y-4">
                <div>
                  <h3 className="text-lg font-semibold mb-2 text-blue-400">Scenario</h3>
                  <p className="text-gray-300">{question.scenario}</p>
                </div>

                <div>
                  <h3 className="text-lg font-semibold mb-2 text-green-400">Task</h3>
                  <p className="text-gray-300">{question.task_description}</p>
                </div>
              </div>
            </div>

            {/* Hints */}
            {hintLevel > 0 && (
              <div className="bg-yellow-900/20 border border-yellow-700 rounded-lg p-4">
                <div className="flex items-start space-x-2">
                  <Lightbulb className="text-yellow-500 mt-1" size={20} />
                  <div>
                    <h4 className="font-semibold text-yellow-400 mb-2">Hint {hintLevel}</h4>
                    <p className="text-yellow-100">
                      {question.hints[hintLevel - 1]?.hint_text}
                    </p>
                  </div>
                </div>
              </div>
            )}

            <div className="flex space-x-3">
              {hintLevel < 3 && (
                <button
                  onClick={showHint}
                  className="px-4 py-2 bg-yellow-600 rounded hover:bg-yellow-700 transition"
                >
                  Show Hint ({hintLevel + 1}/3)
                </button>
              )}
              <button
                onClick={loadRandomQuestion}
                className="px-4 py-2 bg-blue-600 rounded hover:bg-blue-700 transition"
              >
                Next Question
              </button>
            </div>
          </div>

          {/* Terminal Panel */}
          <div className="bg-gray-800 rounded-lg border border-gray-700">
            <div className="bg-gray-700 px-4 py-2 rounded-t-lg border-b border-gray-600">
              <h3 className="font-semibold">Terminal</h3>
            </div>
            <div className="p-4">
              <TerminalEmulator onCommand={handleCommand} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
PRACTICEPAGE

# Dashboard page
cat > "$INSTALL_DIR/app/dashboard/page.tsx" << 'DASHPAGE'
'use client';

import { useEffect, useState } from 'react';
import Link from 'next/link';
import { BookOpen, Target, Trophy, TrendingUp } from 'lucide-react';

export default function DashboardPage() {
  const [domains, setDomains] = useState<any[]>([]);
  const [stats, setStats] = useState({
    totalAttempts: 0,
    correctAnswers: 0,
    studyStreak: 0,
    totalTime: 0,
  });

  useEffect(() => {
    loadDashboardData();
  }, []);

  const loadDashboardData = async () => {
    try {
      const res = await fetch('/api/domains');
      const data = await res.json();
      setDomains(data.domains || []);
    } catch (error) {
      console.error('Failed to load dashboard:', error);
    }
  };

  return (
    <div className="min-h-screen bg-gray-900 text-white">
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-4xl font-bold mb-8">Dashboard</h1>

        {/* Stats Grid */}
        <div className="grid grid-cols-1 md:grid-cols-4 gap-6 mb-8">
          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Questions Attempted</p>
                <p className="text-3xl font-bold mt-1">{stats.totalAttempts}</p>
              </div>
              <BookOpen className="text-blue-500" size={32} />
            </div>
          </div>

          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Correct Answers</p>
                <p className="text-3xl font-bold mt-1">{stats.correctAnswers}</p>
              </div>
              <Target className="text-green-500" size={32} />
            </div>
          </div>

          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Study Streak</p>
                <p className="text-3xl font-bold mt-1">{stats.studyStreak} days</p>
              </div>
              <Trophy className="text-yellow-500" size={32} />
            </div>
          </div>

          <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-gray-400 text-sm">Study Time</p>
                <p className="text-3xl font-bold mt-1">{Math.floor(stats.totalTime / 60)}h</p>
              </div>
              <TrendingUp className="text-purple-500" size={32} />
            </div>
          </div>
        </div>

        {/* Quick Actions */}
        <div className="grid grid-cols-1 md:grid-cols-3 gap-6 mb-8">
          <Link 
            href="/practice"
            className="bg-gradient-to-br from-blue-600 to-blue-800 rounded-lg p-6 hover:from-blue-700 hover:to-blue-900 transition"
          >
            <BookOpen className="mb-3" size={32} />
            <h3 className="text-xl font-bold mb-2">Practice Mode</h3>
            <p className="text-blue-100">Learn with hints and detailed feedback</p>
          </Link>

          <Link 
            href="/exam"
            className="bg-gradient-to-br from-red-600 to-red-800 rounded-lg p-6 hover:from-red-700 hover:to-red-900 transition"
          >
            <Target className="mb-3" size={32} />
            <h3 className="text-xl font-bold mb-2">Exam Mode</h3>
            <p className="text-red-100">Timed exam simulation</p>
          </Link>

          <Link 
            href="/lab"
            className="bg-gradient-to-br from-green-600 to-green-800 rounded-lg p-6 hover:from-green-700 hover:to-green-900 transition"
          >
            <PlusCircle className="mb-3" size={32} />
            <h3 className="text-xl font-bold mb-2">Custom Labs</h3>
            <p className="text-green-100">Create your own questions</p>
          </Link>
        </div>

        {/* Domain Progress */}
        <div className="bg-gray-800 rounded-lg p-6 border border-gray-700">
          <h2 className="text-2xl font-bold mb-6">Domain Progress</h2>
          <div className="space-y-4">
            {domains.map((domain) => (
              <div key={domain.id} className="flex items-center justify-between">
                <div className="flex items-center space-x-4 flex-1">
                  <div 
                    className="w-3 h-3 rounded-full"
                    style={{ backgroundColor: domain.color }}
                  />
                  <div className="flex-1">
                    <div className="flex items-center justify-between mb-1">
                      <span className="font-semibold">{domain.name}</span>
                      <span className="text-sm text-gray-400">
                        {domain.question_count} questions
                      </span>
                    </div>
                    <div className="w-full bg-gray-700 rounded-full h-2">
                      <div 
                        className="h-2 rounded-full transition-all"
                        style={{ 
                          width: '0%',
                          backgroundColor: domain.color 
                        }}
                      />
                    </div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
DASHPAGE

echo "✓ Application files created successfully!"
