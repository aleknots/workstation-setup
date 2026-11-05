# Workstation Windows 11 com PowerShell 7 (DevOps / SRE)

## Visão Geral

Um script para o Windows 11 **Home e Pro**, focado no terminal: instala as CLIs de DevOps/SRE via winget, configura o PowerShell 7 e o Windows Terminal e implanta um perfil rápido com prompt nativo. Na versão Home o lab de Kubernetes roda no Docker Desktop (k3s via k3d); na Pro ele prepara o WSL2 com Ubuntu 26.04 e o Hyper-V.

| Arquivo | Função |
|---|---|
| `setup-windows.ps1` | Script único: instala o PowerShell 7 e configura a máquina em até 16 etapas, com resumo no final |
| `Microsoft.PowerShell_profile.ps1` | Perfil implantado pelo setup (precisa estar na mesma pasta) |

O `setup-windows.ps1` pode ser iniciado no Windows PowerShell 5.1 que já vem com o Windows. Nesse caso ele instala o PowerShell 7 x64 (pelo winget ou, sem winget, pelo MSI oficial do GitHub), desbloqueia os arquivos da pasta e se reabre no PowerShell 7 com os mesmos parâmetros, na mesma janela. Se você já estiver no PowerShell 7, ele vai direto para o setup.

> [!IMPORTANT]
> **Revise a lista de apps antes de rodar.** O setup instala **todos** os apps da lista `$WingetPackages` (jogos, navegadores, Slack, Teams, Zoom, CLIs de nuvem...) e o módulo Az. Abra o `setup-windows.ps1`, veja o que você realmente quer e **comente com `#`** a linha de cada app que não deseja instalar. Veja [Escolher os apps](#escolher-os-apps).
## Versão do Windows

No início, o script pergunta qual versão instalar e sugere a da edição detectada (Enter aceita):

```
Versão do Windows (detectada: Windows 11 Pro)
  1  Windows 11 Home  PowerShell 7 com as ferramentas de DevOps + Docker Desktop e k3s (k3d). Sem Ubuntu.
  2  Windows 11 Pro   PowerShell 7 + WSL2 com Ubuntu 26.04, Hyper-V, Área Restrita, Vagrant, Packer e Multipass.
  Opção [2]:
```

| | Home | Pro |
|---|---|---|
| Edições | Home e Pro | Pro, Enterprise e Education (com Hyper-V) |
| PowerShell 7 customizado, CLIs de DevOps, Kubernetes e nuvem no Windows | ✓ | ✓ |
| Apps de trabalho e pessoais (incluindo os jogos) | ✓ | ✓ |
| Remoção dos apps pré-instalados (LinkedIn, Paciência, Notícias, Family, Clipchamp...) e da pesquisa web do Bing | ✓ | ✓ |
| sudo do Windows, Finalizar Tarefa e painel de detalhes do Explorer | ✓ | ✓ |
| Aparência leve (sem animações, transparência e anúncios; Widgets ativos com o tempo) | ✓ | — |
| WSL2 | ✓ (motor do Docker Desktop) | ✓ |
| Docker Desktop + k3d (k3s em contêineres) | ✓ | — |
| Ubuntu 26.04 no WSL2 (Docker e k3s pelo playbook) | — | ✓ |
| Hyper-V (plataforma, Gerenciador `virtmgmt.msc` e módulo do PowerShell) | — | ✓ |
| Área Restrita do Windows (Windows Sandbox) | — | ✓ |
| Seu usuário no grupo Administradores do Hyper-V (VMs sem abrir como admin) | — | ✓ |
| Vagrant (provider padrão: Hyper-V), Packer e Multipass | — | ✓ |

A versão **Home** não instala o Ubuntu: as ferramentas rodam no PowerShell 7 e o Docker e o k3s vêm do **Docker Desktop**, que usa o WSL2 como motor (com a própria distro `docker-desktop`) e só ocupa memória enquanto está aberto. Numa máquina Pro dá para escolher a Home mesmo assim (opção 1), para ter uma instalação mais leve. No Windows 11 Home a opção 2 aparece como indisponível, porque o Home não tem Hyper-V.

Por ser mais leve, a versão Home também serve para dispositivos portáteis com Windows 11, como ROG Ally, Legion Go e similares.

Para não perguntar, use `-Versao Home` ou `-Versao Pro`; sem terminal interativo, vale a versão da edição detectada.

## Configuração do WSL (.wslconfig)

Nas versões Home e Pro (e no Enterprise), o setup grava o `%USERPROFILE%\.wslconfig`. Ele vale para o Ubuntu da versão Pro e para a distro do Docker Desktop da versão Home:

```ini
[wsl2]
networkingMode=mirrored    # o WSL usa o IP e as portas do Windows (localhost nos dois sentidos)
dnsTunneling=true          # DNS resolvido pelo Windows: funciona com VPN e proxy
autoProxy=true             # o WSL herda o proxy configurado no Windows
firewall=true              # regras do Firewall do Windows valem também para o WSL
memory=6GB                 # veja a tabela abaixo
processors=6               # até 6, sem passar dos processadores da máquina

[general]
instanceIdleTimeout=-1     # mantém o WSL ligado quando ocioso: terminal instantâneo

[experimental]
autoMemoryReclaim=gradual  # devolve ao Windows a memória de cache que o WSL não usa
sparseVhd=true             # o disco virtual encolhe quando você apaga imagens e clusters
```

### Limite de memória

| Máquina | Memória do WSL |
|---|---|
| PCs em geral | **6 GB**, sem passar da metade da RAM (ex.: 4 GB num PC de 8 GB) |
| ROG Ally / Ally X / Xbox Ally | **25% da RAM, mínimo 4 GB** (a RAM é dividida com a GPU e os jogos) |
| Qualquer máquina, com `-WslMemoryGB <n>` | **n GB** |

Outros portáteis, como o Legion Go, não são detectados: neles vale a regra dos PCs em geral, ou use `-WslMemoryGB` (ex.: `-WslMemoryGB 4`).

No ROG Ally o setup **não** grava o `instanceIdleTimeout=-1`: lá o WSL desliga quando ocioso, para não gastar RAM e bateria durante os jogos.

As chaves acima são reaplicadas a cada execução do setup (com backup do arquivo anterior em `.wslconfig.bak-<data>`). Outras chaves que você adicionar no arquivo são mantidas. As mudanças valem depois de `wsl --shutdown` ou de reiniciar o Windows.
## Requisitos

- Windows 11 Home ou Pro (24H2 ou superior para o `sudo` do Windows); a versão Pro precisa do Pro, Enterprise ou Education
- Conta com permissão de administrador
- winget (App Installer da Microsoft Store)
- Virtualização habilitada na BIOS (WSL2, Docker Desktop e Hyper-V)
- Docker Desktop (versão Home): gratuito para uso pessoal, educação e empresas pequenas; empresas maiores precisam de assinatura
- Conexão ativa com a Internet

## Como Executar

1. Baixe ou clone este repositório (ex.: `C:\Setup\workstation-setup`).
2. **Revise os apps:** abra o `setup-windows.ps1` e comente com `#` os apps que não quer instalar (veja [Escolher os apps](#escolher-os-apps)).
3. Abra o **Windows PowerShell como Administrador** e rode:

```powershell
cd C:\Setup\workstation-setup\windows-11
powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
```

4. Reinicie o Windows ao final, se o resumo pedir.
5. Siga o [Primeiro uso](#primeiro-uso) da versão escolhida.

### Parâmetros

| Parâmetro | Uso |
|---|---|
| `-Versao Perguntar\|Home\|Pro` | Versão do Windows (padrão: pergunta no início) |
| `-WslMemoryGB <n>` | Memória do WSL em GB (padrão: 6 GB, sem passar da metade da RAM; no ROG Ally, 25% da RAM). Veja [Limite de memória](#limite-de-memória) |
| `-SkipApps` | Não instala o grupo "Pessoal / Opcional" |
| `-UpgradeAll` | Também roda `winget upgrade --all` |
| `-SkipWindowsFeatures` | Não mexe nos recursos do Windows |
| `-SkipProfile` | Não implanta o perfil |
| `-RemoveX86` | Remove o PowerShell 7 de 32 bits, se existir |

## Etapas do Setup

1. **Pré-requisitos**: Windows 11, dispositivo, versão, winget, reinicialização pendente, ExecutionPolicy e PSGallery.
2. **Recursos do Windows**: WSL e Plataforma de Máquina Virtual; na Pro também Hyper-V e Área Restrita; Cliente Telnet nas duas.
3. **WSL2**: `wsl --update` e WSL 2 como padrão; na Pro também instala o Ubuntu 26.04.
4. **Configuração do WSL**: grava o `.wslconfig` com rede espelhada, DNS e proxy do Windows, limites de memória e processadores, recuperação de memória e disco esparso (veja [Configuração do WSL](#configuração-do-wsl-wslconfig)).
5. **Remover apps pré-instalados**: LinkedIn, Paciência, Notícias (Microsoft Start), Pesquisa do Bing, Hub de Comentários, Family Safety, Clipchamp, Notas Autoadesivas, Clima, Dicas, Microsoft 365, Teams e Outlook pessoais, Spotify, TikTok, WhatsApp e outros, do usuário e da imagem do Windows. Também desliga a pesquisa web do Bing no Iniciar e impede que o Windows reinstale apps sugeridos.
6. **Ferramentas e aplicativos (winget)**: os grupos das duas versões e os da versão escolhida.
7. **Docker Desktop e k3d** (Home): seu usuário no grupo `docker-users`.
8. **CLIs do Kubernetes (GitHub Releases)**: `kubeseal` e `kubectl-argo-rollouts`, que não estão no winget.
9. **Hyper-V e VMs** (Pro): grupo Administradores do Hyper-V e o Hyper-V como provider padrão do Vagrant.
10. **Ajustes de desenvolvedor**: Finalizar Tarefa na barra de tarefas, `sudo` do Windows ativado (modo inline), painel de detalhes do Explorer com a pré-visualização da imagem (`Alt+Shift+P`), extensões e arquivos ocultos visíveis, caminhos longos, modo de desenvolvedor e defaults do git.
11. **Aparência leve** (Home): efeitos visuais em melhor desempenho (mantendo a suavização de fontes e as miniaturas), sem transparência, sem atraso nos apps de inicialização e sem sugestões e anúncios no Iniciar. Os Widgets continuam ativos, com o tempo na barra de tarefas. Vale no próximo login.
12. **Fonte Nerd Font**: MesloLGM Nerd Font.
13. **Módulos do PowerShell**: PSReadLine, Terminal-Icons, PSFzf, CompletionPredictor e Az.
14. **Windows Terminal**: PowerShell 7 como padrão e a Nerd Font (com backup do `settings.json`).
15. **Perfil do PowerShell**: copia o perfil (com backup), desbloqueia o arquivo e cria o `profile.local.ps1`.
16. **Atualizar aplicativos**: só com `-UpgradeAll`.

A saída do winget fica em `%TEMP%\setup-windows-<data>\winget.log`.

## Pacotes

A lista `$WingetPackages` segue a mesma ordem da lista antiga do Chocolatey, com o nome do pacote do Chocolatey comentado ao lado de cada Id do winget.

| Grupo | Versão | Pacotes |
|---|---|---|
| Trabalho / DevOps / SRE | Home e Pro | Cursor, Vagrant, Azure CLI, Azure Storage Explorer, Slack, Teams, VS Code, Antigravity, Claude Code (CLI), Claude (app desktop), Git, Terraform, AWS CLI, Argo CD CLI, k9s, Helm, Postman, Grok CLI, kubelogin, Google Cloud SDK |
| Pessoal / Opcional | Home e Pro | Discord, Epic Games, Steam, CCleaner, Zoom, Chrome, Firefox, Remote Desktop Manager, PowerToys, Valorant (servidor BR), Google Drive, OBS Studio, Notion, Obsidian, WebView2 Runtime, Sublime Text 4, Oh My Posh, TreeSize Free, Roblox, Flameshot 12.1.0 |
| Terminal e shell | Home e Pro | PowerShell 7, Windows Terminal, GitHub CLI, Neovim, fzf, zoxide, eza, ripgrep, fd, bat, delta, jq, yq |
| Kubernetes | Home e Pro | kubectl, kubectx, kubens, stern, Headlamp |
| Docker Desktop | Home | Docker Desktop, k3d |
| Virtualização | Pro | Vagrant, Packer, Multipass |

O módulo Az do PowerShell (`azurepowershell`) fica na lista `$PSModules` e também é instalado; comente a linha dele se não usar Azure (ele é grande). O driver e o app da NVIDIA não estão no winget. Para fazer um grupo entrar só numa versão, adicione-o em `$EditionGroups`. Um item no formato `Id@versão` instala essa versão e faz um `winget pin`. O Valorant tem um pacote por servidor: troque o sufixo de `RiotGames.Valorant.BR` se precisar.
### Escolher os apps

Por padrão **todos os apps estão ativos**. Antes de rodar, abra o `setup-windows.ps1` e revise a lista `$WingetPackages`: comente cada app que você não quer. Cada app fica numa linha, com o nome do pacote no Chocolatey ao lado:

- **Para não instalar** um app, comente a linha com `#` no início.
- **Para instalar** um app comentado, apague o `#`.

```powershell
'Pessoal / Opcional' = @(
    'Valve.Steam'                            # steam: será instalado
    # 'Zoom.Zoom'                            # zoom: comentado, não será instalado
    # 'Piriform.CCleaner'                    # ccleaner: comentado, não será instalado
    'Notion.Notion'                          # notion: será instalado
)
```

Para não instalar nada do grupo "Pessoal / Opcional", use `-SkipApps`. Os apps já instalados não são removidos quando você comenta a linha.

Os apps pré-instalados que o setup remove ficam na lista `$BloatwareApps`, do mesmo jeito: para **manter** um deles (ex.: Relógio ou Media Player), comente a linha. Loja, Calculadora, Fotos, Bloco de Notas, Paint, Ferramenta de Captura, Câmera, Terminal, Edge e os apps do Xbox nunca são removidos. Um app removido pode ser reinstalado pela Microsoft Store.

## Perfil do PowerShell 7

- **Prompt nativo** com hora, RAM, contexto do kubectl, GCP, Azure, AWS, pasta e status do git, sem Oh My Posh.
- **Autocompletar** com cache semanal para kubectl (e `k`), helm, gh e kind, além do Azure CLI.
- **PSReadLine** com predição em lista e histórico/arquivos com fzf (`Ctrl+r` / `Ctrl+t`).
- **Atalhos** de git e Kubernetes (`kgp`, `kev`, `kbad`, `ksecret`, `knetshoot`…).
- **Troca de conta** com fzf: `awsp`, `azsub` e `gcpp`.

Personalizações vão no `profile.local.ps1`, na mesma pasta do perfil. O setup nunca sobrescreve esse arquivo.

### Lab de Kubernetes (k3s e Argo CD)

Os mesmos comandos nas duas versões; muda só onde o k3s roda:

| | Home | Pro |
|---|---|---|
| Onde roda | Contêineres do Docker Desktop (k3d) | Ubuntu do WSL2 |
| Contexto do kubectl | `k3d-lab` | `k3s` |
| Instalação do Argo CD e add-ons | `lab-argocd` (`-Grafana` inclui o kube-prometheus-stack) | [playbook do WSL2](../ubuntu-26.04-wsl2/README.md) com `--tags k3s -e k3s_lab=true` |

| Comando | Função |
|---|---|
| `k3s-up` / `k3s-down` / `k3s-status` | Liga, desliga e mostra o cluster. Na Home, o primeiro `k3s-up` cria o cluster `lab` (o Docker Desktop precisa estar aberto) |
| `lab-argocd` | Só na Home: Argo CD, Sealed Secrets e Argo Rollouts como Applications do Argo CD |
| `argocd-ui`, `argocd-pass`, `argocd-login` | Argo CD em `https://localhost:8080` |
| `rollouts-ui` | Dashboard do Argo Rollouts em `http://localhost:3100` |
| `grafana-ui` | Grafana em `http://localhost:3000`, se o add-on estiver ligado |
| `docker ...`, `k3d ...` | Só na Pro: repassados para o Docker do Ubuntu |

Com o cluster ligado, `kubectl`, `k9s`, `helm`, `argocd`, `kubeseal`, `kubectl argo rollouts` e o Headlamp do Windows acessam o cluster pelo `localhost`.

## Primeiro uso

### Versão Home

1. Faça logoff e login (ou reinicie), para valer o grupo `docker-users`.
2. Abra o **Docker Desktop** uma vez, aceite os termos e espere ele ficar pronto. Em *Settings › General*, desmarque *Start Docker Desktop when you sign in* para ele só ocupar memória quando você usar.
3. No PowerShell 7:

```powershell
k3s-up        # cria o cluster "lab" na primeira vez; depois só o religa
lab-argocd    # Argo CD, Sealed Secrets e Argo Rollouts
argocd-ui     # abre o Argo CD em https://localhost:8080
```

Ao terminar, `k3s-down` para o cluster; fechar o Docker Desktop libera a memória.

### Versão Pro

1. Se o setup avisar que o WSL acabou de ser habilitado, reinicie e rode o setup de novo para instalar o Ubuntu.
2. Abra o Ubuntu (`wsl -d Ubuntu-26.04`) e crie o usuário Linux.
3. Rode o [playbook do WSL2](../ubuntu-26.04-wsl2/README.md) para instalar o que precisar nele; para o lab, use `--tags k3s -e k3s_lab=true`.
4. No PowerShell 7: `k3s-up` e depois `argocd-ui`.
## Licença

Distribuído sob a [Licença MIT](./LICENSE).
