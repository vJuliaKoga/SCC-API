param(
    [string]$Root = "."
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

function Get-FilesToRedact {
    param(
        [string]$RepoRoot,
        [string[]]$ExcludePaths = @()
    )

    $files = New-Object System.Collections.Generic.List[object]
    $pending = New-Object System.Collections.Generic.Stack[string]
    $excludedFullPaths = @{}

    foreach ($path in $ExcludePaths) {
        if ([string]::IsNullOrWhiteSpace($path)) {
            continue
        }

        try {
            $resolvedExcludePath = (Resolve-Path -LiteralPath $path -ErrorAction Stop).Path
        }
        catch {
            $resolvedExcludePath = [System.IO.Path]::GetFullPath($path)
        }

        $excludedFullPaths[$resolvedExcludePath.ToLowerInvariant()] = $true
    }

    $pending.Push($RepoRoot)

    while ($pending.Count -gt 0) {
        $current = $pending.Pop()
        $children = @(Get-ChildItem -LiteralPath $current -Force -ErrorAction SilentlyContinue)

        foreach ($child in $children) {
            if ($excludedFullPaths.ContainsKey($child.FullName.ToLowerInvariant())) {
                continue
            }

            if ($child.PSIsContainer) {
                if ($excludeDirs -contains $child.Name) {
                    continue
                }

                $pending.Push($child.FullName)
                continue
            }

            $leafName = $child.Name.ToLowerInvariant()
            $extension = [System.IO.Path]::GetExtension($child.Name).ToLowerInvariant()
            if (
                ($allowExt -contains $extension) -or
                ($leafName -eq ".env") -or
                ($leafName.StartsWith(".env.", [System.StringComparison]::Ordinal))
            ) {
                $files.Add($child)
            }
        }
    }

    return $files
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

function Write-TextFilePreservingEncoding {
    param(
        [string]$Path,
        [string]$Text,
        [System.Text.Encoding]$Encoding
    )

    [System.IO.File]::WriteAllText($Path, $Text, $Encoding)
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

function Apply-RegexReplacement {
    param(
        [string]$Text,
        [regex]$Regex,
        [string]$Replacement
    )

    $matchCount = $Regex.Matches($Text).Count
    if ($matchCount -eq 0) {
        return [pscustomobject]@{
            Text = $Text
            MatchCount = 0
        }
    }

    return [pscustomobject]@{
        Text = $Regex.Replace($Text, $Replacement)
        MatchCount = $matchCount
    }
}

function Get-RedactionPreview {
    param(
        [string]$Text,
        [object[]]$Rules
    )

    $currentText = $Text
    $totalMatches = 0

    foreach ($rule in $Rules) {
        $result = Apply-RegexReplacement -Text $currentText -Regex $rule.Regex -Replacement $rule.Replacement
        $currentText = $result.Text
        $totalMatches += $result.MatchCount
    }

    return [pscustomobject]@{
        Text = $currentText
        MatchCount = $totalMatches
    }
}

function Read-RedactionChoice {
    param(
        [string]$RelativePath,
        [int]$Index,
        [int]$Total,
        [int]$MatchCount
    )

    while ($true) {
        $plural = if ($MatchCount -eq 1) { "" } else { "es" }
        $choice = Read-Host ("MASK [{0}/{1}] {2} ({3} match{4})? [Y]es/[N]o/[A]ll/[Q]uit" -f $Index, $Total, $RelativePath, $MatchCount, $plural)
        if ($null -eq $choice) {
            $choice = ""
        }
        $normalized = $choice.Trim().ToUpperInvariant()

        switch ($normalized) {
            "Y" { return "Y" }
            "YES" { return "Y" }
            "N" { return "N" }
            "NO" { return "N" }
            "A" { return "A" }
            "ALL" { return "A" }
            "Q" { return "Q" }
            "QUIT" { return "Q" }
            default {
                Write-Host "Please enter Y, N, A, or Q."
            }
        }
    }
}

try {
    $resolvedRoot = (Resolve-Path -LiteralPath $Root).Path
    $script:GitExe = Get-GitExecutable
    $repoRoot = $null

    Push-Location $resolvedRoot
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

    $scriptPath = (Resolve-Path -LiteralPath $MyInvocation.MyCommand.Path).Path
    $scriptDir = Split-Path -Parent $scriptPath
    $launcherScriptPath = Join-Path $scriptDir "repo-start.ps1"
    $launcherCmdPath = Join-Path (Split-Path -Parent $scriptDir) "repo-start.cmd"

    # Text-like file types to scan.
    $allowExt = @(
        ".env",
        ".ini",
        ".cfg",
        ".conf",
        ".toml",
        ".json",
        ".md",
        ".txt",
        ".yaml",
        ".yml",
        ".py",
        ".js",
        ".ts",
        ".tsx",
        ".jsx",
        ".sh",
        ".bat",
        ".ps1",
        ".xml",
        ".csv"
    )

    # Directories to skip during scanning.
    $excludeDirs = @(
        ".git",
        "node_modules",
        ".venv",
        "venv",
        "dist",
        "build",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache"
    )

    # Common secret value patterns only.
    # Avoid key-name based masking so code like `apiKey` / `loadApiKey` is never rewritten.
    $rxSkLike = [regex]'\bsk-[A-Za-z0-9][A-Za-z0-9_-]{10,}\b'
    $rxGoogleApi = [regex]'\bAIza[0-9A-Za-z_-]{20,}\b'
    $rxAwsId = [regex]'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'
    $rxGitHub1 = [regex]'\bgh[pousr]_[A-Za-z0-9]{20,}\b'
    $rxGitHub2 = [regex]'\bgithub_pat_[A-Za-z0-9_]{20,}\b'
    $rxSlack = [regex]'\bxox[baprs]-[A-Za-z0-9-]{10,}\b'
    $rxBearer = [regex]'(?i)\bbearer\s+[A-Za-z0-9._~+\/=-]{10,}\b'
    $redactionRules = @(
        [pscustomobject]@{ Regex = $rxSkLike; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxGoogleApi; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxAwsId; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxGitHub1; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxGitHub2; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxSlack; Replacement = "APIKEY" },
        [pscustomobject]@{ Regex = $rxBearer; Replacement = "Bearer APIKEY" }
    )

    Write-Host "Redacting secrets in: $repoRoot"

    $files = Get-FilesToRedact -RepoRoot $repoRoot -ExcludePaths @(
        $scriptPath,
        $launcherScriptPath,
        $launcherCmdPath
    )

    $candidates = New-Object System.Collections.Generic.List[object]

    foreach ($file in $files) {
        try {
            $fileContent = Read-TextFilePreservingEncoding -Path $file.FullName
            $text = [string]$fileContent.Text
            $encoding = $fileContent.Encoding
        }
        catch {
            continue
        }

        if ($null -eq $text) {
            $text = ""
        }

        $original = $text

        try {
            $preview = Get-RedactionPreview -Text $text -Rules $redactionRules
            $text = $preview.Text
        }
        catch {
            throw "Redaction failed for $($file.FullName): $($_.Exception.Message)"
        }

        if ($text -ne $original) {
            $candidates.Add([pscustomobject]@{
                FullPath = $file.FullName
                RelativePath = Get-RelativeRepoPath -RepoRoot $repoRoot -FullPath $file.FullName
                RedactedText = $text
                Encoding = $encoding
                MatchCount = $preview.MatchCount
            })
        }
    }

    if ($candidates.Count -eq 0) {
        Write-Host "No secrets detected."
        Write-Host "Done: redacted 0 file(s)."
        exit 0
    }

    Write-Host ""
    Write-Host ("Detected secret-like values in {0} file(s):" -f $candidates.Count)
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $candidate = $candidates[$i]
        $plural = if ($candidate.MatchCount -eq 1) { "" } else { "es" }
        Write-Host ("  [{0}] {1} ({2} match{3})" -f ($i + 1), $candidate.RelativePath, $candidate.MatchCount, $plural)
    }
    Write-Host "Choices: [Y]es = mask this file / [N]o = skip / [A]ll = mask this and remaining files / [Q]uit = stop"
    Write-Host ""

    $changed = 0
    $skipped = 0
    $applyAll = $false

    for ($i = 0; $i -lt $candidates.Count; $i++) {
        $candidate = $candidates[$i]
        $shouldApply = $false

        if ($applyAll) {
            $shouldApply = $true
        }
        else {
            $choice = Read-RedactionChoice -RelativePath $candidate.RelativePath -Index ($i + 1) -Total $candidates.Count -MatchCount $candidate.MatchCount
            switch ($choice) {
                "Y" { $shouldApply = $true }
                "N" { $shouldApply = $false }
                "A" {
                    $applyAll = $true
                    $shouldApply = $true
                }
                "Q" {
                    throw ([System.OperationCanceledException]::new("Secret redaction was canceled by user."))
                }
            }
        }

        if ($shouldApply) {
            Write-TextFilePreservingEncoding -Path $candidate.FullPath -Text $candidate.RedactedText -Encoding $candidate.Encoding
            Write-Host ("REDACTED: {0}" -f $candidate.RelativePath)
            $changed++
        }
        else {
            Write-Host ("SKIPPED: {0}" -f $candidate.RelativePath)
            $skipped++
        }
    }

    Write-Host ("Done: redacted {0} file(s), skipped {1} file(s)." -f $changed, $skipped)
    exit 0
}
catch [System.OperationCanceledException] {
    Write-Host ("CANCELED: " + $_.Exception.Message) -ForegroundColor Yellow
    exit 2
}
catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
