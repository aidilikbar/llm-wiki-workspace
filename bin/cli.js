#!/usr/bin/env node
'use strict';

// LLM Wiki Workspace installer, Node edition.
// Mirrors install.sh so Windows users get the same result without bash.
// CI diffs the output of the two to keep them identical.

const fs = require('fs');
const os = require('os');
const path = require('path');
const { spawnSync } = require('child_process');

const VERSION = '0.2.0';
const ROOT = path.resolve(__dirname, '..');
const SRC = path.join(ROOT, 'template');
const PRESET = path.join(ROOT, 'obsidian-preset');
const HANDOFF_SRC = path.join(ROOT, 'handoff');
const KICKOFF_SRC = path.join(ROOT, 'kickoff', 'instruction.md');
const HANDOFF_MARKER = 'llm-wiki-workspace:handoff-protocol';
const ABOUT_PLACEHOLDER = 'Not given at install. Start by asking the human what the project is.';

const CORE_PATHS = [
  'AGENTS.md', '.gitignore', '.githooks/pre-commit',
  'system/RULES.md', 'system/agents/escalation.md', 'system/templates',
  'context/AGENTS.md', 'context/constraints', 'context/requirements',
  'state/AGENTS.md', 'state/STATE.md', 'state/handoff.md', 'state/backlog',
  'record/AGENTS.md', 'record/decisions', 'record/logbook', 'record/backlog',
  'work/AGENTS.md', 'work/sources/INDEX.md', 'work/temp',
];
const EJECT_PATHS = [
  'template', 'handoff', 'kickoff', 'install.sh', 'bin', 'scripts', 'obsidian-preset',
  'package.json', 'package-lock.json', 'docs', '.github',
];

const USAGE = `LLM Wiki Workspace installer

usage: npx llm-wiki-workspace [options] [folder]

In a terminal with no --yes, it asks what to set up. Any flag answers its question.

what to install:
  (default)          a workspace: the knowledge base your agents read and write
  --handoff          a .handoff/ task exchange in an existing code repo instead

workspace:
  --project NAME     project name, used in the kick-off brief
  --about TEXT       what you are making, in a sentence or two
  --owner NAME       your name, written into each file's owner field
  --core | --full    the files you need in week one (default), or every folder
  --obsidian         also write .obsidian/ so the folder opens as a vault
  --git              git init, turn on the front-matter check, make the first commit
  --no-obsidian, --no-git

existing folders:
  The folder must be new or empty. To install into one that is not:
  --merge            add only the files that are missing
  --force            overwrite files that already exist
  --eject            for a "Use this template" clone: install into it, then delete
                     the packaging

handoff:
  --handoff-ignore   add .handoff/ to the code repo's .gitignore

general:
  -y, --yes          never ask; use the flags given and defaults for the rest
  --dry-run          print what would happen, write nothing
  --version, -h, --help`;

const say = (s = '') => process.stdout.write(s + '\n');
const warn = (s) => process.stderr.write(s + '\n');
function fail(msg, ...lines) {
  process.stderr.write(`\nInstallation failed: ${msg}\n`);
  for (const l of lines) process.stderr.write(l + '\n');
  process.exit(1);
}
// Anything unexpected (a read-only folder, a full disk) still ends in a plain verdict.
process.on('uncaughtException', (e) => fail(`unexpected error: ${e.message}`));

const o = {
  mode: '', target: '', tier: '', obsidian: null, git: null, handoffIgnore: null,
  name: '', about: '', owner: '', nameSet: false, aboutSet: false, ownerSet: false,
  force: false, merge: false, eject: false, dry: false, yes: false,
};

const argv = process.argv.slice(2);
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  const value = (flag) => {
    const v = argv[i + 1];
    if (v === undefined || v === '') fail(`${flag} needs a value.`);
    i++;
    return v;
  };
  switch (true) {
    case a === '--handoff': o.mode = 'handoff'; break;
    case a === '--core': o.tier = 'core'; break;
    case a === '--full': o.tier = 'full'; break;
    case a === '--obsidian': o.obsidian = true; break;
    case a === '--no-obsidian': o.obsidian = false; break;
    case a === '--git': o.git = true; break;
    case a === '--no-git': o.git = false; break;
    case a === '--handoff-ignore': o.handoffIgnore = true; break;
    case a === '--project': o.name = value(a); o.nameSet = true; break;
    case a.startsWith('--project='): o.name = a.slice(10); o.nameSet = true; break;
    case a === '--about': o.about = value(a); o.aboutSet = true; break;
    case a.startsWith('--about='): o.about = a.slice(8); o.aboutSet = true; break;
    case a === '--owner': o.owner = value(a); o.ownerSet = true; break;
    case a.startsWith('--owner='): o.owner = a.slice(8); o.ownerSet = true; break;
    case a === '--merge': o.merge = true; break;
    case a === '--force': o.force = true; break;
    case a === '--eject': o.eject = true; break;
    case a === '--dry-run': o.dry = true; break;
    case a === '-y' || a === '--yes' || a === '--no-interaction': o.yes = true; break;
    case a === '--version': say(VERSION); process.exit(0); break;
    case a === '-h' || a === '--help': say(USAGE); process.exit(0); break;
    case a.startsWith('-'): fail(`unknown option ${a}.`, 'Run with --help to see the options.'); break;
    default: o.target = a;
  }
}

// ------------------------------------------------------------------ prompting
// Answers are read synchronously from the terminal (or LWW_TTY, a file of answers, for
// tests). Where no terminal can be opened (Windows, CI) it runs with the defaults.

let ttyFd = null;
if (!o.yes && !process.env.LWW_NONINTERACTIVE) {
  try { ttyFd = fs.openSync(process.env.LWW_TTY || '/dev/tty', 'r'); } catch (_) { ttyFd = null; }
}
const interactive = ttyFd !== null;

function readLine() {
  let s = '';
  const b = Buffer.alloc(1);
  for (;;) {
    let n;
    try { n = fs.readSync(ttyFd, b, 0, 1, null); } catch (e) { if (e.code === 'EAGAIN') continue; return s; }
    if (n === 0) return s;
    const c = b.toString('utf8');
    if (c === '\n') return s;
    if (c !== '\r') s += c;
  }
}
function ask(q, d = '') {
  process.stderr.write(d ? ` ${q} [${d}]: ` : ` ${q}: `);
  const r = readLine();
  return r === '' ? d : r;
}
function askYN(q, d) {
  process.stderr.write(` ${q} [${d ? 'Y/n' : 'y/N'}]: `);
  const r = readLine();
  if (/^[Yy]/.test(r)) return true;
  if (/^[Nn]/.test(r)) return false;
  return d;
}
function askChoice(q, d, opts) {
  process.stderr.write(`\n ${q}\n`);
  opts.forEach((t, i) => process.stderr.write(`   [${i + 1}] ${t}\n`));
  process.stderr.write(` > [${d}]: `);
  const r = readLine();
  const n = /^[0-9]+$/.test(r) ? parseInt(r, 10) : d;
  return n >= 1 && n <= opts.length ? n : d;
}

function dirIsEmpty(dir) {
  if (!fs.existsSync(dir)) return true;
  return fs.readdirSync(dir).every((e) => e === '.git' || e === '.DS_Store');
}
const shownPath = (t) => (t === '.' ? './' : t.replace(/\/$/, '') + '/');
// The folder that will actually be written to: the target if it exists, otherwise the
// nearest existing folder above it.
function writableBase(t) {
  let d = t;
  while (!fs.existsSync(d)) { const up = path.dirname(d); if (up === d) break; d = up; }
  return d;
}
function canWrite(d) { try { fs.accessSync(d, fs.constants.W_OK); return true; } catch (_) { return false; } }

if (interactive) {
  process.stderr.write(`\n  LLM Wiki Workspace  v${VERSION}\n`);
  if (!o.mode) {
    o.mode = askChoice('What would you like to set up?', 1, [
      'A workspace: the knowledge base your agents read and write',
      'A .handoff/ exchange in a code repo, for the planner-executor workflow',
    ]) === 2 ? 'handoff' : 'workspace';
  }
  if (!o.target) {
    process.stderr.write('\n');
    if (o.mode === 'handoff') o.target = ask('Path to the code repo', '.');
    else if (dirIsEmpty('.')) o.target = ask('Folder for the workspace (a new folder name, or . for this one)', '.');
    else o.target = ask('Folder for the workspace (a new folder name)', 'my-workspace');
  }
}
if (!o.mode) o.mode = 'workspace';
if (!o.target) o.target = '.';
const SHOWN = shownPath(o.target);

// ------------------------------------------------------------------ preflight
if (o.mode === 'handoff') {
  if (fs.existsSync(o.target) && !fs.statSync(o.target).isDirectory()) {
    fail(`${SHOWN} is a file, not a folder.`, '--handoff installs into the folder of an existing code repo.');
  }
  if (!fs.existsSync(o.target)) {
    fail(`${SHOWN} does not exist.`, '--handoff installs into an existing code repo. Check the path.');
  }
  if (!o.dry && !canWrite(o.target)) {
    fail(`cannot write to ${SHOWN} (permission denied).`, "Check the folder's permissions, or choose another folder.");
  }
  if (!o.force && fs.existsSync(path.join(o.target, 'system/RULES.md')) && fs.existsSync(path.join(o.target, 'state'))) {
    fail(`${SHOWN} looks like a workspace, not a code repo.`,
      'The .handoff/ exchange goes in the code repo the executor works in.',
      'Run again with --force to install it here anyway.');
  }
} else {
  if (fs.existsSync(o.target) && !fs.statSync(o.target).isDirectory()) fail(`${SHOWN} is a file, not a folder.`);
  const base = writableBase(o.target);
  if (!o.dry && !canWrite(base)) {
    fail(`cannot write to ${shownPath(base)} (permission denied).`, "Check the folder's permissions, or choose another folder.");
  }
  if (o.eject) o.merge = true;
  if (!o.merge && !o.force && !dirIsEmpty(o.target)) {
    fail(`${SHOWN} already exists and is not empty.`,
      'Choose a new folder name, or run again with:',
      '  --merge   to add only the files that are missing',
      '  --force   to overwrite files that already exist');
  }
}

const haveGit = () => spawnSync('git', ['--version'], { stdio: 'ignore' }).status === 0;
const defaultName = () => path.basename(o.target === '.' ? process.cwd() : o.target);

if (interactive) {
  if (o.mode === 'workspace') {
    process.stderr.write('\n');
    if (!o.nameSet) o.name = ask('Project name', defaultName());
    if (!o.aboutSet) o.about = ask('What are you making? A sentence or two, or Enter to skip');
    if (!o.ownerSet) {
      let gitName = '';
      if (haveGit()) gitName = (spawnSync('git', ['config', '--global', 'user.name'], { encoding: 'utf8' }).stdout || '').trim();
      o.owner = ask('Your name, for the owner field in each file', gitName);
    }
    if (!o.tier) {
      o.tier = askChoice('Which structure?', 1, [
        'Core: the files you fill in during week one (recommended)',
        'Full: every folder, including design, architecture and evals',
      ]) === 2 ? 'full' : 'core';
    }
    process.stderr.write('\n');
    if (o.obsidian === null) o.obsidian = askYN('Configure it as an Obsidian vault?', false);
    if (o.git === null) o.git = askYN('Set up git, the front-matter check and a first commit?', true);
  } else {
    process.stderr.write('\n');
    if (o.handoffIgnore === null) {
      o.handoffIgnore = !askYN('Commit .handoff/ to git? Answer no for restricted or air-gapped repos', true);
    }
  }
}

if (!o.tier) o.tier = 'core';
if (o.obsidian === null) o.obsidian = false;
if (o.git === null) o.git = false;
if (o.handoffIgnore === null) o.handoffIgnore = false;
if (!o.name) o.name = defaultName();
o.owner = o.owner.replace(/[\r\n]/g, '');
o.name = o.name.replace(/[\r\n]/g, '');

if (interactive) {
  process.stderr.write('\n');
  if (o.mode === 'handoff') {
    process.stderr.write(`  Code repo  ${SHOWN}\n  .handoff/  ${o.handoffIgnore ? 'gitignored' : 'committed with the repo'}\n`);
  } else {
    let extras = o.tier;
    if (o.obsidian) extras += ', Obsidian vault';
    if (o.git) extras += ', git';
    process.stderr.write(`  Project    ${o.name}\n  Folder     ${SHOWN}\n  Owner      ${o.owner || 'not set'}\n  Setup      ${extras}\n`);
  }
  process.stderr.write('\n');
  if (!askYN('Proceed?', true)) { say('Cancelled. Nothing was written.'); process.exit(0); }
  process.stderr.write('\n');
}

// ------------------------------------------------------------------ helpers
if (!fs.existsSync(SRC)) fail(`the template folder is missing at ${SRC}.`);
const pad = (n) => String(n).padStart(2, '0');
const now = new Date();
const today = `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`;
let installed = 0;
let skipped = 0;

function walk(dir, base = '', out = []) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const rel = base ? path.posix.join(base, e.name) : e.name;
    if (e.isDirectory()) walk(path.join(dir, e.name), rel, out); else out.push(rel);
  }
  return out;
}
const sortC = (a) => a.sort((x, y) => (x < y ? -1 : x > y ? 1 : 0));
function coreList() {
  const out = [];
  for (const p of CORE_PATHS) {
    const abs = path.join(SRC, p);
    if (!fs.existsSync(abs)) { warn(`warning: core path missing from template: ${p}`); continue; }
    if (fs.statSync(abs).isDirectory()) walk(abs, p, out); else out.push(p);
  }
  return sortC([...new Set(out)]);
}

// Stamp `updated:` with today's date (real dates only) and fill `owner: TODO`.
function finishMd(file) {
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  if (lines[0] !== '---') return;
  for (let i = 1; i < lines.length; i++) {
    if (lines[i] === '---') break;
    if (/^updated: \d{4}-\d{2}-\d{2}$/.test(lines[i])) lines[i] = `updated: ${today}`;
    else if (lines[i] === 'owner: TODO' && o.owner) lines[i] = `owner: ${o.owner}`;
  }
  fs.writeFileSync(file, lines.join('\n'));
}

function copyTree(srcRoot, destRoot, rels, finish) {
  for (const rel of rels) {
    const dest = path.join(destRoot, rel);
    if (fs.existsSync(dest) && !o.force) { skipped++; continue; }
    if (o.dry) {
      say(`  would write ${path.relative('.', dest) || dest}`);
    } else {
      fs.mkdirSync(path.dirname(dest), { recursive: true });
      fs.copyFileSync(path.join(srcRoot, rel), dest);
      if (rel.endsWith('.md') && finish) finishMd(dest);
      if (rel.startsWith('.githooks/')) fs.chmodSync(dest, 0o755);
    }
    installed++;
  }
}

function writeInstruction() {
  const dest = path.join(o.target, 'instruction.md');
  if (fs.existsSync(dest) && !o.force) { skipped++; return; }
  if (o.dry) { say('  would write instruction.md'); installed++; return; }
  const sub = (s, from, to) => s.split(from).join(to);
  let text = fs.readFileSync(KICKOFF_SRC, 'utf8');
  text = sub(text, '{{project_name}}', o.name);
  text = sub(text, '{{project_description}}', o.about || ABOUT_PLACEHOLDER);
  text = sub(text, '{{owner}}', o.owner || 'TODO');
  text = sub(text, '{{date}}', today);
  fs.writeFileSync(dest, text);
  installed++;
}

const git = (args, opts = {}) => spawnSync('git', args, { encoding: 'utf8', ...opts });
const CHECK_ENV = {
  ...process.env,
  GIT_AUTHOR_NAME: 'check', GIT_AUTHOR_EMAIL: 'check@example.invalid',
  GIT_COMMITTER_NAME: 'check', GIT_COMMITTER_EMAIL: 'check@example.invalid',
};
// Proves the hook works in a throwaway repository.
// 0 ok, 1 accepts a file without front matter, 2 rejects a valid file.
function verifyHook(hook) {
  const t = fs.mkdtempSync(path.join(os.tmpdir(), 'lww-check-'));
  const commit = (m) => git(['-C', t, '-c', 'core.hooksPath=.githooks', '-c', 'commit.gpgsign=false',
    'commit', '-q', '-m', m], { env: CHECK_ENV, stdio: 'ignore' }).status === 0;
  try {
    git(['-C', t, 'init', '-q']);
    fs.mkdirSync(path.join(t, '.githooks'));
    fs.copyFileSync(hook, path.join(t, '.githooks', 'pre-commit'));
    fs.chmodSync(path.join(t, '.githooks', 'pre-commit'), 0o755);
    fs.writeFileSync(path.join(t, 'bad.md'), '# no front matter\n');
    git(['-C', t, 'add', 'bad.md']);
    if (commit('check-bad')) return 1;
    git(['-C', t, 'rm', '-q', '--cached', 'bad.md']);
    fs.unlinkSync(path.join(t, 'bad.md'));
    fs.writeFileSync(path.join(t, 'good.md'),
      `---\nstatus: draft\nupdated: ${today}\nowner: check\nclassification: public\n---\n\n# ok\n`);
    git(['-C', t, 'add', 'good.md']);
    if (!commit('check-good')) return 2;
    return 0;
  } finally {
    fs.rmSync(t, { recursive: true, force: true });
  }
}

function appendBlock(file) {
  if (fs.existsSync(file) && fs.readFileSync(file, 'utf8').includes(HANDOFF_MARKER)) return 'protocol already present';
  if (o.dry) return 'would add the protocol';
  const block = fs.readFileSync(path.join(HANDOFF_SRC, '_agents-block.md'), 'utf8');
  if (fs.existsSync(file) && fs.statSync(file).size > 0) fs.appendFileSync(file, '\n' + block);
  else fs.writeFileSync(file, '# AGENTS.md\n\n' + block);
  return 'protocol added';
}
const row = (k, v, w = 10) => say(`  ${k.padEnd(w)} ${v}`);

// ------------------------------------------------------------------ handoff mode
if (o.mode === 'handoff') {
  if (!fs.existsSync(HANDOFF_SRC)) fail('the handoff files are missing.');
  const existed = fs.existsSync(path.join(o.target, '.handoff'));
  copyTree(HANDOFF_SRC, path.join(o.target, '.handoff'),
    sortC(walk(HANDOFF_SRC).filter((r) => r !== '_agents-block.md')), false);

  const agentsState = appendBlock(path.join(o.target, 'AGENTS.md'));
  const claude = path.join(o.target, 'CLAUDE.md');
  let lst = null;
  try { lst = fs.lstatSync(claude); } catch (_) { lst = null; }
  let claudeState;
  if (lst && lst.isSymbolicLink()) claudeState = 'a link already; left as it is';
  else if (lst) claudeState = appendBlock(claude);
  else if (o.dry) claudeState = 'would link to AGENTS.md';
  else {
    try { fs.symlinkSync('AGENTS.md', claude); claudeState = 'linked to AGENTS.md'; }
    catch (_) { fs.copyFileSync(path.join(o.target, 'AGENTS.md'), claude); claudeState = 'copied from AGENTS.md (no link rights)'; }
  }

  let ignoreState = '';
  if (o.handoffIgnore) {
    const gi = path.join(o.target, '.gitignore');
    const cur = fs.existsSync(gi) ? fs.readFileSync(gi, 'utf8') : '';
    if (cur.split('\n').includes('.handoff/')) ignoreState = '.handoff/ already ignored';
    else if (o.dry) ignoreState = 'would ignore .handoff/';
    else {
      fs.appendFileSync(gi, (cur.length && !cur.endsWith('\n') ? '\n' : '') + '.handoff/\n');
      ignoreState = '.handoff/ added';
    }
  }

  const repoState = haveGit() && git(['-C', o.target, 'rev-parse', '--is-inside-work-tree']).status === 0
    ? 'git repository'
    : 'not a git repository (fine; .handoff/ works without git)';
  const filesState = existed
    ? `${installed} file(s) written, ${skipped} already there`
    : `${installed} file(s): tasks/, results/, templates/`;

  say('');
  say(o.dry ? 'Dry run complete. Nothing was written.' : 'Installation complete.');
  say('');
  row('Setup', existed ? '.handoff/ exchange, updated' : '.handoff/ exchange');
  row('Code repo', `${SHOWN}  (${repoState})`);
  row('.handoff/', filesState);
  row('AGENTS.md', agentsState);
  row('CLAUDE.md', claudeState);
  if (ignoreState) row('.gitignore', ignoreState);
  if (!o.dry) {
    say('');
    say('Next:');
    say('  The planner writes .handoff/tasks/T-001.md from .handoff/templates/task.md.');
    say('  Then tell the executor, in this repo:');
    say('');
    say('      run T-001');
    say('');
  }
  process.exit(0);
}

// ------------------------------------------------------------------ workspace mode
if (!o.dry) fs.mkdirSync(o.target, { recursive: true });
copyTree(SRC, o.target, o.tier === 'full' ? sortC(walk(SRC)) : coreList(), true);

if (!fs.existsSync(KICKOFF_SRC)) fail('the kick-off template is missing.');
writeInstruction();

if (o.obsidian) {
  if (!fs.existsSync(PRESET)) fail('the Obsidian settings are missing.');
  copyTree(PRESET, path.join(o.target, '.obsidian'), sortC(walk(PRESET)), false);
}

if (o.eject) {
  for (const p of EJECT_PATHS) {
    const abs = path.join(o.target, p);
    if (!fs.existsSync(abs)) continue;
    if (o.dry) say(`  would remove ${p}`); else fs.rmSync(abs, { recursive: true, force: true });
  }
  const readme = path.join(o.target, 'README.md');
  if (fs.existsSync(readme) && fs.readFileSync(readme, 'utf8').includes('llm-wiki-workspace:upstream-readme')) {
    if (o.dry) say('  would replace README.md with a project stub');
    else fs.writeFileSync(readme, `# ${o.name}\n\nAn LLM Wiki Workspace. Start at \`instruction.md\`, then \`AGENTS.md\`.\n`);
  }
}

let gitState = 'not set up';
let checkState = 'off: the front-matter check needs git';
let commitState = '';
let problems = 0;

if (o.git) {
  if (!haveGit()) {
    gitState = 'not set up: git is not installed'; problems = 1;
  } else if (o.dry) {
    gitState = 'would initialise git and turn on the check';
    checkState = 'would verify the hook';
  } else {
    const absTarget = fs.realpathSync(o.target);
    const r = git(['-C', o.target, 'rev-parse', '--show-toplevel']);
    const top = r.status === 0 ? fs.realpathSync(r.stdout.trim()) : '';
    if (top && top !== absTarget) {
      gitState = `not set up: the folder is inside the git repository at ${top}`;
      checkState = 'off: core.hooksPath applies to that whole repository, so it was left alone';
      problems = 1;
    } else {
      if (!top) { git(['-C', o.target, 'init', '-q']); gitState = 'new repository'; } else gitState = 'existing repository';
      git(['-C', o.target, 'config', 'core.hooksPath', '.githooks']);

      const rc = verifyHook(path.join(o.target, '.githooks', 'pre-commit'));
      if (rc === 0) checkState = 'on, and verified: a file without front matter is rejected';
      else {
        checkState = rc === 1 ? 'FAILED: the hook accepted a file without front matter' : 'FAILED: the hook rejected a valid file';
        problems = 1;
      }

      if (git(['-C', o.target, 'rev-parse', '-q', '--verify', 'HEAD']).status !== 0) {
        git(['-C', o.target, 'add', '-A']);
        const c = git(['-C', o.target, 'commit', '-q', '-m', 'Install LLM Wiki Workspace']);
        if (c.status === 0) commitState = 'first commit made';
        else {
          const out = (c.stderr || '') + (c.stdout || '');
          if (/tell me who you are|identity unknown|auto-detect/.test(out)) {
            commitState = 'not made yet: git does not know your name and email. Set them, then commit:\n' +
              '               git config --global user.name "Your Name"\n' +
              '               git config --global user.email you@example.com\n' +
              '               git commit -m "Install LLM Wiki Workspace"';
          } else {
            commitState = `FAILED: ${out.split('\n')[0]}`;
            problems = 1;
          }
        }
      }
    }
  }
}

say('');
if (o.dry) say('Dry run complete. Nothing was written.');
else if (!problems) say('Installation complete.');
else say('Installation finished, with problems. See below.');
say('');

const filesLine = skipped > 0
  ? `${installed} file(s) written, ${skipped} already there and kept`
  : `${installed} file(s), ${o.tier}`;
row('Project', o.name);
row('Folder', `${SHOWN}  (${filesLine})`);
row('Owner', o.owner || 'not set: files keep owner: TODO');
if (o.obsidian) row('Obsidian', 'configured: open the folder as a vault');
row('Git', gitState);
row('Check', checkState);
if (commitState) row('Commit', commitState);

if (!o.dry) {
  say('');
  say('Next:');
  if (o.target !== '.') say(`  cd ${o.target}`);
  say('  Open the folder with your AI agent and tell it:');
  say('');
  say('      Read instruction.md and start the kick-off.');
  say('');
}
process.exit(problems);
