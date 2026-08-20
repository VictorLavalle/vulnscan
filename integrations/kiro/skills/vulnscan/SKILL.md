---
name: vulnscan
description: Scan current project for dependency vulnerabilities, show results grouped by severity, and suggest fixes. Works with Maven, Gradle, Node.js, Python, Go, .NET, and Rust projects.
---

# Vulnerability Scan

Scan the current project for known dependency vulnerabilities (CVEs). Follow these steps:

## 1. Detect project type

Check which files exist in the current directory:
- `pom.xml` → Maven (Java/Kotlin)
- `build.gradle` or `build.gradle.kts` → Gradle (Java/Kotlin)
- `package-lock.json` or `yarn.lock` or `pnpm-lock.yaml` → Node.js
- `requirements.txt` or `Pipfile.lock` or `poetry.lock` or `uv.lock` → Python
- `go.sum` → Go
- `Cargo.lock` → Rust
- `packages.lock.json` or `*.csproj` → .NET

## 2. Generate SBOM and scan

For Maven:
```bash
mvn org.cyclonedx:cyclonedx-maven-plugin:makeBom -q && grype sbom:target/bom.json --sort-by severity --only-fixed -o json
```

For Gradle:
```bash
./gradlew cyclonedxBom -q && grype sbom:build/reports/bom.json --sort-by severity --only-fixed -o json
```

For Node.js, Python, Go, .NET, Rust:
```bash
grype dir:. --sort-by severity --only-fixed -o json
```

## 3. Present results

Parse the JSON output and present a summary:
- Total vulnerabilities found grouped by severity (Critical, High, Medium, Low)
- For each affected library: name, current version, fixed version, number of CVEs
- Sort by severity (Critical first)

## 4. Suggest fixes

For each vulnerability with a fix available:
- If it's a **direct dependency**: suggest updating the version in the project file
- If it's a **transitive dependency**: suggest adding a version override in dependency management
- Provide the exact code change needed

$ARGUMENTS
