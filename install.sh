#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# vulnscan - Local Dependency Vulnerability Scanner Setup
# https://github.com/VictorLavalle/Vulns-Scan
#
# One-command setup for local vulnerability scanning of Maven/Gradle projects.
# No API keys required. No cloud credentials needed.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/your-org/vulnscan/main/install.sh | bash
#   # or
#   ./install.sh
# ============================================================================

VERSION="1.0.0"
SHELL_RC=""
VULNSCAN_DIR="${HOME}/.vulnscan"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

print_header() {
  echo ""
  echo -e "${BOLD}🛡️  vulnscan v${VERSION} - Local Vulnerability Scanner Setup${NC}"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

print_step() {
  echo -e "${BLUE}▶${NC} $1"
}

print_success() {
  echo -e "${GREEN}✔${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
  echo -e "${RED}✖${NC} $1"
}

# Detect OS
detect_os() {
  case "$(uname -s)" in
    Darwin*) OS="macos" ;;
    Linux*)  OS="linux" ;;
    *)       print_error "Unsupported OS: $(uname -s)"; exit 1 ;;
  esac
}

# Detect shell
detect_shell() {
  if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="${HOME}/.zshrc"
    SHELL_NAME="zsh"
  elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
    SHELL_RC="${HOME}/.bashrc"
    SHELL_NAME="bash"
  else
    SHELL_RC="${HOME}/.profile"
    SHELL_NAME="sh"
  fi
}

# Check if a command exists
has_cmd() {
  command -v "$1" &>/dev/null
}

# Install Homebrew (macOS) or check package manager (Linux)
ensure_package_manager() {
  if [[ "$OS" == "macos" ]]; then
    if ! has_cmd brew; then
      print_step "Installing Homebrew..."
      /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
      print_success "Homebrew installed"
    fi
  fi
}

# Install grype
install_grype() {
  if has_cmd grype; then
    local version
    version=$(grype version 2>/dev/null | grep "^Application" | awk '{print $2}' || grype version 2>/dev/null | head -1)
    print_success "Grype already installed (${version})"
    return
  fi

  print_step "Installing Grype (vulnerability scanner)..."
  if [[ "$OS" == "macos" ]]; then
    brew install grype
  else
    curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
  fi
  print_success "Grype installed"
}

# Install checkov
install_checkov() {
  if has_cmd checkov; then
    local version
    version=$(checkov --version 2>/dev/null || echo "unknown")
    print_success "Checkov already installed (${version})"
    return
  fi

  print_step "Installing Checkov (IaC/secrets scanner)..."
  if has_cmd pipx; then
    pipx install checkov
  elif [[ "$OS" == "macos" ]] && has_cmd brew; then
    brew install checkov
  elif has_cmd pip3; then
    pip3 install --user checkov
  else
    print_warning "Could not install Checkov. Install manually: pipx install checkov"
    return
  fi
  print_success "Checkov installed"
}

# Install jq (needed for vulnscan-summary)
install_jq() {
  if has_cmd jq; then
    print_success "jq already installed"
    return
  fi

  print_step "Installing jq (JSON processor)..."
  if [[ "$OS" == "macos" ]]; then
    brew install jq
  else
    sudo apt-get install -y jq 2>/dev/null || sudo yum install -y jq 2>/dev/null
  fi
  print_success "jq installed"
}

# Check for Maven
check_maven() {
  if has_cmd mvn; then
    print_success "Maven found ($(mvn --version 2>/dev/null | head -1 | awk '{print $3}'))"
  else
    print_warning "Maven not found. Required for scanning Maven projects."
    echo "         Install: brew install maven (macOS) or sudo apt install maven (Linux)"
  fi
}

# Check for Java
check_java() {
  if has_cmd java; then
    local version
    version=$(java -version 2>&1 | head -1 | awk -F '"' '{print $2}')
    print_success "Java found (${version})"
  else
    print_warning "Java not found. Required for building Maven projects."
  fi
}

# Create the vulnscan directory and scripts
create_scripts() {
  print_step "Creating vulnscan scripts in ${VULNSCAN_DIR}..."
  mkdir -p "${VULNSCAN_DIR}"

  # Main vulnscan-summary script (standalone, doesn't need to be a shell function)
  cat > "${VULNSCAN_DIR}/vulnscan-summary.sh" << 'SCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Auto-detect project type and generate SBOM
echo "📦 Generating SBOM..."
if [[ -f "pom.xml" ]]; then
  mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null
  BOM_PATH="target/bom.json"
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  ./gradlew cyclonedxBom -q 2>/dev/null || gradle cyclonedxBom --init-script <(cat <<'INIT'
initscript {
    repositories { mavenCentral() }
    dependencies { classpath 'org.cyclonedx:cyclonedx-gradle-plugin:2.2.1' }
}
allprojects { apply plugin: org.cyclonedx.gradle.CycloneDxPlugin }
INIT
  ) -q
  BOM_PATH="build/reports/bom.json"
else
  echo "ERROR: No pom.xml or build.gradle found" >&2
  exit 1
fi

echo ""
echo "🔍 Scanning for vulnerabilities..."
echo ""

GRYPE_OUTPUT=$(grype "sbom:$BOM_PATH" --sort-by severity -o json 2>/dev/null)

if echo "$GRYPE_OUTPUT" | jq -e '.matches | length == 0' &>/dev/null; then
  echo "🎉 No vulnerabilities found!"
  exit 0
fi

echo "$GRYPE_OUTPUT" | jq -r '
  [.matches[] | {
    name: .artifact.name,
    installed: .artifact.version,
    fixed: .vulnerability.fix.versions[0],
    severity: .vulnerability.severity,
    id: .vulnerability.id
  }] |
  group_by(.name) |
  sort_by(-(.[0] | if .severity == "Critical" then 4 elif .severity == "High" then 3 elif .severity == "Medium" then 2 else 1 end)) |
  length as $libs |
  (map(length) | add // 0) as $total |
  "🛡️  \($total) vulnerabilities in \($libs) libraries\n" +
  "┌──────────┬─────────────────────────────────┬─────────────────────────┬──────┬─────────────────────────────────────────────┐\n" +
  "│ Severity │ Library                         │ Upgrade Path            │ CVEs │ GHSAs                                       │\n" +
  "├──────────┼─────────────────────────────────┼─────────────────────────┼──────┼─────────────────────────────────────────────┤\n" +
  ([.[] |
    (.[0].severity | if . == "Critical" then "\u001b[31m\(.)\u001b[0m" elif . == "High" then "\u001b[33m\(.)\u001b[0m" elif . == "Medium" then "\u001b[34m\(.)\u001b[0m" else "\u001b[32m\(.)\u001b[0m" end) as $sev |
    (.[0].name | if length > 30 then .[:27] + "..." else . end) as $name |
    ("\(.[0].installed) → \(.[0].fixed // "?")" | if length > 22 then .[:19] + "..." else . end) as $path |
    (length | tostring) as $count |
    ([.[].id] | if length > 3 then [.[:3][], "...+\(length - 3)"] else . end | join(", ") | if length > 43 then .[:40] + "..." else . end) as $ghsas |
    "│ \($sev)\(" " * (8 - (.[0].severity | length))) │ \($name)\(" " * (31 - ($name | length))) │ \($path)\(" " * (23 - ($path | length))) │ \($count)\(" " * (4 - ($count | length))) │ \($ghsas)\(" " * (43 - ($ghsas | length))) │"
  ] | join("\n")) +
  "\n└──────────┴─────────────────────────────────┴─────────────────────────┴──────┴─────────────────────────────────────────────┘"
'
SCRIPT

  chmod +x "${VULNSCAN_DIR}/vulnscan-summary.sh"
  print_success "Scripts created"
}

# Add shell aliases
install_shell_aliases() {
  local marker="# >>> vulnscan >>>"
  local marker_end="# <<< vulnscan <<<"

  # Check if already installed
  if grep -q "$marker" "$SHELL_RC" 2>/dev/null; then
    print_success "Shell aliases already configured in ${SHELL_RC}"
    return
  fi

  print_step "Adding aliases to ${SHELL_RC}..."

  cat >> "$SHELL_RC" << 'ALIASES'

# >>> vulnscan >>>
# Local vulnerability scanning (no API keys needed)
# https://github.com/VictorLavalle/Vulns-Scan

# Auto-detect project type and generate SBOM
_vulnscan_sbom() {
  if [[ -f "pom.xml" ]]; then
    mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q
    echo "target/bom.json"
  elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
    ./gradlew cyclonedxBom -q 2>/dev/null || gradle cyclonedxBom --init-script <(cat <<'INIT'
initscript {
    repositories { mavenCentral() }
    dependencies { classpath 'org.cyclonedx:cyclonedx-gradle-plugin:2.2.1' }
}
allprojects { apply plugin: org.cyclonedx.gradle.CycloneDxPlugin }
INIT
    ) -q
    echo "build/reports/bom.json"
  else
    echo "ERROR: No pom.xml or build.gradle found" >&2
    return 1
  fi
}

alias vulnscan='_bom=$(_vulnscan_sbom) && grype "sbom:$_bom" --sort-by severity --only-fixed'
alias vulnscan-all='_bom=$(_vulnscan_sbom) && grype "sbom:$_bom" --sort-by severity'
alias vulnscan-json='_bom=$(_vulnscan_sbom) && grype "sbom:$_bom" -o json > target/vuln-report.json && echo "Report: target/vuln-report.json"'
alias checkscan="checkov -d . --compact --quiet"
vulnscan-summary() {
  local _bom
  _bom=$(_vulnscan_sbom) || return 1
  echo "" && \
  grype "sbom:$_bom" --sort-by severity -o json 2>/dev/null | \
  jq -r '
    [.matches[] | {
      name: .artifact.name,
      installed: .artifact.version,
      fixed: .vulnerability.fix.versions[0],
      severity: .vulnerability.severity,
      id: .vulnerability.id
    }] |
    group_by(.name) |
    sort_by(-(.[0] | if .severity == "Critical" then 4 elif .severity == "High" then 3 elif .severity == "Medium" then 2 else 1 end)) |
    length as $libs |
    (map(length) | add // 0) as $total |
    "🛡️  \($total) vulnerabilities in \($libs) libraries\n" +
    "┌──────────┬─────────────────────────────────┬─────────────────────────┬──────┬─────────────────────────────────────────────┐\n" +
    "│ Severity │ Library                         │ Upgrade Path            │ CVEs │ GHSAs                                       │\n" +
    "├──────────┼─────────────────────────────────┼─────────────────────────┼──────┼─────────────────────────────────────────────┤\n" +
    ([.[] |
      (.[0].severity | if . == "Critical" then "\u001b[31m\(.)\u001b[0m" elif . == "High" then "\u001b[33m\(.)\u001b[0m" elif . == "Medium" then "\u001b[34m\(.)\u001b[0m" else "\u001b[32m\(.)\u001b[0m" end) as $sev |
      (.[0].name | if length > 30 then .[:27] + "..." else . end) as $name |
      ("\(.[0].installed) → \(.[0].fixed // "?")" | if length > 22 then .[:19] + "..." else . end) as $path |
      (length | tostring) as $count |
      ([.[].id] | if length > 3 then [.[:3][], "...+\(length - 3)"] else . end | join(", ") | if length > 43 then .[:40] + "..." else . end) as $ghsas |
      "│ \($sev)\(" " * (8 - (.[0].severity | length))) │ \($name)\(" " * (31 - ($name | length))) │ \($path)\(" " * (23 - ($path | length))) │ \($count)\(" " * (4 - ($count | length))) │ \($ghsas)\(" " * (43 - ($ghsas | length))) │"
    ] | join("\n")) +
    "\n└──────────┴─────────────────────────────────┴─────────────────────────┴──────┴─────────────────────────────────────────────┘"
  '
}
# <<< vulnscan <<<
ALIASES

  print_success "Aliases added to ${SHELL_RC}"
}

# Print summary
print_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo -e "${GREEN}${BOLD}✔ Installation complete!${NC}"
  echo ""
  echo "  Reload your shell:"
  echo -e "    ${BOLD}source ${SHELL_RC}${NC}"
  echo ""
  echo "  Available commands:"
  echo -e "    ${BOLD}vulnscan${NC}         Scan deps, sorted by severity (only fixable)"
  echo -e "    ${BOLD}vulnscan-all${NC}     Scan deps, including unfixable"
  echo -e "    ${BOLD}vulnscan-summary${NC} Grouped table with colors"
  echo -e "    ${BOLD}vulnscan-json${NC}    Export results to JSON"
  echo -e "    ${BOLD}checkscan${NC}        Scan IaC, Dockerfiles, secrets (failures only)"
  echo ""
  echo "  Run from the root of any Maven project:"
  echo -e "    ${BOLD}cd your-project && vulnscan-summary${NC}"
  echo ""
}

# Main
main() {
  print_header
  detect_os
  detect_shell

  echo -e "  OS:    ${BOLD}${OS}${NC}"
  echo -e "  Shell: ${BOLD}${SHELL_NAME}${NC} (${SHELL_RC})"
  echo ""

  ensure_package_manager
  install_grype
  install_checkov
  install_jq
  check_maven
  check_java
  create_scripts
  install_shell_aliases
  print_summary
}

main "$@"
