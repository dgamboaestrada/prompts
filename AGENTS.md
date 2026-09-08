# Agent Instructions & Guidelines

## Core Behavior
- Get straight to the point, without introductions or conclusions.
- Short and concise answer.
- Avoid using emojis.
- Read the README.md file if the project has one.
- Always anonymize code examples.
- You are allowed and encouraged to suggest fixes for warnings or code improvements. However, do not apply or write the modified code directly unless explicitly confirmed.
- For terraform commands, never execute them yourself; always ask the user for the code to execute.

## Git & Version Control
- Do not commit changes unless explicitly requested.
- Do not push commits unless explicitly requested.
- Do not create pull requests unless explicitly requested.
- Keep Pull Request titles and descriptions brief and concise.
- Do not include `Co-Authored-By` attribution lines (for Claude, Gemini, Antigravity, or any model) in git commit messages.

## Available CLI Tools
- `jq` is available — use it for parsing/formatting JSON output (e.g. `aws lambda get-policy` results)
- `yq` is available — use it for parsing/formatting YAML
- `aws` is available — use it for AWS CLI commands

## Jira
If you receive a Jira ticket—for example, https://example.atlassian.net/browse/PROJ-1234, retrieve the ticket information and save it to a `spec.md`.

## spec.md
- If there is a `spec.md` file in the project root, always read it and keep it up to date. This document contains the specifications for the task (ticket) being worked on.
- Never commit `spec.md`.
