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

.NOTES
    This technique is particularly useful for creating reusable function factories where you want to
    pre-configure some behavior but retain flexibility in how the generated functions are used.

    Without GetNewClosure(), the variables defined in the parent scope ($logFile, $Headers, etc.)
    would be lost when the returned scriptblock is executed, resulting in undefined variables.

    In this example, we create two distinct logging functions with different configurations
    from a single Logger factory function, demonstrating the power of closures for creating
    specialized behavior.
#>

$Main = {

    # Initialize logging, one function for normal logging, one for exceptions
    $logHeaders = 'User', 'Property', 'Value', 'Message'
    $function:Log = Logger -LogName UserUpdate -Headers $logHeaders -LogType Information

    $logHeaders =  'Action', 'Message'
    $function:LogEx = Logger -LogName UserUpdateException -Headers $logHeaders -LogType Exception

    # Usage of the logging functions
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
    switch ($LogType) {
        'Information' { $writeHost = { param($Message) Write-Host -Message $Message -ForegroundColor Gray } }
        'Exception' { $writeHost = { param($Message) Write-Host -Message $Message -ForegroundColor Yellow } }
    }

    return {
        param (
            [Parameter(Mandatory = $true)]
            [hashtable]$LogObject
        )

        # Write the log object to the console host
        [PSCustomObject]$LogObject | Format-List | Out-String | ForEach-Object { & $writeHost $_ }

        # Write the log object to the CSV file
        if (-not (Test-Path -Path $logFile)) { $Headers -join ',' | Out-File -FilePath $logFile }
        [PSCustomObject]$LogObject | Export-Csv -Path $logFile -Append -Force -NoTypeInformation

    }.GetNewClosure()
}

& $Main