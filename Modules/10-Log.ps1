#Requires -Version 5.1
<#
    WinMedic - persistent activity log

    Upstream's Write-GuiLog writes to the on-screen text box and nowhere else,
    so once the window closes there is no record that a tool which edits the
    registry, disables services and deletes drivers ever ran. This module gives
    every one of those operations a durable trail without touching any of them:
    Write-GuiLog is the single funnel they already share.

    One file per day under data\logs. Each line carries the machine name, so
    logs collected from several machines stay readable when pooled.

    Logging must never break a maintenance action, so every failure here is
    swallowed after the first warning - a lost log line is preferable to an
    aborted repair.

    ASCII only in this file. PSScriptAnalyzer requires a BOM for files with
    non-ASCII content, and Modules/ is gated on warnings; user-facing strings
    belong in the translation table in WMT-GUI.ps1 instead.
#>

$script:WmtLogFilePath = $null
$script:WmtLogRotated = $false
$script:WmtLogFailed = $false

function Get-WmtLogDirectory {
    <#
        .SYNOPSIS
        Returns the folder holding the activity logs, creating it if needed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $root = $null
    try { $root = Get-DataPath }
    catch {
        Write-Debug ("Get-WmtLogDirectory: Get-DataPath unavailable - {0}" -f $_.Exception.Message)
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($root)) { return $null }

    $dir = Join-Path $root 'logs'
    if (-not (Test-Path -LiteralPath $dir)) {
        try { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        catch {
            Write-Debug ("Get-WmtLogDirectory: cannot create {0} - {1}" -f $dir, $_.Exception.Message)
            return $null
        }
    }

    return $dir
}

function Get-WmtLogPath {
    <#
        .SYNOPSIS
        Returns today's log file path, or $null when logging is unavailable.

        .DESCRIPTION
        The path is cached for the session. A run that crosses midnight keeps
        writing to the file it started in, which keeps one session in one file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($script:WmtLogFilePath) { return $script:WmtLogFilePath }

    $dir = Get-WmtLogDirectory
    if (-not $dir) { return $null }

    $script:WmtLogFilePath = Join-Path $dir ('{0}.log' -f (Get-Date -Format 'yyyy-MM-dd'))
    return $script:WmtLogFilePath
}

function Test-WmtLoggingEnabled {
    <#
        .SYNOPSIS
        True unless the user has turned file logging off in settings.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $settings = Get-WmtSettings
        if ($settings -and $null -ne $settings.FileLoggingEnabled) {
            return [bool]$settings.FileLoggingEnabled
        }
    }
    catch {
        Write-Debug ("Test-WmtLoggingEnabled: settings unavailable - {0}" -f $_.Exception.Message)
    }

    return $true
}

function Invoke-WmtLogRotation {
    <#
        .SYNOPSIS
        Deletes log files older than the retention window. Runs once per session.

        .OUTPUTS
        The number of files removed.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([int])]
    param(
        [ValidateRange(1, 3650)]
        [int]$RetentionDays = 0
    )

    if ($RetentionDays -le 0) {
        $RetentionDays = 30
        try {
            $settings = Get-WmtSettings
            $configured = 0
            if ($settings -and $settings.LogRetentionDays) {
                $configured = [int]$settings.LogRetentionDays
            }
            if ($configured -gt 0) { $RetentionDays = $configured }
        }
        catch {
            Write-Debug ("Invoke-WmtLogRotation: settings unavailable - {0}" -f $_.Exception.Message)
        }
    }

    $dir = Get-WmtLogDirectory
    if (-not $dir) { return 0 }

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    $removed = 0

    try {
        $stale = @(Get-ChildItem -LiteralPath $dir -Filter '*.log' -File -ErrorAction Stop |
                Where-Object { $_.LastWriteTime -lt $cutoff })

        foreach ($file in $stale) {
            if ($PSCmdlet.ShouldProcess($file.FullName, 'Delete expired log')) {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $removed++
            }
        }
    }
    catch {
        Write-Debug ("Invoke-WmtLogRotation: {0}" -f $_.Exception.Message)
    }

    return $removed
}

function Write-WmtLogFile {
    <#
        .SYNOPSIS
        Appends one line to today's log file.

        .DESCRIPTION
        Called from Write-GuiLog, so it runs for every operation in the app.
        Never throws: after the first failure it stops trying for the rest of
        the session rather than warning once per action.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Message
    )

    if ($script:WmtLogFailed) { return }
    if (-not (Test-WmtLoggingEnabled)) { return }

    $path = Get-WmtLogPath
    if (-not $path) { return }

    if (-not $script:WmtLogRotated) {
        $script:WmtLogRotated = $true
        Invoke-WmtLogRotation -Confirm:$false | Out-Null
        Write-WmtLogHeader
    }

    try {
        $line = '[{0}] [{1}] {2}{3}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
        $env:COMPUTERNAME, $Message, [Environment]::NewLine
        [System.IO.File]::AppendAllText($path, $line, [System.Text.Encoding]::UTF8)
    }
    catch {
        $script:WmtLogFailed = $true
        Write-Warning ("WinMedic could not write to the log file, continuing without it: {0}" -f $_.Exception.Message)
    }
}

function Write-WmtLogHeader {
    <#
        .SYNOPSIS
        Writes a session banner so a pooled log says which machine and build
        produced the lines that follow.
    #>
    [CmdletBinding()]
    param()

    $path = Get-WmtLogPath
    if (-not $path) { return }

    $mode = 'unknown'
    try { $mode = Get-WmtMode }
    catch { Write-Debug ("Write-WmtLogHeader: mode unavailable - {0}" -f $_.Exception.Message) }

    $osName = 'unknown'
    try { $osName = (Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction Stop).Caption }
    catch { Write-Debug ("Write-WmtLogHeader: OS caption unavailable - {0}" -f $_.Exception.Message) }

    $lines = @(
        ''
        ('=' * 78)
        ('WinMedic {0} session started {1}' -f $script:AppVersion, (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))
        ('  machine : {0}' -f $env:COMPUTERNAME)
        ('  user    : {0}' -f $env:USERNAME)
        ('  os      : {0}' -f $osName)
        ('  mode    : {0}' -f $mode)
        ('=' * 78)
    )

    try {
        [System.IO.File]::AppendAllText($path, ($lines -join [Environment]::NewLine) + [Environment]::NewLine, [System.Text.Encoding]::UTF8)
    }
    catch {
        Write-Debug ("Write-WmtLogHeader: {0}" -f $_.Exception.Message)
    }
}

function Show-WmtLogFolder {
    <#
        .SYNOPSIS
        Opens the log folder in Explorer.
    #>
    [CmdletBinding()]
    param()

    $dir = Get-WmtLogDirectory
    if (-not $dir) {
        Write-Warning 'WinMedic has no log folder to open.'
        return
    }

    try { Start-Process -FilePath 'explorer.exe' -ArgumentList $dir }
    catch { Write-Warning ("Could not open the log folder: {0}" -f $_.Exception.Message) }
}
