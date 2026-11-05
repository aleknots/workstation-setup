#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Configura uma workstation Windows 11 (Pro ou Home) para SRE/DevOps com foco no PowerShell 7.

.DESCRIPTION
    Script único: pode ser iniciado no Windows PowerShell 5.1 que já vem com o Windows.
    Nesse caso ele instala o PowerShell 7 x64 e se reabre nele para continuar o setup.

    No início ele pergunta a versão do Windows (ou use -Versao):
    - Home: PowerShell 7 customizado com as ferramentas de DevOps no Windows, mais o
            Docker Desktop e o k3d para rodar o k3s. Sem Ubuntu: o WSL2 só serve de
            motor ao Docker Desktop, que só ocupa memória enquanto está aberto.
    - Pro:  PowerShell 7 + WSL2 com Ubuntu 26.04, Hyper-V, Área Restrita do Windows,
            Vagrant, Packer e Multipass. Depois, configure o Ubuntu com o playbook
            ubuntu-26.04-wsl2. Só nas edições com Hyper-V (Pro, Enterprise, Education).

    .wslconfig nas duas versões: rede espelhada, DNS e proxy do Windows, memória e
    processadores limitados, recuperação de memória e disco esparso. A memória padrão é
    6 GB (sem passar da metade da RAM); no ROG Ally / Ally X / Xbox Ally, 25% da RAM
    (mínimo 4 GB), porque ela é dividida com a GPU.

    Nas duas versões:
    - CLIs de Kubernetes, Terraform, Headlamp, kubeseal e Argo Rollouts no Windows
    - CLIs de nuvem (Azure, AWS, GCP), módulo Az e Telnet
    - Apps de trabalho, jogos e de uso pessoal (VS Code, Steam, Sublime...)
    - Ajustes de desenvolvedor, Nerd Font, módulos do PowerShell e Windows Terminal
    - Perfil do PowerShell 7 (prompt nativo) que fica na mesma pasta deste script

    Docker: na versão Home vem do Docker Desktop; na versão Pro roda no Ubuntu do WSL e o
    perfil expõe o comando `docker` a partir dele. O Docker Desktop é gratuito para uso
    pessoal e empresas pequenas; em empresas grandes exige assinatura.

.PARAMETER Versao
    Perguntar (padrão): mostra a escolha no início, sugerindo a edição detectada.
    Home ou Pro: escolhe sem perguntar. Sem terminal interativo, vale a edição detectada.


.PARAMETER WslMemoryGB
    Limite de memória do WSL em GB. Sem ele: 6 GB, sem passar da metade da RAM; no
    ROG Ally, 25% da RAM (mínimo 4 GB).

.PARAMETER UpgradeAll
    Ao final, também atualiza todos os aplicativos com `winget upgrade --all`.

.PARAMETER SkipWindowsFeatures
    Não habilita recursos do Windows.

.PARAMETER SkipProfile
    Não copia o perfil para a pasta do PowerShell.

.PARAMETER RemoveX86
    Remove o PowerShell 7 de 32 bits, se existir. Ele costuma ser aberto por atalhos
    antigos no lugar do de 64 bits.

.PARAMETER SkipApps
    Não instala o grupo "Pessoal / Opcional".

.EXAMPLE
    # Num Windows PowerShell (ou PowerShell 7) aberto como Administrador, na pasta do script:
    powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1
    powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 -Versao Pro
    powershell -ExecutionPolicy Bypass -File .\setup-windows.ps1 -Versao Home -SkipApps

.NOTES
    O perfil (Microsoft.PowerShell_profile.ps1) precisa estar na mesma pasta.

    Script desenvolvido por Aleon Chagas
#>
[CmdletBinding()]
param(
    [ValidateSet('Perguntar', 'Home', 'Pro')]
    [string]$Versao = 'Perguntar',
    [ValidateRange(0, 256)]
    [int]$WslMemoryGB = 0,
    [switch]$UpgradeAll,
    [switch]$SkipWindowsFeatures,
    [switch]$SkipProfile,
    [switch]$RemoveX86,
    [switch]$SkipApps
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# =============================================================================
#  Fase 1 (Windows PowerShell 5.1): instala o PowerShell 7 e reabre este script nele
#  Tudo neste bloco precisa ser compatível com o 5.1.
# =============================================================================

if ($PSVersionTable.PSVersion.Major -lt 7) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    # Num Windows PowerShell de 32 bits, $env:ProgramFiles aponta para "Program Files (x86)"
    $programFiles = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
    $pwsh = Join-Path $programFiles 'PowerShell\7\pwsh.exe'

    Write-Host "`n==> Instalando o PowerShell 7 (x64)" -ForegroundColor Cyan
    $wingetCode = $null
    if (-not (Test-Path $pwsh) -and (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        & winget install --id Microsoft.PowerShell --exact --source winget --architecture x64 --silent --scope machine `
            --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
        $wingetCode = '0x{0:X8}' -f $LASTEXITCODE
    }
    # O winget pode dizer "já instalado" (0x8A150061) por causa do PowerShell da Microsoft
    # Store, que não fica em Program Files; nesse caso, ou com erro, instala o MSI oficial.
    if (-not (Test-Path $pwsh)) {
        $reason = if ($wingetCode) { "winget retornou $wingetCode" } else { 'winget indisponível' }
        Write-Host "  $reason e o pwsh.exe não está em Program Files; baixando o MSI oficial do GitHub..." -ForegroundColor Yellow
        try {
            $release = Invoke-RestMethod -UseBasicParsing -Uri 'https://api.github.com/repos/PowerShell/PowerShell/releases/latest'
            $asset = $release.assets | Where-Object { $_.name -match '^PowerShell-.*-win-x64\.msi$' } | Select-Object -First 1
            if (-not $asset) { throw 'MSI x64 não encontrado na última release do PowerShell.' }
            $msi = Join-Path $env:TEMP $asset.name
            Write-Host ("  Baixando {0} ({1:N0} MB)..." -f $asset.name, ($asset.size / 1MB))
            # O WebClient é bem mais rápido que o Invoke-WebRequest no Windows PowerShell 5.1
            (New-Object Net.WebClient).DownloadFile($asset.browser_download_url, $msi)
            Write-Host '  Instalando o MSI (leva 1 a 2 minutos, sem janela)...'
            $msiArgs = "/i `"$msi`" /qn ADD_PATH=1 ENABLE_PSREMOTING=0 REGISTER_MANIFEST=1 USE_MU=1 ENABLE_MU=1"
            $process = Start-Process msiexec.exe -ArgumentList $msiArgs -Wait -PassThru
            # 1618: outra instalação em andamento (ex.: Windows Update)
            if ($process.ExitCode -eq 1618) { throw 'outra instalação está em andamento (Windows Update?); espere ela terminar e rode de novo' }
            Remove-Item $msi -Force -ErrorAction SilentlyContinue
            # 3010: instalado, requer reinicialização
            if ($process.ExitCode -notin 0, 3010) { throw "msiexec retornou $($process.ExitCode)" }
        }
        catch { Write-Host "  [!!] MSI: $($_.Exception.Message)" -ForegroundColor Yellow }
    }
    if (-not (Test-Path $pwsh)) {
        # Último recurso: outro PowerShell 7 do PATH (ex.: o da Microsoft Store), de
        # preferência o de 64 bits
        $found = @(Get-Command pwsh.exe -All -ErrorAction SilentlyContinue) |
            Sort-Object { $_.Source -match 'x86' } | Select-Object -First 1
        if (-not $found) { throw 'O PowerShell 7 não foi instalado. Veja as mensagens acima.' }
        $pwsh = $found.Source
        Write-Host "  [!!] Usando o PowerShell 7 encontrado no PATH: $pwsh" -ForegroundColor Yellow
    }
    Write-Host "  [OK] PowerShell $(& $pwsh -NoProfile -NoLogo -Command '$PSVersionTable.PSVersion.ToString()')" -ForegroundColor Green

    $x86 = Get-ItemProperty 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like 'PowerShell 7*x86*' }
    foreach ($entry in $x86) {
        if ($RemoveX86) {
            Start-Process msiexec.exe -ArgumentList "/x $($entry.PSChildName) /qn" -Wait
            Write-Host "  [OK] $($entry.DisplayName) removido" -ForegroundColor Green
        }
        else {
            Write-Host "  [!!] $($entry.DisplayName) está instalado; rode com -RemoveX86 para removê-lo" -ForegroundColor Yellow
        }
    }

    # Arquivos baixados ou vindos de compartilhamento ficam bloqueados para RemoteSigned
    Get-ChildItem -Path $PSScriptRoot -File | Unblock-File

    Write-Host "`n==> Continuando o setup no PowerShell 7" -ForegroundColor Cyan
    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    foreach ($param in $PSBoundParameters.GetEnumerator()) {
        if ($param.Value -is [switch]) {
            if ($param.Value.IsPresent) { $arguments += "-$($param.Key)" }
        }
        else {
            $arguments += "-$($param.Key)", $param.Value
        }
    }
    & $pwsh @arguments
    exit $LASTEXITCODE
}

# =============================================================================
#  Fase 2 (PowerShell 7): setup
# =============================================================================

if ($PSVersionTable.PSVersion.Major -eq 7 -and $PSVersionTable.PSVersion.Minor -lt 4) {
    throw "Este script precisa do PowerShell 7.4 ou superior (atual: $($PSVersionTable.PSVersion))."
}
[Console]::OutputEncoding = [Text.UTF8Encoding]::new()

# =============================================================================
#  Máquina
# =============================================================================

$OsInfo = Get-CimInstance Win32_OperatingSystem
$ComputerInfo = Get-CimInstance Win32_ComputerSystem
# ROG Ally RC71L, Ally X RC72LA, Xbox Ally RC73...
$IsRogAlly = $ComputerInfo.Model -match 'Ally|RC7\d'
# O Home não lista o Hyper-V entre os recursos opcionais: só a versão Home
$HyperVAvailable = [bool](Get-CimInstance Win32_OptionalFeature -Filter "Name='Microsoft-Hyper-V-All'")
# Definida no início da execução (pergunta ou -Versao)
$Edition = 'Home'

# =============================================================================
#  Configuração
# =============================================================================

# Versao: o recurso só é habilitado nessa versão.
# Recursos que a edição não tem são pulados.
$WindowsFeatures = @(
    # WSL nas duas versões: na Home é o motor do Docker Desktop (sem Ubuntu)
    @{ Name = 'Microsoft-Windows-Subsystem-Linux'; Label = 'Subsistema do Windows para Linux' }
    @{ Name = 'VirtualMachinePlatform'; Label = 'Plataforma de Máquina Virtual' }
    @{ Name = 'Microsoft-Hyper-V-All'; Label = 'Hyper-V (plataforma, Gerenciador e módulo)'; Versao = 'Pro' }
    @{ Name = 'Containers-DisposableClientVM'; Label = 'Área Restrita do Windows (Sandbox)'; Versao = 'Pro' }
    @{ Name = 'TelnetClient'; Label = 'Cliente Telnet' }
)

# Grupo "Administradores do Hyper-V" pelo SID, porque o nome muda com o idioma
$HyperVAdminsSid = 'S-1-5-32-578'

$WslDistro = 'Ubuntu-26.04'

# REVISE ANTES DE RODAR: todos os apps abaixo estão ativos. Para não instalar um app,
# comente a linha com # no início; para instalar de novo, tire o #.
# Ao lado de cada Id está o nome do pacote no Chocolatey. "Id@versão" instala uma versão
# fixa e faz um winget pin para o upgrade --all não trocá-la.
$WingetPackages = [ordered]@{
    'Trabalho / DevOps / SRE' = @(
       # 'Anysphere.Cursor'                       # cursoride
       # 'Hashicorp.Vagrant'                      # vagrant
       # 'Microsoft.AzureCLI'                     # azure-cli
       # 'Microsoft.Azure.StorageExplorer'        # microsoftazurestorageexplorer
       # 'SlackTechnologies.Slack'                # slack
       # 'Microsoft.Teams'                        # microsoft-teams-new-bootstrapper
        'Microsoft.VisualStudioCode'             # vscode
        'Google.Antigravity'                     # antigravity
        'Anthropic.ClaudeCode'                   # claude-code
        'Anthropic.Claude'                       # claude (app desktop)
        'Git.Git'                                # git
        'Hashicorp.Terraform'                    # terraform
        # 'Amazon.AWSCLI'                          # awscli
        'argoproj.argocd'                        # argocd-cli
        'Derailed.k9s'                           # k9s
        'Helm.Helm'                              # kubernetes-helm
        #'Postman.Postman'                        # postman
        #'Microsoft.Azure.Kubelogin'              # login nos clusters AKS
        #'Google.CloudSDK'                        # gcloud
        # azurepowershell: é o módulo Az, na lista $PSModules
    )
    'Pessoal / Opcional' = @(
        #'Discord.Discord'                        # discord
        #'EpicGames.EpicGamesLauncher'            # epicgameslauncher
        'Valve.Steam'                            # steam
        #'Piriform.CCleaner'                      # ccleaner
        #'Zoom.Zoom'                              # zoom
        #'Google.Chrome'                          # googlechrome
        #'Mozilla.Firefox'                        # firefox
        #'Devolutions.RemoteDesktopManager'       # rdm
        #'Microsoft.PowerToys'                    # powertoys
        'RiotGames.Valorant.BR'                  # valorant (servidor BR; troque o sufixo se precisar)
        'Google.GoogleDrive'                     # googledrive
        #'OBSProject.OBSStudio'                   # obs-studio
        'Notion.Notion'                          # notion
        'Obsidian.Obsidian'                      # obsidian
        'Microsoft.EdgeWebView2Runtime'          # webview2-runtime
        'SublimeHQ.SublimeText.4'                # sublimetext4
        'JanDeDobbeleer.OhMyPosh'                # oh-my-posh (também instala a Nerd Font)
        'JAMSoftware.TreeSize.Free'              # treesizefree
        'Roblox.Roblox'                          # roblox
        'Flameshot.Flameshot@12.1.0'             # versão estável
        # nvidia-display-driver e nvidia-app: não estão no winget
        # docker-desktop: na versão Home vem no grupo Docker Desktop
    )
    # Ferramentas de terminal e Kubernetes usadas pelo perfil do PowerShell
    'Terminal e shell' = @(
        'Microsoft.PowerShell'
        'Microsoft.WindowsTerminal'
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
        'ahmetb.kubectx'
        'ahmetb.kubens'
        'stern.stern'
        'Headlamp.Headlamp'                      # interface gráfica; usa o mesmo kubeconfig
    )
    # Só na versão Home: sem Ubuntu no WSL, o Docker e o k3s (via k3d) vêm do Docker Desktop
    'Docker Desktop' = @(
        'Docker.DockerDesktop'
        'k3d.k3d'                                # k3s em contêineres do Docker
    )
    # Só na versão Pro: usam o Hyper-V
    'Virtualização' = @(
        'Hashicorp.Vagrant'
        'Hashicorp.Packer'
        'Canonical.Multipass'                    # VMs Ubuntu com um comando
    )
}
# Pulados com -SkipApps
$AppGroups = 'Pessoal / Opcional'
# Grupos que só entram numa das versões; os outros entram nas duas
$EditionGroups = @{
    'Docker Desktop' = 'Home'
    'Virtualização'  = 'Pro'
}

# CLIs do lab que não estão no winget: baixadas do GitHub Releases. Asset é uma
# regex do nome do arquivo; Exe é o binário dentro do .tar.gz.
# Apps que vêm com o Windows e são removidos (do usuário e da imagem, para não voltarem
# em contas novas). Nomes de pacote Appx; aceitam curinga. Para manter um, comente a linha.
# Ficam: Loja, Calculadora, Fotos, Bloco de Notas, Paint, Ferramenta de Captura, Câmera,
# Terminal, Edge e os apps do Xbox (usados pelos jogos).
$BloatwareApps = @(
    '7EE7776C.LinkedInforWindows'           # LinkedIn
    'Microsoft.MicrosoftSolitaireCollection' # Paciência
    'Microsoft.BingNews'                     # Notícias (Microsoft Start)
    'Microsoft.BingWeather'                  # Clima
    'Microsoft.BingSearch'                   # Pesquisa do Bing
    'Microsoft.GetHelp'                      # Obter Ajuda
    'Microsoft.Getstarted'                   # Dicas
    'Microsoft.MicrosoftOfficeHub'           # Microsoft 365 (Office)
    'Microsoft.People'
    'Microsoft.WindowsFeedbackHub'           # Hub de Comentários
    'Microsoft.WindowsMaps'                  # Mapas
    'Microsoft.WindowsAlarms'                # Relógio
    'Microsoft.WindowsSoundRecorder'         # Gravador de Som
    'Microsoft.ZuneVideo'                    # Filmes e TV
    'Microsoft.ZuneMusic'                    # Media Player
    'Microsoft.Todos'                        # To Do
    'Microsoft.PowerAutomateDesktop'
    'Microsoft.MicrosoftJournal'
    'Microsoft.OutlookForWindows'            # novo Outlook
    'Microsoft.YourPhone'                    # Vincular ao Celular
    'Microsoft.549981C3F5F10'                # Cortana
    'Microsoft.Windows.DevHome'
    'MicrosoftCorporationII.QuickAssist'     # Assistência Rápida
    'MicrosoftCorporationII.MicrosoftFamily' # Family Safety
    'MicrosoftTeams'                         # Teams pessoal (antigo)
    'MSTeams'                                # Teams pessoal
    'Clipchamp.Clipchamp'
    'SpotifyAB.SpotifyMusic'
    'Disney.37853FC22B2CE'                   # Disney+
    'AmazonVideo.PrimeVideo'
    'BytedancePte.Ltd.TikTok'
    'Facebook.Instagram'
    'FACEBOOK.FACEBOOK'
    '5319275A.WhatsAppDesktop'
    '*CandyCrush*'
    # 'Microsoft.Copilot'
    'Microsoft.MicrosoftStickyNotes'         # Notas Autoadesivas
)

$GitHubTools = @(
    @{ Name = 'kubeseal'; Repo = 'bitnami-labs/sealed-secrets'; Asset = '^kubeseal-.*-windows-amd64\.tar\.gz$'; Exe = 'kubeseal.exe' }
    @{ Name = 'kubectl-argo-rollouts'; Repo = 'argoproj/argo-rollouts'; Asset = '^kubectl-argo-rollouts-windows-amd64$' }
)
$GitHubToolsDir = Join-Path $env:ProgramFiles 'DevTools\bin'

$PSModules = @(
    @{ Name = 'PSReadLine' }
    @{ Name = 'Terminal-Icons' }
    @{ Name = 'PSFzf' }
    @{ Name = 'CompletionPredictor' }
    @{ Name = 'Az'; Note = 'é grande, pode levar alguns minutos' }     # azurepowershell
)

# No ROG Ally a RAM é compartilhada com a GPU integrada. Sem limite, o WSL pode usar
# até 50% dela e disputar memória com os jogos.
$WslMemoryShare = 0.25   # fração da RAM para o WSL
$WslMemoryMinGB = 4
$WslMemoryDefaultGB = 6      # nos outros PCs, sem passar da metade da RAM
$WslProcessorsDefault = 6

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

$FontFace          = 'MesloLGM Nerd Font'
$PwshProfileGuid   = '{574e775e-4f2a-5b96-ac1e-a2962a402336}'   # perfil PowerShell 7 do Windows Terminal
$ProfileFiles      = @('Microsoft.PowerShell_profile.ps1')

# Códigos do winget que significam "já está instalado / nada a atualizar"
$WingetNoop = @(
    0x8A150061   # APPINSTALLER_CLI_ERROR_PACKAGE_ALREADY_INSTALLED
    0x8A15002B   # APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE
)

$Stamp  = Get-Date -Format 'yyyyMMdd-HHmmss'
$LogDir = Join-Path $env:TEMP "setup-windows-$Stamp"
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
        "Windows 11 $Edition$(if ($IsRogAlly) { ' · ROG Ally' })"
        "Usuário $env:USERNAME · logs em $LogDir"
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
    if ($Edition -eq 'Pro') {
        Write-Host "  $($Ui.Accent)›$($Ui.Reset) Abra o Ubuntu ($($Ui.Dim)wsl -d $WslDistro$($Ui.Reset)) para criar o usuário Linux e rode o playbook $($Ui.Dim)ubuntu-26.04-wsl2$($Ui.Reset)."
        Write-Host "  $($Ui.Accent)›$($Ui.Reset) Hyper-V: $($Ui.Dim)virtmgmt.msc$($Ui.Reset) · VM Ubuntu: $($Ui.Dim)multipass launch --name lab$($Ui.Reset) · Área Restrita no menu Iniciar"
    }
    else {
        Write-Host "  $($Ui.Accent)›$($Ui.Reset) Abra o Docker Desktop uma vez para aceitar os termos; depois, no PowerShell: $($Ui.Dim)k3s-up$($Ui.Reset) e $($Ui.Dim)lab-argocd$($Ui.Reset)."
    }
    Write-Host "  $($Ui.Accent)›$($Ui.Reset) Ajustes pessoais:$($Ui.Dim)profile.local.ps1$($Ui.Reset) na pasta do perfil."
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

function Install-WingetPackage([string]$Spec) {
    $id, $version = $Spec -split '@', 2
    if ((Invoke-Winget 'list', '--id', $id, '--exact') -eq 0) {
        Write-Item Skip $id 'já instalado'
        return
    }
    $arguments = @('install', '--id', $id, '--exact', '--source', 'winget', '--silent', '--accept-package-agreements')
    if ($version) { $arguments += '--version', $version }
    $code = Invoke-Winget $arguments
    if ($code -eq 0) {
        if ($version) {
            $null = Invoke-Winget 'pin', 'add', '--id', $id, '--exact', '--version', $version
            Write-Item Ok $id "instalado na $version (fixado)"
        }
        else { Write-Item Ok $id 'instalado' }
    }
    elseif ($code -in $WingetNoop) { Write-Item Skip $id 'já instalado' }
    else { Write-Item Fail $id ('winget retornou 0x{0:X8}' -f $code) }
}

function Set-RegistryDword {
    param([string]$Path, [string]$Name, $Value, [string]$Label, [string]$Type = 'DWord')
    if (-not (Test-Path $Path)) { $null = New-Item -Path $Path -Force }
    $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction Ignore).$Name
    if ($null -ne $current -and (@($current) -join ',') -eq (@($Value) -join ',')) {
        if ($Label) { Write-Item Skip $Label 'já configurado' }
        return
    }
    Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type
    if ($Label) { Write-Item Ok $Label }
}

# =============================================================================
#  Etapas
# =============================================================================

function Step-Prerequisites {
    $build = [int]$OsInfo.BuildNumber
    if ($build -ge 22000) { Write-Item Ok ($OsInfo.Caption -replace '^Microsoft ', '') "build $build" }
    else { Write-Item Warn 'Windows anterior ao 11' "build $build; o script foi feito para o Windows 11" }

    $device = "$($ComputerInfo.Manufacturer) $($ComputerInfo.Model)".Trim()
    Write-Item Ok 'Dispositivo' $(if ($IsRogAlly) { "$device (ROG Ally: limite de memória do WSL)" } else { $device })
    Write-Item Ok "Versão Windows 11 $Edition" $(if ($Edition -eq 'Pro') { 'PowerShell 7 + WSL2/Ubuntu, Hyper-V e ferramentas de VM' } else { 'PowerShell 7 + Docker Desktop e k3d, sem Ubuntu' })

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

function Step-WindowsFeatures {
    foreach ($feature in $WindowsFeatures) {
        if ($feature.Versao -and $feature.Versao -ne $Edition) {
            Write-Item Skip $feature.Label "só na versão $($feature.Versao)"
            continue
        }
        $info = Get-CimInstance Win32_OptionalFeature -Filter "Name='$($feature.Name)'"
        if (-not $info) {
            Write-Item Skip $feature.Label 'não existe nesta edição do Windows'
            continue
        }
        if ($info.InstallState -eq 1) {
            Write-Item Skip $feature.Label 'já habilitado'
            continue
        }
        $null = & dism.exe /online /enable-feature "/featurename:$($feature.Name)" /all /norestart /quiet
        switch ($LASTEXITCODE) {
            0       { Write-Item Ok $feature.Label 'habilitado' }
            3010    { Write-Item Ok $feature.Label 'habilitado, requer reinicialização'; $script:RebootNeeded = $true }
            default { Write-Item Fail $feature.Label "dism retornou $LASTEXITCODE" }
        }
    }
}

function Step-RemoveBloatware {
    # O módulo Appx não funciona direito no PowerShell 7: a remoção roda no 5.1
    $script = {
        param($Patterns)
        $provisioned = Get-AppxProvisionedPackage -Online
        foreach ($pattern in $Patterns) {
            $packages = @(Get-AppxPackage -AllUsers -Name $pattern)
            $images = @($provisioned | Where-Object DisplayName -like $pattern)
            if (-not $packages -and -not $images) { continue }
            $name = if ($packages) { $packages[0].Name } else { $images[0].DisplayName }
            try {
                $packages | Remove-AppxPackage -AllUsers -ErrorAction Stop
                $images | Remove-AppxProvisionedPackage -Online -ErrorAction Stop | Out-Null
                "Ok|$name"
            }
            catch { "Warn|$name|$($_.Exception.Message)" }
        }
    }
    $command = "& { $script } -Patterns @('$($BloatwareApps -join "','")')"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
    $results = @(& "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -EncodedCommand $encoded 2>&1)
    foreach ($line in $results) {
        $status, $name, $message = "$line" -split '\|', 3
        switch ($status) {
            'Ok'    { Write-Item Ok $name 'removido' }
            'Warn'  { Write-Item Warn $name $message }
            default { if ("$line".Trim()) { Write-Item Warn 'Remoção de apps' "$line" } }
        }
    }
    if (-not ($results | Where-Object { "$_" -like 'Ok|*' })) { Write-Item Skip 'Apps pré-instalados' 'nada a remover' }

    # Impede que o Windows reinstale apps sugeridos (LinkedIn, jogos, Spotify...)
    $cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-RegistryDword -Label 'Sem instalação automática de apps sugeridos' -Value 0 -Name 'SilentInstalledAppsEnabled' -Path $cdm
    Set-RegistryDword -Value 0 -Name 'PreInstalledAppsEnabled' -Path $cdm
    Set-RegistryDword -Value 0 -Name 'OemPreInstalledAppsEnabled' -Path $cdm
    Set-RegistryDword -Value 1 -Name 'DisableWindowsConsumerFeatures' -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent'

    # Sem pesquisa web do Bing no Iniciar e na busca da barra de tarefas
    Set-RegistryDword -Label 'Sem pesquisa web do Bing no Iniciar' -Value 1 -Name 'DisableSearchBoxSuggestions' `
        -Path 'HKCU:\Software\Policies\Microsoft\Windows\Explorer'
    Set-RegistryDword -Value 0 -Name 'BingSearchEnabled' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
    Set-RegistryDword -Value 0 -Name 'CortanaConsent' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search'
}

function Step-CliTools {
    foreach ($group in $WingetPackages.GetEnumerator()) {
        if (-not $group.Value) { continue }
        $groupEdition = $EditionGroups[$group.Key]
        if ($groupEdition -and $groupEdition -ne $Edition) {
            Write-Item Skip $group.Key "só na versão $groupEdition"
            continue
        }
        if ($SkipApps -and $group.Key -in $AppGroups) {
            Write-Item Skip $group.Key 'pulado (-SkipApps)'
            continue
        }
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

    # Painel de detalhes do Explorer (Alt+Shift+P): miniatura grande da imagem e propriedades
    Set-RegistryDword -Label 'Painel de detalhes do Explorer' -Type Binary -Value ([byte[]](1, 0, 0, 0, 2, 0, 0, 0)) -Name 'DetailsContainer' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Modules\GlobalSettings\DetailsContainer'
    # Miniaturas no lugar de ícones, para a pré-visualização aparecer
    Set-RegistryDword -Value 0 -Name 'IconsOnly' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    # sudo do Windows (Configurações > Sistema > Para desenvolvedores), modo inline.
    # Gravado no registro: o "sudo config" não roda enquanto o sudo está desativado.
    $build = [int](Get-CimInstance Win32_OperatingSystem).BuildNumber
    if ($build -lt 26100) {
        Write-Item Skip 'sudo para Windows' 'requer Windows 11 24H2'
    }
    else {
        try {
            # 1 = nova janela, 2 = entrada desativada, 3 = inline
            Set-RegistryDword -Label 'sudo para Windows (inline)' -Value 3 -Name 'Enabled' `
                -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Sudo'
        }
        catch { Write-Item Warn 'sudo para Windows' "$($_.Exception.Message) (pode estar bloqueado por política)" }
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
    Write-Item Ok 'Configuração global do git' $detail
}

# Versão Home: Windows com o mínimo de efeitos visuais, para ficar leve e rápido.
# Mantém só a suavização de fontes e as miniaturas de imagens.
function Step-LightAppearance {
    $desktop  = 'HKCU:\Control Panel\Desktop'
    $advanced = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'

    # "Ajustar para melhor desempenho", personalizado: sem animações, sombras e esmaecimentos
    Set-RegistryDword -Value 3 -Name 'VisualFXSetting' -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
    Set-RegistryDword -Label 'Efeitos visuais: melhor desempenho' -Type Binary -Name 'UserPreferencesMask' `
        -Value ([byte[]](0x90, 0x12, 0x03, 0x80, 0x10, 0x00, 0x00, 0x00)) -Path $desktop
    Set-RegistryDword -Type String -Value '0' -Name 'MinAnimate' -Path "$desktop\WindowMetrics"
    Set-RegistryDword -Type String -Value '2' -Name 'FontSmoothing' -Path $desktop
    Set-RegistryDword -Type String -Value '0' -Name 'MenuShowDelay' -Path $desktop
    Set-RegistryDword -Value 0 -Name 'TaskbarAnimations' -Path $advanced
    Set-RegistryDword -Value 0 -Name 'ListviewAlphaSelect' -Path $advanced
    Set-RegistryDword -Value 0 -Name 'ListviewShadow' -Path $advanced
    Set-RegistryDword -Value 0 -Name 'EnableAeroPeek' -Path 'HKCU:\Software\Microsoft\Windows\DWM'

    Set-RegistryDword -Label 'Sem transparência' -Value 0 -Name 'EnableTransparency' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
    Set-RegistryDword -Label 'Sem atraso nos apps de inicialização' -Value 0 -Name 'StartupDelayInMSec' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Serialize'
    # Widgets ligados: o botão da barra de tarefas mostra o tempo. Remove a política
    # que os desligava (gravada por versões anteriores deste setup).
    $dsh = 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh'
    if ((Get-ItemProperty $dsh -Name AllowNewsAndInterests -ErrorAction Ignore).AllowNewsAndInterests -eq 0) {
        Remove-ItemProperty $dsh -Name AllowNewsAndInterests
        Write-Item Ok 'Widgets (tempo na barra de tarefas)' 'reativados'
    }
    else { Write-Item Skip 'Widgets (tempo na barra de tarefas)' 'já ativos' }
    Set-RegistryDword -Label 'Sem sugestões e anúncios no Iniciar' -Value 0 -Name 'SubscribedContent-338388Enabled' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
    Set-RegistryDword -Value 0 -Name 'SystemPaneSuggestionsEnabled' `
        -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'

    Write-Item Info 'Aplicação' 'os efeitos visuais valem no próximo login'
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
        # A cópia leva a marca "baixado da internet"; com RemoteSigned o perfil não carregaria
        Unblock-File -Path $target
        Write-Item Ok $file $detail
    }

    $localProfile = Join-Path $profileDir 'profile.local.ps1'
    if (-not (Test-Path $localProfile)) {
        @(
            '# Customizações locais: o setup nunca sobrescreve este arquivo.'
        ) | Set-Content -Path $localProfile -Encoding utf8
        Write-Item Ok 'profile.local.ps1' 'criado para customizações pessoais'
    }
    Write-Item Info 'Pasta do perfil' $profileDir
}

function Step-GitHubTools {
    $null = New-Item -ItemType Directory -Path $GitHubToolsDir -Force
    $machinePath = [Environment]::GetEnvironmentVariable('Path', 'Machine')
    if (($machinePath -split ';') -notcontains $GitHubToolsDir) {
        [Environment]::SetEnvironmentVariable('Path', "$machinePath;$GitHubToolsDir", 'Machine')
        Write-Item Ok 'PATH' "$GitHubToolsDir adicionado"
    }

    foreach ($tool in $GitHubTools) {
        try {
            $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$($tool.Repo)/releases/latest" -Headers @{ Accept = 'application/vnd.github+json' }
            $target = Join-Path $GitHubToolsDir "$($tool.Name).exe"
            # A tag instalada fica ao lado do binário; só baixa de novo quando sai versão nova
            $versionFile = "$target.version"
            if ((Test-Path $target) -and (Test-Path $versionFile) -and (Get-Content $versionFile -Raw).Trim() -eq $release.tag_name) {
                Write-Item Skip $tool.Name "$($release.tag_name) já instalado"
                continue
            }
            $asset = $release.assets | Where-Object name -match $tool.Asset | Select-Object -First 1
            if (-not $asset) { throw "nenhum asset de $($release.tag_name) casa com '$($tool.Asset)'" }

            # Extrai/baixa direto no destino: mover um .exe recém-criado falha enquanto
            # o antivírus ainda o examina
            if ($asset.name -like '*.tar.gz') {
                $download = Join-Path $env:TEMP $asset.name
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $download -ErrorAction Stop
                tar -xzf $download -C $GitHubToolsDir $tool.Exe
                $tarExit = $LASTEXITCODE
                Remove-Item $download -Force -ErrorAction Ignore
                if ($tarExit) { throw "tar retornou $tarExit" }
            }
            else {
                Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $target -ErrorAction Stop
            }
            if (-not (Test-Path $target)) { throw "$target não foi criado" }
            Set-Content -Path $versionFile -Value $release.tag_name -ErrorAction Stop
            Write-Item Ok $tool.Name "$($release.tag_name) instalado"
        }
        catch {
            Write-Item Fail $tool.Name $_.Exception.Message
        }
    }
    Update-SessionPath
}

function Step-WslUbuntu {
    # Sem isso o wsl.exe responde em UTF-16 e a lista de distros vem com bytes nulos
    $env:WSL_UTF8 = '1'

    $null = & wsl.exe --update 2>&1
    if ($LASTEXITCODE -eq 0) { Write-Item Ok 'WSL atualizado' }
    else { Write-Item Warn 'wsl --update' "retornou $LASTEXITCODE" }
    $null = & wsl.exe --set-default-version 2 2>&1

    # Na versão Home o WSL só serve de motor ao Docker Desktop, que cria a própria distro
    if ($Edition -ne 'Pro') {
        Write-Item Skip $WslDistro 'não instalado na versão Home (o Docker Desktop usa a própria distro)'
        return
    }

    $distros = @(& wsl.exe --list --quiet 2>$null) -replace "`0", '' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    if ($distros -contains $WslDistro) {
        Write-Item Skip $WslDistro 'já instalado'
        return
    }

    # --no-launch: instala sem abrir o Ubuntu; o usuário Linux é criado na primeira abertura
    $null = & wsl.exe --install --distribution $WslDistro --no-launch 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Item Ok $WslDistro 'instalado; abra o Ubuntu para criar o usuário Linux'
    }
    elseif ($script:RebootNeeded) {
        Write-Item Warn $WslDistro 'o WSL acabou de ser habilitado; reinicie e rode o setup de novo para instalar'
    }
    else {
        Write-Item Fail $WslDistro "wsl --install retornou $LASTEXITCODE"
    }
}

function Step-DockerDesktop {
    # O Docker Desktop só aceita membros do grupo docker-users (criado pelo instalador)
    $member = "$env:USERDOMAIN\$env:USERNAME"
    try {
        $members = @(Get-LocalGroupMember -Group 'docker-users' -ErrorAction Stop | ForEach-Object Name)
        if ($members -contains $member) {
            Write-Item Skip 'Grupo docker-users' "$member já é membro"
        }
        else {
            Add-LocalGroupMember -Group 'docker-users' -Member $member
            Write-Item Ok 'Grupo docker-users' "$member adicionado; vale no próximo login"
        }
    }
    catch {
        Write-Item Warn 'Grupo docker-users' $_.Exception.Message
    }
    Write-Item Info 'Primeira abertura' 'abra o Docker Desktop uma vez para aceitar os termos; depois use k3s-up no PowerShell'
    Write-Item Info 'Memória' 'desligue "Start Docker Desktop when you sign in" para ele só rodar quando você usar'
}

function Step-WslConfig {
    $path = Join-Path $env:USERPROFILE '.wslconfig'
    $ramGB = [math]::Round($ComputerInfo.TotalPhysicalMemory / 1GB)
    $cpus = [int]$ComputerInfo.NumberOfLogicalProcessors

    # Memória: -WslMemoryGB; no ROG Ally 25% da RAM (mínimo 4 GB); nos outros PCs
    # $WslMemoryDefaultGB, sem passar da metade da RAM
    $memoryGB = if ($WslMemoryGB) { $WslMemoryGB }
    elseif ($IsRogAlly) { [math]::Max($WslMemoryMinGB, [math]::Floor($ramGB * $WslMemoryShare)) }
    else { [math]::Max(2, [math]::Min($WslMemoryDefaultGB, [math]::Floor($ramGB / 2))) }
    $processors = [math]::Max(1, [math]::Min($WslProcessorsDefault, $cpus))

    $settings = [ordered]@{
        'wsl2' = [ordered]@{
            networkingMode = @('mirrored', '# Rede espelhada: o WSL usa o IP e as portas do Windows (localhost nos dois sentidos)')
            dnsTunneling   = @('true', '# DNS resolvido pelo Windows: funciona com VPN e proxy')
            autoProxy      = @('true', '# O WSL herda o proxy configurado no Windows')
            firewall       = @('true', '# Regras do Firewall do Windows valem também para o WSL')
            memory         = @("${memoryGB}GB", "# Limite de memória ($ramGB GB de RAM nesta máquina)")
            processors     = @("$processors", "# Processadores lógicos para o WSL ($cpus nesta máquina)")
        }
        'general' = [ordered]@{
            instanceIdleTimeout = @('-1', "# Mantém o WSL ligado quando ocioso: abrir um terminal fica instantâneo`n# em vez de reiniciar o systemd (4-7 s). -1 = nunca desligar.")
        }
        'experimental' = [ordered]@{
            autoMemoryReclaim = @('gradual', "# Devolve ao Windows, aos poucos, a memória de cache que o WSL não está usando.`n# Importante com Docker/k3d ligados o dia todo.")
            sparseVhd         = @('true', '# O disco virtual do WSL encolhe quando você apaga imagens e clusters.')
        }
    }
    # No ROG Ally o WSL desliga quando ocioso, para não gastar RAM e bateria nos jogos
    if ($IsRogAlly) { $settings['general'].Remove('instanceIdleTimeout') }

    # Chaves que o setup não gerencia continuam no arquivo, na mesma seção
    $existing = [ordered]@{}
    $current = $null
    if (Test-Path $path) {
        foreach ($line in Get-Content $path) {
            if ($line -match '^\s*\[([^\]]+)\]\s*$') { $current = $Matches[1].Trim(); if (-not $existing.Contains($current)) { $existing[$current] = [ordered]@{} } }
            elseif ($current -and $line -match '^\s*([^#;=\s][^=]*?)\s*=\s*(.*?)\s*$') { $existing[$current][$Matches[1]] = $Matches[2] }
        }
    }
    if ($IsRogAlly -and $existing['general'] -and $existing['general']['instanceIdleTimeout'] -eq '-1') {
        Write-Item Warn 'instanceIdleTimeout=-1 no .wslconfig' 'mantém o WSL ligado e gasta bateria; considere remover'
    }

    $out = [Collections.Generic.List[string]]::new()
    $out.Add('# Gerado pelo setup-windows.ps1. As chaves abaixo são reaplicadas a cada execução;')
    $out.Add('# outras chaves que você adicionar são mantidas. Vale depois de: wsl --shutdown')
    foreach ($section in @($settings.Keys) + @($existing.Keys | Where-Object { -not $settings.Contains($_) })) {
        $out.Add('')
        $out.Add("[$section]")
        if ($settings.Contains($section)) {
            foreach ($key in $settings[$section].Keys) {
                $value, $comment = $settings[$section][$key]
                $comment -split "`n" | ForEach-Object { $out.Add($_) }
                $out.Add("$key=$value")
            }
        }
        if ($existing.Contains($section)) {
            foreach ($key in $existing[$section].Keys) {
                if ($settings.Contains($section) -and $settings[$section].Contains($key)) { continue }
                $out.Add("$key=$($existing[$section][$key])")
            }
        }
    }

    $text = ($out -join "`r`n") + "`r`n"
    if ((Test-Path $path) -and (Get-Content $path -Raw) -eq $text) {
        Write-Item Skip '.wslconfig' 'já configurado'
        return
    }
    if (Test-Path $path) { Copy-Item $path "$path.bak-$Stamp" }
    [IO.File]::WriteAllText($path, $text, [Text.UTF8Encoding]::new($false))
    Write-Item Ok '.wslconfig' "rede espelhada, DNS e proxy do Windows, $memoryGB GB de $ramGB GB, $processors de $cpus processadores"
    Write-Item Info 'Aplicação' 'vale depois de wsl --shutdown (ou ao reiniciar)'
}
# Pergunta a versão do Windows, a menos que venha por -Versao. Enter aceita a
# versão que corresponde à edição detectada.
function Select-Edition {
    $detected = if ($HyperVAvailable) { 'Pro' } else { 'Home' }
    $choice = $Versao
    if ($choice -eq 'Perguntar') {
        # Sem terminal interativo (agendador, pipeline) não há como perguntar
        if (-not [Environment]::UserInteractive -or [Console]::IsInputRedirected) { return $detected }
        $default = if ($detected -eq 'Pro') { '2' } else { '1' }
        Write-Host ''
        Write-Host "$($Ui.Bold)Versão do Windows$($Ui.Reset) $($Ui.Dim)(detectada: $(($OsInfo.Caption -replace '^Microsoft ', '')))$($Ui.Reset)"
        Write-Host "  $($Ui.Accent)1$($Ui.Reset)  Windows 11 Home  PowerShell 7 com as ferramentas de DevOps + Docker Desktop e k3s (k3d). Sem Ubuntu."
        if ($HyperVAvailable) {
            Write-Host "  $($Ui.Accent)2$($Ui.Reset)  Windows 11 Pro   PowerShell 7 + WSL2 com Ubuntu 26.04, Hyper-V, Área Restrita, Vagrant, Packer e Multipass."
        }
        else {
            Write-Host "$($Ui.Dim)  2  Windows 11 Pro   indisponível: esta edição do Windows não tem Hyper-V$($Ui.Reset)"
        }
        while ($true) {
            $answer = (Read-Host "  Opção [$default]").Trim()
            if (-not $answer) { $answer = $default }
            if ($answer -eq '1') { return 'Home' }
            if ($answer -eq '2') {
                if ($HyperVAvailable) { return 'Pro' }
                Write-Host "  $($Ui.Warn)Esta edição não tem Hyper-V; escolha 1.$($Ui.Reset)"
            }
            else {
                Write-Host '  Digite 1 ou 2.'
            }
        }
    }
    if ($choice -eq 'Pro' -and -not $HyperVAvailable) {
        Write-Host "$($Ui.Warn)▲ -Versao Pro precisa de Hyper-V, que esta edição não tem; seguindo com a Home.$($Ui.Reset)"
        return 'Home'
    }
    $choice
}

function Step-HyperV {
    # Membros do grupo criam e controlam VMs sem abrir o terminal como administrador
    $member = "$env:USERDOMAIN\$env:USERNAME"
    try {
        $group = Get-LocalGroup -SID $HyperVAdminsSid
        $members = @(Get-LocalGroupMember -SID $HyperVAdminsSid | ForEach-Object Name)
        if ($members -contains $member) {
            Write-Item Skip "Grupo $($group.Name)" "$member já é membro"
        }
        else {
            Add-LocalGroupMember -SID $HyperVAdminsSid -Member $member
            Write-Item Ok "Grupo $($group.Name)" "$member adicionado; vale no próximo login"
        }
    }
    catch {
        # Máquinas gerenciadas podem controlar os grupos locais por política
        Write-Item Warn 'Grupo Administradores do Hyper-V' $_.Exception.Message
    }

    # Sem isso o Vagrant procura o VirtualBox, que não convive bem com o Hyper-V
    if ([Environment]::GetEnvironmentVariable('VAGRANT_DEFAULT_PROVIDER', 'User') -eq 'hyperv') {
        Write-Item Skip 'Vagrant usa o Hyper-V' 'já configurado'
    }
    else {
        [Environment]::SetEnvironmentVariable('VAGRANT_DEFAULT_PROVIDER', 'hyperv', 'User')
        Write-Item Ok 'Vagrant usa o Hyper-V' 'VAGRANT_DEFAULT_PROVIDER=hyperv'
    }
}

function Step-UpgradeAll {
    $code = Invoke-Winget 'upgrade', '--all', '--include-unknown', '--silent', '--accept-package-agreements'
    if ($code -eq 0 -or $code -in $WingetNoop) { Write-Item Ok 'Aplicativos atualizados' }
    else { Write-Item Warn 'winget upgrade --all' ('retornou 0x{0:X8}; veja o log' -f $code) }
}

# =============================================================================
#  Execução
# =============================================================================

$Edition = Select-Edition

$Steps = @(
    @{ Title = 'Pré-requisitos';                      Action = { Step-Prerequisites }; Critical = $true }
    @{ Title = 'Recursos do Windows';                 Action = { Step-WindowsFeatures }; Skip = $SkipWindowsFeatures.IsPresent }
    @{ Title = $(if ($Edition -eq 'Pro') { "WSL2 e $WslDistro" } else { 'WSL2 (motor do Docker Desktop)' }); Action = { Step-WslUbuntu } }
    @{ Title = 'Configuração do WSL (.wslconfig)';    Action = { Step-WslConfig } }
    @{ Title = 'Remover apps pré-instalados';         Action = { Step-RemoveBloatware } }
    @{ Title = 'Ferramentas e aplicativos (winget)';  Action = { Step-CliTools } }
    @{ Title = 'Docker Desktop e k3d';                Action = { Step-DockerDesktop }; Skip = $Edition -ne 'Home' }
    @{ Title = 'CLIs do Kubernetes (GitHub Releases)'; Action = { Step-GitHubTools } }
    @{ Title = 'Hyper-V e VMs';                       Action = { Step-HyperV }; Skip = $Edition -ne 'Pro' }
    @{ Title = 'Ajustes de desenvolvedor';            Action = { Step-DeveloperSettings } }
    @{ Title = 'Aparência leve';                      Action = { Step-LightAppearance }; Skip = $Edition -ne 'Home' }
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
