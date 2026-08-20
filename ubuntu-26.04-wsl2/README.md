# DevOps/SRE Workstation Setup for Ubuntu 26.04 on WSL2 with Native Docker Engine

Ansible playbook to provision an Ubuntu 26.04 LTS distribution running inside WSL2, tailored for DevOps, SRE, automation, and terminal-centric workflows, featuring native Docker Engine running directly inside Linux without requiring Docker Desktop on Windows.

## Purpose

Prepares a lightweight WSL2 development environment with:
- Terminal utilities & network diagnostic tools
- Terraform, PowerShell, MongoDB Database Tools
- Zsh + Oh My Zsh + Powerlevel10k theme
- Docker Engine running natively inside Ubuntu on WSL2

## Installed Toolset

### System Core & Utilities
- Essential system packages & network tools
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `xclip`, `xdg-utils`, `fastfetch`

### DevOps/SRE & Cloud Engineering
- AWS CLI v2, Azure CLI & `kubelogin`, Google Cloud CLI
- Terraform, PowerShell, Vagrant, `yq`, Rclone
- `kubectl`, `k9s`, `kind`, `kubectx`, `kubens`, Helm, Flux CLI, Argo CD CLI
- MongoDB Database Tools, `mongosh`

### Native Docker in WSL2
- Docker Engine, Docker CLI, `containerd`, Docker Compose Plugin, Docker Buildx
- `systemd` enabled in WSL via `/etc/wsl.conf`

### Shell Environment
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `command-not-found`

## Requirements

- Windows 11 with WSL2 enabled
- Ubuntu 26.04 installed in WSL2
- `sudo` access inside distribution & active internet connection
- Ansible installed in WSL

## Installing Ansible in WSL

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip sshpass
python3 -m venv pyenv
source pyenv/bin/activate
pip install --upgrade pip
pip install ansible
ansible --version
```

## How to Run

Execute inside Ubuntu distribution in WSL:

```bash
sudo ~/pyenv/bin/ansible-playbook ubuntu-wsl-setup.yml
```

or using `-K` with prompt:

```bash
ansible-playbook ubuntu-wsl-setup.yml -K
```

## Execution Steps

The playbook:
1. Validates host system runs Ubuntu 26.04 on WSL2.
2. Configures keyrings and deb822 repositories.
3. Installs base utilities, cloud CLIs, K8s tools, and MongoDB tools.
4. Installs Docker Engine inside WSL and adds user to `docker` group.
5. Configures `/etc/wsl.conf` with `systemd=true`.
6. Sets up Zsh, Oh My Zsh, Powerlevel10k, plugins, and sets default shell.

## Post-Installation

### Restart WSL Distribution
Close terminal and execute in Windows PowerShell / CMD:

```powershell
wsl --shutdown
```

Then reopen Ubuntu in WSL.

### Test Docker Engine
```bash
docker version
docker run hello-world
```

### Verify Service Status
```bash
systemctl status docker
```

### Confirm Default Shell
```bash
echo $SHELL
```

Expected output:
```bash
/usr/bin/zsh
```

## Important Notes

- Designed for Ubuntu 26.04 running on WSL2.
- Uses native Docker Engine inside Linux without Docker Desktop on Windows.
- Requires `systemd` enabled in WSL and a `wsl --shutdown` restart after completion.
