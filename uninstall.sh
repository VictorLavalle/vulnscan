#!/usr/bin/env bash
set -euo pipefail

echo "🗑️  Uninstalling vulnscan..."

# Detect shell config
if [[ -f "${HOME}/.zshrc" ]]; then
  SHELL_RC="${HOME}/.zshrc"
elif [[ -f "${HOME}/.bashrc" ]]; then
  SHELL_RC="${HOME}/.bashrc"
else
  SHELL_RC="${HOME}/.profile"
fi

# Remove aliases from shell config
if grep -q ">>> vulnscan >>>" "$SHELL_RC" 2>/dev/null; then
  sed -i.bak '/# >>> vulnscan >>>/,/# <<< vulnscan <<</d' "$SHELL_RC"
  echo "✔ Removed aliases from ${SHELL_RC}"
else
  echo "⚠ No vulnscan aliases found in ${SHELL_RC}"
fi

# Remove vulnscan directory
if [[ -d "${HOME}/.vulnscan" ]]; then
  rm -rf "${HOME}/.vulnscan"
  echo "✔ Removed ~/.vulnscan directory"
fi

echo ""
echo "✔ vulnscan uninstalled."
echo "  Tools (grype, checkov, jq) were NOT removed."
echo "  To remove them: brew uninstall grype && pipx uninstall checkov"
echo ""
echo "  Reload your shell: source ${SHELL_RC}"
