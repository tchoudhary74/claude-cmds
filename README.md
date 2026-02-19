# Claude CLI Configuration

Curated setup for enterprise Claude CLI teams. Enforces quality, catches mistakes, and saves tokens.

## Setup

```bash
cp -r rules/ commands/ agents/ hooks/ scripts/ ~/.claude/
export CLAUDE_PLUGIN_ROOT="$HOME/.claude"
```

Requires Node.js 16+ for hook scripts.

---

## Rules

Rules are loaded into every Claude session automatically. They shape how Claude writes code.

| File | What It Does |
|------|-------------|
| `rules/coding-style.md` | Enforces immutability (spread over mutation), small files (800 lines max), error handling, input validation with Zod |
| `rules/security.md` | No hardcoded secrets, parameterized queries only, validate all user input, auth on every protected route |
| `rules/performance.md` | Use Haiku for simple tasks (cheapest), Sonnet for coding (default), Opus only for architecture (expensive). Manage context window wisely |

## Commands

Type these in Claude CLI to invoke them.

| Command | What It Does | Why |
|---------|-------------|-----|
| `/plan` | Restates requirements, identifies risks, creates step-by-step implementation plan. Waits for your approval before writing any code | Prevents Claude from coding the wrong thing and wasting tokens |
| `/build-fix` | Detects build system (npm/gradle/cargo/go), captures errors, fixes them one at a time with minimal changes | Saves 10-30 min of manual debugging per broken build |
| `/code-review` | Scans uncommitted changes for security issues, code quality, and best practices. Rates findings CRITICAL/HIGH/MEDIUM/LOW | Catches problems before they reach PR review |

## Agents

Sub-agents Claude spawns for specialized tasks.

| Agent | Model | What It Does | Why |
|-------|-------|-------------|-----|
| `agents/code-reviewer.md` | Sonnet | Runs `git diff`, reads full file context, checks OWASP Top 10, React patterns, N+1 queries, missing error handling. Only reports issues with >80% confidence | Thorough automated review without noise |
| `agents/build-error-resolver.md` | Sonnet | Fixes build/TypeScript errors only. No refactoring, no architecture changes, no scope creep. Minimal diffs | Gets the build green fast without touching unrelated code |
| `agents/architect.md` | **Opus** | System design, trade-off analysis, Architecture Decision Records, scalability planning. Evaluates patterns and proposes multi-phase implementation | Deep reasoning for decisions that shape the codebase long-term. **~15x cost of Sonnet — use sparingly. For routine planning use `/plan` instead** |

## Hooks

Run automatically at specific events. No manual invocation needed.

| When | What It Does | Why |
|------|-------------|-----|
| **Before `git push`** | Reminds you to review changes | Prevents accidental pushes |
| **Before creating `.md` files** | Blocks random doc files (allows README, CLAUDE.md) | Stops Claude from creating files nobody asked for |
| **Before every Edit/Write** | Counts tool calls, suggests `/compact` after 50 | Prevents auto-compaction from destroying context mid-task |
| **Before context compaction** | Saves current state to session file | Preserves progress when context gets summarized |
| **After editing JS/TS files** | Warns if `console.log` was added, shows line numbers | Catches debug logging immediately |
| **When Claude stops responding** | Scans all modified JS/TS files for `console.log` (skips tests/config) | Final safety net before you move on |
| **When session ends** | Parses transcript, saves summary of tasks/files/tools to `~/.claude/sessions/` | Continuity when you start a new session tomorrow |
| **When session ends** | Checks if session was long enough (10+ messages) for pattern extraction | Builds up learned patterns over time |

## Scripts

Supporting code that powers the hooks.

| File | What It Does |
|------|-------------|
| `scripts/lib/utils.js` | Cross-platform file ops, git helpers, stdin parsing, logging. All hooks depend on this |
| `scripts/lib/package-manager.js` | Detects npm/pnpm/yarn/bun from lock files, package.json, or config. No child processes on startup |
| `scripts/hooks/suggest-compact.js` | Tracks tool call count per session, suggests `/compact` at intervals |
| `scripts/hooks/pre-compact.js` | Logs compaction timestamp, annotates active session file |
| `scripts/hooks/post-edit-console-warn.js` | Reads edited file, greps for `console.log`, warns via stderr |
| `scripts/hooks/check-console-log.js` | Gets git-modified files, checks each for `console.log`, excludes test files |
| `scripts/hooks/session-end.js` | Reads JSONL transcript, extracts user messages + files modified + tools used, writes session summary |
| `scripts/hooks/evaluate-session.js` | Counts session messages, flags long sessions for pattern extraction |

## Budget Tips

- Always `/plan` before coding. A $0.03 plan prevents a $0.30 redo.
- Use `/compact` between tasks. The hook will remind you.
- Be specific: "fix type error in src/api/client.ts:42" not "fix the build".
- Code-reviewer and build-error-resolver use Sonnet. Architect uses Opus (~15x cost) — reserve for major decisions.
