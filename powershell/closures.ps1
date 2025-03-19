<#
.SYNOPSIS
    Example script demonstrating PowerShell closures through a configurable logging function.

.DESCRIPTION
    This script demonstrates the concept of closures in PowerShell by implementing a flexible logging system.
    A closure is a function that retains access to the local variables of its parent scope even after
    the parent function has completed execution.

    The Logger function in this script uses GetNewClosure() to create a scriptblock that "captures" variables
    from its parent scope (like $LogFile, $Headers, etc.) so they remain available when the returned scriptblock
    is executed elsewhere. This allows for creating customized logging functions with pre-configured settings.

.EXAMPLE
    $log = Logger -LogName "MyApp" -Headers @("Timestamp", "Message", "Severity") -LogType "Information"
    $log([PSCustomObject]@{Timestamp = Get-Date; Message = "Application started"; Severity = "Info"})

.NOTES
    This technique is particularly useful for creating reusable function factories where you want to
#>

test

function Logger {
    [OutputType([ScriptBlock])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        # No whitespace allowed in log name
        [ValidateScript({ -not ($_ -match '^\s|\s$') -and -not ($_ -match '\s') })]
        [string]$LogName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Headers,

        [ValidateSet('Information', 'Exception')]
        [string]$LogType = 'Information',

        [switch]$SuppressHostOutput,
        [switch]$SuppressLogOutput
    )

    $logDirectory = Join-Path -Path $PSScriptRoot -ChildPath 'Output'
    if (-not (Test-Path -Path $logDirectory)) {
        New-Item -Path $logDirectory -ItemType Directory | Out-Null
    }
    $logFileName = "$(Get-Date -Format 'yyyy-MM-dd-HHmmss')_$($LogName).csv"
    $logFile = Join-Path -Path $logDirectory -ChildPath $logFileName
    switch ($LogType) {
        'Information' { $WriteHost = { param($Message) Write-Host -Message $Message -ForegroundColor Gray } }
        'Exception' { $WriteHost = { param($Message) Write-Host -Message $Message -ForegroundColor Yellow } }
    }
    return {
        [OutputType($null)]
        param (
            [Parameter(Mandatory, Position = 0)]
            [ValidateScript(
                {
                    # Validate that the object passed to the logger has the same properties as the headers
                    $passedProperties = $_.PSObject.Properties.Name
                    $result = Compare-Object -ReferenceObject $Headers -DifferenceObject $passedProperties
                    return $result.Count -eq 0
                },
                ErrorMessage = 'The item following item did not pass validation for logging: {0}.' +
                'Ensure the properties of the logging object contain each of the defined log headers.'
            )]
            [PSCustomObject]$LogObject
        )
        if (-not $SuppressHostOutput) {
            # Then write to host
            $logObject | Format-List | Out-String | ForEach-Object { $_ -split "`n" } |
                Where-Object { $_ -ne '' -and $_ -ne $null } | ForEach-Object { & $WriteHost $_ }
        }
        if (-not $SuppressLogOutput) {
            # Then write to log file
            $csvEncoding = 'utf8BOM'
            if (-not (Test-Path -Path $logFile)) {
                $Headers -join ',' | Out-File -FilePath $logFile -Encoding $csvEncoding
            }
            $logObject | Export-Csv -Path $logFile -Append -Force -NoTypeInformation -Encoding $csvEncoding
        }
    }.GetNewClosure()
    # Use a scriptblock closure to capture or "close" variables that are defined in the outer funcion, i.e. the
    # parent function before before the returned scriptblock; otherwise the returned scriptblock will not be
    # able to access variables from the outer function..
}