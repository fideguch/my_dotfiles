/**
 * Project Type Detection
 *
 * Detects the project type, languages, and frameworks from files in the working directory.
 */

'use strict';

const fs = require('fs');
const path = require('path');

function detectProjectType(cwd) {
  const dir = cwd || process.cwd();
  const exists = f => fs.existsSync(path.join(dir, f));

  const languages = [];
  const frameworks = [];

  // Language detection — mutually exclusive: tsconfig.json → typescript, else package.json → javascript
  if (exists('tsconfig.json')) languages.push('typescript');
  else if (exists('package.json')) languages.push('javascript');
  if (exists('Cargo.toml')) languages.push('rust');
  if (exists('go.mod')) languages.push('go');
  if (exists('pyproject.toml') || exists('setup.py') || exists('requirements.txt')) languages.push('python');
  if (exists('build.gradle') || exists('build.gradle.kts')) languages.push('kotlin');
  if (exists('pom.xml')) languages.push('java');
  if (exists('Gemfile')) languages.push('ruby');
  if (exists('composer.json')) languages.push('php');
  if (exists('Package.swift')) languages.push('swift');

  // Framework detection
  try {
    const pkg = JSON.parse(fs.readFileSync(path.join(dir, 'package.json'), 'utf8'));
    const deps = { ...pkg.dependencies, ...pkg.devDependencies };
    if (deps.next) frameworks.push('next.js');
    if (deps.react) frameworks.push('react');
    if (deps.vue) frameworks.push('vue');
    if (deps.svelte || deps['@sveltejs/kit']) frameworks.push('svelte');
    if (deps.express) frameworks.push('express');
    if (deps.fastify) frameworks.push('fastify');
  } catch (_) { /* no package.json */ }

  if (exists('requirements.txt') || exists('pyproject.toml')) {
    try {
      const reqs = fs.readFileSync(
        path.join(dir, exists('requirements.txt') ? 'requirements.txt' : 'pyproject.toml'), 'utf8'
      );
      if (reqs.includes('django')) frameworks.push('django');
      if (reqs.includes('fastapi')) frameworks.push('fastapi');
      if (reqs.includes('flask')) frameworks.push('flask');
    } catch (_) { /* ignore */ }
  }

  const type = languages[0] || 'unknown';

  // Project health checks (all existsSync — sub-millisecond).
  // Note: existsSync returns true for files too, but .claude as a file is not
  // a realistic scenario. Acceptable trade-off for sub-ms performance.
  const health = {
    isGitRepo: exists('.git'),
    hasClaudeMd: exists('CLAUDE.md'),
    hasClaudeDir: exists('.claude'),
    hasMcpJson: exists('.mcp.json'),
    hasSettingsLocal: exists('.claude/settings.local.json'),
  };

  return { type, languages, frameworks, health };
}

module.exports = { detectProjectType };
