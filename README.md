# 🛡️ vulnscan

[![CI](https://github.com/VictorLavalle/vulnscan/actions/workflows/ci.yml/badge.svg)](https://github.com/VictorLavalle/vulnscan/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/github/v/tag/VictorLavalle/vulnscan?label=version)](https://github.com/VictorLavalle/vulnscan/releases)

Local dependency vulnerability scanning for **any project**. No API keys. No cloud credentials. Just results.

Supports: **Java/Kotlin** (Maven, Gradle) · **Node.js** (npm, yarn, pnpm) · **Python** (pip, Pipenv, Poetry, uv) · **Go** · **.NET** (NuGet) · **Rust** (Cargo)

<img width="882" height="356" alt="image" src="https://github.com/user-attachments/assets/cac178f8-c107-49fe-a950-259eeb4dbcce" />


## Why?

Cloud security tools (Prisma Cloud, Snyk, etc.) catch vulnerabilities **after deployment**. By then, it's too late — you have extra work fixing and redeploying.

`vulnscan` lets you scan **before you push**, catching the same CVEs locally in ~5 seconds.

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/VictorLavalle/Vulns-Scan/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/VictorLavalle/Vulns-Scan.git
cd Vulns-Scan
./install.sh
```

## What it installs

| Tool | Purpose | Size |
|------|---------|------|
| [Grype](https://github.com/anchore/grype) | Scans dependencies for known CVEs | ~50MB |
| [CycloneDX Maven Plugin](https://github.com/CycloneDX/cyclonedx-maven-plugin) | Generates SBOM from `pom.xml` (runs via Maven, no install) | — |
| [Checkov](https://github.com/bridgecrewio/checkov) | Scans IaC, Dockerfiles, secrets, GitHub Actions | ~100MB |
| [jq](https://github.com/jqlang/jq) | JSON processing for formatted output | ~1MB |

## Commands

After installation, these commands are available in any Maven project:

| Command | Description |
|---------|-------------|
| `vulnscan` | Scan dependencies, sorted by severity (only shows fixable vulns) |
| `vulnscan-all` | Same but includes vulnerabilities without a known fix |
| `vulnscan-summary` | Grouped table view with colors and GHSA references |
| `vulnscan-json` | Export full results to `target/vuln-report.json` |
| `vulnscan-update` | Update the vulnerability database |
| `checkscan` | Scan IaC, Dockerfiles, secrets, GitHub Actions (failures only) |

## Usage

```bash
cd your-project
vulnscan-summary
```

The tool **auto-detects** your project type:

| Ecosystem | Detected by | Method |
|-----------|------------|--------|
| Java/Kotlin (Maven) | `pom.xml` | SBOM via CycloneDX plugin |
| Java/Kotlin (Gradle) | `build.gradle` / `build.gradle.kts` | SBOM via CycloneDX plugin (injected, no build file changes) |
| Node.js | `package-lock.json` / `yarn.lock` / `pnpm-lock.yaml` | Direct lockfile scan |
| Python | `requirements.txt` / `Pipfile.lock` / `poetry.lock` / `uv.lock` | Direct lockfile scan |
| Go | `go.sum` | Direct lockfile scan |
| .NET | `packages.lock.json` / `*.csproj` | Direct lockfile scan |
| Rust | `Cargo.lock` | Direct lockfile scan |

### Example output

```
🛡️  114 vulnerabilities in 31 libraries
┌──────────┬─────────────────────────────────┬─────────────────────────┬──────┬─────────────────────────────────────────────┐
│ Severity │ Library                         │ Upgrade Path            │ CVEs │ GHSAs                                       │
├──────────┼─────────────────────────────────┼─────────────────────────┼──────┼─────────────────────────────────────────────┤
│ Critical │ bcprov-jdk18on                  │ 1.80 → 1.80.2           │ 2    │ GHSA-574f-3g2m-x479, GHSA-c3fc-8qff-9hwx   │
│ Critical │ spring-cloud-config-server      │ 4.3.0 → 4.3.3           │ 5    │ GHSA-6g23-24mc-hx6x, GHSA-3qwq-q9vm-5j42...│
│ Critical │ tomcat-embed-core               │ 11.0.15 → 11.0.22       │ 13   │ GHSA-r29c-68gh-xp6x, GHSA-h6fc-48rj-7qqh...│
│ High     │ httpcore5                       │ 5.3.6 → 5.4.3           │ 1    │ GHSA-hf6x-8p5f-cgmf                        │
│ High     │ jackson-databind                │ 2.19.4 → 2.21.4         │ 5    │ GHSA-j3rv-43j4-c7qm, GHSA-rmj7-2vxq-3g9f...│
│ Medium   │ httpclient5                     │ 5.5.1 → 5.6.3           │ 1    │ GHSA-hjcp-jmpx-g3qm                        │
│ Low      │ logback-core                    │ 1.5.23 → 1.5.34         │ 3    │ GHSA-jhq6-gfmj-v8fx, GHSA-p47f-322f-whfh...│
└──────────┴─────────────────────────────────┴─────────────────────────┴──────┴─────────────────────────────────────────────┘
```

## How to fix vulnerabilities

The `Upgrade Path` column in the scan results shows the version to upgrade to. How you apply the fix depends on your ecosystem:

| Ecosystem | How to fix |
|-----------|-----------|
| Maven | Update version in `pom.xml` or add `<dependencyManagement>` override |
| Gradle | Update version in `build.gradle` or add `constraints` block |
| Node.js | `npm update <package>` or edit `package.json` |
| Python | `pip install --upgrade <package>` or edit `requirements.txt` |
| Go | `go get <package>@latest` |
| .NET | `dotnet add package <package> --version <version>` |
| Rust | `cargo update -p <package>` |

After fixing, re-run `vulnscan` to verify the vulnerability is gone.

## Suppressing False Positives

Copy the template to your project to ignore accepted risks:

```bash
cp /path/to/vulnscan/.grype.yaml.template .grype.yaml
```

Then uncomment and customize the rules. Grype picks up `.grype.yaml` automatically. See [`.grype.yaml.template`](.grype.yaml.template) for examples.

## Comparison with cloud scanners

| Feature | vulnscan (local) | Prisma Cloud / Snyk |
|---------|-----------------|---------------------|
| **When** | Before push (~5s) | After deploy (minutes) |
| **API key** | ❌ Not needed | ✅ Required |
| **Languages** | Java, Kotlin, Node.js, Python, Go, .NET, Rust | All |
| **OS-level vulns** | ❌ | ✅ |
| **Custom policies** | ❌ | ✅ |
| **Cost** | Free | Paid |

> **Best practice:** Use `vulnscan` locally to catch Java dependency CVEs before pushing. Let cloud scanners handle OS-level vulnerabilities in base images.

## AI Agent Integrations

vulnscan integrates with AI coding assistants for automated security workflows:

| Integration | Use Case | Location |
|-------------|----------|----------|
| [**Kiro Skill**](integrations/kiro/skills/vulnscan/SKILL.md) | `/vulnscan` slash command in Kiro CLI | `integrations/kiro/skills/` |
| [**Kiro Hook**](integrations/kiro/hooks/README.md) | Blocks `git push` on Critical/High vulns | `integrations/kiro/hooks/` |
| [**GitHub Action**](integrations/github-action/README.md) | PR scanner with comment & check | `integrations/github-action/` |
| [**MCP Server**](integrations/mcp-server/README.md) | Tool for Claude, Codex, Cursor, any MCP client | `integrations/mcp-server/` |

### Quick setup examples

**Kiro Skill** — scan on demand:
```bash
cp -r integrations/kiro/skills/vulnscan ~/.kiro/skills/
# Then in Kiro: /vulnscan
```

**Kiro Hook** — block push with vulns:
```bash
cp integrations/kiro/hooks/vulnscan-gate.sh ~/.kiro/hooks/
chmod +x ~/.kiro/hooks/vulnscan-gate.sh
# Add to .kiro/agents/your-agent.json (see integrations/kiro/hooks/README.md)
```

**GitHub Action** — PR scanner:
```bash
cp integrations/github-action/vulnscan.yml .github/workflows/
# Done — triggers on PRs that modify dependency files
```

**MCP Server** — AI agent tool:
```bash
cp integrations/mcp-server/vulnscan-mcp-server.sh ~/.local/bin/
chmod +x ~/.local/bin/vulnscan-mcp-server
# Add to your MCP config (see integrations/mcp-server/README.md)
```

## Requirements

- macOS or Linux
- Homebrew (macOS) or curl (Linux)
- For Java/Kotlin: Java 11+ and Maven 3.x or Gradle 7+
- For other ecosystems: just the lockfile (no build tools needed for scanning)

## Uninstall

```bash
# Remove aliases from your shell config
sed -i.bak '/>>> vulnscan >>>/,/<<< vulnscan <<</d' ~/.zshrc

# Remove tools (optional)
brew uninstall grype
pipx uninstall checkov

# Remove vulnscan directory
rm -rf ~/.vulnscan
```

## Contributing

PRs welcome! Ideas for future support:
- PHP (Composer)
- Ruby (Bundler)
- Swift (Package.resolved)
- Dart/Flutter (pubspec.lock)

Open an issue or submit a PR.

## License

MIT
