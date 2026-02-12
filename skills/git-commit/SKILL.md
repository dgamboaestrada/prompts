---
description: Git commit staged
---

## Steps to commit staged files in git

### 1. Check what files are staged
```bash
git status
```
or
```bash
git diff --cached --name-only
```

### 2. Review the changes
```bash
git diff --cached
```

### 3. Create the commit with a descriptive message
```bash
git commit -m "Your commit message here"
```

For a multi-line commit message:
```bash
git commit -m "Short summary line

- Detailed change 1
- Detailed change 2
- Detailed change 3"
```

### 4. Verify the commit was created
```bash
git log -1
```

### 5. Push to remote repository (only if it was required)
```bash
git push origin <branch-name>
```

## Best Practices

- Write clear, descriptive commit messages
- Use present tense ("Add feature" not "Added feature")
- Keep commits focused on a single logical change
- Review staged changes before committing
- Use `git commit --amend` if you need to modify the last commit

## Example Workflow

```bash
# 1. Check status
git status

# 2. Review changes
git diff --cached

# 3. Commit with descriptive message
git commit -m "Fix Docker build and add Docker documentation

- Fix Dockerfile to copy binaries to installed package location
- Add comprehensive Docker installation and usage documentation to README
- Include notes about CIA tool for AWS authentication"

# 4. Verify the commit
git log -1

# 5. Push to remote (optional - ask before pushing)
# Ask: "Do you want to push this commit to the remote repository?"
# If yes:
git push origin <branch-name>
```
