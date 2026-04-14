#!/usr/bin/env node
/**
 * webdriver-exec.js — Layer 3: Execute inspect.js via safaridriver WebDriver
 *
 * Zero-dependency Node.js script (stdlib only: http, fs, child_process).
 * Connects to iOS Simulator Safari or macOS Safari via W3C WebDriver protocol.
 *
 * Usage:
 *   node webdriver-exec.js --platform ios --selector 'header'
 *   node webdriver-exec.js --platform mac --url 'http://localhost:3000' --selector '.app'
 *   node webdriver-exec.js --platform ios --output /tmp/result.json
 */

const http = require('http');
const fs = require('fs');
const path = require('path');
const { spawn } = require('child_process');

// --- Argument Parsing ---

const args = process.argv.slice(2);
const config = {
  platform: 'ios',
  selector: null,
  url: null,
  output: null,
  port: 0, // 0 = auto-select
  timeout: 30000
};

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--platform':
      config.platform = args[++i];
      break;
    case '--selector':
      config.selector = args[++i];
      break;
    case '--url':
      config.url = args[++i];
      break;
    case '--output':
      config.output = args[++i];
      break;
    case '--port':
      config.port = parseInt(args[++i], 10);
      break;
    case '--timeout':
      config.timeout = parseInt(args[++i], 10);
      break;
    case '-h':
    case '--help':
      console.log(`Usage: node webdriver-exec.js [options]

Options:
  --platform ios|mac   Target platform (default: ios)
  --selector <sel>     CSS selector to inspect
  --url <url>          Navigate to URL before inspecting
  --output <path>      Write JSON to file (default: /tmp/ios-inspect-<ts>.json)
  --port <port>        safaridriver port (default: auto)
  --timeout <ms>       Request timeout in ms (default: 30000)
`);
      process.exit(0);
  }
}

if (!config.output) {
  config.output = `/tmp/ios-inspect-${Date.now()}.json`;
}

// --- HTTP Helper ---

function httpRequest(method, urlPath, body) {
  return new Promise((resolve, reject) => {
    const options = {
      hostname: '127.0.0.1',
      port: config.port,
      path: urlPath,
      method: method,
      headers: { 'Content-Type': 'application/json' },
      timeout: config.timeout
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, body: JSON.parse(data) });
        } catch (e) {
          reject(new Error(`Invalid JSON response: ${data.substring(0, 200)}`));
        }
      });
    });

    req.on('error', reject);
    req.on('timeout', () => {
      req.destroy();
      reject(new Error('Request timed out'));
    });

    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

// --- Port Selection ---

function findFreePort() {
  return new Promise((resolve, reject) => {
    const server = require('net').createServer();
    server.listen(0, '127.0.0.1', () => {
      const port = server.address().port;
      server.close(() => resolve(port));
    });
    server.on('error', reject);
  });
}

// --- Wait for safaridriver readiness ---

function waitForDriver(maxWait) {
  const start = Date.now();
  return new Promise((resolve, reject) => {
    function check() {
      if (Date.now() - start > maxWait) {
        return reject(new Error('safaridriver did not start within ' + maxWait + 'ms'));
      }
      httpRequest('GET', '/status')
        .then((res) => {
          if (res.status === 200) resolve();
          else setTimeout(check, 200);
        })
        .catch(() => setTimeout(check, 200));
    }
    check();
  });
}

// --- Main ---

async function main() {
  // Select port
  if (config.port === 0) {
    config.port = await findFreePort();
  }

  console.error(`[ios-web-inspect] Starting safaridriver on port ${config.port}...`);

  // Start safaridriver
  const driver = spawn('safaridriver', ['-p', String(config.port)], {
    stdio: ['ignore', 'pipe', 'pipe']
  });

  let driverExited = false;
  driver.on('exit', (code) => {
    driverExited = true;
    if (code !== 0 && code !== null) {
      console.error(`[ios-web-inspect] safaridriver exited with code ${code}`);
    }
  });

  // Capture stderr for diagnostics
  let driverStderr = '';
  driver.stderr.on('data', (chunk) => { driverStderr += chunk.toString(); });

  const cleanup = () => {
    if (!driverExited) {
      driver.kill('SIGTERM');
    }
  };

  process.on('SIGINT', cleanup);
  process.on('SIGTERM', cleanup);

  try {
    // Wait for driver to be ready
    await waitForDriver(10000);
    console.error('[ios-web-inspect] safaridriver is ready.');

    // Create session
    const platformName = config.platform === 'ios' ? 'iOS' : 'mac';
    const capabilities = {
      capabilities: {
        alwaysMatch: {
          browserName: 'Safari',
          platformName: platformName
        }
      }
    };

    if (platformName === 'iOS') {
      capabilities.capabilities.alwaysMatch['safari:useSimulator'] = true;
    }

    console.error(`[ios-web-inspect] Creating ${platformName} session...`);
    const sessionRes = await httpRequest('POST', '/session', capabilities);

    if (sessionRes.status !== 200) {
      const errMsg = sessionRes.body.value && sessionRes.body.value.message
        ? sessionRes.body.value.message
        : JSON.stringify(sessionRes.body);
      throw new Error(`Failed to create session: ${errMsg}`);
    }

    const sessionId = sessionRes.body.value.sessionId;
    console.error(`[ios-web-inspect] Session created: ${sessionId}`);

    try {
      // Navigate to URL if provided
      if (config.url) {
        console.error(`[ios-web-inspect] Navigating to ${config.url}...`);
        await httpRequest('POST', `/session/${sessionId}/url`, { url: config.url });
        // Wait for document.readyState === 'complete'
        for (let attempt = 0; attempt < 30; attempt++) {
          const readyRes = await httpRequest('POST', `/session/${sessionId}/execute/sync`, {
            script: 'return document.readyState',
            args: []
          });
          if (readyRes.body && readyRes.body.value === 'complete') break;
          await new Promise(r => setTimeout(r, 500));
        }
      }

      // Read inspect.js
      const inspectJsPath = path.join(__dirname, 'inspect.js');
      const inspectJs = fs.readFileSync(inspectJsPath, 'utf8');

      // Build execution script — use JSON.stringify for safe escaping
      const selectorStr = JSON.stringify(config.selector); // null becomes "null", strings get proper escaping
      const execScript = `${inspectJs}; return iosWebInspect({ selector: ${selectorStr} });`;

      console.error('[ios-web-inspect] Executing inspection...');
      const execRes = await httpRequest('POST', `/session/${sessionId}/execute/sync`, {
        script: execScript,
        args: []
      });

      if (execRes.status !== 200) {
        const errMsg = execRes.body.value && execRes.body.value.message
          ? execRes.body.value.message
          : JSON.stringify(execRes.body);
        throw new Error(`Script execution failed: ${errMsg}`);
      }

      const inspectResult = execRes.body.value;

      // Write output
      const jsonOutput = JSON.stringify(inspectResult, null, 2);
      fs.writeFileSync(config.output, jsonOutput, 'utf8');
      console.error(`[ios-web-inspect] Results written to ${config.output}`);

      // Also output to stdout for piping
      console.log(jsonOutput);

    } finally {
      // Delete session
      console.error('[ios-web-inspect] Cleaning up session...');
      await httpRequest('DELETE', `/session/${sessionId}`).catch(() => {});
    }

  } catch (err) {
    console.error(`[ios-web-inspect] Error: ${err.message}`);
    if (driverStderr) {
      console.error(`[ios-web-inspect] safaridriver stderr: ${driverStderr.substring(0, 500)}`);
    }
    process.exitCode = 1;
  } finally {
    cleanup();
  }
}

main();
