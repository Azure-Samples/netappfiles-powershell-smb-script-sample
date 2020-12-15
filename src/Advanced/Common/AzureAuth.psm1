# Copyright(c) Microsoft and contributors. All rights reserved
#
# This source code is licensed under the MIT license found in the LICENSE file in the root directory of the source tree

<#
.DESCRIPTION
    Includes functions to authenticate script to access Azure and select the right subscription
#>

Import-Module .\Common\Util.psm1

function ConnectToAzure
{
    <#
    .SYNOPSIS
        Connect and authenticate with Azure Account
    .DESCRIPTION
        A login dialog will pop up to authenticate with Azure
    .EXAMPLE
        $accountObj = ConnectToAzure
    .OUTPUTS
        Returns Azure account object
    #>
    try
    {
        $AccountObject = Add-AzAccount
    }
    catch
    {
        OutputMessage -Message "Failed to connect to Azure. please try again!" -MessageType Error
    }
    return $AccountObject
}


function SwitchToTargetSubscription
{
    <#
    .SYNOPSIS
        Selects an Azure subscription
    .DESCRIPTION
        A helper method to switch to the targeted subscription
    .EXAMPLE
        $currentSub = SwitchToTargetSubscription
    .OUTPUTS
        Returns Azure subscription object
    #>
    param
    (
        [string]$TargetSubscriptionId
    )

    #try to switch to the correct target subscription
    try
    {
        $CurrentSubscription = Select-AzSubscription -Subscription $SubscriptionId
    }
    catch
    {
        OutputMessage -Message "Invalid subsciption. Provide a valid subscription ID and try again!"
    }

    return $CurrentSubscription
}