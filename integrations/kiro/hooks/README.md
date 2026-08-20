# Kiro Hook: Pre-push Vulnerability Gate

A Kiro hook that **blocks `git push`** if Critical or High severity vulnerabilities with available fixes are detected.

## Installation

```bash
# Copy the hook script
cp integrations/kiro/hooks/vulnscan-gate.sh ~/.kiro/hooks/
chmod +x ~/.kiro/hooks/vulnscan-gate.sh
```

Then add to your agent config (`.kiro/agents/your-agent.json`):

```json
{
  "hooks": {
    "preToolUse": [
      {
        "matcher": "shell",
        "command": "~/.kiro/hooks/vulnscan-gate.sh",
        "timeout_ms": 60000
      }
    ]
  }
}
```

Or use the provided example:

```bash
cp integrations/kiro/hooks/agent-example.json .kiro/agents/secure-dev.json
```

## How it works

1. Intercepts any `shell` tool call that contains `git push`
2. Auto-detects project type (Maven, Gradle, Node.js, Python, Go, .NET, Rust)
3. Runs Grype vulnerability scan
4. **Blocks push** (exit code 2) if Critical/High fixable vulnerabilities exist
5. **Allows push** if no critical issues found

## Bypass

- Push directly from terminal (outside Kiro) to bypass
- Or remove the hook from your agent config

## Requirements

- [Grype](https://github.com/anchore/grype) installed (`brew install grype`)
- [jq](https://github.com/jqlang/jq) installed (`brew install jq`)
- For Maven/Gradle: `mvn` or `gradle` available
