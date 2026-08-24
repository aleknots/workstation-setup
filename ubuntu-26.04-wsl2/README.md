# Configuração de Workstation DevOps/SRE para Ubuntu 26.04 no WSL2 com Docker Engine Nativo

Playbook do Ansible para provisionar uma distribuição Ubuntu 26.04 LTS executando dentro do WSL2, sob medida para fluxos de trabalho de DevOps, SRE, automação e focados em terminal, contando com Docker Engine nativo rodando diretamente dentro do Linux sem necessitar do Docker Desktop no Windows.

## Objetivo

Prepara um ambiente leve de desenvolvimento WSL2 com:
- Utilitários de terminal & ferramentas de diagnóstico de rede
- Terraform, PowerShell, MongoDB Database Tools
- Zsh + Oh My Zsh + tema Powerlevel10k
- Docker Engine executando nativamente dentro do Ubuntu no WSL2

## Conjunto de Ferramentas Instaladas

### Núcleo do Sistema & Utilitários
- Pacotes essenciais do sistema & ferramentas de rede
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `xclip`, `xdg-utils`, `fastfetch`

### DevOps/SRE & Engenharia de Nuvem
- AWS CLI v2, Azure CLI & `kubelogin`, Google Cloud CLI
- Terraform, PowerShell, Vagrant, `yq`, Rclone
- `kubectl`, `k9s`, `kind`, `kubectx`, `kubens`, Helm, Flux CLI, Argo CD CLI
- MongoDB Database Tools, `mongosh`

### Docker Nativo no WSL2
- Docker Engine, Docker CLI, `containerd`, Plugin Docker Compose, Docker Buildx
- `systemd` habilitado no WSL via `/etc/wsl.conf`

### Ambiente Shell
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `command-not-found`

## Requisitos

- Windows 11 com WSL2 habilitado
- Ubuntu 26.04 instalado no WSL2
- Acesso `sudo` dentro da distribuição & conexão ativa com a internet
- Ansible instalado no WSL

## Instalando Ansible no WSL

```bash
sudo apt update
sudo apt install -y python3-venv python3-pip sshpass
python3 -m venv pyenv
source pyenv/bin/activate
pip install --upgrade pip
pip install ansible
ansible --version
```

## Como Executar

Execute dentro da distribuição Ubuntu no WSL:

```bash
sudo ~/pyenv/bin/ansible-playbook ubuntu-wsl-setup.yml
```

ou utilizando `-K` com prompt de senha:

```bash
ansible-playbook ubuntu-wsl-setup.yml -K
```

## Etapas de Execução

O playbook:
1. Valida se o sistema hospedeiro roda Ubuntu 26.04 no WSL2.
2. Configura keyrings e repositórios deb822.
3. Instala utilitários base, CLIs de nuvem, ferramentas de K8s e ferramentas do MongoDB.
4. Instala o Docker Engine dentro do WSL e adiciona o usuário ao grupo `docker`.
5. Configura `/etc/wsl.conf` com `systemd=true`.
6. Configura Zsh, Oh My Zsh, Powerlevel10k, plugins e define o shell padrão.

## Pós-Instalação

### Reiniciar Distribuição WSL
Feche o terminal e execute no Windows PowerShell / CMD:

```powershell
wsl --shutdown
```

Em seguida, reabra o Ubuntu no WSL.

### Testar Docker Engine
```bash
docker version
docker run hello-world
```

### Verificar Status do Serviço
```bash
systemctl status docker
```

### Confirmar Shell Padrão
```bash
echo $SHELL
```

Saída esperada:
```bash
/usr/bin/zsh
```

## Notas Importantes

- Projetado para Ubuntu 26.04 rodando no WSL2.
- Utiliza Docker Engine nativo dentro do Linux sem Docker Desktop no Windows.
- Requer `systemd` habilitado no WSL e reinicialização via `wsl --shutdown` após a conclusão.
