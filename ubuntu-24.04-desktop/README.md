# Configuração da Estação DevOps/SRE para Ubuntu 24.04 Desktop

Playbook Ansible para provisionar um ambiente Ubuntu 24.04 Desktop sob medida para DevOps, SRE, engenharia de nuvem, automação, conteinerização, virtualização e produtividade.

Este playbook é projetado para instalação local no Ubuntu Desktop nativo e inclui utilitários de terminal, repositórios de terceiros deb822, Docker Engine, ferramentas de Kubernetes, CLIs de nuvem, Terraform, PowerShell, ferramentas do MongoDB, aplicações desktop e um ambiente Zsh com Oh My Zsh e Powerlevel10k.

## Conjunto de Ferramentas Instaladas

### Núcleo do Sistema & Utilitários
- Pacotes essenciais do sistema e ferramentas de diagnóstico de rede
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `fastfetch`

### DevOps/SRE & Engenharia de Nuvem
- Claude Code (CLI de IA da Anthropic, instalado em `~/.local/bin/claude`)
- Terraform, PowerShell, Azure CLI, `kubelogin`, AWS CLI v2, `yq`, Rclone, MongoDB Database Tools, `mongosh`
- Docker Engine, Plugin Docker Compose, Docker Buildx
- `kubectl`, `k9s`, `kubectx`, `kubens`, `k3s`, Vagrant, Helm, Flux CLI, Argo CD CLI, GitHub CLI, Google Cloud CLI

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

## Reexecução (Pula o que Já Está Instalado)

O playbook pode ser executado de novo a qualquer momento: ferramentas que já estão instaladas são puladas (aparecem como `ok` ou `skipping`), sem baixar nem reinstalar nada.

| Ferramenta | Como detecta que já está instalada |
|------------|------------------------------------|
| Pacotes apt (base, Docker, Terraform, kubectl, Chrome, VS Code...) | `state: present` do módulo apt |
| Snaps (Postman, Notion, Storage Explorer, Google Cloud CLI) | módulo `community.general.snap` |
| Rclone, Vagrant, Remote Desktop Manager | `dpkg-query -W <pacote>` |
| AWS CLI v2 | existência de `/usr/local/bin/aws` |
| K9s | existência de `~/.local/bin/k9s` |
| Helm, Flux, kubelogin, k3s, Claude Code, Oh My Zsh | `creates:` no binário ou diretório |
| yq, Argo CD CLI, Rclone Browser, fontes Meslo | arquivo de destino já existe (`get_url`) |
| kubectx/kubens, Powerlevel10k, plugins do zsh | repositório já clonado (`update: false`) |
| `.zshrc` | já contém o tema `powerlevel10k` (suas edições são preservadas) |

O cache de fontes (`fc-cache`) só é refeito quando alguma fonte nova é baixada.

O que **sempre** roda em toda execução, de propósito:
- `apt dist-upgrade` (tarefa `Atualizar todos os pacotes do sistema`), para manter o sistema atualizado.
- Configurações leves e idempotentes: grupos do usuário, shell padrão, pastas do GNOME, `updatedb` e `autoremove`.

Para **forçar a reinstalação ou atualização** de uma ferramenta detectada por arquivo ou pacote, remova-a e rode o playbook de novo. Exemplos:

```bash
sudo rm /usr/local/bin/yq && ansible-playbook ubuntu-desktop-setup.yml
```

```bash
sudo apt-get remove -y rclone && ansible-playbook ubuntu-desktop-setup.yml
```

Para sobrescrever o `.zshrc` com a versão do playbook (perde as suas personalizações):

```bash
ansible-playbook ubuntu-desktop-setup.yml -e overwrite_zshrc=true
```

Para rodar só uma parte, use as tags disponíveis (por exemplo, pular o Claude Code):

```bash
ansible-playbook ubuntu-desktop-setup.yml --skip-tags claude-code
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

### Autenticar o Claude Code
Na primeira execução, o `claude` abre o login no navegador (conta Claude Pro/Max ou Console da Anthropic):
```bash
claude
```
O binário se atualiza sozinho em segundo plano. Para checar a instalação, use `claude doctor`.


### Configurar Fontes do Terminal
Defina a fonte do seu terminal para:
```text
MesloLGS NF Regular
```

### Usar o k3s (cluster Kubernetes local)
O k3s substitui o Kind. Ele é instalado **parado e fora do boot**, para não consumir memória nem ocupar as portas 80/443/6443 sem necessidade. Para usar:

```bash
sudo systemctl start k3s
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl get nodes
```

O kubeconfig `/etc/rancher/k3s/k3s.yaml` é gerado na primeira subida, legível pelo seu usuário (modo `0640`, grupo do usuário), sem precisar de `sudo`. Ele não substitui o `~/.kube/config`, então os contextos de AKS/EKS/GKE continuam intactos.

Para parar o cluster (o `systemctl stop` sozinho deixa os contêineres rodando):

```bash
sudo systemctl stop k3s && sudo /usr/local/bin/k3s-killall.sh
```

Para o k3s subir sempre no boot, rode o playbook com `-e k3s_enable_on_boot=true`. Para desinstalar: `sudo /usr/local/bin/k3s-uninstall.sh`.

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
claude --version
```
