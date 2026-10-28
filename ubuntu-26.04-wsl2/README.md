# Configuração de Workstation DevOps/SRE para Ubuntu 26.04 no WSL2 com Docker Engine Nativo

Playbook do Ansible para provisionar uma distribuição Ubuntu 26.04 LTS executando dentro do WSL2, sob medida para fluxos de trabalho de DevOps, SRE, automação e focados em terminal, contando com Docker Engine nativo rodando diretamente dentro do Linux sem necessitar do Docker Desktop no Windows.

## Objetivo

Prepara um ambiente leve de desenvolvimento WSL2 com:
- Utilitários de terminal & ferramentas de diagnóstico de rede
- CLIs de nuvem, Kubernetes, IaC e segurança
- Zsh + Oh My Zsh + tema Powerlevel10k
- Docker Engine executando nativamente dentro do Ubuntu no WSL2, iniciado sob demanda
- Inicialização rápida do WSL (serviços desnecessários desligados e PATH do Windows enxuto)

## Conjunto de Ferramentas Instaladas

### Núcleo do Sistema & Utilitários
- Shell e produtividade: `git`, `git-delta`, `jq`, `fzf`, `ripgrep`, `fd`, `bat`, `eza`, `zoxide`, `direnv`, `entr`, `tmux`, `vim`, `tree`, `pv`, `plocate`
- Monitoramento e troubleshooting: `htop`, `btop`, `glances`, `iftop`, `iotop`, `ncdu`, `lsof`, `strace`, `sysstat`, `fastfetch`
- Rede: `curl`, `wget`, `httpie`, `mtr`, `traceroute`, `nmap`, `tcpdump`, `iperf3`, `ipcalc`, `socat`, `netcat`, `dig`, `whois`, `speedtest-cli`
- Bancos e runtimes: `mysql-client`, `postgresql-client`, `nodejs`, `npm`

### DevOps/SRE & Engenharia de Nuvem
- AWS CLI v2, Azure CLI, Google Cloud CLI (com `gke-gcloud-auth-plugin`)
- Terraform (repositório HashiCorp), `tflint`, `sops`, `age`
- `kubectl`, Helm, `k9s`, `k3s`, `kubectx`, `kubens`, `stern`, `helmfile`, Flux CLI, Argo CD CLI, `kubelogin`
- `trivy`, `hadolint`, `shellcheck`, `yamllint`, `dive`, `lazygit`, `lazydocker`
- MongoDB Database Tools, `mongosh`
- `pre-commit` e `ansible-lint` via `pipx`
- Claude Code (CLI de IA da Anthropic, instalado em `~/.local/bin/claude`; tags `tools` e `claude-code`)

As ferramentas distribuídas pelo GitHub Releases são baixadas na última versão (ou na versão fixada em `github_tools`) e só são baixadas de novo quando sai uma versão nova. Os completions do zsh são instalados junto.

### Docker Nativo no WSL2
- Docker Engine, Docker CLI, `containerd`, Plugin Docker Compose, Docker Buildx
- Rotação de logs e BuildKit em `/etc/docker/daemon.json`
- Docker sob demanda: sobe no primeiro comando `docker` (via `docker.socket`), não no boot
- `systemd` habilitado no WSL via `/etc/wsl.conf`

### Ambiente Shell
- Zsh, Oh My Zsh, Powerlevel10k (com o `gitstatusd` já baixado, sem depender da rede ao abrir o terminal)
- Plugins: `git`, `gh`, `docker`, `docker-compose`, `kubectl`, `helm`, `terraform`, `aws`, `azure`, `gcloud`, `fzf`, `zoxide`, `direnv`, `sudo`, `extract`, `colored-man-pages`, `command-not-found`, `zsh-autosuggestions`, `zsh-syntax-highlighting`, `zsh-completions`
- Aliases e funções em `~/.oh-my-zsh/custom/devops.zsh`: `kev`, `kbad`, `ksecret`, `knetshoot`, troca de conta com fzf (`awsp`, `azsub`, `gcpp`)
- Defaults do git (rebase no pull, `delta` como pager, `zdiff3`)

## Requisitos

- Windows 11 com WSL2 habilitado
- Ubuntu 26.04 instalado no WSL2
- Acesso `sudo` dentro da distribuição & conexão ativa com a internet
- Ansible instalado no WSL (o pacote `ansible` já inclui as collections `community.general` e `ansible.posix`)

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

Execute dentro da distribuição Ubuntu no WSL, na pasta deste playbook:

```bash
ansible-playbook ubuntu-wsl-setup.yml
```

O `ansible.cfg` da pasta já pede a senha do `sudo`. Para rodar só uma parte, use as tags:

```bash
ansible-playbook ubuntu-wsl-setup.yml --tags tools
ansible-playbook ubuntu-wsl-setup.yml --skip-tags upgrade
```

Tags disponíveis: `base`, `upgrade`, `wsl`, `migrate`, `repos`, `vendor`, `docker`, `k3s`, `cloud`, `tools`, `claude-code`, `shell`, `git`.

O playbook pode ser executado de novo a qualquer momento: o que já está instalado é pulado. Pacotes apt e snap são checados pelo próprio módulo, o AWS CLI pela existência de `/usr/local/bin/aws`, as ferramentas do GitHub Releases pela versão registrada (só baixam de novo quando sai versão nova) e o Claude Code e o k3s pela existência de `~/.local/bin/claude` e `/usr/local/bin/k3s`. O `~/.zshrc` é gerenciado pelo playbook (com backup); personalizações vão em `~/.zshrc.local`.

### Rede corporativa com proxy

Se a rede só sai para a internet por um proxy, passe o endereço na primeira execução:

```bash
https_proxy=http://proxy.empresa:3128 ansible-playbook ubuntu-wsl-setup.yml
```

O playbook repassa o proxy para todas as tarefas (inclusive as que usam `sudo`), configura o Docker daemon para usá-lo e exporta as variáveis no `~/.zshrc`. Nas execuções seguintes o proxy já vem do ambiente.

### Variáveis úteis

| Variável | Padrão | Uso |
|---|---|---|
| `k8s_minor` | `v1.36` | Canal do `kubectl` em `pkgs.k8s.io` |
| `hashicorp_packages` | `[terraform]` | Pacotes do repositório HashiCorp |
| `docker_on_demand` | `true` | `false` volta a iniciar o Docker no boot |
| `k3s_enable_on_boot` | `false` | `true` sobe o k3s no boot |
| `k3s_channel` | `stable` | Canal de versão do k3s (`stable`, `latest` ou `v1.36`) |
| `wsl_append_windows_path` | `false` | `true` coloca todo o PATH do Windows no WSL |
| `git_user_name` / `git_user_email` | vazio | Identidade global do git |
| `proxy_url` | `$https_proxy` | Proxy corporativo |

## Etapas de Execução

O playbook:
1. Valida se o sistema hospedeiro roda Ubuntu 26.04 no WSL2 e usa o `sudo` clássico quando disponível (o 26.04 vem com `sudo-rs`).
2. Instala os pacotes base e ajusta limites de `inotify` (k3s, IDEs).
3. Configura o `/etc/wsl.conf` e desliga serviços sem uso no WSL (`snapd`, `wsl-pro`, `lm-sensors`, `landscape-client`).
4. Remove instalações antigas que conflitam com as versões do apt ou foram substituídas, como o Kind (tag `migrate`).
5. Configura os repositórios deb822. Quando um fornecedor ainda não publica pacotes para o 26.04, usa os do 24.04 automaticamente.
6. Instala Docker, kubectl, Helm, Terraform, `gh`, CLIs de nuvem e ferramentas do MongoDB.
7. Instala o k3s (parado, fora do boot) como cluster Kubernetes local.
8. Instala as ferramentas do GitHub Releases, o AWS CLI v2 e o Claude Code.
9. Configura Zsh, Oh My Zsh, Powerlevel10k, plugins, git e define o shell padrão.

## Pós-Instalação

### Reiniciar Distribuição WSL
Feche o terminal e execute no Windows PowerShell / CMD:

```powershell
wsl --shutdown
```

Em seguida, reabra o Ubuntu no WSL e rode `p10k configure`.

### Autenticar o Claude Code
Na primeira execução, o `claude` mostra um link de login para abrir no navegador do Windows (conta Claude Pro/Max ou Console da Anthropic):
```bash
claude
```
O binário se atualiza sozinho em segundo plano. Para checar a instalação, use `claude doctor`.

### Abertura instantânea do terminal

Por padrão o WSL desliga o Ubuntu cerca de 15 s depois que o último terminal fecha, e a próxima abertura reinicia o `systemd` (4 a 7 s). Para manter o Ubuntu ligado, adicione ao `%USERPROFILE%\.wslconfig` no Windows:

```ini
[general]
instanceIdleTimeout=-1
```

### Testar Docker Engine
```bash
docker version
docker run hello-world
```

O primeiro comando `docker` depois de abrir o WSL leva alguns segundos porque inicia o daemon. Contêineres com `restart: always` só voltam a subir depois desse primeiro comando.

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
- Utiliza Docker Engine nativo dentro do Linux sem Docker Desktop no Windows. Se a integração WSL do Docker Desktop estiver ativa, o playbook avisa.
- Com `wsl_append_windows_path: false`, só as pastas úteis do Windows entram no PATH do zsh (`code`, `explorer.exe`, `clip.exe`, `pwsh.exe` continuam funcionando).
- Personalizações do shell vão em `~/.zshrc.local`, que o playbook nunca sobrescreve.
- Requer `systemd` habilitado no WSL e reinicialização via `wsl --shutdown` após a conclusão.
