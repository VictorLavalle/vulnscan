#!/usr/bin/env bash
# vulnscan-gate.sh - Kiro Hook: Block git push if critical/high vulnerabilities exist
# Install: chmod +x this file, reference in .kiro/agents/*.json
set -euo pipefail

# Read hook event from stdin
EVENT=$(cat)

# Only intercept shell commands that contain "git push"
TOOL_NAME=$(echo "$EVENT" | jq -r '.tool_name // empty' 2>/dev/null)
COMMAND=$(echo "$EVENT" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only act on shell tool with git push
if [[ "$TOOL_NAME" != "shell" && "$TOOL_NAME" != "execute_bash" ]]; then
  exit 0
fi

if [[ "$COMMAND" != *"git push"* ]]; then
  exit 0
fi

echo "🛡️  vulnscan: Running vulnerability check before push..." >&2

# Detect project type
if [[ -f "pom.xml" ]]; then
  mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null
  TARGET="sbom:target/bom.json"
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  if [[ -f "./gradlew" ]]; then
    ./gradlew cyclonedxBom -q 2>/dev/null
  fi
  TARGET="sbom:build/reports/bom.json"
elif [[ -f "package-lock.json" || -f "yarn.lock" || -f "pnpm-lock.yaml" || -f "requirements.txt" || -f "Pipfile.lock" || -f "poetry.lock" || -f "go.sum" || -f "Cargo.lock" ]]; then
  TARGET="dir:."
else
  # No supported project, allow push
  exit 0
fi

# Check if grype is available
if ! command -v grype &>/dev/null; then
  echo "⚠️  vulnscan: grype not installed, skipping scan" >&2
  exit 0
fi

# Run scan and check for critical/high with fixes
CRITICAL_HIGH=$(grype "$TARGET" --sort-by severity --only-fixed -o json 2>/dev/null | \
  jq '[.matches[] | select(.vulnerability.severity == "Critical" or .vulnerability.severity == "High")] | length' 2>/dev/null || echo "0")

if [[ "$CRITICAL_HIGH" -gt 0 ]]; then
  echo "" >&2
  echo "❌ vulnscan: Found $CRITICAL_HIGH Critical/High vulnerabilities with available fixes!" >&2
  echo "" >&2
  echo "   Run 'vulnscan-summary' to see details and fix them before pushing." >&2
  echo "   To bypass: remove this hook or use git push directly outside Kiro." >&2
  echo "" >&2
  # Exit 2 = block the tool execution
  exit 2
fi

echo "✅ vulnscan: No critical/high fixable vulnerabilities found. Push allowed." >&2
exit 0
