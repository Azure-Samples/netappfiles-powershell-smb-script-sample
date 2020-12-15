# Copyright(c) Microsoft and contributors. All rights reserved
#
# This source code is licensed under the MIT license found in the LICENSE file in the root directory of the source tree

<#
This Module includes common functions for creating and deleting Azure NetApp Files main resources (Account, Capacity Pool, and Volume)
#>

Import-Module .\Common\Util.psm1

function CleanUpResources
{
    <#
    .SYNOPSIS
        Clean-up Azure NetApp Files Resources
    .DESCRIPTION
        This method will clean up all created Azure Netapp Files resources if the argument -CleanupResources is set to $true 
    .PARAMETER TargetResourceGroupName
        Name of the Azure Resource Group where the ANF will be created
    .PARAMETER AzNetAppAccountName
        Name of the Azure NetApp Files Account
    .PARAMETER AzNetAppPoolName
        Name of the Azure NetApp Files Capacity Pool
    .PARAMETER AzNetAppVolumeName 
        Name of the Azure NetApp Files Volume 
    .EXAMPLE
        CleanUpResources
    #>
    param
    (
        [string]$TargetResourceGroupName,  
        [string]$AzNetAppAccountName,
        [string]$AzNetAppPoolName, 
        [string]$AzNetAppVolumeName
    )

    #Deleting ANF volume
    OutputMessage -Message "Deleting Azure NetApp Files Volume {$AzNetAppVolumeName}..." -MessageType Info
    try
    {
        Remove-AzNetAppFilesVolume -ResourceGroupName $TargetResourceGroupName `
            -AccountName $AzNetAppAccountName `
            -PoolName $AzNetAppPoolName `
            -Name $AzNetAppVolumeName

        #Validating if the volume is completely deleted 
        $DeletedVolume = Get-AzNetAppFilesVolume -ResourceGroupName $TargetResourceGroupName `
            -AccountName $AzNetAppAccountName `
            -PoolName $AzNetAppPoolName `
            -Name $AzNetAppVolumeName `
            -ErrorAction SilentlyContinue

        if($null -eq $DeletedVolume)
        {
            OutputMessage -Message "$AzNetAppVolumeName has been deleted successfully" -MessageType Success
        }
        else
        {
            OutputMessage -Message "Wasn't able to fully delete {$AzNetAppVolumeName}" -MessageType Error            
        }
    }
    catch
    {
        OutputMessage -Message "Failed to delete Volume!" -MessageType Error
    }   
      
    #Deleting ANF Capacity pool
    OutputMessage -Message "Deleting Azure NetApp Files Capacity Pool {$AzNetAppPoolName}..." -MessageType Info
    try
    {
        Remove-AzNetAppFilesPool -ResourceGroupName $TargetResourceGroupName -AccountName $AzNetAppAccountName -PoolName $AzNetAppPoolName

        #Validating if the pool is completely deleted
        $DeletedPool = Get-AzNetAppFilesPool -ResourceGroupName $TargetResourceGroupName `
            -AccountName $AzNetAppAccountName `
            -PoolName $AzNetAppPoolName `
            -ErrorAction SilentlyContinue

        if($null -eq $DeletedPool)
        {
            OutputMessage -Message "$AzNetAppPoolName has been deleted successfully" -MessageType Success
        }
        else
        {
            OutputMessage -Message "Wasn't able to fully delete {$AzNetAppPoolName}" -MessageType Error            
        }       
    }
    catch
    {
        OutputMessage -Message "Failed to delete Capacity Pool!" -MessageType Error
    }
  
    #Deleting ANF Account
    OutputMessage -Message "Deleting Azure NetApp Files Account {$AzNetAppAccountName}..." -MessageType Info
    try
    {
        Remove-AzNetAppFilesAccount -ResourceGroupName $TargetResourceGroupName -Name $AzNetAppAccountName
        #Validating if the account is completely deleted
        $DeletedAccount = Get-AzNetAppFilesAccount -ResourceGroupName $TargetResourceGroupName -AccountName $AzNetAppAccountName -ErrorAction SilentlyContinue
        if($null -eq $DeletedAccount)
        {
            OutputMessage -Message "$AzNetAppAccountName has been deleted successfully" -MessageType Success
        }
        else
        {
            OutputMessage -Message "Wasn't able to fully delete {$AzNetAppAccountName}" -MessageType Error            
        }        
    }
    catch
    {
        OutputMessage -Message "Failed to delete Account!" -MessageType Error
    }  

}

function CreateNewANFAccount
{  
    <#
    .SYNOPSIS
        Creates new Azure NetApp Files account
    .DESCRIPTION
        This method will create new Azure NetApp Files account under the specified Resource Group
    .PARAMETER TargetResourceGroupName
        Name of the Azure Resource Group where the ANF will be created
    .PARAMETER AzureLocation
        Azure Location
    .PARAMETER AzNetAppAccountName
        Name of the Azure NetApp Files Account
    .PARAMETER DnsList
        DNS list
    .PARAMETER AdFQDN
        AD Domain Name
    .PARAMETER DomainJoinUsername
        Domain Username
    .PARAMETER DomainJoinPassword
        Domain Password
    .PARAMETER SmbServerNamePrefix
        SMB Server name prefix
    .OUTPUT
        ANF account object
    .EXAMPLE
        CreateNewANFAccount - resourceGroupName 'My-RG' -location 'WestUS' -netAppAccountName 'netapptestaccount' - DnsList '10.0.0.4,10.0.2.5' -Domain 'testdomain.local' -DomainJoinUsername 'testusername' -DomainJoinPassword 'Pa$$w0rd' -SMBServerNamePrefix 'pmcsmb'
    #>
    param
    (
        [string]$TargetResourceGroupName, 
        [string]$Azurelocation, 
        [string]$AzNetAppAccountName,
        [string]$DnsList,
        [string]$AdFQDN,
        [string]$DomainJoinUsername,
        [string]$DomainJoinPassword,
        [string]$SmbServerNamePrefix
    )

    try
    {
        $ActiveDirectory = New-Object Microsoft.Azure.Commands.NetAppFiles.Models.PSNetAppFilesActiveDirectory
        $ActiveDirectory.Dns = $DnsList
        $ActiveDirectory.Username = $DomainJoinUsername
        $ActiveDirectory.Password = $DomainJoinPassword
        $ActiveDirectory.Domain = $AdFQDN
        $ActiveDirectory.SmbServerName = $SmbServerNamePrefix

        $NewANFAccount = New-AzNetAppFilesAccount -ResourceGroupName $TargetResourceGroupName -Location $Azurelocation -Name $AzNetAppAccountName -ActiveDirectory @($ActiveDirectory)
        if ($NewANFAccount.ProvisioningState -ne "Succeeded")
        {
            OutputMessage -Message "Failed to create ANF Account {$AzNetAppAccountName}" -MessageType Error     
        }
    }
    catch
    {
        OutputMessage -Message "Failed to create ANF Account" -MessageType Error
    }
    return $NewANFAccount
}


function CreateNewANFCapacityPool
{
    <#
    .SYNOPSIS
        Creates new Azure NetApp Files capacity pool
    .DESCRIPTION
        This method will create new Azure NetApp Files capacity pool within the specified account
    .PARAMETER TargetResourceGroupName
        Name of the Azure Resource Group where the ANF will be created
    .PARAMETER AzureLocation 
        Azure Location
    .PARAMETER AzNetAppAccountName
        Name of the Azure NetApp Files Account
    .PARAMETER AzNetAppPoolName
        Name of the Azure NetApp Files Capacity Pool
    .PARAMETER AzServiceLevel
        Ultra, Premium or Standard
    .PARAMETER AzNetAppPoolSize
        Size of the Azure NetApp Files Capacity Pool in Bytes. Range between 4398046511104 and 549755813888000
    .OUTPUT
        ANF Capacity Pool object
    .EXAMPLE
        CreateNewANFCapacityPool - resourceGroupName 'My-RG' -location 'WestUS' -netAppAccountName 'testaccount' -netAppPoolName 'pool1' -netAppPoolSize 4398046511104 -serviceLevel Standard
    #>
    param
    (
        [string]$TargetResourceGroupName, 
        [string]$Azurelocation, 
        [string]$AzNetAppAccountName,
        [string]$AzNetAppPoolName, 
        [long]$AzNetAppPoolSize, 
        [string]$ServiceLevelTier
    )

    try
    {
        $NewANFPool= New-AzNetAppFilesPool -ResourceGroupName $TargetResourceGroupName `
            -Location $Azurelocation `
            -AccountName $AzNetAppAccountName `
            -Name $AzNetAppPoolName `
            -PoolSize $AzNetAppPoolSize `
            -ServiceLevel $ServiceLevelTier

        if($NewANFPool.ProvisioningState -ne "Succeeded")
        {
           OutputMessage -Message "Failed to create ANF Capacity Pool {$AzNetAppPoolName}" -MessageType Error
        }
    }
    catch
    {
        OutputMessage -Message "Failed to create ANF Capacity Pool." -MessageType Error
    }

    return $NewANFPool
}

function CreateNewANFVolume
{
    <#
    .SYNOPSIS
        Creates new Azure NetApp Files NFS volume
    .DESCRIPTION
        This method will create new Azure NetApp Files volume under the specified Capacity Pool
    .PARAMETER TargetResourceGroupName
        Name of the Azure Resource Group where the ANF will be created
    .PARAMETER AzureLocation
        Azure Location
    .PARAMETER AzNetAppAccountName
        Name of the Azure NetApp Files Account
    .PARAMETER AzNetAppPoolName
        Name of the Azure NetApp Files Capacity Pool
    .PARAMETER ServiceLevelTier
        Ultra, Premium or Standard
    .PARAMETER AzNetAppPoolSize
        Size of the Azure NetApp Files Capacity Pool in Bytes. Range between 4398046511104 and 549755813888000
    .PARAMETER AzNetAppVolumeName
        Name of the Azure NetApp Files Volume
    .PARAMETER VolumeProtocolType
        NFSv4.1 or NFSv3
    .PARAMETER AzNetAppVolumeSize
        Size of the Azure NetApp Files volume in Bytes. Range between 107374182400 and 109951162777600
    .PARAMETER VNETSubnetId
        The Delegated subnet Id within the VNET
    .PARAMETER EPUnixReadOnly
        Export Policy UnixReadOnly property 
    .PARAMETER EPUnixReadWrite
        Export Policy UnixReadWrite property
    .PARAMETER AllowedClientsIp
        Client IP to access Azure NetApp files volume
    .EXAMPLE
        CreateNewANFVolume - resourceGroupName [Resource Group Name] -location [Azure Location] -netAppAccountName [NetApp Account Name] -netAppPoolName [NetApp Pool Name] -netAppPoolSize [Size of the Capacity Pool] -serviceLevel [service level (Ultra, Premium or Standard)] -netAppVolumeName [NetApp Volume Name] -netAppVolumeSize [Size of the Volume] -protocolType [NFSv3 or NFSv4.1] -subnetId [Subnet ID] -unixReadOnly [Read Permission flag] -unixReadWrite [Read/Write permission flag] -allowedClients [Allowed clients IP]
    #>
    param
    (
        [string]$TargetResourceGroupName, 
        [string]$AzureLocation, 
        [string]$AzNetAppAccountName,
        [string]$AzNetAppPoolName, 
        [long]$AzNetAppPoolSize, 
        [string]$AzNetAppVolumeName,
        [long]$AzNetAppVolumeSize,
        [string]$ServiceLevelTier, 
        [string]$VNETSubnetId
    )

   
    try
    {
        $NewANFVolume = New-AzNetAppFilesVolume -ResourceGroupName $TargetResourceGroupName `
            -Location $AzureLocation `
            -AccountName $AzNetAppAccountName `
            -PoolName $AzNetAppPoolName `
            -Name $AzNetAppVolumeName `
            -UsageThreshold $AzNetAppVolumeSize `
            -SubnetId $VNETSubnetId `
            -CreationToken $AzNetAppVolumeName `
            -ServiceLevel $ServiceLevelTier `
            -ProtocolType CIFS
                 

        if($NewANFVolume.ProvisioningState -ne "Succeeded")
        {
           OutputMessage -Message "Failed to create ANF Volume {$netAppPoolName}" -MessageType Error
        }
    }
    catch
    {
        OutputMessage -Message "Failed to create ANF Volume" -MessageType Error
    }
    
    return $NewANFVolume

}
