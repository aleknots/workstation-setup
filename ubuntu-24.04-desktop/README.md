# Configuração da Estação DevOps/SRE para Ubuntu 24.04 Desktop

Playbook Ansible para provisionar um ambiente Ubuntu 24.04 Desktop sob medida para DevOps, SRE, engenharia de nuvem, automação, conteinerização, virtualização e produtividade.

Este playbook é projetado para instalação local no Ubuntu Desktop nativo e inclui utilitários de terminal, repositórios de terceiros deb822, Docker Engine, ferramentas de Kubernetes, CLIs de nuvem, Terraform, PowerShell, ferramentas do MongoDB, aplicações desktop e um ambiente Zsh com Oh My Zsh e Powerlevel10k.

## Conjunto de Ferramentas Instaladas

### Núcleo do Sistema & Utilitários
- Pacotes essenciais do sistema e ferramentas de diagnóstico de rede
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `fastfetch`

### DevOps/SRE & Engenharia de Nuvem
- Terraform, PowerShell, Azure CLI, `kubelogin`, AWS CLI v2, `yq`, Rclone, MongoDB Database Tools, `mongosh`
- Docker Engine, Plugin Docker Compose, Docker Buildx
- `kubectl`, `k9s`, `kubectx`, `kubens`, `kind`, Vagrant, Helm, Flux CLI, Argo CD CLI, GitHub CLI, Google Cloud CLI

### Ambiente de Shell
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `command-not-found`

### Virtualização & Ferramentas de Desktop
- Stack KVM, `libvirt`, `virt-manager`
- `gnome-tweaks`, `gnome-shell-extension-manager`, `chrome-gnome-shell`, `tilix`, `flameshot`, `obs-studio`, `vlc`
- Fontes Fira Code, Powerline e Meslo Nerd Fonts

### Aplicações Desktop
- Google Chrome, Visual Studio Code, Sublime Text, Remote Desktop Manager, Rclone Browser, Postman, Notion Desktop, Azure Storage Explorer

## Requisitos

- Ubuntu 24.04 Desktop (bare-metal ou VM local)
- Privilégios de `sudo` & conexão ativa com a internet
- Ansible & coleção `community.general` instalados

## Instalando o Ansible

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip sshpass
python3 -m venv pyenv
source pyenv/bin/activate
pip install --upgrade pip
pip install ansible
ansible-galaxy collection install community.general
ansible --version
```

## Como Executar

Execute dentro do Ubuntu 24.04 Desktop:

```bash
sudo ~/pyenv/bin/ansible-playbook ubuntu-desktop-setup.yml
```

ou usando `-K` com prompt de senha:

```bash
ansible-playbook ubuntu-desktop-setup.yml -K
```

## Etapas de Execução

O playbook:
1. Valida se o host roda Ubuntu 24.04 Desktop (não WSL2).
2. Configura keyrings, diretórios e preserva pacotes core de sessão do GNOME.
3. Instala ferramentas base do sistema, utilitários de terminal, CLIs de nuvem, Docker Engine e ferramentas K8s.
4. Provisiona aplicações desktop (VS Code, Chrome, Remote Desktop Manager) e virtualização KVM.
5. Configura Zsh, Oh My Zsh, tema Powerlevel10k, plugins e aliases personalizados de shell.

## Pós-Instalação

### Reiniciar Sessão
Após a conclusão, encerre a sessão e faça login novamente para aplicar:
- Membros de grupos de usuário `docker`, `kvm` e `libvirt`.
- Shell padrão `zsh`.

### Configurar Fontes do Terminal
Defina a fonte do seu terminal para:
```text
MesloLGS NF Regular
```

### Validar Ferramentas de CLI
```bash
terraform version
pwsh
kubectl version --client
az version
aws --version
gh --version
helm version
argocd version --client
```
