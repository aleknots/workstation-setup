# =======================================================================
#  INITIAL WINDOWS 11 WORKSTATION SETUP SCRIPT - SRE / DEVOPS
# =======================================================================
#
#  OVERVIEW
# -----------------------------------------------------------------------
#  This script automates initial setup of a clean Windows 11 installation:
#
#  - Essential tools and runtimes installation
#  - Windows optional features enablement (WSL, Telnet, Virtual Machine Platform, Hyper-V)
#  - Applications installation via Chocolatey and winget
#
#  Designed for execution immediately following OS installation.
#
#  REQUIREMENTS
# -----------------------------------------------------------------------
#  - Windows 11 Pro (recommended)
#  - Administrator privileges
#  - Active internet connection
#
#  EXECUTION POLICY
# -----------------------------------------------------------------------
#  Before running this script, enable script execution:
#
#  Open PowerShell as Administrator and run:
#
#      Set-ExecutionPolicy RemoteSigned -Scope LocalMachine -Force
#
#  Verify current policies:
#
#      Get-ExecutionPolicy -List
#
# =======================================================================

$ErrorActionPreference = 'Stop'

function Write-Step {
    param([string]$Message)
    Write-Host "`n==> $Message" -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Gray
}

function Write-Ok {
    param([string]$Message)
    Write-Host "[OK] $Message" -ForegroundColor Green
}

function Write-WarnMsg {
    param([string]$Message)
    Write-Warning $Message
}

function Test-PendingReboot {
    $paths = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )

    foreach ($path in $paths) {
        if (Test-Path $path) {
            return $true
        }
    }

    try {
        $pendingFileRename = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name 'PendingFileRenameOperations' -ErrorAction SilentlyContinue
        if ($null -ne $pendingFileRename) {
            return $true
        }
    }
    catch {
        # ignorar
    }

    return $false
}

function Refresh-Path {
    $machinePath = [System.Environment]::GetEnvironmentVariable('Path', 'Machine')
    $userPath = [System.Environment]::GetEnvironmentVariable('Path', 'User')
    $env:Path = "$machinePath;$userPath"
}

function Install-ChocoPackage {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [switch]$IgnoreChecksums
    )

    $args = @('install', $Name, '-y', '--force', '--force-dependencies', '--no-progress')

    if ($IgnoreChecksums) {
        $args += '--ignore-checksums'
    }

    & choco @args
}

function Test-CommandExists {
    param([string]$Name)
    return [bool](Get-Command $Name -ErrorAction SilentlyContinue)
}

# Executar PowerShell como Administrador
Write-Step "Verificando permissões de administrador"
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-WarnMsg "Este script requer permissões de administrador. Por favor, execute-o novamente como administrador."
    exit 1
}
Write-Ok "Permissões de administrador verificadas com sucesso."

# 0. Verificar versão do Windows
Write-Host "==> Verificando versão do Windows" -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem
$buildNumber = [int]$os.BuildNumber
$caption = $os.Caption

Write-Host "SO Detectado: $caption (Build $buildNumber)"

if ($buildNumber -lt 22000) {
    Write-Warning "Este script foi desenvolvido para o Windows 11. A build detectada é inferior a 22000."
}
else {
    Write-Host "[OK] Windows 11 detectado." -ForegroundColor Green
}

# 1. Instalar fonte Meslo Nerd Font para renderização no terminal
Write-Step "Instalando a fonte MesloLGS NF"
try {
    $mesloFontName = 'MesloLGS NF Regular'
    $mesloFontFileName = 'MesloLGS NF Regular.ttf'
    $mesloFontUrl = 'https://github.com/romkatv/powerlevel10k-media/raw/master/MesloLGS%20NF%20Regular.ttf'
    $mesloFontTempPath = Join-Path $env:TEMP $mesloFontFileName
    $mesloFontInstallPath = Join-Path $env:WINDIR "Fonts\$mesloFontFileName"
    $fontsRegistryPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $fontsRegistryName = "$mesloFontName (TrueType)"

    if (-not (Test-Path $mesloFontInstallPath)) {
        Invoke-WebRequest -Uri $mesloFontUrl -OutFile $mesloFontTempPath -UseBasicParsing
        Copy-Item -Path $mesloFontTempPath -Destination $mesloFontInstallPath -Force
        Remove-Item -Path $mesloFontTempPath -Force -ErrorAction SilentlyContinue
        Write-Ok "Arquivo de fonte $mesloFontName instalado."
    }
    else {
        Write-Ok "Arquivo de fonte $mesloFontName já instalado."
    }

    New-ItemProperty -Path $fontsRegistryPath -Name $fontsRegistryName -Value $mesloFontFileName -PropertyType String -Force | Out-Null
    Write-Ok "Fonte $mesloFontName registrada nas fontes do Windows."
}
catch {
    Write-WarnMsg "Não foi possível instalar a fonte MesloLGS NF: $($_.Exception.Message)"
}

# 2. Habilitar opções de produtividade de desenvolvedor no Windows
Write-Step "Configurando opções de produtividade do desenvolvedor no Windows"
try {
    $taskbarDeveloperSettingsPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
    if (-not (Test-Path $taskbarDeveloperSettingsPath)) {
        New-Item -Path $taskbarDeveloperSettingsPath -Force | Out-Null
    }

    Set-ItemProperty -Path $taskbarDeveloperSettingsPath -Name 'TaskbarEndTask' -Type DWord -Value 1
    Write-Ok "Opção Finalizar Tarefa na barra de tarefas habilitada para o usuário atual."
}
catch {
    Write-WarnMsg "Não foi possível habilitar a opção Finalizar Tarefa: $($_.Exception.Message)"
}

try {
    if ($buildNumber -ge 26100 -and (Test-CommandExists -Name 'sudo.exe')) {
        & sudo config --enable normal
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "Sudo para Windows habilitado no modo inline."
        }
        else {
            Write-WarnMsg "O comando sudo retornou o código de saída $LASTEXITCODE."
        }
    }
    elseif ($buildNumber -lt 26100) {
        Write-WarnMsg "O Sudo para Windows requer Windows 11 24H2 ou superior. Ignorando configuração de sudo inline."
    }
    else {
        Write-WarnMsg "sudo.exe não foi encontrado. Ignorando configuração de sudo inline."
    }
}
catch {
    Write-WarnMsg "Não foi possível habilitar o modo inline do Sudo para Windows: $($_.Exception.Message)"
}

# 3. Verificar reinicializações pendentes
Write-Step "Verificando reinicializações pendentes"

$rebootRequired = $false

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
    $rebootRequired = $true
}

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    $rebootRequired = $true
}

if ($rebootRequired) {
    Write-Host "[INFO] Reinicialização pendente detectada, continuando mesmo assim..." -ForegroundColor Yellow
}
else {
    Write-Ok "Nenhuma reinicialização pendente."
}

# 4. Detectar arquitetura do sistema operacional
Write-Step "Detectando arquitetura do sistema operacional"
$arch = if ([Environment]::Is64BitOperatingSystem) { 'x64' } else { 'x86' }
Write-Ok "Arquitetura detectada: $arch"

# 5. Garantir que o Chocolatey está instalado
Write-Step "Verificando instalação do Chocolatey"
if (-not (Test-CommandExists -Name 'choco.exe')) {
    Write-Info "Chocolatey não encontrado. Instalando..."
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    try {
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        Refresh-Path
        Write-Ok "Chocolatey instalado com sucesso."
    }
    catch {
        Write-Error "Falha ao instalar o Chocolatey: $($_.Exception.Message)"
        exit 1
    }
}
else {
    Write-Info "Chocolatey já instalado. Atualizando o Chocolatey..."
    & choco upgrade chocolatey -y --no-progress
    Refresh-Path
    Write-Ok "Chocolatey pronto para uso."
}

# Habilitar recurso de confirmação global no Chocolatey
& choco feature enable -n allowGlobalConfirmation | Out-Null

# 6. Verificar se o winget está disponível e atualizar aplicativos instalados
Write-Step "Verificando disponibilidade do winget"
$wingetAvailable = Test-CommandExists -Name 'winget.exe'
if ($wingetAvailable) {
    Write-Ok "winget detectado."
    try {
        Write-Step "Atualizando aplicações via winget"
        & winget upgrade --all --include-unknown --accept-package-agreements --accept-source-agreements --disable-interactivity
        Write-Ok "Atualização de aplicações via winget concluída."
    }
    catch {
        Write-WarnMsg "Falha ao executar o winget upgrade. Erro: $($_.Exception.Message)"
    }
}
else {
    Write-WarnMsg "winget não foi encontrado. As instalações via winget serão ignoradas."
}

# 7. Habilitar Recursos do Windows (Cliente Telnet, WSL, Plataforma de Máquina Virtual, Hyper-V)
Write-Step "Habilitando Recursos do Windows (Telnet, WSL, Virtual Machine Platform, Hyper-V)"
$featuresToEnable = @(
    'TelnetClient',
    'Microsoft-Windows-Subsystem-Linux',
    'VirtualMachinePlatform',
    'Microsoft-Hyper-V-All'
)

foreach ($feature in $featuresToEnable) {
    try {
        Write-Info "Habilitando recurso: $feature ..."
        & dism.exe /online /enable-feature "/featurename:$feature" /all /norestart | Out-Null
        Write-Ok "Recurso $feature habilitado."
    }
    catch {
        Write-WarnMsg "Falha ao habilitar recurso $feature. Erro: $($_.Exception.Message)"
    }
}

# 8. Instalar runtimes essenciais via Chocolatey
Write-Step "Instalando runtimes essenciais"
try {
    & choco install dotnet-desktopruntime vcredist140 dotnet-6.0-desktopruntime -y --force --force-dependencies --no-progress
    Write-Ok "Runtimes essenciais instalados com sucesso."
}
catch {
    Write-WarnMsg "Falha ao instalar runtimes essenciais. Erro: $($_.Exception.Message)"
}

# 9. Instalação consolidada de pacotes via Chocolatey
Write-Step "Preparando lista de pacotes para instalação"

$packagesToInstall = @(

    # Trabalho / DevOps / SRE

    'vscode',
    'cursoride',
    'antigravity',
    'git',
    'terraform',
    'vagrant',
    'azurepowershell',
    'azure-cli',
    'microsoftazurestorageexplorer',
    'awscli',
    'argocd-cli',
    'k9s',
    'kubernetes-helm',
    'slack',
    'microsoft-teams-new-bootstrapper',
    'postman',

    # Pessoal / Opcional

    #'discord',
    #'epicgameslauncher',
    #'steam',
    #'nvidia-display-driver',
    #'nvidia-app',
    #'docker-desktop', # Docker Engine é instalado via WSL2
    'ccleaner',
    'zoom',
    'googledrive',
    'googlechrome',
    'firefox',
    'rdm',
    'obs-studio',
    'notion',
    'obsidian',
    'webview2-runtime',
    'powertoys',
    'sublimetext4',
    'oh-my-posh',
    'treesizefree'
) 

$packagesWithIgnoredChecksums = @(
    'notion',
    'googledrive',
    'microsoftazurestorageexplorer',
    'googlechrome'
)

Write-Step "Iniciando instalação dos pacotes Chocolatey selecionados"

foreach ($package in $packagesToInstall) {
    Write-Info "Instalando $package ..."
    try {
        if ($package -in $packagesWithIgnoredChecksums) {
            Install-ChocoPackage -Name $package -IgnoreChecksums
        }
        else {
            Install-ChocoPackage -Name $package
        }
        Write-Ok "$package instalado com sucesso."
    }
    catch {
        Write-WarnMsg "Falha ao instalar o pacote $package. Erro: $($_.Exception.Message)"
    }
}

Write-Step "Instalando Flameshot 12.1.0 (versão estável)"
try {
    choco install flameshot --version=12.1.0 -y
    if ($LASTEXITCODE -eq 0) {
        choco pin add -n=flameshot | Out-Null
        Write-Ok "Flameshot 12.1.0 instalado e fixado com sucesso."
    }
    else {
        Write-WarnMsg "A instalação do Flameshot 12.1.0 retornou o código de saída $LASTEXITCODE."
    }
}
catch {
    Write-WarnMsg "Falha ao instalar o Flameshot 12.1.0. Erro: $($_.Exception.Message)"
}

# 10. Atualizar o próprio winget (App Installer)
if ($wingetAvailable) {
    Write-Step "Atualizando winget (App Installer)"
    try {
        & winget upgrade --id Microsoft.DesktopAppInstaller --accept-package-agreements --accept-source-agreements --disable-interactivity
        Write-Ok "Atualização do winget concluída."
    }
    catch {
        Write-WarnMsg "Falha ao atualizar o winget. Erro: $($_.Exception.Message)"
    }
}

# 11. Instalando WhatsApp
Write-Step "Instalando WhatsApp"

try {
    winget install 9NKSQGP7F2NH `
        --source msstore `
        --accept-package-agreements `
        --accept-source-agreements `
        --silent `
        --disable-interactivity

    Write-Ok "Instalação do WhatsApp solicitada."
}
catch {
    Write-WarnMsg "Instalação do WhatsApp falhou. Instale manualmente via Microsoft Store."
}

# 12. Verificar e instalar PowerShell 7
Write-Step "Verificando se o PowerShell 7 (pwsh) está instalado"
if (-not (Test-CommandExists -Name 'pwsh.exe')) {
    if ($wingetAvailable) {
        Write-Info "PowerShell 7 não encontrado. Instalando via winget..."
        try {
            & winget install --id Microsoft.PowerShell --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
            Write-Ok "Instalação do PowerShell 7 solicitada."
        }
        catch {
            Write-WarnMsg "Falha ao instalar o PowerShell 7 via winget. Erro: $($_.Exception.Message)"
        }
    }
    else {
        Write-WarnMsg "PowerShell 7 não está instalado e o winget não está disponível, instalação ignorada."
    }
}
else {
    Write-Ok "PowerShell 7 (pwsh) já está instalado."
}

# 13. Verificar e instalar GitHub CLI (gh)
Write-Step "Verificando se o GitHub CLI (gh) está instalado"
if (-not (Test-CommandExists -Name 'gh.exe')) {
    if ($wingetAvailable) {
        Write-Info "GitHub CLI não encontrado. Instalando via winget..."
        try {
            & winget install --id GitHub.cli --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
            Write-Ok "Instalação do GitHub CLI solicitada."
        }
        catch {
            Write-WarnMsg "Falha ao instalar o GitHub CLI via winget. Erro: $($_.Exception.Message)"
        }
    }
    else {
        Write-WarnMsg "GitHub CLI não está instalado e o winget não está disponível, instalação ignorada."
    }
}
else {
    Write-Ok "GitHub CLI (gh) já está instalado."
}

# 14. Instalar VMware PowerCLI para o PowerShell 7
Write-Step "Instalando VMware PowerCLI para PowerShell 7"
if (Test-CommandExists -Name 'pwsh.exe') {
    try {
        Write-Info "Configurando PSGallery e instalando VMware.PowerCLI..."
        $pwshCommand = "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction SilentlyContinue; Install-Module -Name VMware.PowerCLI -Scope CurrentUser -Repository PSGallery -AllowClobber -Force"
        & pwsh.exe -ExecutionPolicy Bypass -NoProfile -Command $pwshCommand
        if ($LASTEXITCODE -eq 0) {
            Write-Ok "VMware.PowerCLI instalado com sucesso para PowerShell 7."
        }
        else {
            Write-WarnMsg "pwsh retornou o código de saída $LASTEXITCODE durante a instalação do VMware.PowerCLI."
        }
    }
    catch {
        Write-WarnMsg "Falha ao instalar VMware.PowerCLI. Erro: $($_.Exception.Message)"
    }
}
else {
    Write-WarnMsg "PowerShell 7 (pwsh) não está instalado ou não está no PATH. Execute esta etapa manualmente mais tarde."
}

# Mensagem final
Write-Host ''
Write-Host '=======================================================' -ForegroundColor Green
Write-Host '  SCRIPT DE CONFIGURAÇÃO CONCLUÍDO!' -ForegroundColor Green
Write-Host '=======================================================' -ForegroundColor Green
Write-Host ''
Write-Host 'ATENÇÃO:' -ForegroundColor Yellow
Write-Host '- É altamente recomendável reiniciar o sistema para aplicar todas as alterações.'
Write-Host '- Se o Ubuntu 24.04 foi ignorado por conta de reinicialização pendente, reinicie o Windows e execute: wsl --install -d Ubuntu-24.04'
Write-Host '- O Hyper-V foi habilitado nesta configuração para WSL2 e fluxos de contêineres.'
Write-Host ''
Write-Host 'Obrigado por utilizar este script de configuração!' -ForegroundColor Green
Write-Host 'Script desenvolvido por Aleon Chagas' -ForegroundColor DarkGray
