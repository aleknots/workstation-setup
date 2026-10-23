#Requires -Version 7.4
#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configura a workstation Windows 11 para SRE/DevOps com foco no PowerShell 7.

.DESCRIPTION
    - Habilita os recursos do Windows usados pelo WSL2 (WSL, VM Platform, Hyper-V, Telnet)
    - Instala as CLIs de DevOps via winget (sem Chocolatey)
    - Aplica ajustes de desenvolvedor (Finalizar Tarefa, sudo, caminhos longos, git)
    - Instala a Nerd Font (via oh-my-posh) e os módulos do PowerShell
    - Configura o Windows Terminal (PowerShell 7 como padrão e fonte)
    - Implanta o perfil (com prompt nativo) que fica na mesma pasta deste script

    Não instala apps de desktop (WhatsApp, Docker Desktop, navegadores, chat...):
    o Docker roda no WSL e o perfil expõe o comando `docker` a partir dele.

.PARAMETER UpgradeAll
    Ao final, também atualiza todos os aplicativos com `winget upgrade --all`.

.PARAMETER SkipWindowsFeatures
    Não habilita recursos do Windows.

.PARAMETER SkipProfile
    Não copia o perfil para a pasta do PowerShell.

.PARAMETER ProxyUrl
    Proxy corporativo repassado aos instaladores via HTTP(S)_PROXY. Necessário quando
    a rede só sai pelo proxy: alguns instaladores (ex.: Google Cloud SDK) baixam
    componentes por conta própria e ignoram o proxy/PAC do Windows.

.EXAMPLE
    # Num PowerShell 7 aberto como Administrador, na pasta do script:
    .\setup-pwsh7.ps1
    .\setup-pwsh7.ps1 -UpgradeAll
    .\setup-pwsh7.ps1 -ProxyUrl http://proxy.empresa:3128

.NOTES
    Pré-requisito numa máquina limpa: rode o install-pwsh7.ps1 (mesma pasta) no
    Windows PowerShell como Administrador; com -RunSetup ele já abre este script:
        powershell -ExecutionPolicy Bypass -File .\install-pwsh7.ps1 -RunSetup
    Se a execução de scripts estiver bloqueada:
        Set-ExecutionPolicy RemoteSigned -Scope CurrentUser -Force

    Script desenvolvido por Aleon Chagas
#>
[CmdletBinding()]
param(
    [switch]$UpgradeAll,
    [switch]$SkipWindowsFeatures,
    [switch]$SkipProfile,
    [string]$ProxyUrl
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()

# Herdado pelo winget e pelos instaladores que ele executa
if ($ProxyUrl) {
    $env:HTTP_PROXY = $env:HTTPS_PROXY = $ProxyUrl
    $env:NO_PROXY = 'localhost,127.0.0.1,::1,.local,10.0.0.0/8,172.16.0.0/12,192.168.0.0/16'
}

# =============================================================================
#  Configuração
# =============================================================================

$WindowsFeatures = [ordered]@{
    'Microsoft-Windows-Subsystem-Linux' = 'Subsistema do Windows para Linux'
    'VirtualMachinePlatform'            = 'Plataforma de Máquina Virtual'
    'Microsoft-Hyper-V-All'             = 'Hyper-V'
    'TelnetClient'                      = 'Cliente Telnet'
}

$WingetPackages = [ordered]@{
    'Terminal e shell' = @(
        'Microsoft.PowerShell'
        'Microsoft.WindowsTerminal'
        'JanDeDobbeleer.OhMyPosh'
        'Git.Git'
        'GitHub.cli'
        'Neovim.Neovim'
        'junegunn.fzf'
        'ajeetdsouza.zoxide'
        'eza-community.eza'
        'BurntSushi.ripgrep.MSVC'
        'sharkdp.fd'
        'sharkdp.bat'
        'dandavison.delta'
        'jqlang.jq'
        'MikeFarah.yq'
    )
    'Kubernetes' = @(
        'Kubernetes.kubectl'
        'Helm.Helm'
        'Derailed.k9s'
        'ahmetb.kubectx'
        'ahmetb.kubens'
        'stern.stern'
        'Kubernetes.kind'
        'FluxCD.Flux'
        'argoproj.argocd'
        'Microsoft.Azure.Kubelogin'
    )
    'Cloud e IaC' = @(
        'Microsoft.AzureCLI'
        'Amazon.AWSCLI'
        'Google.CloudSDK'
        'Hashicorp.Terraform'
        'Hashicorp.Vagrant'
    )
    # Apps de desktop opcionais: descomente o que quiser instalar
    'Apps opcionais' = @(
        # 'Microsoft.VisualStudioCode'
        # 'Anysphere.Cursor'
        # 'Postman.Postman'
    )
}

$PSModules = @(
    @{ Name = 'PSReadLine' }
    @{ Name = 'Terminal-Icons' }
    @{ Name = 'PSFzf' }
    @{ Name = 'CompletionPredictor' }
    @{ Name = 'Az'; Note = 'é grande, pode levar alguns minutos' }
)

$GitGlobalConfig = [ordered]@{
    'init.defaultBranch'     = 'main'
    'pull.rebase'            = 'true'
    'push.autoSetupRemote'   = 'true'
    'fetch.prune'            = 'true'
    'core.longpaths'         = 'true'
    'core.pager'             = 'delta'
    'interactive.diffFilter' = 'delta --color-only'
    'delta.navigate'         = 'true'
    'merge.conflictStyle'    = 'zdiff3'
}

# Inspeção TLS: o proxy corporativo reassina o HTTPS com uma CA própria. O Windows
# confia nela, mas CLIs com Python/Node embutido (az, aws, gcloud) usam a própria
# lista de CAs; essas variáveis apontam para um pacote com as raízes do Windows.
$TlsProbeHost    = 'dl.google.com'
$CaBundlePath    = Join-Path $HOME '.certs\ca-bundle.pem'
$CaBundleEnvVars = 'REQUESTS_CA_BUNDLE', 'AWS_CA_BUNDLE', 'CLOUDSDK_CORE_CUSTOM_CA_CERTS_FILE',
                   'NODE_EXTRA_CA_CERTS', 'PIP_CERT', 'SSL_CERT_FILE'

$FontFace          = 'MesloLGM Nerd Font'
$PwshProfileGuid   = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # perfil PowerShell 7 do Windows Terminal
$ProfileFiles      = @('Microsoft.PowerShell_profile.ps1')

# Códigos do winget que significam "já está instalado / nada a atualizar"
$WingetNoop = @(
    0x8A150061   # APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
    0x8A15002B   # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
)

$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $env:TEMP "setup-pwsh7-$Stamp"
$null   = New-Item -ItemType Directory -Path $LogDir -Force
$WingetLog = Join-Path $LogDir 'winget.log'

# =============================================================================
#  Interface
# =============================================================================

$Ui = @{
    Accent = $PSStyle.Foreground.FromRgb(0x00, 0x8A, 0xD7)
    Ok     = $PSStyle.Foreground.BrightGreen
    Warn   = $PSStyle.Foreground.BrightYellow
    Fail   = $PSStyle.Foreground.BrightRed
    Dim    = $PSStyle.Foreground.BrightBlack
    Bold   = $PSStyle.Bold
    Reset  = $PSStyle.Reset
}

$script:Results       = [Collections.Generic.List[object]]::new()
$script:Failures      = [Collections.Generic.List[string]]::new()
$script:RebootNeeded  = $false
$script:StepIndex     = 0
$script:StepTitle     = ''
$script:StepWarnings  = 0
$script:StepFailures  = 0

function Write-Banner {
    $os = Get-CimInstance Win32_OperatingSystem
    $lines = @(
        "$($Ui.Bold)Workstation SRE/DevOps · PowerShell 7$($Ui.Reset)$($Ui.Accent)"
        "$($os.Caption) · build $($os.BuildNumber) · pwsh $($PSVersionTable.PSVersion)"
        "Usuário $env:USERNAME · logs em $LogDir"
        if ($ProxyUrl) { "Proxy $ProxyUrl" }
    )
    $width = ($lines | ForEach-Object { ($_ -replace '\e\[[0-9;]*m').Length } | Measure-Object -Maximum).Maximum + 4
    Write-Host ''
    Write-Host "$($Ui.Accent)╭$('─' * $width)╮"
    foreach ($line in $lines) {
        $pad = $width - 2 - ($line -replace '\e\[[0-9;]*m').Length
        Write-Host "│  $line$(' ' * $pad)│"
    }
    Write-Host "╰$('─' * $width)╯$($Ui.Reset)"
}

function Write-Item {
    param(
        [Parameter(Mandatory)][ValidateSet('Ok', 'Skip', 'Warn', 'Fail', 'Info')][string]$Kind,
        [Parameter(Mandatory)][string]$Text,
        [string]$Detail
    )
    # Símbolos sem versão emoji: têm largura de 1 coluna também no console clássico
    $icon, $color = switch ($Kind) {
        'Ok'   { '✓', $Ui.Ok }
        'Skip' { '•', $Ui.Dim }
        'Warn' { '▲', $Ui.Warn }
        'Fail' { '✗', $Ui.Fail }
        'Info' { '›', $Ui.Accent }
    }
    if ($Kind -eq 'Warn') { $script:StepWarnings++ }
    if ($Kind -eq 'Fail') {
        $script:StepFailures++
        $script:Failures.Add("$($script:StepTitle): $Text$(if ($Detail) { " ($Detail)" })")
    }
    $suffix = if ($Detail) { " $($Ui.Dim)$Detail$($Ui.Reset)" } else { '' }
    Write-Host "  $color$icon$($Ui.Reset) $Text$suffix"
}

function Write-Group([string]$Title) {
    Write-Host "  $($Ui.Dim)── $Title$($Ui.Reset)"
}

function Invoke-Step {
    param([hashtable]$Step, [int]$Total)

    $script:StepIndex++
    $script:StepTitle = $Step.Title
    $script:StepWarnings = 0
    $script:StepFailures = 0
    $counter = '{0:D2}/{1:D2}' -f $script:StepIndex, $Total

    if ($Step.Skip) {
        Write-Host "`n$($Ui.Dim)[$counter] $($Step.Title) · pulado$($Ui.Reset)"
        $script:Results.Add([pscustomobject]@{ Etapa = $Step.Title; Status = 'Pulado'; Tempo = '-' })
        return $true
    }

    Write-Host "`n$($Ui.Accent)$($Ui.Bold)[$counter]$($Ui.Reset) $($Ui.Bold)$($Step.Title)$($Ui.Reset)"
    $timer = [Diagnostics.Stopwatch]::StartNew()
    $ok = $true
    try {
        $null = & $Step.Action
        $status = if ($script:StepFailures) { 'Parcial' } elseif ($script:StepWarnings) { 'Aviso' } else { 'OK' }
    }
    catch {
        Write-Item Fail $_.Exception.Message
        $status = 'Falha'
        $ok = $false
    }
    $script:Results.Add([pscustomobject]@{
        Etapa  = $Step.Title
        Status = $status
        Tempo  = '{0:mm\:ss}' -f $timer.Elapsed
    })
    return $ok
}

function Write-Summary([TimeSpan]$Elapsed) {
    $colors = @{ OK = $Ui.Ok; Aviso = $Ui.Warn; Parcial = $Ui.Warn; Falha = $Ui.Fail; Pulado = $Ui.Dim }

    Write-Host "`n$($Ui.Accent)$('─' * 64)$($Ui.Reset)"
    Write-Host ("$($Ui.Bold)Resumo$($Ui.Reset) $($Ui.Dim)· {0:mm\:ss} no total$($Ui.Reset)" -f $Elapsed)
    foreach ($r in $script:Results) {
        Write-Host ('  {0}{1,-8}{2} {3,-44} {4}{5}{2}' -f $colors[$r.Status], $r.Status, $Ui.Reset, $r.Etapa, $Ui.Dim, $r.Tempo)
    }

    if ($script:Failures.Count) {
        Write-Host "`n$($Ui.Fail)$($Ui.Bold)Itens com falha$($Ui.Reset)"
        $script:Failures | ForEach-Object { Write-Host "  $($Ui.Fail)✗$($Ui.Reset) $_" }
        Write-Host "  $($Ui.Dim)Detalhes do winget: $WingetLog$($Ui.Reset)"
    }

    Write-Host "`n$($Ui.Bold)Próximos passos$($Ui.Reset)"
    if ($script:RebootNeeded) {
        Write-Host "  $($Ui.Warn)▲$($Ui.Reset) Reinicie o Windows para concluir a ativação dos recursos."
    }
    Write-Host "  $($Ui.Accent)›$($Ui.Reset) Abra uma nova aba do Windows Terminal (PowerShell 7 é o padrão)."
    Write-Host "  $($Ui.Accent)›$($Ui.Reset) Proxy e ajustes pessoais: $($Ui.Dim)profile.local.ps1$($Ui.Reset) na pasta do perfil."
    Write-Host "  $($Ui.Accent)›$($Ui.Reset) Logins: gh auth login · az login · aws configure sso · gcloud init"
    Write-Host "`n$($Ui.Dim)Script desenvolvido por Aleon Chagas$($Ui.Reset)`n"
}

# =============================================================================
#  Utilitários
# =============================================================================

function Test-Cmd([string]$Name) {
    [bool](Get-Command $Name -CommandType Application -ErrorAction Ignore)
}

function Update-SessionPath {
    $env:Path = @(
        [Environment]::GetEnvironmentVariable('Path', 'Machine')
        [Environment]::GetEnvironmentVariable('Path', 'User')
    ) -join ';'
}

function Test-PendingReboot {
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    )
    ($keys | Where-Object { Test-Path $_ }).Count -gt 0
}

function Invoke-Winget {
    param([Parameter(Mandatory)][string[]]$Arguments)
    $output = & winget @Arguments --accept-source-agreements --disable-interactivity 2>&1
    $exitCode = $LASTEXITCODE
    "`n### winget $($Arguments -join ' ') => $exitCode`n$($output -join "`n")" |
        Out-File -FilePath $WingetLog -Append -Encoding utf8
    $exitCode
}

function Install-WingetPackage([string]$Id) {
    if ((Invoke-Winget 'list', '--id', $Id, '--exact') -eq 0) {
        Write-Item Skip $Id 'já instalado'
        return
    }
    $code = Invoke-Winget 'install', '--id', $Id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements'
    if ($code -eq 0) { Write-Item Ok $Id 'instalado' }
    elseif ($code -in $WingetNoop) { Write-Item Skip $Id 'já instalado' }
    else { Write-Item Fail $Id ('winget retornou 0x{0:X8}' -f $code) }
}

# Cadeia de certificados que o cliente recebe de fato (via HTTPS_PROXY, se houver)
function Get-TlsChain([string]$HostName) {
    $proxy = if ($env:HTTPS_PROXY) { [Uri]$env:HTTPS_PROXY }
    $endpoint = if ($proxy) { $proxy } else { [Uri]"https://$HostName" }
    $tcp = [Net.Sockets.TcpClient]::new()
    try {
        if (-not $tcp.ConnectAsync($endpoint.Host, $endpoint.Port).Wait(10000)) {
            throw "sem resposta de $($endpoint.Host):$($endpoint.Port)"
        }
        $stream = $tcp.GetStream()
        $stream.ReadTimeout = 10000
        if ($proxy) {
            $connect = [Text.Encoding]::ASCII.GetBytes("CONNECT ${HostName}:443 HTTP/1.1`r`nHost: ${HostName}:443`r`n`r`n")
            $stream.Write($connect, 0, $connect.Length)
            $buffer = [byte[]]::new(4096)
            $read = $stream.Read($buffer, 0, $buffer.Length)
            $status = ([Text.Encoding]::ASCII.GetString($buffer, 0, $read) -split "`r`n")[0]
            if ($status -notmatch ' 200 ') { throw "proxy recusou o CONNECT: $status" }
        }
        $ssl = [Net.Security.SslStream]::new($stream, $false, { $true })
        $ssl.AuthenticateAsClient($HostName)
        $chain = [Security.Cryptography.X509Certificates.X509Chain]::new()
        $chain.ChainPolicy.RevocationMode = 'NoCheck'
        $null = $chain.Build([Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate))
        $chain.ChainElements | ForEach-Object Certificate
    }
    finally {
        $tcp.Dispose()
    }
}

function Set-RegistryDword {
    param([string]$Path, [string]$Name, [int]$Value, [string]$Label)
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore).$Name
    if ($current -eq $Value) {
        Write-Item Skip $Label 'já configurado'
        return
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type DWord
    Write-Item Ok $Label
}

# =============================================================================
#  Etapas
# =============================================================================

function Step-Prerequisites {
    $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    if ($build -ge 22000) { Write-Item Ok 'Windows 11' "build $build" }
    else { Write-Item Warn 'Windows anterior ao 11' "build $build; o script foi feito para o Windows 11" }

    Write-Item Ok 'PowerShell' "$($PSVersionTable.PSVersion)"

    if (-not (Test-Cmd winget)) {
        throw 'winget não encontrado. Instale o "App Installer" pela Microsoft Store e rode de novo.'
    }
    Write-Item Ok 'winget' (winget --version)

    if (Test-PendingReboot) {
        $script:RebootNeeded = $true
        Write-Item Warn 'Reinicialização pendente' 'o setup continua; reinicie ao final'
    }

    if ((Get-ExecutionPolicy -Scope CurrentUser) -eq 'RemoteSigned') {
        Write-Item Skip 'ExecutionPolicy RemoteSigned' 'já configurada'
    }
    else {
        try {
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
            Write-Item Ok 'ExecutionPolicy RemoteSigned' 'escopo CurrentUser'
        }
        catch {
            Write-Item Warn 'ExecutionPolicy não alterada' $_.Exception.Message
        }
    }

    # Num usuário que nunca usou o PSResourceGet o PSResourceRepository.xml ainda não
    # existe e o Set-PSResourceRepository falha; o Get-PSResourceRepository o cria.
    try {
        $null = Get-PSResourceRepository -Name PSGallery
        Set-PSResourceRepository -Name PSGallery -Trusted
        Write-Item Ok 'PSGallery marcada como confiável'
    }
    catch {
        Write-Item Warn 'PSGallery não marcada como confiável' 'os módulos são instalados com -TrustRepository'
    }
}

function Step-CorporateCA {
    try {
        $chain = @(Get-TlsChain $TlsProbeHost)
    }
    catch {
        Write-Item Warn 'Não foi possível testar a conexão HTTPS' $_.Exception.Message
        return
    }
    if ($chain.Count -lt 2 -or $chain[1].Subject -match 'Google Trust Services') {
        Write-Item Ok 'Sem inspeção TLS' "$TlsProbeHost chega com o certificado original"
        return
    }

    $rootName = $chain[-1].GetNameInfo('SimpleName', $false)
    Write-Item Info 'Inspeção TLS detectada' "raiz: $rootName"

    # Raízes confiáveis do Windows (inclui as da empresa) + intermediárias da inspeção
    $now = Get-Date
    $certs = @(Get-ChildItem Cert:\LocalMachine\Root, Cert:\CurrentUser\Root) + $chain[1..($chain.Count - 1)] |
        Where-Object { $_.NotAfter -gt $now } |
        Sort-Object Thumbprint -Unique
    $pem = foreach ($cert in $certs) { "# $($cert.Subject)"; $cert.ExportCertificatePem() }
    $null = New-Item -ItemType Directory -Path (Split-Path $CaBundlePath) -Force
    $pem | Set-Content -Path $CaBundlePath -Encoding ascii
    Write-Item Ok 'Pacote de CAs gerado' "$($certs.Count) certificados em $CaBundlePath"

    foreach ($name in $CaBundleEnvVars) {
        [Environment]::SetEnvironmentVariable($name, $CaBundlePath, 'User')
        Set-Item -Path "Env:$name" -Value $CaBundlePath
    }
    Write-Item Ok 'Variáveis de CA definidas' ($CaBundleEnvVars -join ', ')

    # git: usa o repositório de certificados do Windows (schannel) em vez do OpenSSL;
    # a checagem de revogação falha porque os servidores de CRL da CA corporativa não respondem
    $GitGlobalConfig['http.sslBackend'] = 'schannel'
    $GitGlobalConfig['http.schannelCheckRevoke'] = 'false'
    Write-Item Info 'git usará o schannel' 'aplicado na etapa de ajustes de desenvolvedor'
}

function Step-WindowsFeatures {
    foreach ($feature in $WindowsFeatures.GetEnumerator()) {
        $state = (Get-CimInstance Win32_OptionalFeature -Filter "Name='$($feature.Key)'").InstallState
        if ($state -eq 1) {
            Write-Item Skip $feature.Value 'já habilitado'
            continue
        }
        $null = & dism.exe /online /enable-feature "/featurename:$($feature.Key)" /all /norestart /quiet
        switch ($LASTEXITCODE) {
            0       { Write-Item Ok $feature.Value 'habilitado' }
            3010    { Write-Item Ok $feature.Value 'habilitado, requer reinicialização'; $script:RebootNeeded = $true }
            default { Write-Item Fail $feature.Value "dism retornou $LASTEXITCODE" }
        }
    }
}

function Step-CliTools {
    foreach ($group in $WingetPackages.GetEnumerator()) {
        if (-not $group.Value) { continue }
        Write-Group $group.Key
        foreach ($id in $group.Value) { Install-WingetPackage $id }
    }
    Update-SessionPath
}

function Step-DeveloperSettings {
    Set-RegistryDword -Label 'Finalizar Tarefa na barra de tarefas' -Value 1 -Name 'TaskbarEndTask' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings'
    Set-RegistryDword -Label 'Mostrar extensões de arquivos' -Value 0 -Name 'HideFileExt' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-RegistryDword -Label 'Mostrar arquivos ocultos' -Value 1 -Name 'Hidden' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    Set-RegistryDword -Label 'Caminhos longos (> 260 caracteres)' -Value 1 -Name 'LongPathsEnabled' `
        -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
    Set-RegistryDword -Label 'Modo de desenvolvedor (symlinks sem admin)' -Value 1 -Name 'AllowDevelopmentWithoutDevLicense' `
        -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock'

    $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    if ($build -lt 26100) {
        Write-Item Skip 'sudo para Windows' 'requer Windows 11 24H2'
    }
    elseif (-not (Test-Cmd sudo)) {
        Write-Item Warn 'sudo para Windows' 'sudo.exe não encontrado'
    }
    else {
        $null = & sudo config --enable normal 2>&1
        if ($LASTEXITCODE -eq 0) { Write-Item Ok 'sudo para Windows' 'modo inline' }
        else { Write-Item Warn 'sudo para Windows' "retornou $LASTEXITCODE (pode estar bloqueado por política)" }
    }

    if (-not (Test-Cmd git)) {
        Write-Item Warn 'Configuração do git' 'git não encontrado no PATH'
        return
    }
    foreach ($entry in $GitGlobalConfig.GetEnumerator()) {
        if ((git config --global --get $entry.Key) -eq $entry.Value) { continue }
        git config --global $entry.Key $entry.Value
    }
    $detail = 'main, rebase no pull, delta, caminhos longos'
    if ($GitGlobalConfig.Contains('http.sslBackend')) { $detail += ', schannel' }
    Write-Item Ok 'Configuração global do git' $detail
}

function Step-NerdFont {
    $fontKeys = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts',
                'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts'
    $installed = $fontKeys | Where-Object { Test-Path $_ } |
        ForEach-Object { (Get-ItemProperty $_).PSObject.Properties.Name } |
        Where-Object { $_ -like "$FontFace*" }
    if ($installed) {
        Write-Item Skip $FontFace 'já instalada'
        return
    }
    if (-not (Test-Cmd oh-my-posh)) { throw 'oh-my-posh não encontrado no PATH' }

    $null = & oh-my-posh font install meslo 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Item Ok $FontFace 'instalada via oh-my-posh' }
    else { Write-Item Fail $FontFace "oh-my-posh retornou $LASTEXITCODE" }
}

function Step-PSModules {
    foreach ($module in $PSModules) {
        $installed = Get-InstalledPSResource -Name $module.Name -Scope CurrentUser -ErrorAction Ignore |
            Sort-Object Version -Descending | Select-Object -First 1
        if ($installed) {
            Write-Item Skip $module.Name "$($installed.Version) já instalado"
            continue
        }
        if ($module.Note) { Write-Item Info $module.Name $module.Note }
        try {
            Install-PSResource -Name $module.Name -Scope CurrentUser -TrustRepository -AcceptLicense -Quiet
            Write-Item Ok $module.Name 'instalado'
        }
        catch {
            Write-Item Fail $module.Name $_.Exception.Message
        }
    }
}

function Step-WindowsTerminal {
    $settingsPath = @(
        "$env:LOCALAPPDATA\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"
        "$env:LOCALAPPDATA\Microsoft\Windows Terminal\settings.json"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1

    if (-not $settingsPath) {
        Write-Item Warn 'settings.json não encontrado' 'abra o Windows Terminal uma vez e rode o setup de novo'
        return
    }

    $settings = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable
    $changes = @()

    if ($settings.defaultProfile -ne $PwshProfileGuid) {
        $settings.defaultProfile = $PwshProfileGuid
        $changes += 'perfil padrão: PowerShell 7'
    }

    if ($settings.profiles -isnot [Collections.IDictionary]) {
        Write-Item Warn 'Formato antigo do settings.json' 'fonte não alterada'
    }
    else {
        if (-not $settings.profiles.defaults) { $settings.profiles.defaults = [ordered]@{} }
        $defaults = $settings.profiles.defaults
        if (-not $defaults.font) { $defaults.font = [ordered]@{} }
        if ($defaults.font.face -ne $FontFace) {
            $defaults.font.face = $FontFace
            $changes += "fonte: $FontFace"
        }
    }

    if (-not $changes) {
        Write-Item Skip 'Windows Terminal' 'já configurado'
        return
    }
    Copy-Item $settingsPath "$settingsPath.bak-$Stamp"
    $settings | ConvertTo-Json -Depth 64 | Set-Content -Path $settingsPath -Encoding utf8
    foreach ($change in $changes) { Write-Item Ok $change }
    Write-Item Info 'Backup do settings.json' "$settingsPath.bak-$Stamp"
}

function Step-Profile {
    $profileDir = Split-Path -Parent $PROFILE.CurrentUserCurrentHost
    $null = New-Item -ItemType Directory -Path $profileDir -Force

    foreach ($file in $ProfileFiles) {
        $source = Join-Path $PSScriptRoot $file
        $target = Join-Path $profileDir $file
        if (-not (Test-Path $source)) {
            Write-Item Fail $file 'não encontrado ao lado do script'
            continue
        }
        if ((Test-Path $target) -and (Get-FileHash $source).Hash -eq (Get-FileHash $target).Hash) {
            Write-Item Skip $file 'já atualizado'
            continue
        }
        $detail = 'implantado'
        if (Test-Path $target) {
            Copy-Item $target "$target.bak-$Stamp"
            $detail = "atualizado; backup em $(Split-Path -Leaf $target).bak-$Stamp"
        }
        Copy-Item $source $target -Force
        Write-Item Ok $file $detail
    }

    $localProfile = Join-Path $profileDir 'profile.local.ps1'
    if (-not (Test-Path $localProfile)) {
        @(
            '# Customizações locais: o setup-pwsh7.ps1 nunca sobrescreve este arquivo.'
            '#'
            '# Proxy corporativo (kubectl, helm, gh e terraform só usam variáveis de ambiente):'
            "# `$global:ProxyUrl = 'http://proxy.empresa:3128'"
            '# proxy-on   # descomente para ativar em todo terminal novo'
        ) | Set-Content -Path $localProfile -Encoding utf8
        Write-Item Ok 'profile.local.ps1' 'criado para customizações pessoais'
    }
    Write-Item Info 'Pasta do perfil' $profileDir
}

function Step-UpgradeAll {
    $code = Invoke-Winget 'upgrade', '--all', '--include-unknown', '--silent', '--accept-package-agreements'
    if ($code -eq 0 -or $code -in $WingetNoop) { Write-Item Ok 'Aplicativos atualizados' }
    else { Write-Item Warn 'winget upgrade --all' ('retornou 0x{0:X8}; veja o log' -f $code) }
}

# =============================================================================
#  Execução
# =============================================================================

$Steps = @(
    @{ Title = 'Pré-requisitos';                      Action = { Step-Prerequisites }; Critical = $true }
    @{ Title = 'Certificado corporativo (inspeção TLS)'; Action = { Step-CorporateCA } }
    @{ Title = 'Recursos do Windows (WSL e Hyper-V)'; Action = { Step-WindowsFeatures }; Skip = $SkipWindowsFeatures.IsPresent }
    @{ Title = 'Ferramentas de linha de comando';     Action = { Step-CliTools } }
    @{ Title = 'Ajustes de desenvolvedor';            Action = { Step-DeveloperSettings } }
    @{ Title = 'Fonte Nerd Font';                     Action = { Step-NerdFont } }
    @{ Title = 'Módulos do PowerShell';               Action = { Step-PSModules } }
    @{ Title = 'Windows Terminal';                    Action = { Step-WindowsTerminal } }
    @{ Title = 'Perfil do PowerShell';                Action = { Step-Profile }; Skip = $SkipProfile.IsPresent }
    @{ Title = 'Atualizar aplicativos (winget)';      Action = { Step-UpgradeAll }; Skip = -not $UpgradeAll }
)

$null = Start-Transcript -Path (Join-Path $LogDir 'setup.log')
$totalTimer = [Diagnostics.Stopwatch]::StartNew()
try {
    Write-Banner
    foreach ($step in $Steps) {
        $ok = Invoke-Step -Step $step -Total $Steps.Count
        if (-not $ok -and $step.Critical) {
            Write-Host "`n$($Ui.Fail)Etapa obrigatória falhou; setup interrompido.$($Ui.Reset)"
            break
        }
    }
    Write-Summary $totalTimer.Elapsed
}
finally {
    $null = Stop-Transcript
}

exit [int]($script:Results.Status -contains 'Falha')
