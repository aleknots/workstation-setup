# DevOps/SRE Workstation Setup for Ubuntu 24.04 Desktop

Ansible playbook to provision an Ubuntu 24.04 Desktop environment tailored for DevOps, SRE, cloud engineering, automation, containerization, virtualization, and desktop productivity.

This playbook is designed for local installation on native Ubuntu Desktop and includes terminal utilities, third-party deb822 repositories, Docker Engine, Kubernetes tools, cloud CLIs, Terraform, PowerShell, MongoDB tools, desktop applications, and a Zsh environment with Oh My Zsh and Powerlevel10k.

## Installed Toolset

### System Core & Utilities
- Essential system packages & network troubleshooting tools
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `fastfetch`

### DevOps/SRE & Cloud Engineering
- Terraform, PowerShell, Azure CLI, `kubelogin`, AWS CLI v2, `yq`, Rclone, MongoDB Database Tools, `mongosh`
- Docker Engine, Docker Compose Plugin, Docker Buildx
- `kubectl`, `k9s`, `kubectx`, `kubens`, `kind`, Vagrant, Helm, Flux CLI, Argo CD CLI, GitHub CLI, Google Cloud CLI

### Shell Environment
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `command-not-found`

### Virtualization & Desktop Tools
- KVM stack, `libvirt`, `virt-manager`
- `gnome-tweaks`, `gnome-shell-extension-manager`, `chrome-gnome-shell`, `tilix`, `flameshot`, `obs-studio`, `vlc`
- Fira Code, Powerline, and Meslo Nerd Fonts

### Desktop Applications
- Google Chrome, Visual Studio Code, Sublime Text, Remote Desktop Manager, Rclone Browser, Postman, Notion Desktop, Azure Storage Explorer

## Requirements

- Ubuntu 24.04 Desktop (bare-metal or local VM)
- `sudo` privileges & active internet connection
- Ansible & `community.general` collection installed

## Installing Ansible

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

## How to Run

Execute inside Ubuntu 24.04 Desktop:

```bash
sudo ~/pyenv/bin/ansible-playbook ubuntu-desktop-setup.yml
```

or using `-K` with prompt:

```bash
ansible-playbook ubuntu-desktop-setup.yml -K
```

## Execution Steps

The playbook:
1. Validates that host runs Ubuntu 24.04 Desktop (not WSL2).
2. Sets up keyrings, directories, and preserves core GNOME session packages.
3. Installs base system tools, terminal utilities, cloud CLIs, Docker Engine, and K8s tools.
4. Provisions desktop applications (VS Code, Chrome, Remote Desktop Manager) and KVM virtualization.
5. Configures Zsh, Oh My Zsh, Powerlevel10k theme, plugins, and custom shell aliases.

## Post-Installation

### Re-log Session
After completion, log out and log back in to apply:
- `docker`, `kvm`, and `libvirt` user group memberships.
- Default `zsh` shell.

### Configure Terminal Fonts
Set your terminal font to:
```text
MesloLGS NF Regular
```

### Validate CLI Tooling
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
