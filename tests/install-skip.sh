#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir="$(mktemp -d)"
trap 'rm -rf "$fixture_dir"' EXIT
export TEST_CALLS="$fixture_dir/calls"
export HOME="$fixture_dir/home"
mkdir -p "$HOME/src" "$fixture_dir/bin" "$fixture_dir/dotfiles/brew" "$fixture_dir/repo-current"

# Exercise the actual parser and guarded sections without deploying any configs.
python3 - "$repo_root/install.sh" "$fixture_dir" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
fixture = Path(sys.argv[2])
parser = source[:source.index('# Local wall clock:')]
sections = []
for start, end in [
    ('if should_skip brew; then', 'print_step "💾 copying .gitignore_global"'),
    ('if should_skip nuon; then', 'if should_skip repo; then'),
    ('if should_skip repo; then', 'echo ""\necho "======================================"\necho "📝 Git User Configuration"'),
]:
    sections.append(source[source.index(start):source.index(end, source.index(start))])
helpers = '''
export DOTFILES_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OSTYPE=darwin
STEP_RESULTS=()
BREW_CHANGES=""
REPO_CURRENT_CHANGES=""
TOOL_UPDATES_CHANGES=""
record_step() { printf '%s: %s %s\\n' "$1" "$2" "${3:-}"; }
print_step() { :; }
progress_bar() { :; }
progress_clear_line() { :; }
append_tool_change() { :; }
report_upgrade() { :; }
'''
(fixture / 'dotfiles/install.sh').write_text(parser + helpers + '\n'.join(sections))
PY

cat > "$fixture_dir/bin/brew" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew %s\n' "$*" >> "$TEST_CALLS"
STUB
cat > "$fixture_dir/bin/nuon" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'nuon %s\n' "$*" >> "$TEST_CALLS"
printf '[]\n'
STUB
cat > "$fixture_dir/bin/gh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'gh %s\n' "$*" >> "$TEST_CALLS"
STUB
cat > "$fixture_dir/bin/git" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'git %s\n' "$*" >> "$TEST_CALLS"
# install.sh skips repo-current unless the checkout reports main.
if [[ " $* " == *" branch --show-current "* ]]; then
    printf 'main\n'
fi
STUB
cat > "$fixture_dir/dotfiles/brew/brew.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'brew-work\n' >> "$TEST_CALLS"
STUB
cat > "$fixture_dir/repo-current/git_pull_all.sh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf 'repo-work\n' >> "$TEST_CALLS"
printf 'Total repositories processed: 1\nTotal repositories with actual changes pulled: 0\nTotal repositories already up to date: 1\nTotal repositories with problems: 0\n'
STUB
printf '%s\n' "$HOME/src" > "$fixture_dir/repo-current/directories.txt"
chmod +x "$fixture_dir/bin/"* "$fixture_dir/repo-current/git_pull_all.sh"
export PATH="$fixture_dir/bin:$PATH"
driver="$fixture_dir/dotfiles/install.sh"

run_case() {
    : > "$TEST_CALLS"
    bash "$driver" "$@" > "$fixture_dir/output" 2>&1
}

assert_called() {
    if ! rg -q "$1" "$TEST_CALLS"; then
        printf 'Missing expected call: %s\n' "$1" >&2
        cat "$fixture_dir/output" >&2
        exit 1
    fi
}

assert_not_called() {
    if rg -q "$1" "$TEST_CALLS"; then
        printf 'Unexpected call: %s\n' "$1" >&2
        exit 1
    fi
}

run_case
assert_called '^brew-work$'
assert_called '^nuon extensions browse'
assert_called '^repo-work$'

for section in brew repo nuon; do
    run_case --skip "$section"
    rg -q -- "skipped --skip $section" "$fixture_dir/output"
    case "$section" in
        brew) assert_not_called '^brew'; assert_called '^repo-work$'; assert_called '^nuon' ;;
        repo) assert_not_called '^repo-work$|^git'; assert_called '^brew-work$'; assert_called '^nuon' ;;
        nuon) assert_not_called '^nuon|^gh'; assert_called '^brew-work$'; assert_called '^repo-work$' ;;
    esac
done

run_case --skip ' brew, repo ' --skip=nuon,brew
[ ! -s "$TEST_CALLS" ]
[ "$(rg -c 'skipped --skip' "$fixture_dir/output")" -eq 3 ]

run_case -n --no-show-repo-path --skip=brew,repo,nuon
[ ! -s "$TEST_CALLS" ]
run_case --dry-run --show-repo-path --skip brew,nuon
# Repo dry-run still probes `git branch --show-current`; brew/nuon must stay quiet.
assert_not_called '^brew|^nuon|^repo-work'
rg -q 'repo-current: dry-run' "$fixture_dir/output"

# Skipping repo also avoids clone/setup when repo-current is absent.
rm -rf "$fixture_dir/repo-current"
run_case --skip brew,repo,nuon
[ ! -s "$TEST_CALLS" ]
[ ! -e "$fixture_dir/repo-current" ]

for flag in --help -h; do
    run_case "$flag"
    rg -q '^Usage:' "$fixture_dir/output"
    [ ! -s "$TEST_CALLS" ]
done
for bad in '--skip=' '--skip=brew,' '--skip=,repo' '--skip=brew,,nuon' '--skip=unknown' '--ship' '--skip'; do
    : > "$TEST_CALLS"
    if bash "$driver" "$bad" > "$fixture_dir/output" 2>&1; then
        printf 'Expected argument failure: %s\n' "$bad" >&2
        exit 1
    else
        rc=$?
        [ "$rc" -eq 2 ]
    fi
    [ ! -s "$TEST_CALLS" ]
done
printf 'Installer skip tests passed.\n'
