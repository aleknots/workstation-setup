# Extras & Utility Reference (WSL2)

## Sudo Configuration & System Clean

Applies to Ubuntu running on WSL2:

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

# Aliases de Navegação
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

# Aliases do Sistema
alias df='df -h'
alias du='du -sh * | sort -h'
alias myip='curl -s ifconfig.me && echo'
alias ports='ss -tulpen'
alias ping='ping -c 5'
alias h='history'
alias j='jobs -l'

# Aliases do Apt
alias apt-update='sudo apt update -y'
alias apt-upgrade='sudo apt upgrade -y'
alias apt-remove='sudo apt autoremove -y'
alias apt-search='apt search'
alias apt-install='sudo apt install -y'

# Aliases do Git
alias g='git'
alias gst='git status'
alias ga='git add'
alias gc='git commit -m'
alias gp='git push'
alias gl='git pull'
alias gco='git checkout'
alias gb='git branch'
alias gcb='git checkout -b'

# Aliases do Docker
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

# Aliases do Kubernetes
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

# Auxiliar Azure
azlogin() { az login --use-device-code "$@"; }

# Auxiliar de Virtualenv Python para Ansible
alias ansible-env='source pyenv/bin/activate'
```

## Vim Configuration (`.vimrc`)

```vim
syntax on              " Habilita o destaque de sintaxe
set number             " Exibe números de linha
set relativenumber     " Exibe números de linha relativos
set showmode           " Exibe o modo atual
set ignorecase         " Busca sem diferenciar maiúsculas/minúsculas
set smartcase          " Busca inteligente de maiúsculas/minúsculas (smartcase)
set autoindent         " Preserva a indentação
set tabstop=2          " Largura do tab
set shiftwidth=2       " Largura da indentação
set expandtab          " Converte tabs em espaços
set bg=dark            " Fundo escuro
```
