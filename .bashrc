
# Kiro CLI pre block. Keep at the top of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bashrc.pre.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bashrc.pre.bash"

# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# Enable forward search
stty -ixon

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# some more ls aliases
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias g='git'

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi


# Custom setting below

# extend user binary path
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"

# enable direnv
eval "$(direnv hook bash)"

# enable pyenv
export PYENV_ROOT="$HOME/.pyenv"
[[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
eval "$(pyenv init - bash)"

# enable nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# export nvm relates for direnv
export NODE_VERSIONS="$HOME/.nvm/versions/node"
export NODE_VERSION_PREFIX="v"

# enable zoxide
eval "$(zoxide init bash)"


# Aliase below
alias bat='batcat'

# # cert
# export REQUESTS_CA_BUNDLE=~/corp_cert.cer
# export SSL_CERT_FILE=~/corp_cert.cer

eval "$(starship init bash)"

export NODE_OPTIONS="--max-old-space-size=2048"
export JAVA_OPTS="-Xmx2g -XX:+UseG1GC"

# pnpm
export PNPM_HOME="/home/djoo/.local/share/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

case ":$PATH:" in
    *:/home/djoo/.juliaup/bin:*)
        ;;

    *)
        export PATH=/home/djoo/.juliaup/bin${PATH:+:${PATH}}
        ;;
esac

# <<< juliaup initialize <<<

function sync_host() {
    local input_path=""
    # --path="경로" 인자 추출
    if [[ "$1" =~ ^--path=(.*)$ ]]; then
        input_path="${BASH_REMATCH[1]}"
    fi

    if [[ -z "$input_path" ]]; then
        echo "❌ 에러: --path 인자가 필요합니다. (예: --path=\"Workspace/law-ax\")"
        return 1
    fi

    # 경로 처리: 슬래시 방향 전환 및 윈도우 드라이브 결합
    local win_src="Z:\\${input_path//\//\\}"
    local wsl_win_path=$(wslpath -w $(pwd))

    echo "📡 로컬(경로: \$HOME/$input_path) -> WSL($wsl_win_path) 동기화 중..."

    powershell.exe -Command "robocopy '$win_src' '$wsl_win_path' /MIR /FFT /Z /XA:H /W:5 /R:5"
    echo "✅ 동기화 완료."
}

function watch_host() {
    local input_path=""
    # --path="경로" 인자 추출
    if [[ "$1" =~ ^--path=(.*)$ ]]; then
        input_path="${BASH_REMATCH[1]}"
    fi

    if [[ -z "$input_path" ]]; then
        echo "❌ 에러: --path 인자가 필요합니다."
        return 1
    fi

    # disabled, 260304 10:00
    # 감시 시작 전 전체 동기화를 1회 먼저 수행합니다.
    # 인자($1)를 그대로 넘겨주어 경로 정보를 유지합니다.
    # sync_host "$1"

    # 변수 설정
    local win_src_raw="Z:\\${input_path//\//\\}"
    local linux_display="\$HOME/${input_path%/}"
    local wsl_win_path=$(wslpath -w $(pwd))

    echo -e "\n👀 감시 모드 시작 (경로: $linux_display)"
    echo "정지하려면 Ctrl + C를 누르세요."

    while true; do
        # PowerShell 내부에서 빈 줄을 필터링하고 실제 변경된 파일만 가져옵니다.
        local raw_output=$(powershell.exe -Command "
            \$out = robocopy '$win_src_raw' '$wsl_win_path' /MIR /FFT /Z /XA:H /W:2 /R:2 /XD .git .venv __pycache__ .next /NC /NS /NDL /NJH /NJS /NP | Where-Object { \$_.Trim() -ne '' }
            if (\$out) { \$out.Trim() }
        " 2>/dev/null)

        if [ -n "$raw_output" ]; then
            echo "$raw_output" | while read -r line; do
                if [ -n "$line" ]; then
                    # 경로 정규화 (백슬래시 -> 슬래시, Z: -> $HOME)
                    local normalized_line=$(echo "$line" | tr '\\' '/')
                    local final_path=$(echo "$normalized_line" | sed "s|.*${input_path}|$linux_display|g")
                    echo -e "[$(date +%H:%M:%S)] 🚀 변경 감지: $final_path"
                fi
            done
        fi
        sleep 3
    done
}

export EDITOR="vim"

# Enhance history
# 1. 히스토리 파일에 즉시 기록 (Append)
shopt -s histappend

# 2. 매 프롬프트가 뜰 때마다 히스토리를 저장하고 다시 읽기 <- 주석처리함, 여러 세션에 history 공유하는 기능 opt out <- 되살림
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# 3. (옵션) 히스토리 용량 늘리기 (기본값은 너무 작음)
export HISTSIZE=10000
export HISTFILESIZE=20000

# 4. (옵션) 중복되거나 공백으로 시작하는 명령어 무시
export HISTCONTROL=ignoreboth

# awsp 등록
source ~/awsp_functions.sh

alias awsall="_awsListProfile"
alias awsp="_awsSetProfile"
alias awswho="aws configure list"

complete -W "$(cat $HOME/.aws/credentials | grep -Eo '\[.*\]' | tr -d '[]')" _awsSwitchProfile
complete -W "$(cat $HOME/.aws/config | grep -Eo '\[.*\]' | tr -d '[]' | cut -d " " -f 2)" _awsSetProfile

#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"


# WSLg clipboard fix
alias wl-copy='env XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir wl-copy'
alias wl-paste='env XDG_RUNTIME_DIR=/mnt/wslg/runtime-dir wl-paste'


# Kiro CLI post block. Keep at the bottom of this file.
[[ -f "${HOME}/.local/share/kiro-cli/shell/bashrc.post.bash" ]] && builtin source "${HOME}/.local/share/kiro-cli/shell/bashrc.post.bash"
