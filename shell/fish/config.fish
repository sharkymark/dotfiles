# 2024-12-25 python vitual env display

function fish_prompt
    set -l last_status $status

    # Default color (green)
    set_color green

    # Print username@machinename
    echo -n (whoami)'@'(hostname | cut -d . -f 1)

    # Check if we are in a virtual environment
    if set -q VIRTUAL_ENV
        echo -n " ("(basename "$VIRTUAL_ENV")")"
    end

    # Print the shortened directory path
    echo -n ' '(prompt_pwd)

    # Check for git branch
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l branch (git symbolic-ref --short HEAD 2>/dev/null; or git rev-parse --short HEAD 2>/dev/null)
        if test -n "$branch"
            echo -n " ($branch)"
        end
    end

    # Reset color if needed
    set_color normal

    # Add a new line and the standard prompt symbol
    echo -e '\n> '
end