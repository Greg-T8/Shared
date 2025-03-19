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

$Main = {

    # Initialize logging
    $logHeaders = 'User', 'Property', 'Value', 'Message'
    $function:Log = Logger -LogName UserUpdate -Headers $logHeaders -LogType Information

    $logHeaders =  'Action', 'Message'
    $function:LogEx = Logger -LogName UserUpdateException -Headers $logHeaders -LogType Exception

    # Example usage of the logging functions
    Log @{ User = 'john'; Property = 'DisplayName'; Value = 'John Doe'; Message = 'User display name updated' }
    LogEx @{ Action = 'Establish Connection'; Message = 'Issue connecting to database' }

}

function Logger {
    [OutputType([ScriptBlock])]
    param (
        [string]$LogName,
        [string[]]$Headers,
        [string]$LogType = 'Information'
    )

    # Set up the log file path, but do not create the file yet
    $logFileName = "$(Get-Date -Format 'yyyy-MM-dd-HHmmss')_$($LogName).csv"
    $logFile     = Join-Path -Path $PSScriptRoot -ChildPath $logFileName

    # Set up a Write-Host function based on the log type, but do not call it yet.
    # $Message is only a placeholder at this point; it does not exist as $WriteHost is not called yet.
    switch ($LogType) {
        'Information' { $WriteHost = { param($Message) Write-Host -Message $Message -ForegroundColor Gray } }
        'Exception' { $WriteHost = { param($Message) Write-Host -Message $Message -ForegroundColor Yellow } }
    }

    return {
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]$LogObject
        )

        # Write the log object to the console host
        [PSCustomObject]$logObject | Format-List | Out-String | ForEach-Object { & $WriteHost $_ }

        # Write the log object to the CSV file
        if (-not (Test-Path -Path $logFile)) { $Headers -join ',' | Out-File -FilePath $logFile }
        [PSCustomObject]$logObject | Export-Csv -Path $logFile -Append -Force -NoTypeInformation

    }.GetNewClosure()
}

& $Main