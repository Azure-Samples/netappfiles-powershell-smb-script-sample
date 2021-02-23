# Copyright(c) Microsoft and contributors. All rights reserved
#
# This source code is licensed under the MIT license found in the LICENSE file in the root directory of the source tree

<#
    .SYNOPSIS
        This script creates Azure Netapp files resources with SMB volume type
    .DESCRIPTION
        Authenticates with Azure and select the targeted subscription first, then created ANF account, capacity pool and SMB Volume
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
    [string]$ResourceGroupName = 'My-RG',

    [string]$Location = 'WestUS',

    [string]$NetAppAccountName = 'anfaccount',
  
    [string]$NetAppPoolName = 'pool1',

    [ValidateSet("Ultra","Premium","Standard")]
    [string]$ServiceLevel = 'Standard',

    [ValidateRange(4398046511104,549755813888000)]
    [long]$NetAppPoolSize = 4398046511104,

    [string]$NetAppVolumeName = 'vol1',

    [ValidateRange(107374182400,109951162777600)]
    [long]$NetAppVolumeSize=107374182400,

    [string]$SubnetId = 'Subnet ID',
  
    [pscredential]$Credential,

    [string]$DNSList = '10.0.2.4,10.0.2.5',

    [string]$ADFQDN = 'testdomain.local',

    [string]$SmbServerNamePrefix = 'pmcsmb',

    [bool]$CleanupResources = $false
)

$ErrorActionPreference="Stop"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Authorizing and connecting to Azure
Write-Verbose -Message "Authorizing with Azure Account..." -Verbose
Add-AzAccount

# Create Azure NetApp Files Account
Write-Verbose -Message "Creating Azure NetApp Files Account -> $NetAppAccountName" -Verbose
$ActiveDirectory = New-Object Microsoft.Azure.Commands.NetAppFiles.Models.PSNetAppFilesActiveDirectory
$ActiveDirectory.Dns = $DNSList
$ActiveDirectory.Username = $Credential.UserName
$ActiveDirectory.Password = $Credential.GetNetworkCredential().Password
$ActiveDirectory.Domain = $ADFQDN
$ActiveDirectory.SmbServerName = $SmbServerNamePrefix

$NewANFAccount = New-AzNetAppFilesAccount -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -Name $NetAppAccountName `
    -ActiveDirectory @($ActiveDirectory)

Write-Verbose -Message "Azure NetApp Files Account has been created successfully: $($NewANFAccount.Id)" -Verbose

# Create Azure NetApp Files Capacity Pool                                                                                                       
Write-Verbose -Message "Creating Azure NetApp Files Capacity Pool -> $NetAppPoolName" -Verbose                                         
$NewANFPool= New-AzNetAppFilesPool -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -AccountName $NetAppAccountName `
    -Name $NetAppPoolName `
    -PoolSize $NetAppPoolSize `
    -ServiceLevel $ServiceLevel

Write-Verbose -Message "Azure NetApp Files Capacity Pool has been created successfuuly: $($NewANFPool.Id)" -Verbose

# Create Azure NetApp Files NFS Volume
Write-Verbose -Message "Creating Azure NetApp Files - SMB Volume -> $NetAppVolumeName" -Verbose
$NewANFVolume = New-AzNetAppFilesVolume -ResourceGroupName $ResourceGroupName `
    -Location $Location `
    -AccountName $NetAppAccountName `
    -PoolName $NetAppPoolName `
    -Name $NetAppVolumeName `
    -UsageThreshold $NetAppVolumeSize `
    -SubnetId $SubnetId `
    -CreationToken $NetAppVolumeName `
    -ServiceLevel $ServiceLevel `
    -ProtocolType CIFS    

Write-Verbose -Message "Azure NetApp Files Volume has been created successfully: $($NewANFVolume.Id)" -Verbose

Write-Verbose -Message "====> SMB Server FQDN: $($NewANFVolume.MountTargets[0].smbServerFQDN.ToString())" -Verbose

Write-Verbose -Message "Azure NetApp Files has been created successfully." -Verbose

if($CleanupResources)
{    
    Write-Verbose -Message "Cleaning up Azure NetApp Files resources..." -Verbose

    Write-Verbose -Message "Deleting Azure NetApp Files Volume $NetAppVolumeName" -Verbose
    Remove-AzNetAppFilesVolume -ResourceGroupName $ResourceGroupName `
        -AccountName $NetAppAccountName `
        -PoolName $NetAppPoolName `
        -Name $NetAppVolumeName
    
    Write-Verbose -Message "Deleting Azure NetApp Files Volume $NetAppPoolName" -Verbose
    Remove-AzNetAppFilesPool -ResourceGroupName $ResourceGroupName -AccountName $NetAppAccountName -PoolName $NetAppPoolName
   
    Write-Verbose -Message "Deleting Azure NetApp Files Volume $NetAppAccountName" -Verbose
    Remove-AzNetAppFilesAccount -ResourceGroupName $ResourceGroupName -Name $NetAppAccountName
   
    Write-Verbose -Message "All Azure NetApp Files resources have been deleted successfully." -Verbose       
}
