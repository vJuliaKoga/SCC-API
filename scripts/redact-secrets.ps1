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

    # Common secret patterns.
    $rxOpenAi = [regex]'\bsk-[A-Za-z0-9]{10,}\b'
    $rxAwsId = [regex]'\b(?:AKIA|ASIA)[0-9A-Z]{16}\b'
    $rxGitHub1 = [regex]'\bgh[pousr]_[A-Za-z0-9]{20,}\b'
    $rxGitHub2 = [regex]'\bgithub_pat_[A-Za-z0-9_]{20,}\b'
    $rxSlack = [regex]'\bxox[baprs]-[A-Za-z0-9-]{10,}\b'
    $rxBearer = [regex]'(?i)\bbearer\s+[A-Za-z0-9._~+\/=-]{10,}\b'

    # Common environment/config key names.
    $keyNames = @(
        "OPENAI_API_KEY",
        "ANTHROPIC_API_KEY",
        "AZURE_OPENAI_API_KEY",
        "GOOGLE_API_KEY",
        "GITHUB_TOKEN",
        "GH_TOKEN",
        "AWS_ACCESS_KEY_ID",
        "AWS_SECRET_ACCESS_KEY",
        "AWS_SESSION_TOKEN",
        "Authorization",
        "AUTHORIZATION"
    )

    $keyAlt = ($keyNames | ForEach-Object { [regex]::Escape($_) }) -join "|"

    $rxKeyValueLine = New-Object System.Text.RegularExpressions.Regex(
        "(?im)^(\s*(?:$keyAlt)\s*[:=]\s*)(.+?)(\s*(?:#.*)?)$"
    )

    $rxCommonJsonYaml = New-Object System.Text.RegularExpressions.Regex(
        '(?im)((?<![A-Za-z0-9_$.-])"?(?:api[_-]?key|access[_-]?key|secret|token|authorization|bearer)"?\s*[:=]\s*"?)([^"\r\n#]+)("?)'
    )

    Write-Host "Redacting secrets in: $repoRoot"

    $files = Get-FilesToRedact -RepoRoot $repoRoot -ExcludePaths @(
        $scriptPath,
        $launcherScriptPath,
        $launcherCmdPath
    )

    $changed = 0

    foreach ($file in $files) {
        try {
            $text = [string](Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop)
        }
        catch {
            continue
        }

        if ($null -eq $text) {
            $text = ""
        }

        $original = $text

        try {
            $text = $rxOpenAi.Replace($text, "APIKEY")
            $text = $rxAwsId.Replace($text, "APIKEY")
            $text = $rxGitHub1.Replace($text, "APIKEY")
            $text = $rxGitHub2.Replace($text, "APIKEY")
            $text = $rxSlack.Replace($text, "APIKEY")
            $text = $rxBearer.Replace($text, "Bearer APIKEY")
            $text = $rxKeyValueLine.Replace($text, '${1}APIKEY${3}')
            $text = $rxCommonJsonYaml.Replace($text, '${1}APIKEY${3}')
        }
        catch {
            throw "Redaction failed for $($file.FullName): $($_.Exception.Message)"
        }

        if ($text -ne $original) {
            # Rewrite only when the content actually changed.
            [System.IO.File]::WriteAllText(
                $file.FullName,
                $text,
                [System.Text.UTF8Encoding]::new($false)
            )
            Write-Host "REDACTED: $($file.FullName)"
            $changed++
        }
    }

    Write-Host "Done: redacted $changed file(s)."
    exit 0
}
catch {
    Write-Host ("ERROR: " + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
