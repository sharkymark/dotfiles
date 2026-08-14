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

# Some cask upgrades abort with "It seems there is already an App at
# '/opt/homebrew/Caskroom/<cask>/<old>/<App>.app'" when the previously staged
# app still sits in the Caskroom (e.g. whatsapp, which updates itself out of
# band). Homebrew won't clobber it, so the upgrade fails. Detect those casks
# from a captured log and force-reinstall them, which overwrites the stale app.
recover_clobbered_casks() {
  local log_file="$1"
  local stuck_casks
  stuck_casks=$(grep -oE "Error: [^:]+: It seems there is already an App at" "$log_file" 2>/dev/null \
    | sed -E "s/Error: ([^:]+): It seems there is already an App at/\\1/" | sort -u)
  [ -z "$stuck_casks" ] && return 1
  echo ""
  echo "🔧 Recovering casks blocked by a pre-existing staged app..."
  while IFS= read -r cask; do
    [ -z "$cask" ] && continue
    echo "   reinstalling $cask"
    brew reinstall --cask --force "$cask"
  done <<< "$stuck_casks"
  return 0
}

# Recent Homebrew refuses to load formulae/casks from third-party (non-
# homebrew/*) taps until they're explicitly trusted, emitting warnings like
# "Skipping <tap> because it is not trusted. Run `brew trust <tap>` to
# trust it." These are warnings, not errors, so brew bundle/upgrade still
# exit 0 while silently skipping those packages. Trust every currently-
# tapped third-party tap up front so nothing gets skipped.
trust_third_party_taps() {
  local tap
  brew tap 2>/dev/null | while IFS= read -r tap; do
    [ -z "$tap" ] && continue
    case "$tap" in
      homebrew/*) ;;
      *)
        if brew trust "$tap" >/dev/null 2>&1; then
          echo "   trusted $tap"
        else
          echo "   ⚠️  failed to trust $tap"
        fi
        ;;
    esac
  done
}

echo "🔐 Trusting third-party Homebrew taps..."
trust_third_party_taps
echo ""

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
    recover_drifted_casks "$bundle_log" && bundle_recovered=0
    recover_clobbered_casks "$bundle_log" && bundle_recovered=0
    if [ "$bundle_recovered" -eq 0 ]; then
      echo ""
      echo "🔁 Re-running brew bundle after recovery..."
      brew bundle --file="$DOTFILES_PATH/brew/Brewfile"
    fi
  fi
  rm -f "$bundle_log"
  echo ""
  echo "🔐 Re-checking third-party tap trust before upgrade..."
  trust_third_party_taps
  echo ""
  echo "⬆️  Upgrading outdated formulae..."
  brew upgrade --formula
  echo ""

  # Most Brewfile casks install into /Applications and Homebrew may need sudo
  # to touch that bundle (e.g. whatsapp, which macOS/Homebrew has left
  # root-owned before). Only auto-upgrade casks known to install as plain
  # binaries under $HOMEBREW_PREFIX, which never need sudo. Everything else
  # self-updates on its own or gets upgraded manually with
  # `brew upgrade --cask <name>` when you're ready to enter your password.
  SAFE_UPGRADE_CASKS=(codex claude-code)
  echo "⬆️  Upgrading sudo-free casks (${SAFE_UPGRADE_CASKS[*]})..."
  upgrade_log=$(mktemp)
  brew upgrade --cask "${SAFE_UPGRADE_CASKS[@]}" 2>&1 | tee "$upgrade_log"
  upgrade_recovered=1
  recover_drifted_casks "$upgrade_log" && upgrade_recovered=0
  recover_clobbered_casks "$upgrade_log" && upgrade_recovered=0
  if [ "$upgrade_recovered" -eq 0 ]; then
    echo ""
    echo "🔁 Re-running brew upgrade after recovery..."
    brew upgrade --cask "${SAFE_UPGRADE_CASKS[@]}"
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