# Ghostty loads this from ~/.zshenv before shell integration runs.
# Keeps a blinking block cursor instead of Ghostty's bar-at-prompt default.
if [[ -n $GHOSTTY_SHELL_FEATURES ]]; then
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES//cursor:blink/}"
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES//cursor:steady/}"
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES//cursor/}"
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES//,,/,}"
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES#,}"
  export GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES%,}"
fi
