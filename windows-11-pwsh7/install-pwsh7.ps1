#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Instala (ou atualiza) o PowerShell 7 x64 e, opcionalmente, abre o setup-pwsh7.ps1 nele.

.DESCRIPTION
    Roda no Windows PowerShell 5.1 que já vem com o Windows.
    1. Instala o PowerShell 7 x64 via winget; sem winget, baixa o MSI oficial do GitHub.
    2. Avisa se existe um PowerShell 7 de 32 bits (ou remove com -RemoveX86).
    3. Com -RunSetup, abre o setup-pwsh7.ps1 (mesma pasta) num PowerShell 7 como Administrador.

.PARAMETER RunSetup
    Ao final, executa o setup-pwsh7.ps1 que está na mesma pasta deste script.

.PARAMETER RemoveX86
    Remove o PowerShell 7 de 32 bits, se existir. Ele costuma ser aberto por atalhos
    antigos no lugar do de 64 bits.

.EXAMPLE
    # Num Windows PowerShell aberto como Administrador, na pasta dos scripts:
    powershell -ExecutionPolicy Bypass -File .\install-pwsh7.ps1 -RunSetup

.NOTES
    Script desenvolvido por Aleon Chagas
#>
[CmdletBinding()]
param(
    [switch]$RunSetup,
    [switch]$RemoveX86
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Proxy corporativo com autenticação integrada
if ([Net.WebRequest]::DefaultWebProxy) {
    [Net.WebRequest]::DefaultWebProxy.Credentials = [Net.CredentialCache]::DefaultNetworkCredentials
}

$PwshPath = Join-Path $env:ProgramFiles 'PowerShell\7\pwsh.exe'
$SetupScript = Join-Path $PSScriptRoot 'setup-pwsh7.ps1'

function Write-Step([string]$Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function Write-Ok([string]$Text) { Write-Host "  [OK] $Text" -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host "  [!!] $Text" -ForegroundColor Yellow }
function Write-Fail([string]$Text) { Write-Host "  [XX] $Text" -ForegroundColor Red }

function Get-PwshVersion {
    if (-not (Test-Path $PwshPath)) { return $null }
    (& $PwshPath -NoProfile -NoLogo -Command '$PSVersionTable.PSVersion.ToString()') | Select-Object -First 1
}

function Install-WithWinget {
    $arguments = @(
        'install', '--id', 'Microsoft.PowerShell', '--exact', '--source', 'winget',
        '--architecture', 'x64', '--silent',
        '--accept-package-agreements', '--accept-source-agreements', '--disable-interactivity'
    )
    & winget @arguments | Out-Null
    # 0x8A15002B: nenhuma atualização disponível; 0x8A150061: já instalado
    $LASTEXITCODE -in 0, -1978335189, -1978335135
}

function Install-WithMsi {
    $release = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
    $asset = $release.assets | Where-Object { $_.name -match '^PowerShell-.*-win-x64\.msi$' } | Select-Object -First 1
    if (-not $asset) { throw 'MSI x64 não encontrado na última release do PowerShell.' }

    $msi = Join-Path $env:TEMP $asset.name
    Write-Host "  Baixando $($asset.name)..."
    Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $msi
    try {
        $msiArgs = "/i `"$msi`" /qn ADD_PATH=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1"
        $process = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
        # 3010: instalado, requer reinicialização
        $process.ExitCode -in 0, 3010
    }
    finally {
        Remove-Item $msi -Force -ErrorAction SilentlyContinue
    }
}

# --- 1. PowerShell 7 x64 ----------------------------------------------------
Write-Step 'PowerShell 7 (x64)'
$before = Get-PwshVersion
if ($before) { Write-Host "  Versão atual: $before" }

$installed = $false
if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
    Write-Host '  Instalando/atualizando via winget...'
    $installed = Install-WithWinget
    if (-not $installed) { Write-Warn "winget retornou $LASTEXITCODE; tentando o MSI do GitHub." }
}
else {
    Write-Warn 'winget não encontrado; usando o MSI do GitHub.'
}
if (-not $installed) {
    try { $installed = Install-WithMsi }
    catch { Write-Fail "Falha ao instalar pelo MSI: $($_.Exception.Message)" }
}

$after = Get-PwshVersion
if (-not $after) {
    Write-Fail 'PowerShell 7 não foi instalado. Veja as mensagens acima.'
    exit 1
}
if ($before -and $before -eq $after) { Write-Ok "PowerShell $after já estava atualizado" }
else { Write-Ok "PowerShell $after instalado em $PwshPath" }

# --- 2. PowerShell 7 de 32 bits ---------------------------------------------
Write-Step 'PowerShell 7 de 32 bits'
$x86 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
    Where-Object { $_.DisplayName -like 'PowerShell 7*x86*' }
if (-not $x86) {
    Write-Ok 'Não instalado'
}
elseif ($RemoveX86) {
    foreach ($entry in $x86) {
        $process = Start-Process msiexec.exe -ArgumentList "/x $($entry.PSChildName) /qn" -Wait -PassThru
        if ($process.ExitCode -in 0, 3010) { Write-Ok "$($entry.DisplayName) removido" }
        else { Write-Fail "$($entry.DisplayName): msiexec retornou $($process.ExitCode)" }
    }
}
else {
    Write-Warn "$($x86[0].DisplayName) está instalado. Rode de novo com -RemoveX86 para removê-lo."
}

# --- 3. Setup ----------------------------------------------------------------
if ($RunSetup) {
    Write-Step 'Setup da workstation'
    if (-not (Test-Path $SetupScript)) {
        Write-Fail "setup-pwsh7.ps1 não encontrado em $PSScriptRoot"
        exit 1
    }
    # Arquivos baixados ou vindos de compartilhamento ficam bloqueados para RemoteSigned
    Get-ChildItem $PSScriptRoot -Filter '*.ps1' | Unblock-File
    Write-Host '  Abrindo o setup no PowerShell 7 (nova janela)...'
    Start-Process $PwshPath -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$SetupScript`""
}
else {
    Write-Host "`nPróximo passo: abra o PowerShell 7 como Administrador e rode .\setup-pwsh7.ps1" -ForegroundColor Cyan
    Write-Host '(ou rode este script com -RunSetup)' -ForegroundColor DarkGray
}
