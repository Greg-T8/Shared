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

.PARAMETER LogName
    When using the Logger function, this parameter defines the base name for the log file.

.PARAMETER Headers
    When using the Logger function, this parameter defines the column headers for the CSV log file.

.PARAMETER LogType
    When using the Logger function, this parameter defines the type of log which affects the console output color.
    Valid values are 'Output' (Gray) and 'Exception' (Yellow).

.EXAMPLE
    $function:Log = Logger -LogName "UserActivity" -Headers @('User', 'Action', 'Time') -LogType Output
    Log @{ User = 'jane'; Action = 'Login'; Time = Get-Date }

    Creates a logging function that writes to a CSV file with the specified headers and displays output in gray.

.EXAMPLE
    $function:ErrorLog = Logger -LogName "ErrorReports" -Headers @('Error', 'Module', 'Message') -LogType Exception
    ErrorLog @{ Error = 'ConnectionFailed'; Module = 'Network'; Message = 'Could not connect to server' }

    Creates an error logging function that writes to a CSV file and displays output in yellow.

.OUTPUTS
    Each logging function creates a timestamped CSV file in the script's directory and writes log entries to both
    the console and the CSV file.

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
    $function:Log = Logger -LogName UserUpdate -Headers $logHeaders -LogType Output

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
        'Output' { $writeHost = { param($Message) Write-Host -Message $Message -ForegroundColor Gray } }
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

    }.GetNewClosure() # Allows inner function to use variables from outer function, i.e. $Headers, $logFile, $writeHost

}

& $Main