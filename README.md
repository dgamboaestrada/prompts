# Prompts

## Installing agents skills

Global agent-compatible:
```bash
mkdir -p ~/.agents/skills/
ln -sfn $PWD/skills/* ~/.agents/skills/.
```

Claude Code agent-compatible:
```bash
mkdir -p ~/.claude/skills/
ln -sfn $PWD/skills/* ~/.claude/skills/.
```

Global Antigravity agent:
```bash
mkdir -p ~/.gemini/antigravity/skills
ln -sfn $PWD/skills/* ~/.gemini/antigravity/skills/.
```

## Installing Global Agent configuration
```bash
ln -sfn $PWD/AGENTS.md ~/.agents/AGENTS.md
```

## Installing Antigravity configuration
```bash
ln -sfn $PWD/AGENTS.md ~/.gemini/AGENTS.md
```

## Installing Claude configuration
```bash
ln -sfn $PWD/AGENTS.md ~/.claude/CLAUDE.md
```


## Resources:
- https://antigravity.google/docs/rules-workflows
- https://antigravity.google/docs/skills
- https://code.claude.com/docs/en/skills
- https://cursor.com/docs/context/skills
- https://geminicli.com/docs/
- https://opencode.ai/docs/skills/
- https://docs.continue.dev/reference

## Conventions
- [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
- [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/)
- Git tag conventions: git tag v0.1.0 -m "Release version 0.1.0"
