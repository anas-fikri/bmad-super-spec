#!/usr/bin/env node
/*
 * bmad-super-spec orchestrator
 * -------------------------------------------------
 * This script is the entry point defined in manifest.json.
 * It implements three commands that PI can invoke:
 *   - init      : start a fresh workflow
 *   - status    : print current stage & log location
 *   - continue  : resume from the saved state
 *
 * The orchestrator assumes the three upstream tools are already
 * available on the host PATH:
 *   • `bmad-help` (from the bmad‑method npm package)
 *   • `specify`   (from the spec‑kit uv tool)
 *   • Super‑powers skills are loaded by the LLM‑agent runtime and are
 *     triggered via the `pi skill invoke` mechanism – we simply call the
 *     corresponding skill command via `pi skill run <skill> <command>`.
 *
 * All external commands are executed synchronously (awaited) and their
 * stdout/stderr is appended to a per‑project log file. After each major
 * stage we persist a tiny JSON state so that the workflow can be resumed
 * later, possibly on a different machine (just copy the project folder).
 */

const { spawnSync, spawn } = require('child_process');
const fs = require('fs');
const path = require('path');

const STATE_FILE = '.bmad-super-spec/state.json';
const LOG_FILE = '.bmad-super-spec/run.log';

function log(message, stateDir) {
  const logPath = path.join(stateDir, LOG_FILE);
  const ts = new Date().toISOString();
  fs.appendFileSync(logPath, `[${ts}] ${message}\n`);
  console.log(message);
}

function execCmd(cmd, args, cwd) {
  // Run command synchronously but provide visual progress feedback.
  // Using spawnSync blocks the event loop, so we cannot show a spinner.
  // Instead we implement an async version `execCmdAsync` that streams output.
  // For backward compatibility, this wrapper calls the async version and waits.
  const promise = execCmdAsync(cmd, args, cwd);
  // Since the surrounding code expects a return value, we block using deasync-like approach.
  // However, in Node we can simply use async/await in callers. We'll adjust callers accordingly.
  // This placeholder will never be used after modifications.
  throw new Error('execCmd should not be called after migration to async version');
}

async function execCmdAsync(cmd, args, cwd) {
  return new Promise((resolve, reject) => {
    const child = spawn(cmd, args, { cwd, stdio: ['ignore', 'pipe', 'pipe'] });
    let stdout = '';
    let stderr = '';
    const spinner = ['|', '/', '-', '\\'];
    let i = 0;
    const interval = setInterval(() => {
      process.stdout.write('\r' + spinner[i % spinner.length] + ' Running ' + cmd + ' ...');
      i++;
    }, 100);
    child.stdout.on('data', data => { stdout += data.toString(); });
    child.stderr.on('data', data => { stderr += data.toString(); });
    child.on('close', code => {
      clearInterval(interval);
      process.stdout.write('\r'); // clear spinner line
      if (code !== 0) {
        const err = stderr || stdout;
        reject(new Error(`Command failed: ${cmd} ${args.join(' ')}\n${err}`));
      } else {
        resolve(stdout);
      }
    });
    child.on('error', err => {
      clearInterval(interval);
      reject(err);
    });
  });
}

function loadState(projectRoot) {
  const statePath = path.join(projectRoot, STATE_FILE);
  if (fs.existsSync(statePath)) {
    return JSON.parse(fs.readFileSync(statePath, 'utf8'));
  }
  return null;
}

function saveState(projectRoot, data) {
  const stateDir = path.join(projectRoot, path.dirname(STATE_FILE));
  fs.mkdirSync(stateDir, { recursive: true });
  const statePath = path.join(projectRoot, STATE_FILE);
  fs.writeFileSync(statePath, JSON.stringify(data, null, 2));
}

function printStatus(projectRoot) {
  const state = loadState(projectRoot);
  if (!state) {
    console.log('No workflow has been started in this folder.');
    return;
  }
  console.log('Current workflow status:');
  console.log(`  Project : ${state.project}`);
  console.log(`  Stage   : ${state.stage}`);
  console.log(`  Log     : ${path.join(projectRoot, LOG_FILE)}`);
}

async function runStage(projectRoot, stage, fn) {
  const state = loadState(projectRoot) || {};
  if (state.stage && state.stage !== stage && !state.completedStages?.includes(stage)) {
    // skip already completed stages
    if (state.completedStages?.includes(stage)) return;
  }
  log(`=== Starting stage: ${stage} ===`, projectRoot);
  await fn();
  // persist progress
  const newState = {
    project: state.project || path.basename(projectRoot),
    stage,
    completedStages: (state.completedStages || []).concat(stage),
  };
  saveState(projectRoot, newState);
  log(`=== Finished stage: ${stage} ===`, projectRoot);
}

async function workflowInit() {
  const cwd = process.cwd();
  // Ask for a project name (simple stdin prompt)
  const readline = require('readline');
  const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
  const projectName = await new Promise(resolve => {
    rl.question('Enter a short project name (used as folder): ', answer => {
      rl.close();
      resolve(answer.trim() || 'my-project');
    });
  });
  const projectRoot = path.join(cwd, projectName);
  fs.mkdirSync(projectRoot, { recursive: true });

  // Ensure log dir exists
  fs.mkdirSync(path.join(projectRoot, '.bmad-super-spec'), { recursive: true });
  log(`Project folder created at ${projectRoot}`, projectRoot);

  // Stage 1 – Vision & Constitution (BMad + Spec‑Kit)
  await runStage(projectRoot, 'vision‑constitution', async () => {
    // bmad‑help can be invoked directly; we just capture its output
    await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-help'], projectRoot);
    // create spec‑kit constitution
    await execCmdAsync('specify', ['constitution', 'Create project guiding principles'], projectRoot);
  });

  // Stage 2 – Brainstorm & Spec (Superpowers + Spec‑Kit)
  await runStage(projectRoot, 'brainstorm‑spec', async () => {
    // Superpowers skill “brainstorming” is triggered via PI skill run; we simulate with a CLI call
    await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'brainstorming'], projectRoot);
    // After brainstorming we ask for a formal spec via Spec‑Kit
    await execCmdAsync('specify', ['specify', 'Describe the product in user‑story style'], projectRoot);
  });

  // Stage 3 – Architecture & Planning (BMad + Superpowers)
  await runStage(projectRoot, 'architecture‑plan', async () => {
    await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-party'], projectRoot);
    await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'writing-plans'], projectRoot);
  });

  // Stage 4 – Generate Tasks (Spec‑Kit)
  await runStage(projectRoot, 'generate‑tasks', async () => {
    await execCmdAsync('specify', ['tasks'], projectRoot);
    // optional: turn tasks into GitHub issues
    await execCmdAsync('specify', ['taskstoissues'], projectRoot);
  });

  // Stage 5 – Sub‑agent driven implementation (Superpowers)
  await runStage(projectRoot, 'implement', async () => {
    await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'subagent-driven-development'], projectRoot);
  });

  // Stage 6 – Finish branch (BMad)
  await runStage(projectRoot, 'finish‑branch', async () => {
    await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-finish-branch'], projectRoot);
  });

  console.log('\n✅ Workflow completed! Check the log at:', path.join(projectRoot, LOG_FILE));
}

async function workflowContinue() {
  const cwd = process.cwd();
  const state = loadState(cwd);
  if (!state) {
    console.error('No saved state found in current directory. Run init first.');
    process.exit(1);
  }
  console.log('Resuming workflow for project', state.project);
  // Determine next stage based on completedStages
  const allStages = [
    'vision‑constitution',
    'brainstorm‑spec',
    'architecture‑plan',
    'generate‑tasks',
    'implement',
    'finish‑branch',
  ];
  const completed = new Set(state.completedStages || []);
  const remaining = allStages.filter(s => !completed.has(s));
  for (const s of remaining) {
    // reuse the same functions as init – we map stage to the appropriate lambda
    switch (s) {
      case 'vision‑constitution':
        await runStage(cwd, s, async () => {
          await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-help'], cwd);
          await execCmdAsync('specify', ['constitution', 'Create project guiding principles'], cwd);
        });
        break;
      case 'brainstorm‑spec':
        await runStage(cwd, s, async () => {
          await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'brainstorming'], cwd);
          await execCmdAsync('specify', ['specify', 'Describe the product in user‑story style'], cwd);
        });
        break;
      case 'architecture‑plan':
        await runStage(cwd, s, async () => {
          await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-party'], cwd);
          await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'writing-plans'], cwd);
        });
        break;
      case 'generate‑tasks':
        await runStage(cwd, s, async () => {
          await execCmdAsync('specify', ['tasks'], cwd);
          await execCmdAsync('specify', ['taskstoissues'], cwd);
        });
        break;
      case 'implement':
        await runStage(cwd, s, async () => {
          await execCmdAsync('pi', ['skill', 'run', 'superpowers', 'subagent-driven-development'], cwd);
        });
        break;
      case 'finish‑branch':
        await runStage(cwd, s, async () => {
          await execCmdAsync('npx', ['bmad-method', 'help', '--skill', 'bmad-finish-branch'], cwd);
        });
        break;
    }
  }
  console.log('\n✅ All remaining stages completed.');
}

async function main() {
  const [, , command] = process.argv;
  switch (command) {
    case 'init':
      await workflowInit();
      break;
    case 'status':
      printStatus(process.cwd());
      break;
    case 'continue':
      await workflowContinue();
      break;
    default:
      console.error('Usage: orchestrator.js <init|status|continue>');
      process.exit(1);
  }
}

main().catch(err => {
  console.error('❌ Workflow error:', err.message);
  process.exit(1);
});
