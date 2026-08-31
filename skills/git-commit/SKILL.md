---
name: git-commit
description: |
  Invoke when a user asks to commit staged git changes — including terse phrases like "do a commit", "make a commit", "commit this", "commit these changes", or any message where the user has staged files (via git add) and wants the commit step done. Also invoke when they ask for a Conventional Commits message for staged work.

  This skill's purpose: generate a properly typed and scoped commit message following the Conventional Commits spec (feat/fix/perf/refactor/docs/ci/etc.), validate it, confirm with the user, then run git commit.

  Do NOT invoke for: push, pull, merge, rebase, cherry-pick, squash, stash, or git history operations.
license: MIT
metadata:
  author: Daniel Gamboa Estrada
  version: "0.3.0"
---

# Role and Context

You are a Git version control expert specializing in the **Conventional Commits** specification. Your goal is to produce a clear, machine-readable commit message that correlates with semantic versioning. You analyze staged changes, auto-detect scope, validate the proposed message, and present it for confirmation before committing.

---

## Step 1: Gather context in parallel

Run all of these before composing anything:

```bash
# Staged file list with stats
git diff --cached --stat

# Full diff (to understand what changed and why)
git diff --cached

# Current branch (to detect branch-prefixed pattern)
git branch --show-current

# Recent commits (to infer common scopes and style)
git log --oneline -10
```

---

## Step 2: Detect commit format

Inspect the current branch name:

- If it matches `PREFIX-NUMBER` (e.g., `FEATURE-001`, `BUGFIX-042`, `TASK-789`), offer **both** formats to the user:
  - Conventional Commits: `feat(scope): description`
  - Branch-prefixed: `PREFIX-NUMBER: description`
  - Default to Conventional Commits unless the user prefers branch-prefixed.
- Otherwise, use Conventional Commits only.

---

## Step 3: Auto-detect scope from staged files

Infer the scope from the file paths of staged files using these rules (in priority order):

| Staged path pattern            | Suggested scope        |
| ------------------------------ | ---------------------- |
| `tests/`, `**/*.test.*`, `**/*.spec.*` | omit scope, use `test` type |
| `docs/`, `*.md`, `*.rst`       | omit scope, use `docs` type |
| `ci/`, `.github/`, `.gitlab/`  | omit scope, use `ci` type  |
| `src/<module>/`                | use `<module>` as scope    |
| `lib/<module>/`                | use `<module>` as scope    |
| `packages/<name>/`             | use `<name>` as scope      |
| Multiple unrelated directories | omit scope                 |
| Single top-level file          | omit scope                 |

Also cross-reference the last 10 commits: if a scope appears 2+ times for this area, prefer it for consistency.

---

## Step 4: Auto-compose the commit message

Using the diff content, the detected scope, and recent commit patterns, generate a proposed message following this structure:

```
<type>[optional scope]: <description>

[optional body]
```

### Types

| Type       | When to use                                                  |
| ---------- | ------------------------------------------------------------ |
| `feat`     | Introduces a new feature (correlates with MINOR in SemVer)  |
| `fix`      | Patches a bug (correlates with PATCH in SemVer)             |
| `docs`     | Documentation changes only                                   |
| `style`    | Formatting, missing semicolons, etc.; no logic change        |
| `refactor` | Code change that neither fixes a bug nor adds a feature      |
| `perf`     | Performance improvement                                      |
| `test`     | Adding or correcting tests                                   |
| `build`    | Changes to build system or external dependencies             |
| `ci`       | Changes to CI/CD configuration and scripts                   |
| `chore`    | Other changes that don't modify src or test files            |
| `revert`   | Reverts a previous commit                                    |

### Description rules

- Imperative mood: "add", not "added" or "adds"
- No period at the end
- Max 72 characters on the first line (type + scope + description combined)
- Summarizes the *what* concisely

### Body (optional — use sparingly)

- Only include if the description alone does not convey intent
- One blank line after the description
- 1-2 sentences explaining *why*, not *what* (the diff shows what)

### Breaking changes

- Append `!` after type/scope: `feat!:` or `feat(api)!:`
- Breaking changes correlate with MAJOR in SemVer

---

## Step 5: Validate the proposed message

Before presenting to the user, check all of the following:

| Rule | Check |
| ---- | ----- |
| First line ≤ 72 characters | `echo -n "<first-line>" \| wc -c` |
| Type is in the allowed list | match against the types table above |
| Description is in imperative mood | does not end with `-ed`, `-s`, or a period |
| No trailing whitespace | |
| Body lines ≤ 72 characters (if present) | |

If any rule fails, fix the message before presenting it. Do not present an invalid message for confirmation.

---

## Step 6: Present a change summary and the proposed message

Show the user:

1. A concise diff summary (files changed, insertions, deletions from `git diff --cached --stat`)
2. The proposed commit message in a code block
3. If branch-prefixed format is also applicable, show the alternative

Example presentation:

```
Staged changes:
  src/auth/login.ts  | 12 +++--
  tests/auth.test.ts |  8 ++++
  2 files changed, 18 insertions(+), 2 deletions(-)

Proposed commit message:
---
feat(auth): add retry logic to login handler

Prevents cascading failures during transient network issues.
---
```

After presenting the message, proceed directly to Step 7.

---

## Step 7: Create the commit

```bash
git commit -m "$(cat <<'EOF'
<type>[optional scope]: <description>
EOF
)"
```

With body (only when necessary):

```bash
git commit -m "$(cat <<'EOF'
<type>[optional scope]: <description>

<concise explanation of why>
EOF
)"
```

---

## Step 8: Verify the commit

```bash
git log -1
```

Confirm the message matches what was proposed and was successfully committed.

---

## Step 9: Push (only if explicitly requested)

```bash
git push origin <branch-name>
```

---

## Best Practices

- One logical change per commit — if staged files span multiple concerns, flag it and suggest splitting
- Scope should be a noun describing the affected module or area
- Avoid redundancy: the type already conveys the nature of the change
- Use `git commit --amend` only to fix the last commit before pushing
- Prefer scopes consistent with recent commits in the same area
