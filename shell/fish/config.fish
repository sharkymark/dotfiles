# 2024-12-25 python vitual env display

function fish_prompt
  if set -q VIRTUAL_ENV
    echo -n "( $(basename $VIRTUAL_ENV) ) "
  end
  echo -n (prompt_login)
end