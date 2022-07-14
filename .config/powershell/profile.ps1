#Requires -Version 7

# Version 1.0.0

# Cross-platform PowerShell profile based on https://devblogs.microsoft.com/powershell/optimizing-your-profile/

# check if newer version
$gistUrl = "https://api.github.com/gists/5beceaccb6bd72a7a8ce60993fb9beed"
$latestVersionFile = [System.IO.Path]::Combine("$HOME", '.latest_profile_version')
$versionRegEx = "# Version (?<version>\d+\.\d+\.\d+)"

if ([System.IO.File]::Exists($latestVersionFile)) {
    $latestVersion = [System.IO.File]::ReadAllText($latestVersionFile)
    $currentProfile = [System.IO.File]::ReadAllText($profile)
    [version]$currentVersion = "0.0.0"
    if ($currentProfile -match $versionRegEx) {
        $currentVersion = $matches.Version
    }

    if ([version]$latestVersion -gt $currentVersion) {
        Write-Verbose "Your version: $currentVersion" -Verbose
        Write-Verbose "New version: $latestVersion" -Verbose
        $choice = Read-Host -Prompt "Found newer profile, install? (Y)"
        if ($choice -eq "Y" -or $choice -eq "") {
            try {
                $gist = Invoke-RestMethod $gistUrl -ErrorAction Stop
                $gistProfile = $gist.Files."profile.ps1".Content
                Set-Content -Path $profile -Value $gistProfile
                Write-Verbose "Installed newer version of profile" -Verbose
                . $profile
                return
            } catch {
                # we can hit rate limit issue with GitHub since we're using anonymous
                Write-Verbose -Verbose "Was not able to access gist, try again next time"
            }
        }
    }
}

$global:profile_initialized = $false


# Useful before doing demos, where default settings might be preferred
function Reset-Console {

    function global:prompt { "PS $($executionContext.SessionState.Path.CurrentLocation)$('>' * ($nestedPromptLevel + 1)) " }

    Set-Location ~

}

function prompt {

    function Initialize-Profile {

        $null = Start-ThreadJob -Name "Get version of `$profile from gist" -ArgumentList $gistUrl, $latestVersionFile, $versionRegEx -ScriptBlock {
            param ($gistUrl, $latestVersionFile, $versionRegEx)

            try {
                $gist = Invoke-RestMethod $gistUrl -ErrorAction Stop

                $gistProfile = $gist.Files."profile.ps1".Content
                [version]$gistVersion = "0.0.0"
                if ($gistProfile -match $versionRegEx) {
                    $gistVersion = $matches.Version
                    Set-Content -Path $latestVersionFile -Value $gistVersion
                }
            } catch {
                # we can hit rate limit issue with GitHub since we're using anonymous
                Write-Verbose -Verbose "Was not able to access gist to check for newer version"
            }
        }

        if ((Get-Module PSReadLine).Version -lt 2.2) {
            throw "Profile requires PSReadLine 2.2+"
        }

        $ErrorView = 'ConciseView'

        # setup psdrives

        if (!(Test-Path repos:)) {
            if (Test-Path ([System.IO.Path]::Combine("$HOME", 'git'))) {
                New-PSDrive -Root ~/git -Name git -PSProvider FileSystem > $Null
            } elseif (Test-Path "c:\git") {
                New-PSDrive -Root c:\git -Name git -PSProvider FileSystem > $Null
            }
        }

        Set-PSReadLineOption -Colors @{ Selection = "`e[92;7m"; InLinePrediction = "`e[36;7;238m" } -PredictionSource History
        Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
        Set-PSReadLineKeyHandler -Chord Ctrl+b -Function BackwardWord
        Set-PSReadLineKeyHandler -Chord Ctrl+f -Function ForwardWord
        Set-PSReadLineOption -MaximumHistoryCount 32767
        Set-PSReadLineOption -PredictionViewStyle ListView
        if ($IsWindows) {
            Set-PSReadLineOption -EditMode Emacs -ShowToolTips
            Set-PSReadLineKeyHandler -Chord Ctrl+Shift+c -Function Copy
            Set-PSReadLineKeyHandler -Chord Ctrl+Shift+v -Function Paste
        } else {
            try {
                Import-UnixCompleters
            } catch [System.Management.Automation.CommandNotFoundException] {
                Install-Module Microsoft.PowerShell.UnixCompleters -Repository PSGallery -AcceptLicense -Force
                Import-UnixCompleters
            }
        }
    
    }


    if ($global:profile_initialized -ne $true) {
        $global:profile_initialized = $true
        Initialize-Profile
    }

    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\default.omp.json" | Invoke-Expression
    prompt

    $currentLastExitCode = $LASTEXITCODE
    $lastSuccess = $?

    # set window title
    try {
        $prefix = ''
        if ($isWindows) {
            $identity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
            $windowsPrincipal = [Security.Principal.WindowsPrincipal]::new($identity)
            if ($windowsPrincipal.IsInRole("Administrators") -eq 1) {
                $prefix = "Admin:"
            }
        }

        $Host.ui.RawUI.WindowTitle = "$prefix$PWD"
    } catch {
        # do nothing if can't be set
    }

    $global:LASTEXITCODE = $currentLastExitCode
}