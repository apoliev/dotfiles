function git_dirty_mark() {
  if [ -n "$(git status -s)" ]; then
    echo " *"
  else
    echo ""
  fi
}

function git_prompt() {
  if [ -n "$(git branch 2>/dev/null)" ]; then
    echo "%{$fg[yellow]%}‹$(git branch --show-current)$(git_dirty_mark)›%{$reset_color%}"
  else
    echo ""
  fi
}

function mise_version_of() {
  if [[ "${plugins[@]}" =~ 'mise' ]]; then
    echo "$(mise current $1 -q)"
  else
    echo ""
  fi
}

function mise_prompt() {
  if [ -n "$(mise_version_of $1)" ] && [ -z "$(mise ls $1 -g --no-header)" ]; then
    echo "%{$fg[$2]%}‹$1-$(mise_version_of $1)›%{$reset_color%}"
  else
    echo ""
  fi
}

function environments() {
  arr=(
    "$(git_prompt)"
    "$(mise_prompt ruby red)"
    "$(mise_prompt node green)"
    "$(mise_prompt python blue)"
  )
  result=""

  for item in "${arr[@]}"; do
    if [ -n "$item" ]; then
      result+=" $item"
    fi
  done

  echo $result
}

if [ -z "$SSH_CLIENT" ]; then
  local ssh_mark=''
else
  local ssh_mark=" via ssh"
fi

if [[ $UID -eq 0 ]]; then
    local user_host='%{$terminfo[bold]$fg[red]%}%n$ssh_mark %{$reset_color%}'
    local user_symbol='#'
else
    local user_host='%{$terminfo[bold]$fg[green]%}%n$ssh_mark %{$reset_color%}'
    local user_symbol='$'
fi

local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"
local current_dir='%{$terminfo[bold]$fg[blue]%}%~%{$reset_color%}'
local envs='$(environments)'

PROMPT="${user_host}${current_dir}${envs} %B${user_symbol}%b "
RPROMPT="%B${return_code}%b"
