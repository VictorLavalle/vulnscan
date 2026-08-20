# GitHub Action: Vulnerability Scan on PRs

Automatically scans dependencies for vulnerabilities on every Pull Request and posts results as a comment.

## Installation

Copy the workflow to your project:

```bash
cp integrations/github-action/vulnscan.yml .github/workflows/vulnscan.yml
```

That's it — no secrets or tokens needed (uses the default `GITHUB_TOKEN`).

## What it does

1. **Triggers** on PRs that modify dependency files (pom.xml, package-lock.json, go.sum, etc.)
2. **Auto-detects** project type
3. **Scans** for known vulnerabilities using Grype
4. **Posts a PR comment** with severity breakdown and full results
5. **Fails the check** if Critical or High severity vulnerabilities with fixes exist

## PR Comment Example

```
## 🛡️ Vulnerability Scan — Failed

| Severity | Count |
|----------|-------|
| 🔴 Critical | 4 |
| 🟡 High | 12 |
| 🔵 Medium | 8 |
| 🟢 Low | 3 |
| **Total** | **27** |

> ⚠️ **Action required:** Fix Critical/High vulnerabilities before merging.
```

The comment updates on each push (doesn't create duplicates).

## Configuration

### Change fail threshold

By default, the action fails on Critical or High. To only fail on Critical, edit the last step:

```yaml
- name: Fail if Critical vulnerabilities
  if: steps.scan.outputs.critical > 0
  run: exit 1
```

### Skip certain paths

Add exclusions to the `paths` trigger:

```yaml
on:
  pull_request:
    paths:
      - 'pom.xml'
    paths-ignore:
      - 'docs/**'
```

## Supported ecosystems

- Java/Kotlin (Maven, Gradle)
- Node.js (npm, yarn, pnpm)
- Python (pip, Pipenv, Poetry, uv)
- Go
- .NET (NuGet)
- Rust (Cargo)
