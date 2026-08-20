# Gradle Init Script

Generates a CycloneDX SBOM from any Gradle project **without modifying** `build.gradle`.

## Usage

```bash
gradle cyclonedxBom --init-script /path/to/cyclonedx-init.gradle
```

Output: `build/reports/bom.json`

## How vulnscan uses it

The `vulnscan` commands automatically use this init script when:
1. `./gradlew cyclonedxBom` is not available (project doesn't have the plugin)
2. The init script exists at `~/.vulnscan/cyclonedx-init.gradle` (installed by `install.sh`)
3. Falls back to inline heredoc if neither is available

## Manual installation

```bash
cp integrations/gradle/cyclonedx-init.gradle ~/.vulnscan/
```
