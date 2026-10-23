# Workstation Windows 11 com PowerShell 7 (DevOps / SRE)

## Visão Geral

Versão enxuta do setup do Windows 11, focada no terminal: instala as CLIs de DevOps/SRE via winget, configura o PowerShell 7 e o Windows Terminal e implanta um perfil rápido com prompt nativo. Não instala apps de desktop (WhatsApp, Docker Desktop, navegadores, chat); o Docker roda no WSL2 (veja [ubuntu-26.04-wsl2](../ubuntu-26.04-wsl2/README.md)).

| Arquivo | Onde roda | Função |
|---|---|---|
| `install-pwsh7.ps1` | Windows PowerShell 5.1 (Administrador) | Instala ou atualiza o PowerShell 7 x64 e, com `-RunSetup`, abre o setup |
| `setup-pwsh7.ps1` | PowerShell 7 (Administrador) | Configura a workstation em 10 etapas, com resumo no final |
| `Microsoft.PowerShell_profile.ps1` | PowerShell 7 | Perfil implantado pelo setup |

## Requisitos

- Windows 11 (24H2 ou superior para o `sudo` do Windows)
- Conta com permissão de administrador
- winget (App Installer da Microsoft Store)
- Conexão ativa com a Internet

## Como Executar

1. Baixe ou clone este repositório (ex.: `C:\Setup\workstation-setup`).
2. Abra o **Windows PowerShell como Administrador** e entre na pasta:

```powershell
cd C:\Setup\workstation-setup\windows-11-pwsh7
```

3. Rode o instalador. Ele instala o PowerShell 7 e abre o setup numa nova janela:

```powershell
powershell -ExecutionPolicy Bypass -File .\install-pwsh7.ps1 -RunSetup
```

4. Quando o setup terminar, reinicie o Windows e abra o Windows Terminal.

Para rodar o setup de novo depois (ele pula o que já está instalado), abra o PowerShell 7 como Administrador:

```powershell
.\setup-pwsh7.ps1
```

### Parâmetros

| Script | Parâmetro | Uso |
|---|---|---|
| `install-pwsh7.ps1` | `-RunSetup` | Abre o `setup-pwsh7.ps1` ao final |
| `install-pwsh7.ps1` | `-RemoveX86` | Remove o PowerShell 7 de 32 bits, se existir |
| `setup-pwsh7.ps1` | `-UpgradeAll` | Também roda `winget upgrade --all` |
| `setup-pwsh7.ps1` | `-SkipWindowsFeatures` | Não mexe nos recursos do Windows |
| `setup-pwsh7.ps1` | `-SkipProfile` | Não implanta o perfil |
| `setup-pwsh7.ps1` | `-ProxyUrl` | Proxy repassado aos instaladores via `HTTP(S)_PROXY` |

## Etapas do Setup

1. **Pré-requisitos**: Windows 11, winget, reinicialização pendente, ExecutionPolicy `RemoteSigned` e PSGallery confiável.
2. **Certificado corporativo**: detecta inspeção TLS do proxy e gera `~\.certs\ca-bundle.pem` com as raízes confiáveis do Windows. Aponta `REQUESTS_CA_BUNDLE`, `AWS_CA_BUNDLE`, `CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE`, `NODE_EXTRA_CA_CERTS`, `PIP_CERT` e `SSL_CERT_FILE` para ele, para que az, aws e gcloud funcionem.
3. **Recursos do Windows**: WSL, Plataforma de Máquina Virtual, Hyper-V e Cliente Telnet.
4. **Ferramentas de linha de comando** (winget):
   - Terminal: PowerShell 7, Windows Terminal, Git, GitHub CLI, Neovim, fzf, zoxide, eza, ripgrep, fd, bat, delta, jq, yq
   - Kubernetes: kubectl, Helm, k9s, kubectx, kubens, stern, kind, Flux, Argo CD, kubelogin
   - Cloud e IaC: Azure CLI, AWS CLI, Google Cloud SDK, Terraform, Vagrant
5. **Ajustes de desenvolvedor**: Finalizar Tarefa na barra de tarefas, extensões e arquivos ocultos visíveis, caminhos longos, modo de desenvolvedor, `sudo` inline e defaults globais do git.
6. **Fonte Nerd Font**: MesloLGM Nerd Font.
7. **Módulos do PowerShell**: PSReadLine, Terminal-Icons, PSFzf, CompletionPredictor e Az.
8. **Windows Terminal**: PowerShell 7 como perfil padrão e a Nerd Font (com backup do `settings.json`).
9. **Perfil do PowerShell**: copia o perfil para a pasta do PowerShell 7 (com backup) e cria o `profile.local.ps1`.
10. **Atualizar aplicativos**: só com `-UpgradeAll`.

A saída do winget fica em `%TEMP%\setup-pwsh7-<data>\winget.log`.

## Perfil do PowerShell 7

- **Prompt nativo** em PowerShell com hora, RAM, contexto do kubectl, GCP, Azure, AWS, pasta e status do git. Não usa Oh My Posh, então o perfil abre em menos de 1 s e cada prompt leva poucos milissegundos fora de repositórios git.
- **Autocompletar** com cache semanal para kubectl (e o alias `k`), helm, gh, flux e kind, além do Azure CLI.
- **PSReadLine** com predição em lista e histórico/arquivos com fzf (`Ctrl+r` / `Ctrl+t`).
- **Atalhos** de git (`gst`, `gc`, `gp`...), Kubernetes (`kgp`, `kev`, `kbad`, `ksecret`, `knetshoot`) e Docker. Sem Docker Desktop, o comando `docker` usa o Docker do WSL.
- **Troca de conta** com fzf: `awsp`, `azsub` e `gcpp`.
- **Proxy corporativo**: `proxy-on` e `proxy-off`, usando o `$global:ProxyUrl` definido no `profile.local.ps1`.

Personalizações vão no `profile.local.ps1`, na mesma pasta do perfil. O setup nunca sobrescreve esse arquivo.

## Licença

Distribuído sob a [Licença MIT](./LICENSE).
