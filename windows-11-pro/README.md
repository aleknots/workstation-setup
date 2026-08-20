# Initial Windows 11 Workstation Setup Script (DevOps / SRE)

## Overview

This PowerShell script automates the initial configuration of a fresh Windows 11 installation, preparing the system for SRE, DevOps, and cloud engineering workflows.

Automation includes installing essential CLI tools, enabling Windows optional features, installing runtimes, development utilities, and productivity software via Chocolatey and winget.

Designed to be executed immediately following Windows installation.

## Requirements

- Windows 11 Pro (recommended)
- PowerShell executed as Administrator
- Active internet connection

> **IMPORTANT:** Before proceeding, verify Windows is fully updated. Install any pending Windows Update patches and **reboot your PC**. Running this script with pending system updates may cause installation failures.

### Execution Policy

Before running the script, enable PowerShell script execution:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
```

To verify current execution policies:

```powershell
Get-ExecutionPolicy -List
```

## How to Run

1. Download or clone this repository to a directory (e.g. `C:\Setup\workstation-setup`).
2. Open PowerShell as Administrator.
3. Navigate to `windows-11-pro` folder:

```powershell
cd C:\Setup\workstation-setup\windows-11-pro
```

4. Unblock script if restricted by Windows Execution Policy:

```powershell
Unblock-File -Path "C:\Setup\workstation-setup\windows-11-pro\windows-setup.ps1"
```

5. Execute script:

```powershell
.\windows-setup.ps1
```

## Installed Components

### Windows Developer Features
- Enables `End Task` in taskbar right-click context menu.
- Enables `Sudo for Windows` inline mode when supported (Windows 11 24H2+).

### Terminal Fonts
- Installs `MesloLGS NF Regular` font for Oh My Posh icons and Nerd Fonts.

### Essential Tooling
- PowerShell 7, Git, Terraform, Vagrant, Visual Studio Code

### Cloud & DevOps Tools
- Azure CLI, Azure PowerShell, AWS CLI, ArgoCD CLI, k9s, Helm, WSL2 + Ubuntu 24.04

### Productivity & Utilities
- Google Chrome, PowerToys, TreeSize Free, Sublime Text, oh-my-posh, WebView2 Runtime, Slack, Microsoft Teams, Zoom, Azure Storage Explorer, WhatsApp

## WSL2 and Ubuntu 24.04 Setup

1. After script completion, reboot Windows.
2. Open Windows Terminal / PowerShell as Administrator.
3. If WSL virtual features were enabled during initial run, install Ubuntu 24.04:

```powershell
wsl --install -d Ubuntu-24.04
```

## Terminal Font Setup

Configure Windows Terminal settings to use installed font:

```text
MesloLGS NF
```

## License

Distributed under the [MIT License](../LICENSE).
