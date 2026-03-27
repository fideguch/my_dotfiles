/**
 * Project Health Check Library
 *
 * Checks project configuration completeness and formats advisory messages.
 * All checks use fs.existsSync for sub-millisecond performance.
 */

'use strict';

const fs = require('fs');
const path = require('path');

/**
 * Check project health gaps based on detected project info.
 * @param {object} projectInfo - Output from detectProjectType()
 * @returns {{ gaps: string[], suggestions: string[] }}
 */
function checkProjectHealth(projectInfo) {
  const { health, languages, frameworks } = projectInfo;
  const gaps = [];
  const suggestions = [];

  // Only check git repos — non-repos are not projects worth configuring
  if (!health.isGitRepo) {
    return { gaps, suggestions };
  }

  if (!health.hasClaudeMd) {
    gaps.push('CLAUDE.md');
    suggestions.push('Add a project-level CLAUDE.md with stack info and conventions');
  }

  if (!health.hasClaudeDir) {
    gaps.push('.claude/');
    suggestions.push('Create .claude/ directory with settings.local.json for project permissions');
  } else if (!health.hasSettingsLocal) {
    gaps.push('.claude/settings.local.json');
    suggestions.push('Add settings.local.json with project-specific tool permissions');
  }

  if (!health.hasMcpJson && (frameworks.length > 0 || languages.length > 1)) {
    gaps.push('.mcp.json');
    suggestions.push('Configure project-level MCP servers in .mcp.json');
  }

  return { gaps, suggestions };
}

/**
 * Format a single-line advisory for SessionStart output.
 * Returns empty string if no gaps detected.
 * @param {{ gaps: string[], suggestions: string[] }} healthResult
 * @returns {string}
 */
function formatHealthAdvisory(healthResult) {
  if (healthResult.gaps.length === 0) {
    return '';
  }

  const missing = healthResult.gaps.join(', ');
  return `Project health: missing ${missing}. Run /health to audit and scaffold.`;
}

/**
 * Select the best CLAUDE.md template based on detected project info.
 * @param {object} projectInfo - Output from detectProjectType()
 * @returns {string} Template filename (without path)
 */
function selectTemplate(projectInfo) {
  const { languages, frameworks } = projectInfo;
  const hasTS = languages.includes('typescript') || languages.includes('javascript');
  const hasRust = languages.includes('rust');
  const hasPython = languages.includes('python');

  if (hasTS && frameworks.includes('next.js')) return 'typescript-nextjs.md';
  if (hasTS && (frameworks.includes('express') || frameworks.includes('fastify'))) return 'typescript-express.md';
  if (hasPython && (frameworks.includes('fastapi') || frameworks.includes('flask'))) return 'python-fastapi.md';
  if (hasRust) return 'rust.md';
  return 'generic.md';
}

/**
 * Generate scaffold file contents for missing project config.
 * Does NOT write files — returns what would be created.
 * @param {object} projectInfo - Output from detectProjectType()
 * @param {string} projectName - Project directory name
 * @returns {{ files: { path: string, content: string, description: string }[] }}
 */
function generateScaffold(projectInfo, projectName) {
  const { health } = projectInfo;
  const safeName = (typeof projectName === 'string' && projectName.trim())
    ? projectName.trim()
    : 'my-project';
  const files = [];

  if (!health.hasClaudeMd) {
    const templateName = selectTemplate(projectInfo);
    const templateDir = path.join(__dirname, '..', '..', 'templates', 'claude-md');
    const templatePath = path.join(templateDir, templateName);

    let content = '';
    try {
      content = fs.readFileSync(templatePath, 'utf8');
      content = content.replace(/\{\{PROJECT_NAME\}\}/g, safeName);
      content = content.replace(/\{\{LANGUAGE\}\}/g, projectInfo.languages[0] || 'unknown');
    } catch (_) {
      content = `# ${safeName}\n\n## Stack\nDescribe your stack here.\n`;
    }

    files.push({
      path: 'CLAUDE.md',
      content,
      description: `Project CLAUDE.md (template: ${templateName})`
    });
  }

  if (!health.hasClaudeDir || !health.hasSettingsLocal) {
    files.push({
      path: '.claude/settings.local.json',
      content: JSON.stringify({
        permissions: {
          allow: [],
          deny: []
        }
      }, null, 2) + '\n',
      description: 'Local settings with empty permission lists'
    });
  }

  return { files, template: selectTemplate(projectInfo) };
}

module.exports = { checkProjectHealth, formatHealthAdvisory, generateScaffold, selectTemplate };
