# 🛡️ vulnscan

Local dependency vulnerability scanning for Maven projects. No API keys. No cloud credentials. Just results.

![vulnscan-summary output](docs/vulnscan-summary.png)

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
| `checkscan` | Scan IaC, Dockerfiles, secrets, GitHub Actions (failures only) |

## Usage

```bash
cd your-maven-project
vulnscan-summary
```

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

When `vulnscan` reports a vulnerable dependency:

1. **Direct dependency** → Update the version in your `pom.xml`
2. **Transitive dependency** → Add a version override in `<dependencyManagement>`

```xml
<properties>
    <httpcore5.version>5.4.3</httpcore5.version>
</properties>

<dependencyManagement>
    <dependencies>
        <dependency>
            <groupId>org.apache.httpcomponents.core5</groupId>
            <artifactId>httpcore5</artifactId>
            <version>${httpcore5.version}</version>
        </dependency>
    </dependencies>
</dependencyManagement>
```

3. Re-run `vulnscan` to verify the fix
4. Commit and push ✅

## Comparison with cloud scanners

| Feature | vulnscan (local) | Prisma Cloud / Snyk |
|---------|-----------------|---------------------|
| **When** | Before push (~5s) | After deploy (minutes) |
| **API key** | ❌ Not needed | ✅ Required |
| **Java deps** | ✅ | ✅ |
| **OS-level vulns** | ❌ | ✅ |
| **Custom policies** | ❌ | ✅ |
| **Cost** | Free | Paid |

> **Best practice:** Use `vulnscan` locally to catch Java dependency CVEs before pushing. Let cloud scanners handle OS-level vulnerabilities in base images.

## Requirements

- macOS or Linux
- Java 11+ and Maven 3.x
- Homebrew (macOS) or curl (Linux)

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

PRs welcome! If you'd like to add support for:
- Gradle projects
- Node.js / npm / yarn
- Python / pip
- Go modules
- .NET / NuGet

Open an issue or submit a PR.

## License

MIT
