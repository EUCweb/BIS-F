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
			02.01.2020 MS: HF 164: Wrong Command for Compatibility Mode
			01.06.2020 MS: HF 238: VDI Fingerprinting support
			01.08.2020 MS: HF 261 - fix Errorhandling

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

	function Remove-Data {
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
	function Stop-Service {
		$svc = Test-BISFService -ServiceName "$ServiceName"
		IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Stop }
	}

	function Set-CompatibilityMode {
		<#
		.SYNOPSIS
		Set Cylance Compatibility Mode

		.DESCRIPTION
		As described in https://support.citrix.com/article/CTX232722
		you must take ownership of the registry and add a value to enable
		compatibility mode

		.NOTES
			Author: Matthias Schlimm

				14.08.2019 MS: function created
				01.08.2020 MS: HF 261 - fix Errorhandling
		#>

		$CompatibilityMode = (Get-ItemProperty HKLM:\SOFTWARE\Cylance\Desktop).CompatibilityMode
        IF ($CompatibilityMode -ne 0) {
            $ErrorActionPreference = "Stop"
            Write-BISFLog -Msg "Take Registry Ownership" -ShowConsole -Color DarkCyan -SubMsg
		    #Adjust current user privilegs
		    $null = enable-BISFprivilege SeTakeOwnershipPrivilege

		    #Take Ownership of Registry Key
		    $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey("SOFTWARE\Cylance\Desktop", [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree, [System.Security.AccessControl.RegistryRights]::takeownership)
		    try {
			    $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::None)
                $me = [System.Security.Principal.NTAccount]"$env:username"
		        $acl.SetOwner($me)
		        $key.SetAccessControl($acl)
		    }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }



		    #Read current ACL and add rule for Builtin\Admnistrators
		    try {
                $acl = $key.GetAccessControl()
		        $rule = New-Object System.Security.AccessControl.RegistryAccessRule ("$env:username", "FullControl", "Allow")
		        $acl.SetAccessRule($rule)
		        $key.SetAccessControl($acl)
		        $key.Close()
            }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }


		    Write-BISFLog -Msg "Set Compatibility Mode" -ShowConsole -Color DarkCyan -SubMsg
		    try {
                New-ItemProperty -Path "HKLM:\SOFTWARE\Cylance\Desktop" -Name "CompatibilityMode" -value 01 -PropertyType Binary -Force
             }

            catch {
			    Write-BISFLog "ACL Error: $_" -Type W -ShowConsole -SubMsg
		    }
            $ErrorActionPreference = "Continue"
        } ELSE  {
            Write-BISFLog -Msg "Compatibility Mode is already set to $CompatibilityMode" -ShowConsole -Color DarkCyan -SubMsg
        }
}

	####################################################################
	####### End functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceName -ProductName $ProductName
	If ($svc -eq $true) {
		Write-BISFLog -Msg "Product $ProductName installed" -ShowConsole -Color Cyan
		$VDIType = (Get-ItemProperty HKLM:\SOFTWARE\Cylance\Desktop).VDIType
		IF (!($VDIType -eq 0)) {
			Stop-Service
			Set-CompatibilityMode
			Remove-Data
		} Else {
			Write-BISFLog -Msg "Skipping ProductName sealing operations !" -ShowConsole -Type W -SubMsg
		}


	}
 Else {
		Write-BISFLog -Msg "Product $ProductName NOT installed"
	}
}

End {
	Add-BISFFinishLine
}