# Configuração de Workstation DevOps/SRE para Ubuntu 26.04 LTS Desktop

Playbook do Ansible para provisionar um ambiente Ubuntu 26.04 LTS Desktop sob medida para DevOps, SRE, engenharia de nuvem, automação, conteinerização, virtualização e produtividade no desktop.

Este playbook foi projetado para instalação local em desktop Ubuntu nativo e inclui utilitários de terminal, repositórios deb822 de terceiros, Docker Engine, ferramentas de Kubernetes, CLIs de nuvem, Terraform, PowerShell, ferramentas do MongoDB, aplicações de desktop e um ambiente Zsh com Oh My Zsh e Powerlevel10k.

## Conjunto de Ferramentas Instaladas

### Núcleo do Sistema & Utilitários
- Pacotes essenciais do sistema & ferramentas de diagnóstico de rede
- `git`, `curl`, `wget`, `jq`, `tmux`, `vim`, `ripgrep`, `htop`, `btop`, `fd`, `fzf`, `tree`, `unzip`, `zip`, `traceroute`, `mtr`, `nmap`, `fastfetch`

### DevOps/SRE & Engenharia de Nuvem
- Claude Code (CLI de IA da Anthropic, instalado em `~/.local/bin/claude`)
- Terraform, PowerShell, Azure CLI, `kubelogin`, AWS CLI v2, `yq`, Rclone, MongoDB Database Tools, `mongosh`
- Docker Engine, Plugin Docker Compose, Docker Buildx
- `kubectl`, `k9s`, `kubectx`, `kubens`, `k3s`, Vagrant, Helm, Flux CLI, Argo CD CLI, GitHub CLI, Google Cloud CLI

### Ambiente Shell
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`, `command-not-found`

### Virtualização & Ferramentas de Desktop
- Stack KVM, `libvirt`, `virt-manager`
- `gnome-tweaks`, `gnome-shell-extension-manager`, `chrome-gnome-shell`, `tilix`, `flameshot`, `obs-studio`, `vlc`
- Fontes Fira Code, Powerline e Meslo Nerd Fonts

### Aplicações de Desktop
- Google Chrome, Visual Studio Code, Sublime Text, Remote Desktop Manager, Rclone Browser, Postman, Notion Desktop, Azure Storage Explorer

## Requisitos

- Ubuntu 26.04 LTS Desktop (bare-metal ou VM local)
- Privilégios de `sudo` & conexão ativa com a internet
- Ansible & coleção `community.general` instalados

> **sudo-rs:** o Ubuntu 26.04 usa `sudo-rs` como `/usr/bin/sudo`. O prompt de senha dele (`[sudo: ...] Senha:`) não é reconhecido pelo Ansible e a execução trava com `Timed out waiting for become success or become password prompt`. Por isso o playbook detecta o `/usr/bin/sudo.ws`, o sudo clássico que continua instalado pelo pacote `sudo`, e o usa no `become`. Confira com `ls -l /usr/bin/sudo.ws`; se não existir, instale com `sudo apt install -y sudo`.
>
> O inventário fica em `inventory.ini` (apenas `localhost` com conexão local). Rode os comandos de dentro da pasta `ubuntu-26.04-desktop` para que o `ansible.cfg` seja carregado.

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

Execute dentro do Ubuntu 26.04 Desktop:

```bash
sudo ~/pyenv/bin/ansible-playbook ubuntu-desktop-setup.yml
```

ou utilizando `-K` com prompt de senha:

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

## Sudo sem Senha (Opcional)

A tarefa `Configurar sudo sem senha para o grupo sudo` vem **desativada por padrão** e aparece como `skipping` na execução (é o `skipped=1` do resumo final). Ela só roda quando a variável `configure_passwordless_sudo` é `true`.

O motivo é segurança: com `NOPASSWD`, qualquer processo do seu usuário consegue virar root sem confirmação. Ative apenas em máquinas pessoais onde isso for aceitável.

Para ativar, execute o playbook passando a variável. O restante é idempotente, então só essa tarefa deve mudar algo:

```bash
cd ~/workstation-setup/ubuntu-26.04-desktop && ansible-playbook ubuntu-desktop-setup.yml -e configure_passwordless_sudo=true
```

Para executar a partir dessa tarefa, sem percorrer todas as anteriores (a detecção do `sudo.ws` fica nos `pre_tasks` e roda mesmo assim):

```bash
cd ~/workstation-setup/ubuntu-26.04-desktop && ansible-playbook ubuntu-desktop-setup.yml -e configure_passwordless_sudo=true --start-at-task "Configurar sudo sem senha para o grupo sudo"
```

O que a tarefa faz:
- Altera a linha `%sudo` do `/etc/sudoers` para `%sudo ALL=(ALL:ALL) NOPASSWD:ALL`.
- Valida o arquivo com `visudo -cf` antes de gravar, então um erro de sintaxe não chega a ser aplicado.
- Vale para o `sudo-rs` e para o `sudo.ws`, que leem o mesmo `/etc/sudoers`.

Depois de ativar, o Ansible continua perguntando a senha por causa do `become_ask_pass = True` no `ansible.cfg`. Basta apertar Enter no prompt, ou remover essa linha do `ansible.cfg`.

Para desfazer, edite com `sudo visudo` e volte a linha para:

```text
%sudo ALL=(ALL:ALL) ALL
```

## Etapas de Execução

O playbook:
1. Valida se o sistema hospedeiro roda Ubuntu 26.04 Desktop (não WSL2) e usa o `sudo` clássico quando disponível (o 26.04 vem com `sudo-rs`).
2. Configura keyrings, diretórios e preserva pacotes essenciais da sessão GNOME.
3. Instala ferramentas base do sistema, utilitários de terminal, CLIs de nuvem, Docker Engine e ferramentas de K8s.
4. Provisiona aplicações de desktop (VS Code, Chrome, Remote Desktop Manager) e virtualização KVM.
5. Configura Zsh, Oh My Zsh, tema Powerlevel10k, plugins e aliases personalizados do shell.

## Pós-Instalação

### Reiniciar Sessão do Usuário
Após a conclusão, faça logout e login novamente para aplicar:
- Permissões nos grupos de usuário `docker`, `kvm` e `libvirt`.
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

### Validar Ferramentas CLI
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
