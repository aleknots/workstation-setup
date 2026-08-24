# Script de Configuração Inicial da Workstation Windows 11 (DevOps / SRE)

## Visão Geral

Este script PowerShell automatiza a configuração inicial de uma instalação limpa do Windows 11, preparando o sistema para fluxos de trabalho de SRE, DevOps e engenharia de nuvem.

A automação inclui a instalação de ferramentas CLI essenciais, habilitação de recursos opcionais do Windows, instalação de runtimes, utilitários de desenvolvimento e softwares de produtividade via Chocolatey e winget.

Projetado para ser executado imediatamente após a instalação do Windows.

## Requisitos

- Windows 11 Pro (recomendado)
- PowerShell executado como Administrador
- Conexão ativa com a Internet

> **IMPORTANTE:** Antes de prosseguir, verifique se o Windows está totalmente atualizado. Instale todas as atualizações pendentes do Windows Update e **reinicie o seu PC**. Executar este script com atualizações pendentes do sistema pode causar falhas de instalação.

### Política de Execução (Execution Policy)

Antes de executar o script, habilite a execução de scripts no PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
```

Para verificar as políticas de execução atuais:

```powershell
Get-ExecutionPolicy -List
```

## Como Executar

1. Baixe ou clone este repositório para um diretório (ex: `C:\Setup\workstation-setup`).
2. Abra o PowerShell como Administrador.
3. Navegue até a pasta `windows-11-pro`:

```powershell
cd C:\Setup\workstation-setup\windows-11-pro
```

4. Desbloqueie o script caso esteja restrito pela Política de Execução do Windows:

```powershell
Unblock-File -Path "C:\Setup\workstation-setup\windows-11-pro\windows-setup.ps1"
```

5. Execute o script:

```powershell
.\windows-setup.ps1
```

## Componentes Instalados

### Recursos de Desenvolvedor do Windows
- Habilita `Finalizar Tarefa` no menu de contexto ao clicar com botão direito na barra de tarefas.
- Habilita modo inline do `Sudo para Windows` quando suportado (Windows 11 24H2+).

### Fontes para Terminal
- Instala a fonte `MesloLGS NF Regular` para ícones do Oh My Posh e Nerd Fonts.

### Ferramentas Essenciais
- PowerShell 7, Git, Terraform, Vagrant, Visual Studio Code

### Ferramentas de Nuvem & DevOps
- Azure CLI, Azure PowerShell, AWS CLI, ArgoCD CLI, k9s, Helm, WSL2 + Ubuntu 24.04

### Produtividade & Utilitários
- Google Chrome, PowerToys, TreeSize Free, Sublime Text, oh-my-posh, WebView2 Runtime, Slack, Microsoft Teams, Zoom, Azure Storage Explorer, WhatsApp

## Configuração do WSL2 e Ubuntu 24.04

1. Após a conclusão do script, reinicie o Windows.
2. Abra o Windows Terminal / PowerShell como Administrador.
3. Se os recursos virtuais do WSL foram habilitados durante a execução inicial, instale o Ubuntu 24.04:

```powershell
wsl --install -d Ubuntu-24.04
```

## Configuração de Fonte no Terminal

Configure as opções do Windows Terminal para usar a fonte instalada:

```text
MesloLGS NF
```

## Licença

Distribuído sob a [Licença MIT](../LICENSE).
