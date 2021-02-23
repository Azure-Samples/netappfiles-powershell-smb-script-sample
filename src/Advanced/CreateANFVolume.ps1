# Copyright(c) Microsoft and contributors. All rights reserved
#
# This source code is licensed under the MIT license found in the LICENSE file in the root directory of the source tree

<#
    .SYNOPSIS
        This script creates Azure Netapp files resources with SMB volume type
    .DESCRIPTION
        Authenticates with Azure and select the targeted subscription first, then created ANF account, capacity pool and NFS Volume
    .PARAMETER SubscriptionId
        Target Subscription
    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group where the ANF will be created
    .PARAMETER Location
        Azure Location (e.g 'WestUS', 'EastUS')
    .PARAMETER NetAppAccountName
        Name of the Azure NetApp Files Account
    .PARAMETER NetAppPoolName
        Name of the Azure NetApp Files Capacity Pool
    .PARAMETER ServiceLevel
        Service Level - Ultra, Premium or Standard
    .PARAMETER NetAppPoolSize
        Size of the Azure NetApp Files Capacity Pool in Bytes. Range between 4398046511104 and 549755813888000
    .PARAMETER NetAppVolumeName\
        Name of the Azure NetApp Files Volume
    .PARAMETER NetAppVolumeSize
        Size of the Azure NetApp Files volume in Bytes. Range between 107374182400 and 109951162777600
    .PARAMETER SubnetId
        The Delegated subnet Id within the VNET
    .PARAMETER Credential
        Domain credential object
    .PARAMETER DNSList
        Comma-seperated DNS list
    .PARAMETER ADFQDN
        Active Directory FQDN
    .PARAMETER SmbServerNamePrefix
        SMB Server name prefix
    .PARAMETER CleanupResources
        If the script should clean up the resources, $false by default
    .EXAMPLE
        PS C:\\> CreateANFVolume.ps1 -SubscriptionId '00000000-0000-0000-0000-000000000000' -ResourceGroupName 'My-RG' -Location 'WestUS' -NetAppAccountName 'testaccount' -NetAppPoolName 'pool1' -ServiceLevel Standard -NetAppVolumeName 'vol1' -ProtocolType NFSv4.1 -SubnetId '/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/My-RG/providers/Microsoft.Network/virtualNetworks/vnet1/subnets/subnet1'
    #>
param
(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [Parameter(Mandatory)]
    [string]$ResourceGroupName,

    [Parameter(Mandatory)]
    [string]$Location,

    [Parameter(Mandatory)]
    [string]$NetAppAccountName,

    [Parameter(Mandatory)]
    [string]$NetAppPoolName,

    [Parameter(Mandatory)]
    [ValidateSet("Ultra","Premium","Standard")]
    [string]$ServiceLevel,

    [Parameter(Mandatory= $false)]
    [ValidateRange(4398046511104,549755813888000)]
    [long]$NetAppPoolSize = 4398046511104,

    [Parameter(Mandatory)]
    [string]$NetAppVolumeName,

    [Parameter(Mandatory= $false)]
    [ValidateRange(107374182400,109951162777600)]
    [long]$NetAppVolumeSize=107374182400,

    [Parameter(Mandatory)]
    [string]$SubnetId,
    
    [pscredential]$Credential,

    [Parameter(Mandatory = $true)]
    [string]$DNSList,

    [Parameter(Mandatory = $true)]
    [string]$ADFQDN,

    [Parameter(Mandatory = $true)]
    [string]$SmbServerNamePrefix,

    [Parameter(Mandatory = $false)]
    [bool]$CleanupResources = $false
)

$ErrorActionPreference="Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module .\Common\AzureAuth.psm1
Import-Module .\Common\Util.psm1
Import-Module .\Common\CommonOperations.psm1


# Display script header text
DisplayScriptHeader

# Authorizing and connecting to Azure
OutputMessage -Message "Authorizing with Azure Account..." -MessageType Info 
$AzureAccount = ConnectToAzure
OutputMessage -Message "Successfully authorized user with your Azure account." -MessageType Success

# Validating if the target subscription Id is set to the current or default. Otherwise Azure NetApp files will be provisioned under the wrong subscription
if($AzureAccount.Context.Subscription.Id -ne $SubscriptionId.Trim())
{
    OutputMessage -Message "Provided subscription {$SubscriptionId} is not set to current or default subscription, Switching now!" -MessageType Warning
    # Choosing the right subscription
    OutputMessage -Message "Switching the current Azure subscription to {$SubscriptionId}" -MessageType Info
    $currentSub = SwitchToTargetSubscription -TargetSubscriptionId $SubscriptionId
    OutputMessage -Message "{$SubscriptionId} is set to current" -MessageType Success    
}

# Create Azure NetApp Files Account
OutputMessage -Message "Creating Azure NetApp Files Account {$NetAppAccountName}" -MessageType Info
$NewAccount = CreateNewANFAccount -TargetResourceGroupName $ResourceGroupName `
    -Azurelocation $Location `
    -AzNetAppAccountName $NetAppAccountName `
    -DnsList $DNSList `
    -AdFQDN $ADFQDN `
    -Credential $Credential
    -SmbServerNamePrefix $SmbServerNamePrefix

OutputMessage -Message "Azure NetApp Files Account {$NetAppAccountName} was successfully created: $($NewAccount.Id)" -MessageType Success 

# Create Azure NetApp Files Capacity Pool                                                                                                       
OutputMessage -Message "Creating Azure NetApp Files Capacity Pool {$NetAppPoolName}" -MessageType Info                                          
$NewPool = CreateNewANFCapacityPool -TargetResourceGroupName $ResourceGroupName `
    -Azurelocation $Location `
    -AzNetAppAccountName $NetAppAccountName `
    -AzNetAppPoolName $NetAppPoolName `
    -AzNetAppPoolSize $NetAppPoolSize `
    -ServiceLevelTier $ServiceLevel

OutputMessage -Message "Azure NetApp Files Capacity Pool {$NetAppPoolName} was successfully created: $($NewPool.Id)" -MessageType Success

# Create Azure NetApp Files NFS Volume
OutputMessage -Message "Creating Azure NetApp Files - SMB Volume {$NetAppVolumeName}" -MessageType Info
$NewVolume = CreateNewANFVolume -TargetResourceGroupName $ResourceGroupName `
    -Azurelocation $Location `
    -AzNetAppAccountName $NetAppAccountName `
    -AzNetAppPoolName $NetAppPoolName `
    -AzNetAppPoolSize $NetAppPoolSize `
    -AzNetAppVolumeName $NetAppVolumeName `
    -AzNetAppVolumeSize $NetAppVolumeSize `
    -ServiceLevelTier $ServiceLevel `
    -VNETSubnetId $SubnetId    

OutputMessage -Message "Azure NetApp Files Volume {$NetAppVolumeName} was successfully created: $($NewVolume.Id)" -MessageType Success

OutputMessage -Message "====> SMB Server FQDN: $($NewVolume.MountTargets[0].smbServerFQDN.ToString())" -MessageType Success

OutputMessage -Message "The script has been successfully executed." -MessageType Success

if($CleanupResources)
{
    DisplayCleanupHeader

    OutputMessage -Message "Cleaning up Azure NetApp Files resources..." -MessageType Info

    CleanUpResources -TargetResourceGroupName $ResourceGroupName `
        -AzNetAppAccountName $NetAppAccountName `
        -AzNetAppPoolName $NetAppPoolName `
        -AzNetAppVolumeName $NetAppVolumeName

    OutputMessage -Message "All Azure NetApp Files resources have been deleted successfully." -MessageType Success        
}
