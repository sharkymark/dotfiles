#!/bin/bash

echo "Setting up Homebrew package manager..."
echo ""

# Check if Homebrew is installed
if ! command -v brew &> /dev/null; then
  echo "📦 Homebrew not installed - installing now..."
  echo "   (This may take a few minutes)"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  echo "✅ Homebrew installed successfully!"
else
  echo "✅ Homebrew is already installed"
fi

echo ""

# Refresh Homebrew formulae and taps so brew bundle/upgrade below see the
# latest versions. Homebrew's auto-update is throttled (24h by default), so
# third-party tap formulae (e.g. nuonco/tap's `nuon`) can otherwise be stale.
echo "🔄 Refreshing Homebrew formulae and taps..."
brew update
echo ""

# Casks with `auto_updates true` (e.g. visual-studio-code) self-update behind
# Homebrew's back, leaving the Caskroom version stale. `brew bundle`/`brew
# upgrade` then bail out with "cask 'X' cannot be upgraded as-is" and fail the
# whole run. Detect those casks from a captured log and force-reinstall them.
recover_drifted_casks() {
  local log_file="$1"
  local stuck_casks
  stuck_casks=$(grep -oE "cask '[^']+' cannot be upgraded as-is" "$log_file" 2>/dev/null \
    | sed -E "s/cask '([^']+)' cannot be upgraded as-is/\\1/" | sort -u)
  [ -z "$stuck_casks" ] && return 1
  echo ""
  echo "🔧 Recovering casks stuck on auto-update drift..."
  while IFS= read -r cask; do
    echo "   reinstalling $cask"
    brew reinstall --cask --force "$cask"
  done <<< "$stuck_casks"
  return 0
}

# Recent Homebrew refuses to load formulae from third-party (non-official) taps
# until they're explicitly trusted, e.g. "Refusing to load formula X from
# untrusted tap T". A single untrusted tap aborts the whole `brew bundle` run,
# so later entries never install. Detect every tap Homebrew flagged in a
# captured log and trust it, generically, so any third-party tap works without
# hardcoding names.
trust_untrusted_taps() {
  local log_file="$1"
  local untrusted_taps
  untrusted_taps=$(grep -oE "untrusted tap [^ ]+" "$log_file" 2>/dev/null \
    | sed -E "s/untrusted tap //; s/[.]$//" | sort -u)
  [ -z "$untrusted_taps" ] && return 1
  echo ""
  echo "🔧 Trusting third-party taps flagged by Homebrew..."
  while IFS= read -r tap; do
    [ -z "$tap" ] && continue
    echo "   trusting $tap"
    brew trust --tap "$tap"
  done <<< "$untrusted_taps"
  return 0
}

# Install packages from Brewfile if it exists
if [ -f "$DOTFILES_PATH/brew/Brewfile" ]; then
  echo "📦 Installing development tools and applications from Brewfile..."
  echo "   (This may take several minutes on a fresh install)"
  echo ""
  bundle_log=$(mktemp)
  brew bundle --file="$DOTFILES_PATH/brew/Brewfile" 2>&1 | tee "$bundle_log"
  bundle_status=${PIPESTATUS[0]}
  if [ "$bundle_status" -ne 0 ]; then
    bundle_recovered=1
    trust_untrusted_taps "$bundle_log" && bundle_recovered=0
    recover_drifted_casks "$bundle_log" && bundle_recovered=0
    if [ "$bundle_recovered" -eq 0 ]; then
      echo ""
      echo "🔁 Re-running brew bundle after recovery..."
      brew bundle --file="$DOTFILES_PATH/brew/Brewfile"
    fi
  fi
  rm -f "$bundle_log"
  echo ""
  echo "⬆️  Upgrading outdated packages..."
  upgrade_log=$(mktemp)
  brew upgrade 2>&1 | tee "$upgrade_log"
  upgrade_recovered=1
  trust_untrusted_taps "$upgrade_log" && upgrade_recovered=0
  recover_drifted_casks "$upgrade_log" && upgrade_recovered=0
  if [ "$upgrade_recovered" -eq 0 ]; then
    echo ""
    echo "🔁 Re-running brew upgrade after recovery..."
    brew upgrade
  fi
  rm -f "$upgrade_log"
  echo ""
  echo "✅ All packages from Brewfile are now installed and up to date!"
  echo "   Run 'brew list' to see what's installed"
else
  echo "⚠️  Brewfile not found - skipping package installation"
fi

echo ""
echo "Homebrew setup complete!"