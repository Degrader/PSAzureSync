#Requires -Module AzureAD
#Requires -Module ActiveDirectory

function Compare-DirectoryGroups {
<#
	.SYNOPSIS
		Compares On-Prem AD group membership to Azure AD group membership, or Azure AD group membership to On-Prem group membership.

	.DESCRIPTION
		Compares On-Prem AD group membership to Azure AD group membership, or Azure AD group membership to On-Prem group membership. Returns an object with array addUsers and array removeUsers.
        This function relies on a non-standard Active Directory Attribute, azureOID. This attribute can be added to your schema, and the AzureAD User OID for each user you intend to sync should
        be stored in this attribute.

	.PARAMETER  ADGroupDN
		Mandatory parameter. The Distinguished Name of the On-Prem Active Directory security group to be compared.
	
	.PARAMETER AzureGroupOID
		Mandatory parameter. The OID of the Azure Group to be compared. (Hint: Use Get-AzureADGroup)
	
	.PARAMETER Direction
		The direction for group comparison.
		Mandatory parameter, with a default value of ToAzureAD.
		ToLocalAD specifies the group membership should be compared for synchronization FROM AzureAD TO On-Prem AD.
		ToAzureAD specifies the group membership should be compared for synchronization FROM On-Prem AD TO AzureAD.
	
	.EXAMPLE
		PS C:\> $syncUsers = Compare-DirectoryGroups -ADGroupDN "CN=TEAM_ServerTeam,OU=Groups,DC=contoso,DC=com" -AzureGroupOID "229c9cd7-f143-43a0-9a24-9d0b794c6632"
		This example shows how to call the Compare-DirectoryGroups function and store the resulting object into a $suncUsers variable. This sync direction was defaulted to "ToAzureAD".
	
	.EXAMPLE
		PS C:\> $syncUsers = Compare-DirectoryGroups -ADGroupDN "CN=TEAM_ServerTeam,OU=Groups,DC=contoso,DC=com" -AzureGroupOID "229c9cd7-f143-43a0-9a24-9d0b794c6632" -Direction ToLocalAD
		This example shows how to call the Compare-DirectoryGroups function and store the resulting object into a $suncUsers variable. This sync direction was user specified "ToLocalAD".
	
	.INPUTS
		System.String,
		System.String,
		System.String

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
	[CmdletBinding()]
	param(
		[Parameter(Position = 0, Mandatory = $true)][ValidateNotNullOrEmpty()]$ADGroupDN,
		[Parameter(Position = 1, Mandatory = $true)][ValidateNotNullOrEmpty()]$AzureGroupOID,
		[Parameter(Position = 2, Mandatory = $true)][ValidateSet("ToLocalAD","ToAzureAD")]$Direction = "ToAzureAD"
	)
	process {
		try
		{
			#Initialize arrays to hold users
			$removeUsers = @()
			$addUsers = @()
			
			#Get local and remote users for comparison
			$localMembers = @(Get-ADGroupMember -Identity $ADGroupDN | % { (Get-ADUser -Identity $_ -Properties azureOID)})
			$azureMembers = @((Get-AzureADGroupMember -ObjectId $AzureGroupOID))
			
            #if direction is ToAzureAD, returned objects should be AzureAD User Objects.
			if ($Direction -eq "ToAzureAD")
			{
				#If user exists in local group, but does not exist in azure group, add it to the $addUsers array
				foreach ($member in $localMembers)
				{
					if ($azureMembers.ObjectID -notcontains $member.azureOID)
					{
                        #Get the AzureAD object to add to our array rather than the on-prem AD account for data consistency
                        $OID = $member.azureOID
                        $addMember = Get-AzureADUser -ObjectId "$OID"
						$addUsers += $addMember
					}
				}
				#if user exists in azure group, but does not exist in local group, add it to the $removeUsers array
				foreach ($member in $azureMembers)
				{
					if ($localMembers.azureOID -notcontains $member.ObjectID)
					{
						$removeUsers += $member
					}
				}
			}
			
            #if direction is ToLocalAD, returned objects should be on-prem Active Directory User Objects.
			if ($Direction -eq "ToLocalAD")
			{
				#If user exists in azure group, but does not exist in local group, add it to the $addUsers array
				foreach ($member in $azureMembers)
				{
					if ($localMembers.azureOID -notcontains $member.ObjectId)
					{
                        $addMember = $localMembers | where {$_.azureOID -eq $member.ObjectID}
						$addUsers += $member
					}
				}
				#if user exists in local group, but does not exist in azure group, add it to the $removeUsers array
				foreach ($member in $localMembers)
				{
					if ($azureMembers.ObjectID -notcontains $member.azureOID)
					{
						$removeUsers += $member
					}
				}
			}
			
			$syncUsers = New-Object psobject -Property @{ addUsers = ''; removeUsers = '' }
			$SyncUsers.addUsers = $addUsers
			$SyncUsers.removeUsers = $removeUsers
		}
		catch
		{
		}
	}
	end {
		try
		{
			#return syncUsers object with addUsers and removeUsers
			$syncUsers
		}
		catch {
		}
	}
}
Export-ModuleMember -Function Compare-DirectoryGroups

function Sync-LocalToAzureGroups {
<#
	.SYNOPSIS
		A brief description of the Sync-LocalToAzureGroups function.

	.DESCRIPTION
		A detailed description of the Sync-LocalToAzureGroups function.

	.PARAMETER AddUsers
		Expects array of users that will be added to the Azure AD Group. Accepts pipeline input typically from Compare-DirectoryGroups function, by property name.
	
	.PARAMETER RemoveUsers
		Expects array of users that will be removed from the Azure AD Group. Accepts pipeline input typically from Compare-DirectoryGroups function, by property name.
	
	.PARAMETER AzureGroupOID
		System.String. OID of Azure AD group to synchronize membership to. Can use Get-AzureADGroup for this information.

	.EXAMPLE
		PS C:\> Sync-LocalToAzureGroups -AddUsers $newUsers -RemoveUsers $oldUsers -AzureGroupOID "229c9cd7-f143-43a0-9a24-9d0b794c6632"
		This example shows how to call the Sync-LocalToAzureGroups function, pass two variables containing user principal names to be added or removed, and specifying the Azure group to update membership.

	.INPUTS
		System.Management.Automation.PSObject,
		System.Management.Automation.PSObject,
		System.String

	.OUTPUTS
		None

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, ValueFromPipelineByPropertyName)]$AddUsers,
		[Parameter(Position = 1, ValueFromPipelineByPropertyName)]$RemoveUsers,
		[Parameter(Position = 2, Mandatory = $true)][ValidateNotNullOrEmpty()]$AzureGroupOID
		
	)
	process {
		try
		{
			#if there are users to add, add them to the specified group
			if ($AddUsers -ne $null -and $AddUsers -ne "")
			{
				foreach ($user in $AddUsers)
				{
					Add-AzureADGroupMember -ObjectId $AzureGroupOID -RefObjectId $user.ObjectID
				}
			}
			#if there are users to remove, remove them from the specified group
			if ($RemoveUsers -ne $null -and $RemoveUsers -ne "")
			{
				foreach ($user in $RemoveUsers)
				{
					Remove-AzureADGroupMember -ObjectId $AzureGroupOID -MemberId $user.ObjectId
				}
			}
		}
		catch
		{
		}
	}
}
Export-ModuleMember -Function Sync-LocalToAzureGroups

function Sync-AzureToLocalGroups {
<#
	.SYNOPSIS
		A brief description of the Sync-AzureToLocalGroups function.

	.DESCRIPTION
		A detailed description of the Sync-AzureToLocalGroups function.

	.PARAMETER AddUsers
		Expects array of users that will be added to the Azure AD Group. Accepts pipeline input typically from Compare-DirectoryGroups function, by property name.
	
	.PARAMETER RemoveUsers
		Expects array of users that will be removed from the Azure AD Group. Accepts pipeline input typically from Compare-DirectoryGroups function, by property name.
	
	.PARAMETER ADGroupDN
		System.String. The Distinguished Name for an On-Prem Active Directory security group, to sync membership to.

	.EXAMPLE
		PS C:\> Sync-AzureToLocalGroups -AddUsers $newUsers -RemoveUsers $oldUsers -AzureGroupOID "229c9cd7-f143-43a0-9a24-9d0b794c6632"
		This example shows how to call the Sync-AzureToLocalGroups function, pass two variables containing user principal names to be added or removed, and specifying the Azure group to update membership.

	.INPUTS
		System.Management.Automation.PSObject,
		System.Management.Automation.PSObject,
		System.String

	.OUTPUTS
		None

	.LINK
		about_modules

	.LINK
		about_functions_advanced

	.LINK
		about_comment_based_help

	.LINK
		about_functions_advanced_parameters

	.LINK
		about_functions_advanced_methods
#>
	[CmdletBinding()]
	param (
		[Parameter(Position = 0, ValueFromPipelineByPropertyName)]$AddUsers,
		[Parameter(Position = 1, ValueFromPipelineByPropertyName)]$RemoveUsers,
		[Parameter(Position = 2, Mandatory = $true)][ValidateNotNullOrEmpty()]$ADGroupDN
		
	)
	process
	{
		try
		{
			#if there are users to add, add them to the specified group
			if ($AddUsers -ne $null -and $AddUsers -ne "")
			{
				Add-ADGroupMember -Identity $ADGroupDN -Members $AddUsers
			}
			#if there are users to remove, remove them from the specified group
			if ($RemoveUsers -ne $null -and $RemoveUsers -ne "")
			{
				Remove-ADGroupMember -Identity $ADGroupDN -Members $RemoveUsers
			}
		}
		catch
		{
		}
	}
}
Export-ModuleMember -Function Sync-AzureToLocalGroups
