# MCP Server: vulnscan

A [Model Context Protocol](https://modelcontextprotocol.io/) server that provides vulnerability scanning as a tool for any MCP-compatible AI agent (Claude, Codex, Kiro, Cursor, etc.).

## Installation

```bash
# Copy and make executable
cp integrations/mcp-server/vulnscan-mcp-server.sh ~/.local/bin/vulnscan-mcp-server
chmod +x ~/.local/bin/vulnscan-mcp-server
```

## Configuration

### Kiro CLI

Add to `.kiro/agents/your-agent.json`:

```json
{
  "mcpServers": {
    "vulnscan": {
      "command": "~/.local/bin/vulnscan-mcp-server",
      "args": []
    }
  }
}
```

### Claude Desktop

Add to `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "vulnscan": {
      "command": "/Users/YOUR_USER/.local/bin/vulnscan-mcp-server",
      "args": []
    }
  }
}
```

### Cursor

Add to `.cursor/mcp.json`:

```json
{
  "mcpServers": {
    "vulnscan": {
      "command": "~/.local/bin/vulnscan-mcp-server",
      "args": []
    }
  }
}
```

## Available Tools

| Tool | Description |
|------|-------------|
| `scan_vulnerabilities` | Full scan with results grouped by severity and fix suggestions |
| `detect_project_type` | Detect project type (Maven, Gradle, Node.js, Python, Go, .NET, Rust) |
| `get_vulnerability_summary` | Quick count of vulnerabilities by severity |

## Tool Parameters

### scan_vulnerabilities

```json
{
  "directory": ".",
  "severity_threshold": "high"
}
```

- `directory` (optional): Path to scan, defaults to current directory
- `severity_threshold` (optional): Minimum severity to report: `critical`, `high`, `medium`, `low`

### detect_project_type

```json
{
  "directory": "."
}
```

### get_vulnerability_summary

```json
{
  "directory": "."
}
```

## Example Usage

Once configured, ask your AI agent:

- "Scan this project for vulnerabilities"
- "Are there any critical CVEs in my dependencies?"
- "What's the vulnerability summary for this project?"
- "Scan and suggest fixes for high severity issues"

The agent will use the MCP tools automatically.

## Requirements

- [Grype](https://github.com/anchore/grype) installed (`brew install grype`)
- [jq](https://github.com/jqlang/jq) installed (`brew install jq`)
- For Maven/Gradle: `mvn` or `gradle` available
- Bash 4+
