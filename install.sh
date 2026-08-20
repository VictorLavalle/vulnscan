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

VERSION="1.1.0"
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
    # macOS uses .bash_profile for login shells, Linux uses .bashrc
    if [[ "$OS" == "macos" ]] && [[ -f "${HOME}/.bash_profile" ]]; then
      SHELL_RC="${HOME}/.bash_profile"
    elif [[ -f "${HOME}/.bashrc" ]]; then
      SHELL_RC="${HOME}/.bashrc"
    else
      SHELL_RC="${HOME}/.bash_profile"
    fi
    SHELL_NAME="bash"
  elif [[ "$SHELL" == */fish ]]; then
    SHELL_RC="${HOME}/.config/fish/config.fish"
    SHELL_NAME="fish"
  else
    SHELL_RC="${HOME}/.profile"
    SHELL_NAME="sh"
  fi

  # Ensure the file exists
  mkdir -p "$(dirname "$SHELL_RC")"
  touch "$SHELL_RC"
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
echo "📦 Detecting project type..."
if [[ -f "pom.xml" ]]; then
  echo "   Maven project detected"
  mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null
  TARGET="sbom:target/bom.json"
elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
  echo "   Gradle project detected"
  ./gradlew cyclonedxBom -q 2>/dev/null || gradle cyclonedxBom --init-script <(cat <<'INIT'
initscript {
    repositories { mavenCentral() }
    dependencies { classpath 'org.cyclonedx:cyclonedx-gradle-plugin:2.2.1' }
}
allprojects { apply plugin: org.cyclonedx.gradle.CycloneDxPlugin }
INIT
  ) -q
  TARGET="sbom:build/reports/bom.json"
elif [[ -f "package-lock.json" || -f "yarn.lock" || -f "pnpm-lock.yaml" ]]; then
  echo "   Node.js project detected"
  TARGET="dir:."
elif [[ -f "requirements.txt" || -f "Pipfile.lock" || -f "poetry.lock" || -f "uv.lock" ]]; then
  echo "   Python project detected"
  TARGET="dir:."
elif [[ -f "go.sum" ]]; then
  echo "   Go project detected"
  TARGET="dir:."
elif [[ -f "packages.lock.json" ]] || ls *.csproj &>/dev/null; then
  echo "   .NET project detected"
  TARGET="dir:."
elif [[ -f "Cargo.lock" ]]; then
  echo "   Rust project detected"
  TARGET="dir:."
else
  echo "ERROR: No supported project detected" >&2
  echo "Supported: Maven, Gradle, Node.js, Python, Go, .NET, Rust" >&2
  exit 1
fi

echo ""
echo "🔍 Scanning for vulnerabilities..."
echo ""

GRYPE_OUTPUT=$(grype "$TARGET" --sort-by severity -o json 2>/dev/null)

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

  # Gradle init script for CycloneDX SBOM generation
  cat > "${VULNSCAN_DIR}/cyclonedx-init.gradle" << 'GRADLE'
initscript {
    repositories { mavenCentral() }
    dependencies { classpath 'org.cyclonedx:cyclonedx-gradle-plugin:2.2.1' }
}
allprojects { apply plugin: org.cyclonedx.gradle.CycloneDxPlugin }
GRADLE

  print_success "Scripts created"
}

# Add shell aliases
install_shell_aliases() {
  local marker="# >>> vulnscan >>>"

  # If already installed, remove old version and reinstall (auto-update)
  if grep -q "$marker" "$SHELL_RC" 2>/dev/null; then
    print_step "Updating existing vulnscan aliases in ${SHELL_RC}..."
    sed -i.bak '/# >>> vulnscan >>>/,/# <<< vulnscan <<</d' "$SHELL_RC"
    rm -f "${SHELL_RC}.bak"
  fi

  print_step "Adding aliases to ${SHELL_RC}..."

  # Fish shell uses different syntax
  if [[ "$SHELL_NAME" == "fish" ]]; then
    cat >> "$SHELL_RC" << 'FISH_ALIASES'

# >>> vulnscan >>>
# Local vulnerability scanning (no API keys needed)
# https://github.com/VictorLavalle/Vulns-Scan

function _vulnscan_detect
    if test -f "pom.xml"
        echo "maven"
    else if test -f "build.gradle" -o -f "build.gradle.kts"
        echo "gradle"
    else if test -f "package-lock.json" -o -f "yarn.lock" -o -f "pnpm-lock.yaml"
        echo "node"
    else if test -f "requirements.txt" -o -f "Pipfile.lock" -o -f "poetry.lock" -o -f "uv.lock"
        echo "python"
    else if test -f "go.sum"
        echo "go"
    else if test -f "packages.lock.json"
        echo "dotnet"
    else if test -f "Cargo.lock"
        echo "rust"
    else
        echo "unknown"
    end
end

function _vulnscan_run
    set -l project_type (_vulnscan_detect)
    switch $project_type
        case maven
            echo "▶ Detected: Maven (pom.xml)" >&2
            mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null
            echo "sbom:target/bom.json"
        case gradle
            echo "▶ Detected: Gradle (build.gradle)" >&2
            if test -f "./gradlew"
                ./gradlew cyclonedxBom -q 2>/dev/null
            else if test -f "$HOME/.vulnscan/cyclonedx-init.gradle"
                gradle cyclonedxBom --init-script "$HOME/.vulnscan/cyclonedx-init.gradle" -q
            end
            echo "sbom:build/reports/bom.json"
        case node
            echo "▶ Detected: Node.js" >&2
            echo "dir:."
        case python
            echo "▶ Detected: Python" >&2
            echo "dir:."
        case go
            echo "▶ Detected: Go" >&2
            echo "dir:."
        case dotnet
            echo "▶ Detected: .NET" >&2
            echo "dir:."
        case rust
            echo "▶ Detected: Rust" >&2
            echo "dir:."
        case '*'
            echo "✖ No supported project detected." >&2
            echo "  Supported: Maven, Gradle, Node.js, Python, Go, .NET, Rust" >&2
            return 1
    end
end

function vulnscan
    set -l target (_vulnscan_run); or return 1
    grype "$target" --sort-by severity --only-fixed
end

function vulnscan-all
    set -l target (_vulnscan_run); or return 1
    grype "$target" --sort-by severity
end

function vulnscan-json
    set -l target (_vulnscan_run); or return 1
    grype "$target" -o json > vuln-report.json
    echo "Report: vuln-report.json"
end

alias checkscan="checkov -d . --compact --quiet"
alias vulnscan-update="grype db update; and echo '✅ Vulnerability database updated'"
# <<< vulnscan <<<
FISH_ALIASES
    print_success "Fish aliases added to ${SHELL_RC}"
    return
  fi

  # Bash/Zsh/sh aliases
  cat >> "$SHELL_RC" << 'ALIASES'

# >>> vulnscan >>>
# Local vulnerability scanning (no API keys needed)
# https://github.com/VictorLavalle/Vulns-Scan

# Auto-detect project type and scan
_vulnscan_detect() {
  # Java/Kotlin - Maven
  if [[ -f "pom.xml" ]]; then
    echo "maven"
  # Java/Kotlin - Gradle
  elif [[ -f "build.gradle" || -f "build.gradle.kts" ]]; then
    echo "gradle"
  # Node.js
  elif [[ -f "package-lock.json" || -f "yarn.lock" || -f "pnpm-lock.yaml" ]]; then
    echo "node"
  # Python
  elif [[ -f "requirements.txt" || -f "Pipfile.lock" || -f "poetry.lock" || -f "uv.lock" ]]; then
    echo "python"
  # Go
  elif [[ -f "go.sum" ]]; then
    echo "go"
  # .NET
  elif [[ -f "packages.lock.json" ]] || ls *.csproj &>/dev/null; then
    echo "dotnet"
  # Rust
  elif [[ -f "Cargo.lock" ]]; then
    echo "rust"
  else
    echo "unknown"
  fi
}

_vulnscan_run() {
  local mode="${1:-dir}"  # "sbom" for Maven/Gradle, "dir" for everything else
  local project_type
  project_type=$(_vulnscan_detect)

  case "$project_type" in
    maven)
      echo -e "\033[34m▶\033[0m Detected: Maven (pom.xml)" >&2
      mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q 2>/dev/null
      echo "sbom:target/bom.json"
      ;;
    gradle)
      echo -e "\033[34m▶\033[0m Detected: Gradle (build.gradle)" >&2
      if [[ -f "./gradlew" ]]; then
        ./gradlew cyclonedxBom -q 2>/dev/null
      elif [[ -f "${HOME}/.vulnscan/cyclonedx-init.gradle" ]]; then
        gradle cyclonedxBom --init-script "${HOME}/.vulnscan/cyclonedx-init.gradle" -q
      else
        gradle cyclonedxBom --init-script <(cat <<'INIT'
initscript {
    repositories { mavenCentral() }
    dependencies { classpath 'org.cyclonedx:cyclonedx-gradle-plugin:2.2.1' }
}
allprojects { apply plugin: org.cyclonedx.gradle.CycloneDxPlugin }
INIT
      ) -q
      fi
      echo "sbom:build/reports/bom.json"
      ;;
    node)
      echo -e "\033[34m▶\033[0m Detected: Node.js" >&2
      echo "dir:."
      ;;
    python)
      echo -e "\033[34m▶\033[0m Detected: Python" >&2
      echo "dir:."
      ;;
    go)
      echo -e "\033[34m▶\033[0m Detected: Go" >&2
      echo "dir:."
      ;;
    dotnet)
      echo -e "\033[34m▶\033[0m Detected: .NET" >&2
      echo "dir:."
      ;;
    rust)
      echo -e "\033[34m▶\033[0m Detected: Rust" >&2
      echo "dir:."
      ;;
    *)
      echo -e "\033[31m✖\033[0m No supported project detected in current directory." >&2
      echo "  Supported: Maven, Gradle, Node.js, Python, Go, .NET, Rust" >&2
      return 1
      ;;
  esac
}

vulnscan() {
  local target
  target=$(_vulnscan_run) || return 1
  grype "$target" --sort-by severity --only-fixed
}

vulnscan-all() {
  local target
  target=$(_vulnscan_run) || return 1
  grype "$target" --sort-by severity
}

vulnscan-json() {
  local target
  target=$(_vulnscan_run) || return 1
  local output="vuln-report.json"
  grype "$target" -o json > "$output"
  echo "Report: $output"
}

alias checkscan="checkov -d . --compact --quiet"
alias vulnscan-update="grype db update && echo '✅ Vulnerability database updated'"

vulnscan-summary() {
  local target
  target=$(_vulnscan_run) || return 1
  echo ""
  grype "$target" --sort-by severity -o json 2>/dev/null | \
  jq -r '
    [.matches[] | {
      name: .artifact.name,
      installed: .artifact.version,
      fixed: .vulnerability.fix.versions[0],
      severity: .vulnerability.severity,
      id: .vulnerability.id
    }] |
    if length == 0 then "🎉 No vulnerabilities found!" else
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
    end
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
  echo "  Run from the root of any project:"
  echo -e "    ${BOLD}cd your-project && vulnscan-summary${NC}"
  echo ""
  echo "  Supported: Maven, Gradle, Node.js, Python, Go, .NET, Rust"
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
