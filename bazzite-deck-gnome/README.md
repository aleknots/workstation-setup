# Configuração de Workstation DevOps/SRE para Bazzite Deck GNOME (amd64)

Playbook do Ansible para provisionar um ambiente DevOps/SRE no **Bazzite Deck com GNOME** (`bazzite-deck-gnome`, amd64). É a conversão do playbook do [Ubuntu 26.04 Desktop](../ubuntu-26.04-desktop/README.md) para um sistema **atômico/imutável** baseado em Fedora.

> **Estado:** convertido a partir do playbook do Ubuntu e validado apenas em sintaxe. Ainda **não foi executado em um Bazzite real**; rode primeiro com `--check` e leia a seção [Limitações Conhecidas](#limitações-conhecidas).

## O que Muda em Relação ao Ubuntu

O Bazzite não tem `apt` nem `snap`, e o `/usr` é somente leitura. Cada ferramenta foi movida para o mecanismo que o Bazzite recomenda:

| No Ubuntu | No Bazzite | Observação |
|-----------|-----------|------------|
| Pacotes `apt` de terminal | **Homebrew** (já vem no Bazzite) | Sem root e sem reiniciar |
| Repositórios `apt` de terceiros (Terraform, kubectl, gh, Helm...) | **Homebrew** | `hashicorp/tap` para o Terraform |
| Snaps e `.deb` de aplicativos | **Flatpak** (Flathub) | Chrome, Sublime, Postman, Flameshot... |
| Docker Engine, VS Code, zsh | **Camada `rpm-ostree`** | Exige reiniciar; só o que faltar na imagem é adicionado |
| Grupo `sudo` | Grupo `wheel` | Arquivo em `/etc/sudoers.d/` |
| `apt dist-upgrade` em toda execução | Opcional (`run_system_update`) | O Bazzite já se atualiza sozinho |
| k3s instalado no host | **k3d** (k3s dentro de contêineres Docker) | Sem root, sem serviço systemd e sem ajuste de SELinux |
| Tilix | Ptyxis (terminal nativo do Bazzite) | Tilix não é instalado |
| Detecção do `sudo-rs` | Removida | O Fedora usa o `sudo` clássico |

## Conjunto de Ferramentas Instaladas

### Terminal (Homebrew)
- `bat`, `btop`, `fd`, `fzf`, `ripgrep`, `jq`, `yq`, `tmux`, `vim`, `tree`, `wget`, `whois`, `ncdu`, `httpie`, `iftop`, `mtr`, `nmap`, `speedtest-cli`, `fastfetch`

### DevOps/SRE & Engenharia de Nuvem
- Homebrew: Terraform, `kubectl`, `k3d`, `k9s`, `kubectx`, `kubens`, Helm, Argo CD CLI, GitHub CLI
- Camada `rpm-ostree`: Docker Engine, Docker Compose, Docker Buildx
- Em `~/.local/bin`: Claude Code

### Ambiente Shell
- Zsh, Oh My Zsh, Powerlevel10k
- Plugins: `git`, `docker`, `docker-compose`, `terraform`, `fzf`, `zsh-syntax-highlighting`, `zsh-autosuggestions`, `zsh-completions`

### Aplicações de Desktop (Flatpak)
- Google Chrome, Sublime Text, Postman
- Flameshot, GNOME Connections
- Visual Studio Code entra como RPM em camada (ou Flatpak com `-e install_vscode_rpm=false`)

### Fontes
- Meslo Nerd Fonts em `~/.local/share/fonts`

## Requisitos

- Bazzite Deck GNOME amd64, no **Modo Desktop** (no Modo Jogo, use *Power → Switch to Desktop*)
- Usuário do grupo `wheel` com senha definida e conexão com a internet
- Ansible com a coleção `community.general`

> Rode como **usuário comum**, nunca com `sudo ansible-playbook`: o Homebrew recusa execução como root. A senha do `sudo` é pedida pelo `-K`.

## Instalando o Ansible

Pelo Homebrew (o pacote `ansible` já inclui a coleção `community.general`):

```bash
brew install ansible
```

```bash
ansible --version
```

Alternativa com virtualenv do Python:

```bash
python3 -m venv ~/pyenv && source ~/pyenv/bin/activate && pip install --upgrade pip ansible
```

## Como Executar

Rode de dentro da pasta `bazzite-deck-gnome`, para que o `ansible.cfg` seja carregado. O `-K` não é necessário porque o `ansible.cfg` já pede a senha do `become`.

Primeiro uma simulação:

```bash
ansible-playbook bazzite-deck-gnome-setup.yml --check
```

Depois a execução real:

```bash
ansible-playbook bazzite-deck-gnome-setup.yml
```

### Execução em Duas Etapas

Pacotes em camada do `rpm-ostree` só existem depois de reiniciar. Por isso:

1. **Primeira execução:** instala os pacotes do Homebrew (incluindo o `k3d`), Flatpaks, Claude Code e fontes, e **agenda** as camadas (Docker, VS Code, zsh se faltar). No final aparece o aviso `REINICIE o sistema`.
2. **Reinicie:**

```bash
systemctl reboot
```

3. **Segunda execução:** conclui o que dependia das camadas: serviço do Docker, grupo `docker`, Oh My Zsh e zsh como shell padrão. Só a partir daqui o `k3d` consegue criar clusters, porque depende do Docker. O resto aparece como `ok`.

Se o zsh já vier na imagem, o ambiente Zsh é configurado logo na primeira execução.

## Variáveis

| Variável | Padrão | Efeito |
|----------|--------|--------|
| `install_docker` | `true` | Adiciona o Docker Engine em camada |
| `install_vscode_rpm` | `true` | VS Code como RPM em camada; `false` usa o Flatpak |
| `run_system_update` | `false` | Roda `rpm-ostree upgrade`, `flatpak update` e `brew upgrade` |
| `configure_passwordless_sudo` | `false` | Cria `/etc/sudoers.d/90-wheel-nopasswd` |
| `overwrite_zshrc` | `false` | Sobrescreve o `.zshrc` existente |
| `configure_gnome_app_folders` | `true` | Cria as pastas DevOps, Remote Access e Media |

Exemplo sem nenhuma camada de Docker ou VS Code:

```bash
ansible-playbook bazzite-deck-gnome-setup.yml -e install_docker=false -e install_vscode_rpm=false
```

Tags disponíveis: `layering`, `brew`, `flatpak`, `claude-code`. Para rodar só os Flatpaks:

```bash
ansible-playbook bazzite-deck-gnome-setup.yml --tags flatpak
```

## Reexecução (Pula o que Já Está Instalado)

| Ferramenta | Como detecta que já está instalada |
|------------|------------------------------------|
| Camadas `rpm-ostree` | `rpm -q <pacote>` e a lista `requested-packages` da implantação pendente |
| Pacotes do Homebrew | módulo `community.general.homebrew` |
| Flatpaks | módulo `community.general.flatpak` |
| Claude Code, Oh My Zsh | `creates:` no binário ou diretório |
| Fontes Meslo | arquivo de destino já existe (`get_url`) |
| Powerlevel10k, plugins do zsh | repositório já clonado (`update: false`) |
| `.zshrc` | já contém o tema `powerlevel10k` (suas edições são preservadas) |

Para forçar a reinstalação de um binário, remova-o e rode de novo:

```bash
rm ~/.local/bin/claude && ansible-playbook bazzite-deck-gnome-setup.yml
```

Para remover uma camada:

```bash
rpm-ostree uninstall docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

## Sudo sem Senha (Opcional)

Desativado por padrão. Com `NOPASSWD`, qualquer processo do seu usuário vira root sem confirmação; ative apenas em máquina pessoal.

```bash
ansible-playbook bazzite-deck-gnome-setup.yml -e configure_passwordless_sudo=true
```

O playbook cria `/etc/sudoers.d/90-wheel-nopasswd`, validado com `visudo -cf` antes de gravar. Para desfazer:

```bash
sudo rm /etc/sudoers.d/90-wheel-nopasswd
```

## Pós-Instalação

### Reiniciar
Reinicie (e rode o playbook de novo) para aplicar as camadas, o grupo `docker` e o shell `zsh`.

### Configurar a Fonte do Terminal
No Ptyxis, em *Preferências → Aparência → Fonte personalizada*, escolha:

```text
MesloLGS NF Regular
```

### Autenticar o Claude Code

```bash
claude
```

### Usar o k3d (cluster Kubernetes local)
O k3d substitui o k3s do playbook do Ubuntu: ele roda o k3s dentro de contêineres Docker, sem root e sem serviço no host. Nenhum cluster é criado pelo playbook, então nada consome memória até você criar um.

Ele depende do Docker, então só funciona **depois do reboot e da segunda execução**, com o seu usuário já no grupo `docker` (confira com `docker ps`).

Criar um cluster com 1 servidor e 2 agentes, expondo as portas 8080 e 8443 do ingress:

```bash
k3d cluster create dev --agents 2 -p "8080:80@loadbalancer" -p "8443:443@loadbalancer"
```

O k3d adiciona o contexto `k3d-dev` ao `~/.kube/config` e o deixa ativo, sem apagar os outros contextos:

```bash
kubectl get nodes
```

Parar e voltar a subir o cluster, preservando o estado:

```bash
k3d cluster stop dev
```

```bash
k3d cluster start dev
```

Listar e apagar clusters:

```bash
k3d cluster list
```

```bash
k3d cluster delete dev
```

Para usar uma imagem local sem publicar em registry: `k3d image import minha-imagem:tag -c dev`.

### Validar Ferramentas CLI

```bash
terraform version; kubectl version --client; gh --version; helm version; k3d version; argocd version --client; claude --version
```

Depois do reboot:

```bash
docker version; code --version
```

## Limitações Conhecidas

- **Não testado em hardware real.** A sintaxe YAML foi validada e todas as URLs, IDs do Flathub e fórmulas do Homebrew foram conferidas, mas o playbook não foi executado em um Bazzite.
- **Camadas `rpm-ostree`:** a documentação do Bazzite desaconselha camadas, porque um pacote em camada com dependência quebrada pode travar as atualizações do sistema até ser removido. Se uma atualização falhar, remova a camada com `rpm-ostree uninstall` ou rode com `install_docker=false` / `install_vscode_rpm=false`.
- **Docker:** se o `containerd.io` conflitar com algum pacote da imagem, a transação inteira do `rpm-ostree` falha. Alternativas: `-e install_docker=false` e usar o Podman (já incluso) ou o Distrobox.
- **k3d depende do Docker:** com `-e install_docker=false` o `k3d` é instalado, mas não consegue criar clusters. O suporte dele ao Podman é experimental e não é configurado aqui.
- **Modo Jogo:** as pastas de aplicativos do GNOME só aparecem na sessão GNOME (Modo Desktop).
- **Flatpaks em sandbox:** Chrome, Sublime Text e Postman não enxergam todas as pastas e ferramentas do host. Ajuste permissões com o Flatseal, se precisar.
- **Flameshot:** tem suporte limitado no GNOME com Wayland; a captura nativa (`Print`) é a alternativa.
- **Fora do escopo (labs locais):** em relação ao playbook do Ubuntu, não são instalados a stack KVM/libvirt e o `virt-manager`, o Vagrant, o Remote Desktop Manager, o PowerShell, o `gnome-tweaks`, o Extension Manager, o Node.js, o Rclone, o OBS Studio, o VLC, a fonte Fira Code, as CLIs de nuvem (Azure CLI, `kubelogin`, AWS CLI, Google Cloud CLI), o Azure Storage Explorer, os monitores `htop` e `glances` (fica o `btop`), o `ag` (fica o `ripgrep`) e os clientes de banco (`mongosh`, MongoDB Database Tools, `psql`, `mysql`). Para um cliente de banco pontual, use um contêiner, por exemplo `docker run -it --rm postgres psql -h <host> -U <usuário>`. Para VMs, o Bazzite oferece `ujust setup-virtualization`.
- **Sem equivalente instalado:** `nala`, `plocate`, `command-not-found`, `net-tools`, `iotop`, `xclip` (o Wayland usa `wl-copy`), `chrome-gnome-shell`, Tilix, Notion Desktop e Rclone Browser (AppImage).
