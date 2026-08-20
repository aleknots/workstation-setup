# Extras & Utility Reference

## Sudo Configuration & System Clean

Applies to both Ubuntu Desktop and WSL2:

- Configure passwordless `sudo` for administrative user group:

```text
%sudo ALL=(ALL:ALL) NOPASSWD:ALL
```

- Update `locate` database:

```bash
updatedb
```

- Clean unneeded package artifacts:

```bash
apt autoclean
apt autoremove
```

## Recommended `.zshrc` Configuration

```bash
plugins=(
  git
  docker
  docker-compose
  terraform
  fzf
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-completions
  command-not-found
)

# Navigation Aliases
alias ..='cd ..'
alias ...='cd ../..'
alias l='ls -CF'
alias ls='ls -lh --color=auto'
alias la='ls -lah --color=auto'
alias cls='clear'
alias c='clear'
alias mkdir='mkdir -pv'
alias cp='cp -iv'
alias mv='mv -iv'

# System Aliases
alias df='df -h'
alias du='du -sh * | sort -h'
alias myip='curl -s ifconfig.me && echo'
alias ports='ss -tulpen'
alias ping='ping -c 5'
alias h='history'
alias j='jobs -l'

# Apt/Snap Aliases
alias apt-update='sudo apt update -y'
alias apt-upgrade='sudo apt upgrade -y'
alias apt-remove='sudo apt autoremove -y'
alias apt-search='apt search'
alias apt-install='sudo apt install -y'
alias snap-install='sudo snap install'
alias snap-remove='sudo snap remove'
alias snap-refresh='sudo snap refresh'

# Git Aliases
alias g='git'
alias gst='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gcb='git checkout -b'

# Docker Aliases
alias up='docker compose up -d'
alias down='docker compose down'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias drm='docker rm'
alias drmi='docker rmi'
alias dlogs='docker logs -f'
alias dexec='docker exec -it'
alias dbuild='docker build -t'

dbash() { docker exec -it "$1" /bin/bash; }
dsh() { docker exec -it "$1" /bin/sh; }

# Kubernetes Aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get svc'
alias kga='kubectl get all'
alias kctx='kubectl config use-context'
alias kctxs='kubectl config get-contexts'
alias kctxc='kubectl config current-context'
alias kget='kubectl get'
alias kdel='kubectl delete'
alias klogs='kubectl logs -f'
alias kapply='kubectl apply -f'

kexec() { kubectl exec -it "$@"; }
kdb() { kubectl exec -it "$1" -- /bin/bash; }
ksh() { kubectl exec -it "$1" -- /bin/sh; }

# Azure Helper
azlogin() { az login --use-device-code "$@"; }

# Ansible Python Virtualenv Helper
alias ansible-env='source pyenv/bin/activate'
```

## System Security & Power Management

### 1. Enable UFW Firewall
```bash
sudo ufw enable
sudo apt install gufw -y
```

### 2. Laptop Battery Optimization (Optional)
```bash
sudo apt install tlp tlp-rdw -y
sudo systemctl enable --now tlp
```

## Vim Configuration (`.vimrc`)

```vim
syntax on              " Enable syntax highlighting
set number             " Show line numbers
set relativenumber     " Show relative line numbers
set showmode           " Display current mode
set ignorecase         " Case insensitive search
set smartcase          " Smart case searching
set autoindent         " Preserve indentation
set tabstop=2          " Tab width
set shiftwidth=2       " Indent width
set expandtab          " Convert tabs to spaces
set bg=dark            " Dark background
```
