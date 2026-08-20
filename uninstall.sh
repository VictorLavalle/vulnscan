#!/usr/bin/env bash
set -euo pipefail

echo "🗑️  Uninstalling vulnscan..."

# Detect shell config
SHELL_RC=""
if [[ "$SHELL" == */zsh ]] && [[ -f "${HOME}/.zshrc" ]]; then
  SHELL_RC="${HOME}/.zshrc"
elif [[ "$SHELL" == */bash ]]; then
  if [[ -f "${HOME}/.bash_profile" ]] && grep -q "vulnscan" "${HOME}/.bash_profile" 2>/dev/null; then
    SHELL_RC="${HOME}/.bash_profile"
  elif [[ -f "${HOME}/.bashrc" ]]; then
    SHELL_RC="${HOME}/.bashrc"
  fi
elif [[ "$SHELL" == */fish ]] && [[ -f "${HOME}/.config/fish/config.fish" ]]; then
  SHELL_RC="${HOME}/.config/fish/config.fish"
elif [[ -f "${HOME}/.profile" ]]; then
  SHELL_RC="${HOME}/.profile"
fi

# Fallback: find which file has vulnscan
if [[ -z "$SHELL_RC" ]]; then
  for rc in "${HOME}/.zshrc" "${HOME}/.bashrc" "${HOME}/.bash_profile" "${HOME}/.config/fish/config.fish" "${HOME}/.profile"; do
    if grep -q ">>> vulnscan >>>" "$rc" 2>/dev/null; then
      SHELL_RC="$rc"
      break
    fi
  done
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
