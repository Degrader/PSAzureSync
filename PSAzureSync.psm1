<#Connect-AzureAD -Credential $cred

$CSV = Import-Csv -Path D:\testcsv.csv

foreach ($group in $CSV)
{
	$groupDN = $group.LocalGroupDN
	$azureGroupOID = $group.AzureGroupOID
	$syncUsers = Compare-DirectoryGroups -GroupDN $groupDN -AzureGroupOID $azureGroupOID
	$addUsers = $syncUsers.addUsers
	$removeUsers = $syncUsers.removeUsers
	
	Sync-LocalToAzureGroup -AzureGroupOID $azureGroupOID -addUsers $addUsers -removeUsers $removeUsers
}
#>

function Compare-LocaltoAzureGroup {
<#
	.SYNOPSIS
		Compares members of specified local group to members of a specified Azure group.
	.DESCRIPTION
		Compares members of specified local group to members of a specified Azure group. Returns users to be added/removed from Azure group.
	.PARAMETER GroupDN
		[System.String] Full distinguished name of the local group to be compared. Example: 
	.PARAMETER AzureGroupOID
		[System.String] Azure object ID of group to be compared. Example: 
	.EXAMPLE
		PS C:\> Compare-LocaltoAzureGroup 
	.INPUTS
		[System.String] Local group distinguished name.
		[System.String] Azure group object ID.
	.OUTPUTS
		[PSObject] Users to be added and/or removed from Azure group.
	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.
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
		[Parameter(mandatory = $true)]$GroupDN,
		[Parameter(mandatory = $true)]$AzureGroupOID
	)
	begin{
		try
		{
			#get principal names of local users
			$localMembers = @(Get-ADGroupMember -Identity $GroupDN | % { (Get-ADUser -Identity $_).UserPrincipalName })
			#get principal name of azure users
			$azureMembers = @(((Get-AzureADGroupMember -ObjectId $AzureGroupOID).UserPrincipalName))
			
			#initialize list/array objects
			$removeUsers = New-Object System.Collections.Generic.List[System.Object]
			$addUsers = New-Object System.Collections.Generic.List[System.Object]
			$syncUsers = New-Object psobject -Property @{ addUsers = ''; removeUsers = '' }
		}
		catch
		{
			Write-Error "Error getting group members. Check that the specified distinguished name is correct, or that the Azure OID exists." -ErrorAction Stop
		}
	}
	process {
		try
		{
			#if user exists in the local group but doesn't exist in azure group, add it to the $addUsers array
			foreach ($member in $localMembers)
			{
				if ($azureMembers -notcontains $member)
				{
					$addUsers.Add($member)
				}
			}
			#if user exist in azure group, but does not exist in local group, add it to the $removeUsers array
			foreach ($member in $azureMembers)
			{
				if ($localMembers -notcontains $member)
				{
					$removeUsers.Add($member)
				}
			}
		}
		catch
		{
			
			
		}
	}
	end {
		try
		{
			#create object and return users to be added/removed from Azure Group.
			$SyncUsers.addUsers = $addUsers
			$SyncUsers.removeUsers = $removeUsers
			
			$syncUsers
		}
		catch
		{
			
		}
	}
}
Export-ModuleMember -Function Compare-LocaltoAzureGroup

function Sync-LocaltoAzureGroup{
<#
	.SYNOPSIS
	.DESCRIPTION
	.PARAMETER 
	.EXAMPLE
		PS C:\> Sync-LocaltoAzureGroup 
	.INPUTS
	.OUTPUTS
	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.
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
		[Parameter(mandatory = $true)]$AzureGroupOID,
		$addUsers,
		$removeUsers
	)
	begin
	{
		try
		{
			#Validate parameters
			if (($addUsers -eq $null -or $addUsers -eq "") -and ($removeUsers -eq $null -or $removeUsers -eq ""))
			{
				Write-Error "No users provided to be added or removed. Stopping sync." -Category InvalidData -ErrorAction Stop
			}
		}
		catch
		{ }
	}
	process
	{
		try
		{
			#if there are users to add, add them to the specified group
			if ($addUsers -ne $null -and $addUsers -ne "")
			{
				foreach ($user in $addUsers)
				{
					$userOID = (Get-AzureADUser -ObjectId $user).ObjectID
					Add-AzureADGroupMember -ObjectId $AzureGroupOID -RefObjectId $userOID
				}
			}
			#if there are users to remove, remove them from the specified group
			if ($removeUsers -ne $null -and $removeUsers -ne "")
			{
				foreach ($user in $removeUsers)
				{
					$userOID = (Get-AzureADUser -ObjectId $user).ObjectID
					Remove-AzureADGroupMember -ObjectId $AzureGroupOID -MemberId $userOID
				}
			}
		}
		catch
		{ }
	}
	end
	{
		try
		{
			
		}
		catch
		{ }
	}
}
Export-ModuleMember -Function Sync-LocaltoAzureGroup

function Set-StoredSecureCredential{
<#
	.SYNOPSIS
		Accepts a plaintext password and stores it as a "secure credential" on disk as type [System.Security.Cryptography.ProtectedData].
	.DESCRIPTION
		Accepts a plaintext password and stores it as a "secure credential" on disk as type [System.Security.Cryptography.ProtectedData]. Scoping (CurrentUser, LocalMachine)
		and output paths are user changeable.
	.PARAMETER Password
		Plain text password to be secured on disk
	.PARAMETER Path
		Output path for secured password. Defaults to "$env:USERPROFILE\Desktop\secure.bin"
	.PARAMETER EntropyPath
		Output path for entropy data. Defaults to "$env:USERPROFILE\Desktop\ent.bin"
	.PARAMETER Scope
		Scope of ProtectedData type. CurrentUser or LocalMachine are the two accepted values. CurrentUser is the default value.
	.EXAMPLE
		PS C:\> Set-StoredSecureCredential "My awesome password!"
	.EXAMPLE
		PS C:\> Set-StoredSecureCredential "My awesome password!" -Scope "LocalMachine"
	.EXAMPLE
		PS C:\> Set-StoredSecureCredential -Password "My awesome password!" -Path "D:\Scripts\EpicScript\secure.bin" -EntropyPath "D:\Scripts\EpicScript\ent.bin"
	.EXAMPLE
		PS C:\> Set-StoredSecureCredential -Password "My awesome password!" -Path "D:\Scripts\EpicScript\secure.bin" -EntropyPath "D:\Scripts\EpicScript\ent.bin" -Scope "LocalMachine"
	.INPUTS
	.OUTPUTS
		Secured password stored as type byte, entropy data stored as type byte.
	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.
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
		[Parameter(Position = 0, Mandatory = $true)][System.String]$Password,
		[Parameter(Position = 1, Mandatory = $false)][System.String]$Path = "$env:USERPROFILE\Desktop\secure.bin",
		[Parameter(Position = 2, Mandatory = $false)][System.String]$EntropyPath = "$env:USERPROFILE\Desktop\ent.bin",
		[Parameter(Position = 3, Mandatory = $false)][System.String]$Scope = "CurrentUser"
	)
	begin
	{
		try
		{
			#Validate Parameters
			if ($Password -eq $null -or $Password -eq "")
			{
				Write-Verbose "Checking for null or empty password"
				Write-Error "Password cannot be empty/null." -ErrorAction Stop -Category InvalidArgument
			}
			if ($Scope -ne "CurrentUser" -or $Scope -ne "LocalMachine")
			{
				Write-Verbose "Checking for null or empty scope"
				Write-Error "Invalid scope specified. Please specify `"CurrentUser`" or `"LocalMachine`". Default is `"CurrentUser`"." -Category InvalidArgument -ErrorAction Stop
			}
		}
		catch
		{ }
	}
	process
	{
		try
		{
			Add-Type -assembly System.Security
			
			Write-Verbose "Generating entropy data"
			#randomize entropy
			$entropy = [byte[]]((Get-Random -Minimum 1 -Maximum 9), (Get-Random -Minimum 1 -Maximum 9), (Get-Random -Minimum 1 -Maximum 9), (Get-Random -Minimum 1 -Maximum 9), (Get-Random -Minimum 1 -Maximum 9))
			Write-Verbose "Storing entropy data in file on disk"
			Write-Verbose "OutputPath: $EntropyPath"
			$entropy | Set-Content -Path $EntropyPath -Encoding Byte -Force
			
			#convert password to bytes for encryption
			Write-Verbose "Converting plaintext password into bytes"
			$passwordBytes = [System.Text.Encoding]::Unicode.GetBytes("$Password")
			#set proper scope data type based on supplied string
			Write-Verbose "Scope: $Scope"
			if ($Scope -eq "CurrentUser")
			{
				Write-Verbose "Setting scope to [System.Security.Cryptography.DataProtectionScope]::CurrentUser"
				$dataProtectionScope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
			}
			if ($Scope -eq "LocalMachine")
			{
				Write-Verbose "Setting scope to [System.Security.Cryptography.DataProtectionScope]::LocalMachine"
				$dataProtectionScope = [System.Security.Cryptography.DataProtectionScope]::LocalMachine
			}
			
			#encrypt data
			Write-Verbose "Encrypting password"
			$encrytpedData = [System.Security.Cryptography.ProtectedData]::Protect($passwordBytes, $entropy, $dataProtectionScope)
			#store encrypted data on disk
			Write-Verbose "Storing encrypted password on disk"
			Write-Verbose "OutputPath: $Path"
			$encrytpedData | Set-Content -Path $Path -Encoding Byte -Force
		}
		catch
		{ }
	}
	end
	{
		try
		{
			
		}
		catch
		{ }
	}
}
Export-ModuleMember -Function Set-StoredSecureCredential

function Get-StoredSecureCredential
{
<#
	.SYNOPSIS
		Gets a stored password (typically using Set-StoredSecureCredential), applies entropy and unprotects the data.
	.DESCRIPTION
		Gets a stored password (typically using Set-StoredSecureCredential), applies entropy and unprotects the data.
		Returns password as [System.String]
	.PARAMETER Path
		Input path for secured password.
	.PARAMETER EntropyPath
		Input path for entropy data.
	.PARAMETER Scope
		Scope of ProtectedData type. CurrentUser or LocalMachine are the two accepted values. CurrentUser is the default value.
	.EXAMPLE
		PS C:\> Get-StoredSecureCredential -Path "D:\Scripts\EpicScript\secure.bin" -EntropyPath "D:\Scripts\EpicScript\ent.bin"
	.INPUTS
		Two files, both of type byte, one containing protected password data, the other containing the entropy data used for protection.
	.OUTPUTS
		Returns stored password as [System.String]
	.NOTES
		For more information about advanced functions, call Get-Help with any
		of the topics in the links listed below.
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
		[Parameter(Position = 0, Mandatory = $true)][System.String]$Path,
		[Parameter(Position = 1, Mandatory = $true)][System.String]$EntropyPath,
		[Parameter(Position = 2, Mandatory = $false)][System.String]$Scope = "CurrentUser",
		[Parameter(Position = 3, Mandatory = $false)][system.Boolean]$AsPlainText = $false
	)
	begin
	{
		try
		{
			#Validate parameters
			if ((Test-Path $Path) -eq $false)
			{
				Write-Error "Provided path is invalid. No file exists at $Path" -Category InvalidArgument -ErrorAction Stop
			}
			if ((Test-Path $EntropyPath) -eq $false)
			{
				Write-Error "Provided entropy path is invalid. No file exists at $EntropyPath" -Category InvalidArgument -ErrorAction Stop
			}
			if ($Scope -notlike "CurrentUser" -or $Scope -notlike "LocalMachine")
			{
				Write-Error "Invalid scope specified. Please specify `"CurrentUser`" or `"LocalMachine`". Default is `"CurrentUser`"." -Category InvalidArgument -ErrorAction Stop
			}
		}
		catch
		{ }
	}
	process
	{
		try
		{
			if ($Scope -eq "CurrentUser")
			{
				Write-Verbose "Setting scope to [System.Security.Cryptography.DataProtectionScope]::CurrentUser"
				$dataProtectionScope = [System.Security.Cryptography.DataProtectionScope]::CurrentUser
			}
			if ($Scope -eq "LocalMachine")
			{
				Write-Verbose "Setting scope to [System.Security.Cryptography.DataProtectionScope]::LocalMachine"
				$dataProtectionScope = [System.Security.Cryptography.DataProtectionScope]::LocalMachine
			}
			
			Write-Verbose "Getting encrypted data from file"
			Write-Verbose "InputPath: $Path"
			$protectedData = Get-Content -Encoding Byte $Path
			Write-Verbose "Getting entropy data from file"
			Write-Verbose "EntropyPath: $EntropyPath"
			$entropy = Get-Content -Encoding Byte $EntropyPath
			Write-Verbose "Decrypting data"
			$unprotectedData = [System.Security.Cryptography.ProtectedData]::Unprotect($protectedData, $entropy, "$dataProtectionScope")
			$password = [System.Text.Encoding]::Unicode.GetString($unprotectedData)
		}
		catch
		{ }
	}
	end
	{
		try
		{
			$password
		}
		catch
		{ }
	}
}
Export-ModuleMember -Function Get-StoredSecureCredential