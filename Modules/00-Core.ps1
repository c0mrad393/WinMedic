#Requires -Version 5.1
<#
    WinMedic - operating mode

    WinMedic serves two audiences from one codebase:

      home  Someone maintaining their own PC. Everything is visible, including
            the game library and gaming tweaks inherited from upstream.

      pro   Someone maintaining machines that are not theirs - a school lab, an
            office floor. Consumer-facing features are hidden to shrink the
            surface an administrator has to reason about, and to keep the tool
            defensible when it runs on institutional hardware.

    The mode only controls visibility. It is not a security boundary: nothing
    here prevents a determined user from switching back.
#>

$script:WmtModeCode = $null

# Controls hidden in pro mode. Names match x:Name in the XAML.
$script:WmtHiddenInProMode = @(
    'btnUtilMas'                  # Microsoft Activation Scripts
    'btnShowLibrary'              # Steam/Epic/GOG game library
    'btnCatGames'                 # "Gaming" catalog filter
    'btnToggleGameMode'
    'btnToggleGameBar'
    'btnToggleGameBarIntegration'
    'btnToggleGameCapture'
)

function Get-WmtMode {
    <#
        .SYNOPSIS
        Returns the active operating mode: 'home' or 'pro'.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($script:WmtModeCode) { return $script:WmtModeCode }

    $mode = 'home'
    try {
        $settings = Get-WmtSettings
        if ($settings -and -not [string]::IsNullOrWhiteSpace([string]$settings.Mode)) {
            $mode = [string]$settings.Mode
        }
    }
    catch {
        # Settings unreadable this early, or not written yet - home is the safe default.
    }

    $mode = $mode.Trim().ToLowerInvariant()
    if ($mode -ne 'pro') { $mode = 'home' }

    $script:WmtModeCode = $mode
    return $mode
}

function Test-WmtProMode {
    <#
        .SYNOPSIS
        True when the active mode is 'pro'.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return ((Get-WmtMode) -eq 'pro')
}

function Set-WmtMode {
    <#
        .SYNOPSIS
        Persists the operating mode and applies it to the current window.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('home', 'pro')]
        [string]$Mode
    )

    if (-not $PSCmdlet.ShouldProcess('WinMedic settings', "Set operating mode to '$Mode'")) { return }

    $settings = Get-WmtSettings
    $settings.Mode = $Mode
    Save-WmtSettings -Settings $settings

    $script:WmtModeCode = $Mode
    Update-WmtModeVisibility
}

function Update-WmtModeVisibility {
    <#
        .SYNOPSIS
        Shows or hides mode-specific controls to match the active mode.

        .DESCRIPTION
        Safe to call before the window exists; controls that cannot be resolved
        are skipped. Returns the number of controls it changed.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param()

    $hide = Test-WmtProMode
    $changed = 0

    foreach ($name in $script:WmtHiddenInProMode) {
        $control = $null
        try { $control = Get-Ctrl $name } catch { continue }
        if (-not $control) { continue }

        $target = if ($hide) {
            [System.Windows.Visibility]::Collapsed
        }
        else {
            [System.Windows.Visibility]::Visible
        }

        if ($control.Visibility -ne $target) {
            $control.Visibility = $target
            $changed++
        }
    }

    return $changed
}
