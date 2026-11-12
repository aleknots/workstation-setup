# =============================================================================
#  PowerShell 7 profile - SRE/DevOps
#  Deployed by setup-windows.ps1 to %USERPROFILE%\.config\powershell, outside
#  OneDrive (overwritten on every run, with a backup).
#  Personal customizations: profile.local.ps1, in the same folder.
# =============================================================================

$ProfileDir = $PSScriptRoot

#region Base ------------------------------------------------------------------
$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = [Text.UTF8Encoding]::new()

if (Test-Path "$env:WINDIR\System32\OpenSSH\ssh.exe") {
    $env:GIT_SSH = "$env:WINDIR\System32\OpenSSH\ssh.exe"
}

# Index of the executables on the PATH, built once: a Get-Command for a command
# that does not exist scans the whole PATH and costs hundreds of milliseconds.
$PathCommands = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($dir in $env:Path -split ';') {
    if (-not $dir -or -not [IO.Directory]::Exists($dir)) { continue }
    foreach ($file in [IO.Directory]::EnumerateFiles($dir)) {
        if ([IO.Path]::GetExtension($file) -in '.exe', '.cmd', '.bat') {
            $null = $PathCommands.Add([IO.Path]::GetFileNameWithoutExtension($file))
        }
    }
}

function Test-Cmd([string]$Name) { $PathCommands.Contains($Name) }
#endregion

#region Prompt ------------------------------------------------------------------
# Native prompt with the look of the Oh My Posh pixelrobots-az-custom theme.
# oh-my-posh.exe cost ~0.5 s per prompt on this machine; here the only external
# process is git, and only inside repositories. Cloud data comes from each CLI's
# config files, re-read only when they change.

$PromptColor = @{
    White  = $PSStyle.Foreground.FromRgb(0xFFFFFF)
    Yellow = $PSStyle.Foreground.FromRgb(0xFFFF00)
    Pink   = $PSStyle.Foreground.FromRgb(0xFFA5D8)
    Red    = $PSStyle.Foreground.FromRgb(0xFF0000)
    Black  = $PSStyle.Foreground.FromRgb(0x000000)
    KubeBg = $PSStyle.Background.FromRgb(0xFFEA00)
    AzBg   = $PSStyle.Background.FromRgb(0x008AD7)
    AzFg   = $PSStyle.Foreground.FromRgb(0x008AD7)
    AwsBg  = $PSStyle.Background.FromRgb(0xFFA400)
    Reset  = $PSStyle.Reset
}

$PromptIcon = @{
    Calendar  = [char]0xF073
    Ram       = [char]0xE266
    Kube      = [char]::ConvertFromUtf32(0xF10FE)
    Gcp       = [char]0xF1A0
    Azure     = [char]0xEBD8
    Aws       = [char]::ConvertFromUtf32(0xF0E0F)
    Arrow     = [char]0xE0B0
    Folder    = [char]0xF115
    Branch    = [char]0xE0A0
    Commit    = [char]0xF417
    Changed   = [char]0xF044
    Staged    = [char]0xF046
    Stash     = [char]0xEB4B
    Error     = [char]0xEA6C
    ErrorLine = [char]0xEA87
    GitHub    = [char]0xF408
    GitLab    = [char]0xF296
    Bitbucket = [char]0xF171
    AzDevOps  = [char]0xEBE8
    Git       = "$([char]0xE5FB) "
}

$PromptIsAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
$PromptFileCache = @{}
$PromptRam = @{ At = [datetime]::MinValue; Text = '' }

# Reads and parses a file, reusing the result while the file does not change
function Read-PromptFile([string]$Path, [scriptblock]$Parse) {
    $info = [IO.FileInfo]::new($Path)
    if (-not $info.Exists) { return $null }
    $entry = $PromptFileCache[$Path]
    if (-not $entry -or $entry.Stamp -ne $info.LastWriteTimeUtc) {
        $value = try { & $Parse ([IO.File]::ReadAllText($Path)) } catch { $null }
        $entry = @{ Stamp = $info.LastWriteTimeUtc; Value = $value }
        $PromptFileCache[$Path] = $entry
    }
    $entry.Value
}

function Get-PromptRam {
    if (([datetime]::UtcNow - $PromptRam.At).TotalSeconds -ge 5) {
        $os = Get-CimInstance Win32_OperatingSystem -Property TotalVisibleMemorySize, FreePhysicalMemory -ErrorAction Ignore
        if ($os) {
            # Values in KB; / 1MB converts to GB, truncated like Oh My Posh does
            $PromptRam.Text = '{0}/{1}GB' -f [math]::Truncate(($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / 1MB),
                [math]::Truncate($os.TotalVisibleMemorySize / 1MB)
        }
        $PromptRam.At = [datetime]::UtcNow
    }
    $PromptRam.Text
}

function Get-PromptKube {
    $config = ($env:KUBECONFIG -split ';' | Where-Object { $_ } | Select-Object -First 1) ?? (Join-Path $HOME '.kube\config')
    Read-PromptFile $config {
        param($text)
        if ($text -notmatch '(?m)^current-context:\s*"?([^"\r\n]+?)"?\s*$') { return }
        $context = $Matches[1]
        $namespace = $null
        foreach ($block in $text -split '(?m)^\s*-\s+context:') {
            if ($block -match "(?m)^\s+name:\s*`"?$([regex]::Escape($context))`"?\s*$" -and
                $block -match '(?m)^\s+namespace:\s*"?([^"\r\n]+?)"?\s*$') {
                $namespace = $Matches[1]
                break
            }
        }
        @{ Context = $context; Namespace = $namespace }
    }
}

function Get-PromptGcp {
    $dir = $env:CLOUDSDK_CONFIG ?? (Join-Path $env:APPDATA 'gcloud')
    $active = Read-PromptFile (Join-Path $dir 'active_config') { param($text) $text.Trim() }
    if (-not $active) { return }
    Read-PromptFile (Join-Path $dir "configurations\config_$active") {
        param($text)
        $core = if ($text -match '(?s)\[core\](.*?)(?:\r?\n\[|$)') { $Matches[1] } else { '' }
        $project = if ($core -match '(?m)^\s*project\s*=\s*(.+?)\s*$') { $Matches[1] }
        $account = if ($core -match '(?m)^\s*account\s*=\s*(.+?)\s*$') { $Matches[1] }
        if ($project) { @{ Project = $project; Account = $account } }
    }
}

function Get-PromptAzure {
    $dir = $env:AZURE_CONFIG_DIR ?? (Join-Path $HOME '.azure')
    Read-PromptFile (Join-Path $dir 'azureProfile.json') {
        param($text)
        $default = ($text | ConvertFrom-Json).subscriptions | Where-Object isDefault | Select-Object -First 1
        if ($default) { @{ Name = $default.name; Origin = 'CLI' } }
    }
}

function Get-PromptAws {
    $config = $env:AWS_CONFIG_FILE ?? (Join-Path $HOME '.aws\config')
    $profileName = $env:AWS_PROFILE ?? $env:AWS_DEFAULT_PROFILE
    if (-not $profileName -and -not (Test-Path -LiteralPath $config)) { return }
    $profileName ??= 'default'
    $region = $env:AWS_REGION ?? $env:AWS_DEFAULT_REGION
    if (-not $region) {
        $regions = Read-PromptFile $config {
            param($text)
            $map = @{}
            $section = $null
            foreach ($line in $text -split '\r?\n') {
                if ($line -match '^\s*\[(?:profile\s+)?([^\]]+)\]') { $section = $Matches[1].Trim() }
                elseif ($section -and $line -match '^\s*region\s*=\s*(\S+)') { $map[$section] = $Matches[1] }
            }
            $map
        }
        if ($regions) { $region = $regions[$profileName] }
    }
    @{ Profile = $profileName; Region = $region }
}

function Get-PromptGit {
    if ($PWD.Provider.Name -ne 'FileSystem') { return }

    # Looks for .git walking up the folders, without calling git outside repositories
    $gitDir = $null
    for ($dir = $PWD.ProviderPath; $dir; $dir = Split-Path $dir -Parent) {
        $candidate = Join-Path $dir '.git'
        if ([IO.Directory]::Exists($candidate) -or [IO.File]::Exists($candidate)) { $gitDir = $candidate; break }
    }
    if (-not $gitDir) { return }

    $lines = git --no-optional-locks status --porcelain=v2 --branch --show-stash 2>$null
    if ($LASTEXITCODE -ne 0) { return }

    $kinds = @{ A = '+'; C = '+'; M = '~'; T = '~'; D = '-'; R = '>' }
    $staging = [ordered]@{ '+' = 0; '~' = 0; '-' = 0; '>' = 0 }
    $working = [ordered]@{ '?' = 0; '+' = 0; '~' = 0; '-' = 0; '>' = 0; 'x' = 0 }
    $oid = $head = $null
    $hasUpstream = $hasAheadBehind = $false
    $ahead = $behind = $stash = 0

    foreach ($line in $lines) {
        switch -Regex ($line) {
            '^# branch\.oid (\S+)' { $oid = $Matches[1]; break }
            '^# branch\.head (.+)$' { $head = $Matches[1]; break }
            '^# branch\.upstream ' { $hasUpstream = $true; break }
            '^# branch\.ab \+(\d+) -(\d+)' { $ahead = [int]$Matches[1]; $behind = [int]$Matches[2]; $hasAheadBehind = $true; break }
            '^# stash (\d+)' { $stash = [int]$Matches[1]; break }
            '^[12] (.)(.) ' {
                $x = $kinds["$($Matches[1])"]; if ($x) { $staging[$x]++ }
                $y = $kinds["$($Matches[2])"]; if ($y) { $working[$y]++ }
                break
            }
            '^u ' { $working['x']++; break }
            '^\? ' { $working['?']++; break }
        }
    }

    # Icon of the service hosting the origin remote
    $url = if ([IO.Directory]::Exists($gitDir)) {
        Read-PromptFile (Join-Path $gitDir 'config') {
            param($text)
            if ($text -match '(?s)\[remote "origin"\][^\[]*?url\s*=\s*(\S+)') { $Matches[1] }
        }
    }
    $upstreamIcon = switch -Regex ($url) {
        'github' { $PromptIcon.GitHub; break }
        'gitlab' { $PromptIcon.GitLab; break }
        'bitbucket' { $PromptIcon.Bitbucket; break }
        'dev\.azure|visualstudio' { $PromptIcon.AzDevOps; break }
        default { $PromptIcon.Git }
    }

    $headText = if ($head -and $head -ne '(detached)') { "$($PromptIcon.Branch)$head" }
    else { "$($PromptIcon.Branch)detached at $($PromptIcon.Commit)$("$oid".Substring(0, [Math]::Min(7, "$oid".Length)))" }

    # Same symbols as Oh My Posh; no upstream (or a deleted upstream) also shows the not-identical sign
    $branchStatus = if (-not $hasUpstream -or -not $hasAheadBehind) { '≢' }
    elseif ($ahead -and $behind) { "↑$ahead ↓$behind" }
    elseif ($ahead) { "↑$ahead" }
    elseif ($behind) { "↓$behind" }
    else { '≡' }

    $format = { param($counts) ($counts.GetEnumerator() | Where-Object Value | ForEach-Object { "$($_.Key)$($_.Value)" }) -join ' ' }
    @{
        UpstreamIcon = $upstreamIcon
        Head         = $headText
        BranchStatus = $branchStatus
        Working      = & $format $working
        Staging      = & $format $staging
        Stash        = $stash
    }
}

function prompt {
    $failed = -not $?
    $exitCode = $global:LASTEXITCODE
    $c = $PromptColor
    $i = $PromptIcon

    # Line 1: time, RAM and cloud contexts
    $now = [datetime]::Now
    $time = $now.ToString('h:mm:ss tt', [cultureinfo]::InvariantCulture) + ' ' + $now.ToString('zz')
    $line1 = "$($c.White)[$($i.Calendar) $time][$($i.Ram) RAM: $(Get-PromptRam)]"

    if ($kube = Get-PromptKube) {
        $namespace = if ($kube.Namespace) { " :: $($kube.Namespace)" }
        $line1 += "$($c.KubeBg)$($c.Black) $($i.Kube) $($kube.Context)$namespace $($c.Reset)$($c.White)"
    }
    if ($gcp = Get-PromptGcp) {
        $line1 += "[$($i.Gcp) $($c.Yellow)$($gcp.Project)$($c.White) :: $($c.Yellow)$($gcp.Account)$($c.White)]"
    }
    $aws = Get-PromptAws
    if ($az = Get-PromptAzure) {
        $line1 += "$($c.AzBg)$($c.Black) $($i.Azure) $($az.Name) [ $($az.Origin) ] "
        $line1 += if ($aws) { "$($c.AwsBg)$($c.AzFg)$($i.Arrow)" } else { "$($c.Reset)$($c.AzFg)$($i.Arrow)$($c.Reset)$($c.White)" }
    }
    if ($aws) {
        $region = if ($aws.Region) { "@$($aws.Region)" }
        $line1 += "$($c.AwsBg)$($c.Black) $($i.Aws) $($aws.Profile)$region$($c.Reset)$($c.White)"
    }

    # Line 2: folder and git
    $path = $PWD.Path
    if ($path -like "$HOME*") { $path = '~' + $path.Substring($HOME.Length) }
    $line2 = "$($c.White)$([char]0x2523)[$($i.Folder) $path]"
    if ($git = Get-PromptGit) {
        $line2 += "$($c.Pink)[$($c.White)$($git.UpstreamIcon) $($c.Pink)$($git.Head)"
        if ($git.BranchStatus) { $line2 += " $($git.BranchStatus)" }
        if ($git.Working) { $line2 += " $($c.White)$($i.Changed)$($c.Pink) $($git.Working)" }
        if ($git.Working -and $git.Staging) { $line2 += ' |' }
        if ($git.Staging) { $line2 += " $($c.White)$($i.Staged)$($c.Pink) $($git.Staging)" }
        if ($git.Stash) { $line2 += " $($c.White)$($i.Stash)$($c.Pink) $($git.Stash)" }
        $line2 += ']'
    }

    # Line 3: admin, last command error and the cursor
    $line3 = "$($c.White)$([char]0x2514)$([char]0x2500)"
    if ($PromptIsAdmin) { $line3 += "$($c.Yellow)[#]$($c.White)" }
    if ($failed) { $line3 += "$($c.Pink)[$($c.White)$($i.Error)$($c.Pink) Error, check your command]$($c.White)" }

    $global:LASTEXITCODE = $exitCode
    "$line1$($c.Reset)`n$line2$($c.Reset)`n$line3>$($c.Reset) "
}

# Input line in red when the typed command has a syntax error
if ($Host.Name -eq 'ConsoleHost') {
    Set-PSReadLineOption -PromptText '> ', "$($PromptColor.Red)$($PromptIcon.ErrorLine)$($PromptColor.Reset) " -ContinuationPrompt ' '
}
#endregion

#region PSReadLine and fzf -----------------------------------------------------
if ($Host.Name -eq 'ConsoleHost') {
    Import-Module CompletionPredictor -ErrorAction Ignore
    try {
        Set-PSReadLineOption -EditMode Emacs -BellStyle None -HistoryNoDuplicates `
            -MaximumHistoryCount 20000 -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView `
            -Colors @{ InlinePrediction = $PSStyle.Foreground.BrightBlack }
    }
    catch {
        # No VT support (e.g. redirected output): no prediction
    }
    Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward

    # PSFzf is only loaded on the first Ctrl+r/Ctrl+t so it does not slow down startup
    if (Test-Cmd fzf) {
        $global:LoadPsFzf = {
            if (-not (Get-Module PSFzf)) {
                Import-Module PSFzf
                Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+t' -PSReadlineChordReverseHistory 'Ctrl+r'
            }
        }
        Set-PSReadLineKeyHandler -Chord Ctrl+r -BriefDescription 'Histórico com fzf' `
            -ScriptBlock { & $global:LoadPsFzf; Invoke-FzfPsReadlineHandlerHistory }
        Set-PSReadLineKeyHandler -Chord Ctrl+t -BriefDescription 'Arquivos com fzf' `
            -ScriptBlock { & $global:LoadPsFzf; Invoke-FzfPsReadlineHandlerProvider }
    }
}

if (Test-Cmd zoxide) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}
#endregion

#region Completion ----------------------------------------------------------------
# Completion scripts are generated once a week and cached; generating them on
# every startup costs hundreds of milliseconds per tool.
$CompletionCache = Join-Path $env:LOCALAPPDATA 'pwsh-completions'
$CompletionSources = [ordered]@{
    kubectl = { kubectl completion powershell }
    helm    = { helm completion powershell }
    gh      = { gh completion -s powershell }
    flux    = { flux completion powershell }
    kind    = { kind completion powershell }
}
foreach ($tool in $CompletionSources.Keys) {
    if (-not (Test-Cmd $tool)) { continue }
    $completionFile = Join-Path $CompletionCache "$tool.ps1"
    $stale = -not (Test-Path $completionFile) -or
        (Get-Item $completionFile).LastWriteTime -lt (Get-Date).AddDays(-7)
    if ($stale) {
        $null = New-Item -ItemType Directory -Path $CompletionCache -Force
        & $CompletionSources[$tool] | Out-File -FilePath $completionFile -Encoding utf8
    }
    . $completionFile
}
if ($__kubectlCompleterBlock) {
    Register-ArgumentCompleter -CommandName k -ScriptBlock $__kubectlCompleterBlock
}

# Azure CLI (official Microsoft snippet)
if (Test-Cmd az) {
    Register-ArgumentCompleter -Native -CommandName az -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $completionFile = New-TemporaryFile
        $env:ARGCOMPLETE_USE_TEMPFILES = 1
        $env:_ARGCOMPLETE_STDOUT_FILENAME = $completionFile
        $env:COMP_LINE = $wordToComplete
        $env:COMP_POINT = $cursorPosition
        $env:_ARGCOMPLETE = 1
        $env:_ARGCOMPLETE_SUPPRESS_SPACE = 0
        $env:_ARGCOMPLETE_IFS = "`n"
        $env:_ARGCOMPLETE_SHELL = 'powershell'
        az 2>&1 | Out-Null
        Get-Content $completionFile | Sort-Object | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
        Remove-Item $completionFile, Env:\_ARGCOMPLETE_STDOUT_FILENAME, Env:\ARGCOMPLETE_USE_TEMPFILES,
            Env:\COMP_LINE, Env:\COMP_POINT, Env:\_ARGCOMPLETE, Env:\_ARGCOMPLETE_SUPPRESS_SPACE,
            Env:\_ARGCOMPLETE_IFS, Env:\_ARGCOMPLETE_SHELL
    }
}
#endregion

#region Built-in aliases ----------------------------------------------------------
# Built-in aliases take precedence over functions, so the ones that share a name
# with the shortcuts below must go (gc=Get-Content, gl=Get-Location,
# gp=Get-ItemProperty, gcm=Get-Command, gcb=Get-Clipboard, h=Get-History).
foreach ($name in 'gc', 'gl', 'gp', 'gcm', 'gcb', 'ls', 'h') {
    Remove-Alias -Name $name -Force -ErrorAction Ignore
}
#endregion

#region Navigation and files ----------------------------------------------------------
if (Test-Cmd eza) {
    function ls { eza --icons --group-directories-first @args }
    function ll { eza -l --icons --git --group-directories-first @args }
    function la { eza -la --icons --git --group-directories-first @args }
    function lt { eza --tree --level=2 --icons --group-directories-first @args }
}
else {
    Import-Module Terminal-Icons -ErrorAction Ignore
    function ls { Get-ChildItem @args }
    function ll { Get-ChildItem @args | Format-Table -AutoSize }
    function la { Get-ChildItem -Force @args | Format-Table -AutoSize }
}
Set-Alias lsl ll
Set-Alias lsla la

function .. { Set-Location .. }
function ... { Set-Location ..\.. }

function mkcd([string]$Path) {
    $null = New-Item -ItemType Directory -Path $Path -Force
    Set-Location $Path
}

function touch([string]$Path) {
    if (Test-Path $Path) { (Get-Item $Path).LastWriteTime = Get-Date }
    else { $null = New-Item -ItemType File -Path $Path }
}

function which([string]$Name) {
    $command = Get-Command $Name -ErrorAction Ignore
    if ($command.Source) { $command.Source } else { $command.Definition }
}

Set-Alias grep Select-String
Set-Alias c Clear-Host
Set-Alias j Get-Job
if (Test-Cmd nvim) { Set-Alias vim nvim }
#endregion

#region System and network -----------------------------------------------------------
function df {
    Get-PSDrive -PSProvider FileSystem | Where-Object Used |
        Select-Object Name,
            @{ n = 'Usado (GB)'; e = { [math]::Round($_.Used / 1GB, 1) } },
            @{ n = 'Livre (GB)'; e = { [math]::Round($_.Free / 1GB, 1) } },
            Root
}

# Size of each item in the current folder, smallest first (same as du -sh * | sort -h)
function dus {
    Get-ChildItem -Force | ForEach-Object {
        $bytes = if ($_.PSIsContainer) {
            (Get-ChildItem $_.FullName -Recurse -Force -File -ErrorAction Ignore | Measure-Object Length -Sum).Sum
        }
        else { $_.Length }
        [pscustomobject]@{ Nome = $_.Name; 'Tamanho (MB)' = [math]::Round($bytes / 1MB, 1) }
    } | Sort-Object 'Tamanho (MB)'
}

function myip { (Invoke-RestMethod https://ifconfig.me/ip).Trim() }

function ports {
    Get-NetTCPConnection -State Listen | Sort-Object LocalPort |
        Select-Object LocalAddress, LocalPort, OwningProcess,
            @{ n = 'Processo'; e = { (Get-Process -Id $_.OwningProcess -ErrorAction Ignore).ProcessName } }
}

function ping { ping.exe -n 5 @args }

# Full history (all sessions) with fzf; runs the chosen command
function h {
    $lines = Get-Content (Get-PSReadLineOption).HistorySavePath
    [array]::Reverse($lines)
    $command = $lines | Select-Object -Unique | fzf --no-sort --prompt 'histórico> '
    if ($command) {
        Write-Host "$($PSStyle.Foreground.BrightBlack)> $command$($PSStyle.Reset)"
        Invoke-Expression $command
    }
}
#endregion

#region Git Bash -------------------------------------------------------------------
# Git for Windows bash in the same window, without WSL and without the Git Bash console:
#   gbash | gbash script.sh | gbash -c 'command'
# Plain "bash" is the WSL launcher in System32, hence the full path.
$GitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
if (Test-Path $GitBash) {
    function gbash {
        if ($args) { & $GitBash @args } else { & $GitBash --login -i }
    }
}
#endregion

#region Git ------------------------------------------------------------------------
Set-Alias g git
function gst { git status @args }
function ga { git add @args }
function gc { git commit -m @args }
function gp { git push @args }
function gl { git pull @args }
function gco { git checkout @args }
function gb { git branch @args }
function gcb { git checkout -b @args }
function gcm { git checkout main @args }
function gcd { git checkout dev @args }
function gpl { git pull origin main @args }
function gcl { git clone @args }

# add + commit + push of everything, with an optional message: d "fix X"
function d([string]$Message = 'Automated commit') {
    git add .
    git commit -m $Message
    git push
}
#endregion

#region Docker (Docker Desktop) -------------------------------------------------------
function up { docker compose up -d @args }
function down { docker compose down @args }
function dps { docker ps @args }
function dpa { docker ps -a @args }
function di { docker images @args }
function drm { docker rm @args }
function drmi { docker rmi @args }
function dlogs { docker logs -f @args }
function dexec { docker exec -it @args }
function dbuild { docker build -t @args }
function dnet { docker network @args }
function dvol { docker volume @args }
function dbash([string]$Container) { docker exec -it $Container /bin/bash }
function dsh([string]$Container) { docker exec -it $Container /bin/sh }
#endregion

#region Kubernetes --------------------------------------------------------------------
Set-Alias k kubectl
function kgp { kubectl get pods @args }
function kgs { kubectl get svc @args }
function kga { kubectl get all @args }
function kget { kubectl get @args }
function kdel { kubectl delete @args }
function klogs { kubectl logs -f @args }
function kexec { kubectl exec -it @args }
function kapply { kubectl apply -f @args }
function kctx { if (Test-Cmd kubectx) { kubectx @args } else { kubectl config use-context @args } }
function kns { if (Test-Cmd kubens) { kubens @args } else { kubectl config set-context --current --namespace @args } }

# Namespace events, most recent last
function kev { kubectl get events --sort-by=.lastTimestamp @args }

# Pods that are neither Running nor Succeeded, in all namespaces
function kbad { kubectl get pods -A '--field-selector=status.phase!=Running,status.phase!=Succeeded' }

# Decodes every key of a Secret: ksecret <name> [-n ns]
function ksecret {
    param([Parameter(Mandatory)][string]$Name, [Parameter(ValueFromRemainingArguments)][string[]]$Rest)
    $secret = kubectl get secret $Name @Rest -o json | ConvertFrom-Json
    $secret.data.PSObject.Properties | ForEach-Object {
        [pscustomobject]@{
            Chave = $_.Name
            Valor = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_.Value))
        }
    }
}

# Ephemeral pod with network tools (dig, curl, tcpdump...) in the current namespace
function knetshoot {
    $command = if ($args) { $args } else { 'zsh' }
    kubectl run "netshoot-$(Get-Random -Maximum 9999)" --rm -it --restart=Never --image=nicolaka/netshoot -- @command
}
#endregion

#region k3s lab ----------------------------------------------------------------------------
# k3s runs in Docker Desktop containers, via k3d, context "k3d-lab". kubectl, k9s,
# helm, argocd, kubeseal and Headlamp reach the cluster through localhost.
$LabContext = $null

if (Test-Cmd k3d) {
    $LabContext = 'k3d-lab'
    $LabCluster = 'lab'

    function Test-DockerReady {
        $null = docker info 2>&1
        if ($LASTEXITCODE) {
            Write-Warning 'O Docker não respondeu: abra o Docker Desktop e espere ele ficar pronto.'
            return $false
        }
        $true
    }

    # Creates the cluster the first time and just restarts it afterwards; k3d writes the
    # k3d-lab context to ~/.kube/config
    function k3s-up {
        if (-not (Test-DockerReady)) { return }
        $exists = @(k3d cluster list -o json | ConvertFrom-Json) | Where-Object name -eq $LabCluster
        if ($exists) { k3d cluster start $LabCluster }
        else { k3d cluster create $LabCluster }
        $null = kubectl config use-context $LabContext
        kubectl get nodes
    }

    function k3s-down { k3d cluster stop $LabCluster }

    function k3s-status { k3d cluster list }

    # Argo CD and the lab add-ons; Argo CD itself installs and maintains each
    # add-on. -Grafana adds kube-prometheus-stack (~1 GB more RAM).
    function lab-argocd {
        param([switch]$Grafana)
        $ctx = '--context', $LabContext
        kubectl @ctx create namespace argocd --dry-run=client -o yaml | kubectl @ctx apply -f - | Out-Null
        kubectl @ctx apply -n argocd --server-side --force-conflicts `
            -f 'https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml' | Out-Null
        kubectl @ctx -n argocd rollout status deployment/argocd-server --timeout=600s

        $addons = @(
            @{ Name = 'sealed-secrets'; Repo = 'https://bitnami.github.io/sealed-secrets'; Namespace = 'kube-system'
               Values = @{ fullnameOverride = 'sealed-secrets-controller' } }
            @{ Name = 'argo-rollouts'; Repo = 'https://argoproj.github.io/argo-helm'; Namespace = 'argo-rollouts'
               Values = @{ dashboard = @{ enabled = $true } } }
        )
        if ($Grafana) {
            $addons += @{ Name = 'kube-prometheus-stack'; Repo = 'https://prometheus-community.github.io/helm-charts'; Namespace = 'monitoring'
                Values = @{ grafana = @{ adminPassword = 'admin' }; kubeEtcd = @{ enabled = $false }
                    kubeControllerManager = @{ enabled = $false }; kubeScheduler = @{ enabled = $false }; kubeProxy = @{ enabled = $false } } }
        }
        foreach ($addon in $addons) {
            @{
                apiVersion = 'argoproj.io/v1alpha1'
                kind       = 'Application'
                metadata   = @{ name = $addon.Name; namespace = 'argocd' }
                spec       = @{
                    project     = 'default'
                    source      = @{ repoURL = $addon.Repo; chart = $addon.Name; targetRevision = '*'
                                     helm = @{ releaseName = $addon.Name; valuesObject = $addon.Values } }
                    destination = @{ server = 'https://kubernetes.default.svc'; namespace = $addon.Namespace }
                    syncPolicy  = @{ automated = @{ prune = $true; selfHeal = $true }
                                     syncOptions = @('CreateNamespace=true', 'ServerSideApply=true') }
                }
            } | ConvertTo-Json -Depth 10 | kubectl @ctx apply -f -
        }
        'Argo CD pronto: argocd-ui'
    }
}

# Argo CD, Rollouts and Grafana commands, in whichever lab context exists
if ($LabContext) {
    function argocd-pass {
        $encoded = kubectl --context $LabContext -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}'
        [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
    }

    # Argo CD UI at https://localhost:8080; Ctrl+C stops the port-forward
    function argocd-ui {
        "https://localhost:8080 · usuário admin · senha: $(argocd-pass)"
        Start-Process 'https://localhost:8080'
        kubectl --context $LabContext -n argocd port-forward svc/argocd-server 8080:443
    }

    # Argo CD CLI login straight through the cluster API, no port-forward
    function argocd-login {
        argocd login --core
        kubectl config set-context --current --namespace argocd
    }

    # Argo Rollouts dashboard at http://localhost:3100
    function rollouts-ui {
        Start-Process 'http://localhost:3100'
        kubectl argo rollouts dashboard
    }

    # Grafana (kube-prometheus-stack add-on) at http://localhost:3000 - admin/admin
    function grafana-ui {
        Start-Process 'http://localhost:3000'
        kubectl --context $LabContext -n monitoring port-forward svc/kube-prometheus-stack-grafana 3000:80
    }
}
#endregion

#region Cloud and IaC -------------------------------------------------------------------
Set-Alias tf terraform

function azlogin { az login --use-device-code @args }

# Generates the ssh config for Azure VMs (az ssh)
function gen-cert { az ssh config --ip * --file (Join-Path $env:TEMP 'az-ssh.conf') @args }

# Switch profile/subscription/project with fzf
function awsp {
    $selected = aws configure list-profiles | fzf --prompt 'AWS profile> '
    if ($selected) { $env:AWS_PROFILE = $selected; "AWS_PROFILE=$selected" }
}
function azsub {
    $selected = az account list --query '[].[name,id]' -o tsv | fzf --prompt 'Azure subscription> '
    if ($selected) {
        az account set --subscription ($selected -split "`t")[1]
        az account show --query name -o tsv
    }
}
function gcpp {
    $selected = gcloud projects list --format='value(projectId)' | fzf --prompt 'GCP project> '
    if ($selected) { gcloud config set project $selected }
}
#endregion

#region Personal scripts ----------------------------------------------------------------
# Local folder, outside OneDrive: %USERPROFILE%\.config\powershell\scripts
$SreScripts = Join-Path $PSScriptRoot 'scripts'

# Keeps the session awake (F15 every 4 min). Runs until Ctrl+C.
function aleonx {
    $script = Join-Path $SreScripts 'aleonx.ps1'
    if (-not (Test-Path -LiteralPath $script)) { Write-Warning "Script não encontrado: $script"; return }
    & $script @args
}
#endregion

#region cursaves ------------------------------------------------------------------------
# Syncs the SRE workspace (#1) with GitHub
function csync { cursaves sync -w 1 @args }
Set-Alias css csync
#endregion

#region Local customizations ------------------------------------------------------------
$LocalProfile = Join-Path $ProfileDir 'profile.local.ps1'
if (Test-Path $LocalProfile) { . $LocalProfile }
#endregion
