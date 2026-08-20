#!/usr/bin/env bash
# vulnscan MCP Server - stdio-based Model Context Protocol server
# Provides vulnerability scanning as a tool for AI agents (Claude, Codex, Kiro, etc.)
#
# Usage in MCP config:
#   {
#     "mcpServers": {
#       "vulnscan": {
#         "command": "/path/to/vulnscan-mcp-server.sh",
#         "args": []
#       }
#     }
#   }

set -euo pipefail

# JSON-RPC response helpers
send_response() {
  local id="$1"
  local result="$2"
  printf '{"jsonrpc":"2.0","id":%s,"result":%s}\n' "$id" "$result"
}

send_error() {
  local id="$1"
  local code="$2"
  local message="$3"
  printf '{"jsonrpc":"2.0","id":%s,"error":{"code":%s,"message":"%s"}}\n' "$id" "$code" "$message"
}

# Tool: detect project type
detect_project() {
  local dir="${1:-.}"
  if [[ -f "$dir/pom.xml" ]]; then echo "maven"
  elif [[ -f "$dir/build.gradle" || -f "$dir/build.gradle.kts" ]]; then echo "gradle"
  elif [[ -f "$dir/package-lock.json" || -f "$dir/yarn.lock" || -f "$dir/pnpm-lock.yaml" ]]; then echo "node"
  elif [[ -f "$dir/requirements.txt" || -f "$dir/Pipfile.lock" || -f "$dir/poetry.lock" || -f "$dir/uv.lock" ]]; then echo "python"
  elif [[ -f "$dir/go.sum" ]]; then echo "go"
  elif [[ -f "$dir/Cargo.lock" ]]; then echo "rust"
  elif [[ -f "$dir/packages.lock.json" ]]; then echo "dotnet"
  else echo "unknown"
  fi
}

# Tool: run vulnerability scan
run_scan() {
  local dir="${1:-.}"
  local severity_filter="${2:-}"
  local project_type
  project_type=$(detect_project "$dir")

  local target=""
  case "$project_type" in
    maven)
      (cd "$dir" && mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null)
      target="sbom:$dir/target/bom.json"
      ;;
    gradle)
      (cd "$dir" && ./gradlew cyclonedxBom -q 2>/dev/null || true)
      target="sbom:$dir/build/reports/bom.json"
      ;;
    *)
      target="dir:$dir"
      ;;
  esac

  local grype_args=(--sort-by severity --only-fixed -o json)
  if [[ -n "$severity_filter" ]]; then
    grype_args+=(--fail-on "$severity_filter")
  fi

  local result
  result=$(grype "$target" "${grype_args[@]}" 2>/dev/null || true)
  echo "$result"
}

# Handle MCP protocol messages
handle_message() {
  local msg="$1"
  local method id

  method=$(echo "$msg" | jq -r '.method // empty')
  id=$(echo "$msg" | jq -r '.id // "null"')

  case "$method" in
    "initialize")
      send_response "$id" '{
        "protocolVersion": "2024-11-05",
        "capabilities": {
          "tools": {}
        },
        "serverInfo": {
          "name": "vulnscan",
          "version": "1.2.0"
        }
      }'
      ;;

    "notifications/initialized")
      # No response needed for notifications
      ;;

    "tools/list")
      send_response "$id" '{
        "tools": [
          {
            "name": "scan_vulnerabilities",
            "description": "Scan project dependencies for known vulnerabilities (CVEs). Auto-detects project type: Maven, Gradle, Node.js, Python, Go, .NET, Rust. Returns vulnerabilities grouped by severity with fix suggestions.",
            "inputSchema": {
              "type": "object",
              "properties": {
                "directory": {
                  "type": "string",
                  "description": "Project directory to scan (defaults to current directory)"
                },
                "severity_threshold": {
                  "type": "string",
                  "enum": ["critical", "high", "medium", "low"],
                  "description": "Minimum severity to report (defaults to all)"
                }
              }
            }
          },
          {
            "name": "detect_project_type",
            "description": "Detect the project type and package manager in a directory.",
            "inputSchema": {
              "type": "object",
              "properties": {
                "directory": {
                  "type": "string",
                  "description": "Directory to check (defaults to current directory)"
                }
              }
            }
          },
          {
            "name": "get_vulnerability_summary",
            "description": "Get a summary count of vulnerabilities by severity for a project.",
            "inputSchema": {
              "type": "object",
              "properties": {
                "directory": {
                  "type": "string",
                  "description": "Project directory to scan (defaults to current directory)"
                }
              }
            }
          }
        ]
      }'
      ;;

    "tools/call")
      local tool_name params dir severity
      tool_name=$(echo "$msg" | jq -r '.params.name')
      params=$(echo "$msg" | jq -r '.params.arguments // {}')
      dir=$(echo "$params" | jq -r '.directory // "."')
      severity=$(echo "$params" | jq -r '.severity_threshold // ""')

      case "$tool_name" in
        "scan_vulnerabilities")
          local scan_result
          scan_result=$(run_scan "$dir" "$severity")

          if [[ -z "$scan_result" || "$scan_result" == "null" ]]; then
            send_response "$id" "{\"content\":[{\"type\":\"text\",\"text\":\"No vulnerabilities found or scan could not be completed.\"}]}"
          else
            # Parse and format results
            local formatted
            formatted=$(echo "$scan_result" | jq -r '
              [.matches[] | {
                name: .artifact.name,
                installed: .artifact.version,
                fixed: .vulnerability.fix.versions[0],
                severity: .vulnerability.severity,
                id: .vulnerability.id
              }] |
              group_by(.name) |
              sort_by(-(.[0] | if .severity == "Critical" then 4 elif .severity == "High" then 3 elif .severity == "Medium" then 2 else 1 end)) |
              map("[\(.[0].severity)] \(.[0].name) \(.[0].installed) → \(.[0].fixed // "no fix") (\(length) CVEs)") |
              join("\n")
            ' 2>/dev/null || echo "Error parsing results")

            local total
            total=$(echo "$scan_result" | jq '.matches | length' 2>/dev/null || echo "0")

            local text="Found $total vulnerabilities:\n\n$formatted"
            local escaped_text
            escaped_text=$(echo "$text" | jq -Rs .)

            send_response "$id" "{\"content\":[{\"type\":\"text\",\"text\":$escaped_text}]}"
          fi
          ;;

        "detect_project_type")
          local ptype
          ptype=$(detect_project "$dir")
          send_response "$id" "{\"content\":[{\"type\":\"text\",\"text\":\"Project type: $ptype\"}]}"
          ;;

        "get_vulnerability_summary")
          local scan_result
          scan_result=$(run_scan "$dir" "")

          local summary
          summary=$(echo "$scan_result" | jq -r '
            {
              critical: [.matches[] | select(.vulnerability.severity == "Critical")] | length,
              high: [.matches[] | select(.vulnerability.severity == "High")] | length,
              medium: [.matches[] | select(.vulnerability.severity == "Medium")] | length,
              low: [.matches[] | select(.vulnerability.severity == "Low")] | length,
              total: .matches | length
            } | "Critical: \(.critical)\nHigh: \(.high)\nMedium: \(.medium)\nLow: \(.low)\nTotal: \(.total)"
          ' 2>/dev/null || echo "Error getting summary")

          local escaped_summary
          escaped_summary=$(echo "$summary" | jq -Rs .)
          send_response "$id" "{\"content\":[{\"type\":\"text\",\"text\":$escaped_summary}]}"
          ;;

        *)
          send_error "$id" "-32601" "Unknown tool: $tool_name"
          ;;
      esac
      ;;

    *)
      if [[ "$id" != "null" ]]; then
        send_error "$id" "-32601" "Method not found: $method"
      fi
      ;;
  esac
}

# Main loop: read JSON-RPC messages from stdin
while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  handle_message "$line"
done
