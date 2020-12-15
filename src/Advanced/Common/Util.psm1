# Copyright(c) Microsoft and contributors. All rights reserved
#
# This source code is licensed under the MIT license found in the LICENSE file in the root directory of the source tree

function DisplayScriptHeader
{
    <#
    .SYNOPSIS
        Display script header text
    #>
    OutputMessage -Message "----------------------------------------------------------------------------------------------------------------------" -MessageType Info
    OutputMessage -Message "Azure NetAppFiles PowerShell SMB SDK Sample - Sample project that creates Azure NetApp Files Volume uses SMB protocol|" -MessageType Info
    OutputMessage -Message "----------------------------------------------------------------------------------------------------------------------" -MessageType Info    
}


function DisplayCleanupHeader
{
    <#
    .SYNOPSIS
        Display Clean up text
    #>
    OutputMessage -Message "-----------------------------------------" -MessageType Info
    OutputMessage -Message "Cleaning up Azure NetApp Files resources|" -MessageType Info
    OutputMessage -Message "-----------------------------------------" -MessageType Info
}


function OutputMessage
{
    <#
    .SYNOPSIS
        Output message with the corresponding message type and color
    .DESCRIPTION
        This methods output messages based on the type {Info, Error, Warning, Success} with the corresponding color
    .PARAMETER Message
        Message Text
    .PARAMETER MessageType 
        Message Type: Info, Success, Warning or Error
    .EXAMPLE
        OutputMessage -Message "Example Message" -MessageType Info
    #>
    param
    (
        [string]$Message,
        [ValidateSet("Info","Success","Warning","Error")]
        [string]$MessageType
    )

    $datetime = Get-Date -Format T
    [string]$showMessage = $datetime +": "+ $message
    switch($MessageType)
    {
        Info {Write-Host -Object $showMessage -ForegroundColor White }
        Success {Write-Host -Object $showMessage -ForegroundColor Green }
        Warning {Write-Host -Object $showMessage -ForegroundColor Yellow }
        Error {Write-Error -Message $showMessage -ErrorAction Stop}
    }
}