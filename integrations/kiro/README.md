# Kiro Skill: vulnscan

A Kiro CLI skill that scans your project for dependency vulnerabilities.

## Installation

Copy the skill to your project or global Kiro skills directory:

```bash
# Project-level (only this repo)
cp -r integrations/kiro/skills/vulnscan .kiro/skills/

# Global (all projects)
cp -r integrations/kiro/skills/vulnscan ~/.kiro/skills/
```

## Usage

In any Kiro chat session:

```
/vulnscan
```

Or with specific focus:

```
/vulnscan only critical and high severity
/vulnscan focus on spring dependencies
/vulnscan check if tomcat-embed-core is vulnerable
```

## What it does

1. Detects your project type (Maven, Gradle, Node.js, Python, Go, .NET, Rust)
2. Runs the appropriate vulnerability scan
3. Presents results grouped by severity
4. Suggests exact code changes to fix each vulnerability

## Requirements

- [Grype](https://github.com/anchore/grype) installed (`brew install grype`)
- For Maven/Gradle: `mvn` or `gradle` available
