<#
    .SYNOPSIS
        Prepare Cylance PROTECT Agent for Image Managemement
	.DESCRIPTION
      	Delete computer specific entries
    .EXAMPLE
    .NOTES
		Author:  Mathias Kowalkowski

		History
			09.05.2019 MK: Script created
			14.08.2019 MS: ENH 98: add function Set-CompatibilityMode

	.LINK
        https://eucweb.com
#>

Begin {
	$Script_Path = $MyInvocation.MyCommand.Path
	$Script_Dir = Split-Path -Parent $Script_Path
	$Script_Name = [System.IO.Path]::GetFileName($Script_Path)

	# Product specific parameters
	$ProductName = "Cylance PROTECT"
	$ProductPath = "${env:ProgramFiles}\Cylance\Desktop"
	$ServiceName = "CylanceSvc"
	[array]$ToDelete = @(
		[pscustomobject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FP" },
		[pscustomobject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FPMask" },
		[pscustomobject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "FPVersion" },
		[pscustomobject]@{type = "REG"; value = "HKLM:\SOFTWARE\Cylance\Desktop"; data = "SelfProtectionLevel" }
	)
}

Process {


	####################################################################
	####### Functions #####
	####################################################################

	function DeleteData {
		Write-BISFLog -Msg "Delete specified items "
		Foreach ($DeleteItem in $ToDelete) {
			IF ($DeleteItem.type -eq "REG") {
				Write-BISFLog -Msg "Processing registry item to delete" -ShowConsole -SubMsg -color DarkCyan
				$VerifyRegistryItem = Test-BISFRegistryValue -Path $DeleteItem.value -Value $DeleteItem.data
				IF ($VerifyRegistryItem) {
					Write-BISFLog -Msg "Deleting registry item -Path($DeleteItem.value) -Name($DeleteItem.data)"
					Remove-ItemProperty -Path $DeleteItem.value -Name $DeleteItem.data -ErrorAction SilentlyContinue
				}
			}

			IF ($DeleteItem.type -eq "FILE") {
				Write-BISFLog -Msg "Processing file item to delete" -ShowConsole -SubMsg -color DarkCyan
				$FullFileName = "$DeleteItem.value\$DeleteItem.data"
				IF (Test-Path ($FullFileName) -PathType Leaf) {
					Write-BISFLog -Msg "Deleting File $FullFileName"
					Remove-Item $FullFileName | Out-Null
				}
			}
		}
	}
	function StopService {
		$svc = Test-BISFService -ServiceName "$ServiceName"
		IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
	}

	function Set-CompatibilityMode {
		<#
		.SYNOPSIS
		Set Cynlance Compatibility Mode

		.DESCRIPTION
		As described in https://support.citrix.com/article/CTX232722
		you must take ownership of the registry and add a value to enable
		compatibility mode

		.NOTES
			Author: Matthias Schlimm

				14.08.2019 MS: function created
		#>

		Write-BISFLog -Msg "Take Registry Ownership" -ShowConsole -Color DarkCyan -SubMsg
		#Adjust current user privilegs
		enable-BISFprivilege SeTakeOwnershipPrivilege

		#Take Ownership of Registry Key
		$key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Cylance\Desktop", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
		$acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
		$me = [System.Security.Principal.NTAccount]"$env:username"
		$acl.SetOwner($me)
		$key.SetAccessControl($acl)

		#Read current ACL and add rule for Builtin\Admnistrators
		$acl = $key.GetAccessControl()
		$rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:username", "FullControl", "Allow")
		$acl.SetAccessRule($rule)
		$key.SetAccessControl($acl)
		$key.Close()

		Write-BISFLog -Msg "Set Compatibility Mode" -ShowConsole -Color DarkCyan -SubMsg
		Set-ItemProperty -Path "HKLM:\SOFTWARE\Cylance\Desktop" -Name "CompatibilityMode" -value 01 -PropertyType Binary -Force
	}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceName -ProductName $ProductName
	If ($svc -eq $true) {
		Write-BISFLog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
		StopService
		Set-CompatibilityMode
		DeleteData
	}
 Else {
		Write-BISFLog -Msg "Product $ProductName NOT installed"
	}
}

End {
	Add-BISFFinishLine
}