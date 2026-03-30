param(
    [string]$Root = ".",
    [switch]$SkipOpenDesktop,
    [string]$LogPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitExecutable {
    $command = Get-Command git.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command git -ErrorAction SilentlyContinue
    }

    if ($command) {
        return $command.Source
    }

    $desktopRoot = Join-Path $env:LOCALAPPDATA "GitHubDesktop"
    if (Test-Path -LiteralPath $desktopRoot) {
        $desktopGit = Get-ChildItem -LiteralPath $desktopRoot -Directory -Filter "app-*" -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending |
            ForEach-Object {
                Join-Path $_.FullName "resources\app\git\cmd\git.exe"
            } |
            Where-Object {
                Test-Path -LiteralPath $_
            } |
            Select-Object -First 1

        if ($desktopGit) {
            return $desktopGit
        }
    }

    $fallbacks = @(
        "$env:ProgramFiles\Git\cmd\git.exe",
        "${env:ProgramFiles(x86)}\Git\cmd\git.exe"
    ) | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_)
    }

    foreach ($candidate in $fallbacks) {
        if (Test-Path -LiteralPath $candidate) {
            return $candidate
        }
    }

    throw "git was not found. Install Git for Windows or GitHub Desktop."
}

function Get-PowerShellExecutable {
    $command = Get-Command pwsh.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command pwsh -ErrorAction SilentlyContinue
    }

    if ($command) {
        return $command.Source
    }

    $command = Get-Command powershell.exe -ErrorAction SilentlyContinue
    if (-not $command) {
        $command = Get-Command powershell -ErrorAction SilentlyContinue
    }

    if ($command) {
        return $command.Source
    }

    throw "PowerShell executable was not found."
}

function Start-RepoTranscript {
    param(
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return
    }

    $directory = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($directory) -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory | Out-Null
    }

    Start-Transcript -LiteralPath $Path -Append | Out-Null
    $script:TranscriptStarted = $true
}

function Stop-RepoTranscript {
    if (-not $script:TranscriptStarted) {
        return
    }

    try {
        Stop-Transcript | Out-Null
    }
    catch {
    }

    $script:TranscriptStarted = $false
}

function Read-TextFilePreservingEncoding {
    param(
        [string]$Path
    )

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encoding = $null
    $preambleLength = 0
    $text = $null

    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true)
        $preambleLength = 3
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.UnicodeEncoding]::new($false, $true)
        $preambleLength = 2
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.UnicodeEncoding]::new($true, $true)
        $preambleLength = 2
    }
    elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        $encoding = [System.Text.UTF32Encoding]::new($false, $true)
        $preambleLength = 4
    }
    elseif ($bytes.Length -ge 4 -and $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        $encoding = [System.Text.UTF32Encoding]::new($true, $true)
        $preambleLength = 4
    }
    else {
        $utf8NoBomStrict = [System.Text.UTF8Encoding]::new($false, $true)

        try {
            $text = $utf8NoBomStrict.GetString($bytes)
            $encoding = [System.Text.UTF8Encoding]::new($false)
        }
        catch {
            $encoding = [System.Text.Encoding]::Default
            $text = $encoding.GetString($bytes)
        }
    }

    if ($null -eq $text) {
        if ($bytes.Length -eq 0) {
            $text = ""
        }
        else {
            $text = $encoding.GetString($bytes, $preambleLength, $bytes.Length - $preambleLength)
        }
    }

    return [pscustomobject]@{
        Text = $text
        Encoding = $encoding
    }
}

function Get-RepoRoot {
    param(
        [string]$BasePath
    )

    $resolved = (Resolve-Path -LiteralPath $BasePath).Path
    $repoRoot = $null

    Push-Location $resolved
    try {
        try {
            $commandOutput = & $script:GitExe rev-parse --show-toplevel 2>$null
            if ($LASTEXITCODE -eq 0 -and $commandOutput) {
                $repoRoot = ($commandOutput | Select-Object -First 1).Trim()
            }
        }
        catch {
            $repoRoot = $null
        }
    }
    finally {
        Pop-Location
    }

    if (-not $repoRoot) {
        throw "The target path is not inside a Git repository."
    }

    return $repoRoot
}

function Add-GitIgnoreLineIfMissing {
    param(
        [string]$GitIgnorePath,
        [string]$Line
    )

    $existingText = ""
    $encoding = [System.Text.UTF8Encoding]::new($false)

    if (Test-Path -LiteralPath $GitIgnorePath) {
        $gitIgnoreContent = Read-TextFilePreservingEncoding -Path $GitIgnorePath
        $existingText = [string]$gitIgnoreContent.Text
        $encoding = $gitIgnoreContent.Encoding
        if ($null -eq $existingText) {
            $existingText = ""
        }
    }
    else {
        [System.IO.File]::WriteAllText($GitIgnorePath, "", $encoding)
    }

    if ([string]::IsNullOrEmpty($existingText)) {
        $existingLines = @()
    }
    else {
        $existingLines = @($existingText -split "\r?\n")
    }

    if ($existingLines -notcontains $Line) {
        $prefix = ""
        if ($existingText.Length -gt 0 -and -not $existingText.EndsWith("`n")) {
            $prefix = [System.Environment]::NewLine
        }

        [System.IO.File]::AppendAllText(
            $GitIgnorePath,
            "$prefix$Line$([System.Environment]::NewLine)",
            $encoding
        )
        Write-Host "ADDED .gitignore: $Line"
    }
}

function Test-GitTracked {
    param(
        [string]$RepoRoot,
        [string]$TargetPath,
        [bool]$IsDirectory
    )

    Push-Location $RepoRoot
    try {
        $trackedEntries = @(& $script:GitExe ls-files -- "$TargetPath")
        return ($trackedEntries.Count -gt 0)
    }
    finally {
        Pop-Location
    }
}

function Untrack-PathIfTracked {
    param(
        [string]$RepoRoot,
        [string]$TargetPath,
        [bool]$IsDirectory
    )

    if (-not (Test-GitTracked -RepoRoot $RepoRoot -TargetPath $TargetPath -IsDirectory $IsDirectory)) {
        return
    }

    Push-Location $RepoRoot
    try {
        if ($IsDirectory) {
            & $script:GitExe rm --cached -r -f --ignore-unmatch -- "$TargetPath"
        }
        else {
            & $script:GitExe rm --cached -f --ignore-unmatch -- "$TargetPath"
        }

        if ($LASTEXITCODE -ne 0) {
            throw "Failed to untrack: $TargetPath"
        }

        Write-Host "UNTRACKED: $TargetPath"
    }
    finally {
        Pop-Location
    }
}

function Open-GitHubDesktop {
    param(
        [string]$RepoRoot
    )

    $desktopCandidates = @(
        "$env:LOCALAPPDATA\GitHubDesktop\GitHubDesktop.exe",
        "$env:ProgramFiles\GitHub Desktop\GitHubDesktop.exe",
        "${env:ProgramFiles(x86)}\GitHub Desktop\GitHubDesktop.exe"
    )

    foreach ($candidate in $desktopCandidates) {
        if ([string]::IsNullOrWhiteSpace($candidate)) {
            continue
        }

        if (Test-Path -LiteralPath $candidate) {
            Start-Process -FilePath $candidate -ArgumentList @("--path", $RepoRoot) | Out-Null
            Write-Host "GitHub Desktop launched."
            return
        }
    }

    try {
        Start-Process "github://openRepo/$RepoRoot" | Out-Null
        Write-Host "GitHub Desktop launched."
        return
    }
    catch {
        Write-Warning "Could not launch GitHub Desktop automatically. Open it manually if needed."
    }
}

function Get-IgnoreCandidateItems {
    param(
        [string]$RepoRoot
    )

    $results = New-Object System.Collections.Generic.List[object]
    $pending = New-Object System.Collections.Generic.Stack[string]
    $pending.Push($RepoRoot)

    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $children = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue)

        foreach ($child in $children) {
            if ($child.Name -eq ".git") {
                continue
            }

            if ($child.PSIsContainer) {
                if ($child.Name -in @("node_modules", ".venv")) {
                    $results.Add($child)
                    continue
                }

                $pending.Push($child.FullName)
                continue
            }

            if ($child.Name -eq ".env" -or $child.Name.StartsWith(".env.", [System.StringComparison]::OrdinalIgnoreCase)) {
                $results.Add($child)
            }
        }
    }

    return $results
}

function Get-RelativeRepoPath {
    param(
        [string]$RepoRoot,
        [string]$FullPath
    )

    $repoBase = $RepoRoot
    if (-not $repoBase.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $repoBase += [System.IO.Path]::DirectorySeparatorChar
    }

    $repoUri = New-Object System.Uri($repoBase)
    $itemUri = New-Object System.Uri($FullPath)
    $relativeUri = $repoUri.MakeRelativeUri($itemUri)

    return [System.Uri]::UnescapeDataString($relativeUri.ToString()).Replace("\", "/")
}

$script:TranscriptStarted = $false
$exitCode = 0

try {
    $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    Start-RepoTranscript -Path $LogPath
    $script:GitExe = Get-GitExecutable
    $script:PowerShellExe = Get-PowerShellExecutable
    $repoRoot = Get-RepoRoot -BasePath $Root
    $redactScriptPath = Join-Path $scriptDir "redact-secrets.ps1"
    $gitIgnorePath = Join-Path $repoRoot ".gitignore"

    if (-not (Test-Path -LiteralPath $redactScriptPath)) {
        throw "redact-secrets.ps1 was not found: $redactScriptPath"
    }

    Write-Host "Target repository: $repoRoot"
    Write-Host "Using git: $script:GitExe"
    Write-Host "Using PowerShell: $script:PowerShellExe"

    # 1. Redact common secret patterns across the repository.
    & $script:PowerShellExe -NoProfile -ExecutionPolicy Bypass -File $redactScriptPath -Root $repoRoot
    if ($LASTEXITCODE -eq 2) {
        throw ([System.OperationCanceledException]::new("Secret redaction was canceled by user."))
    }
    if ($LASTEXITCODE -ne 0) {
        throw "Secret redaction failed."
    }

    # 2. Detect .env / node_modules / .venv and add them to .gitignore.
    $targets = Get-IgnoreCandidateItems -RepoRoot $repoRoot

    $uniqueTargets = @{}
    foreach ($item in $targets) {
        $fullPath = $item.FullName
        if (-not $uniqueTargets.ContainsKey($fullPath)) {
            $uniqueTargets[$fullPath] = $item
        }
    }

    foreach ($entry in $uniqueTargets.GetEnumerator()) {
        $item = $entry.Value
        $relativePath = Get-RelativeRepoPath -RepoRoot $repoRoot -FullPath $item.FullName

        if ($item.PSIsContainer) {
            Add-GitIgnoreLineIfMissing -GitIgnorePath $gitIgnorePath -Line "/$relativePath/"
            Untrack-PathIfTracked -RepoRoot $repoRoot -TargetPath $relativePath -IsDirectory $true
        }
        else {
            Add-GitIgnoreLineIfMissing -GitIgnorePath $gitIgnorePath -Line "/$relativePath"
            Untrack-PathIfTracked -RepoRoot $repoRoot -TargetPath $relativePath -IsDirectory $false
        }
    }

    # 3. Stage .gitignore updates and untracked removals.
    Push-Location $repoRoot
    try {
        if (Test-Path -LiteralPath $gitIgnorePath) {
            & $script:GitExe add .gitignore
        }
        & $script:GitExe add -A
        if ($LASTEXITCODE -ne 0) {
            throw "git add failed."
        }
    }
    finally {
        Pop-Location
    }

    # 4. Open GitHub Desktop at the end unless explicitly skipped.
    if (-not $SkipOpenDesktop) {
        Open-GitHubDesktop -RepoRoot $repoRoot
    }
}
catch [System.OperationCanceledException] {
    $exitCode = 2
}
catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
    $exitCode = 1
}
finally {
    Stop-RepoTranscript
}

exit $exitCode
