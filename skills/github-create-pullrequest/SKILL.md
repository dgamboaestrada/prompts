---
name: github-create-pullrequest
description: Use this skill when the user's goal is to CREATE a pull request or WRITE a PR description. Must trigger for: "create a PR", "open a PR", "publish a PR", "submit this for review", "open this for review", "push for review", "draft the PR body", "write a PR description", "give me a PR description to copy". Invoke on intent — the user doesn't need to say "pull request" explicitly. Skip only when reviewing an existing PR's diff, resolving merge conflicts, merging a PR, squashing commits, or managing git tags.
license: MIT
metadata:
  author: Daniel Gamboa Estrada
  version: "0.5.0"
---

# Role and Context

You are a GitHub expert specializing in Pull Request creation and documentation using the GitHub CLI (`gh`). This skill covers two modes — detect which one the user needs and follow the corresponding path.

## Detect Mode

| User intent | Mode |
| --- | --- |
| Create/open/submit/push a PR | **Full PR creation** |
| Generate/draft/write a PR description, "give me the description" | **Description only** |

When ambiguous, default to **Full PR creation**.

---

## Shared Analysis (run in both modes)

### Step 1 — Detect base branch and repository status

```bash
BASE_BRANCH=$(git branch -r | grep -E 'origin/(main|master)$' | sed 's/.*origin\///' | sort | head -n 1)
CURRENT_BRANCH=$(git branch --show-current)
echo "Base: $BASE_BRANCH | Current: $CURRENT_BRANCH"
git status
```

If `git status` shows uncommitted changes and the mode is **Full PR creation**, stop and tell the user: they need to commit or stash before creating a PR. In **Description only** mode, proceed anyway.

### Step 2 — Review commit history and diff

```bash
git log --oneline origin/$BASE_BRANCH..HEAD
git diff origin/$BASE_BRANCH...HEAD --name-status
git diff origin/$BASE_BRANCH...HEAD --stat
```

### Step 3 — Read key modified files

Identify the most relevant changed files from the diff output and read their content. Focus on files that carry the most intent — logic, configuration, interfaces. This step is what separates a generic description from one that actually explains the "why".

---

## Mode A: Description Only

After completing the shared analysis, compile the description using the template below and output it inside a markdown code block so the user can copy it directly.

**Output format:**

````text
```markdown
[description content here]
```
````

Use the **Description template** section below. Omit `## Testing`, `## Breaking changes`, and `## Related issues` — those are only relevant when creating a real PR.

---

## Mode B: Full PR Creation

### Step 4 — Push the branch

```bash
git push origin $CURRENT_BRANCH
```

### Step 5 — Write PR body to a temp file

Build the description using the template below and write it to a temp file to avoid shell escaping issues:

```bash
cat > /tmp/pr_body.md << 'EOF'
[body content here]
EOF
```

Include all applicable sections from the **Description template**. Omit sections that add no value (e.g., no breaking changes — skip that section).

### Step 6 — Create the PR

```bash
# Standard PR (default)
gh pr create \
  --base "$BASE_BRANCH" \
  --head "$CURRENT_BRANCH" \
  --title "<title>" \
  --body "$(cat /tmp/pr_body.md)"

# Draft PR — only if the user explicitly asked for a draft
gh pr create --draft \
  --base "$BASE_BRANCH" \
  --head "$CURRENT_BRANCH" \
  --title "<title>" \
  --body "$(cat /tmp/pr_body.md)"
```

**Title rules:**

- Keep it concise and descriptive (under 72 characters)
- If the branch name contains a ticket ID (e.g., `TASK-1234`, `ABC-56`), prefix the title with it: `TASK-1234: <description>`
- Otherwise, use a plain imperative title: `Add user authentication` not `Added user authentication`
- Match the exact casing of ticket IDs from the branch name

### Step 7 — Open in browser

```bash
gh pr view --web
```

---

## Description template

Use this structure. Omit any section that doesn't apply — blank sections add noise.

```markdown
## Description

[1-3 sentences explaining what this PR does and why. Focus on intent, not just mechanics.]

## Main changes

1. **[Change category]**
   - Specific detail
   - Additional detail if applicable

2. **[Change category]**
   - Specific detail

## Modified files

- `path/to/file1.ext`
- `path/to/file2.ext`

## Impact

- **[Impact area]** — brief description of the benefit or behavior change

## Testing

[How was this tested? Manual steps, test commands, or "no behavior change" if it's a pure refactor.]

## Breaking changes

[Describe any breaking changes. Omit this section if there are none.]

## Related issues

[Link to issues, tickets, or context. Omit if none.]
```

**Writing the description well matters.** Reviewers use it to understand intent before reading the diff. Be specific: instead of "Updated the auth module", write "Replaced session-based auth with JWT to support stateless scaling."

---

## Common errors

| Error | Cause | Solution |
| --- | --- | --- |
| `No commits between $BASE_BRANCH and <branch>` | Branch has no new commits or wrong base | Verify with `git log --oneline origin/$BASE_BRANCH..HEAD` |
| `Head sha can't be blank` | Branch not pushed to remote | Run `git push origin $CURRENT_BRANCH` first |
| `already exists` | PR for this branch already open | Run `gh pr view` to find it |
| Title has wrong ticket casing | Branch name casing not matched | Check with `git branch --show-current` |
