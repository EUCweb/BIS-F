<#
	.SYNOPSIS
		Copy FSLogix rules and assignments from central share
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author:         Matthias Schlimm
		Company:  EUCWeb.com

		History:
		03.06.2015 MS: Initial script development
		13.08.2015 MS: Copy FSLogix rules and assignment files from central share to the FSLogix Apps rules folder at computer startup
		17.08.2015 MS: The FSlogix rules are copied from the central share but not applied, in the FSLogix personalization script, the copy must be performed after starting the FSLogix service, to resolve this issue
		21.08.2015 MS: Do not checked PVS or MCS DiskMode, Service is already running or will be started if stopped
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		03.10.2019 MS: ENH 141 - FSLogix App Masking URL Rule Files
		03.10.2019 MS: ENH 140 - cleanup redirected CloudCache empty directories
		13.02.2020 JK: Fixed Log output spelling
		05.12.2020 MS: HF 294 - using registry policy vlaue from $LIC_BISF_CLI_RS to get the central rules share

	.LINK
		https://eucweb.com
#>
Begin {
	$ErrorActionPreference = "SilentlyContinue"

	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "FSLogix Apps"
	$product_path = "${env:ProgramFiles}\FSLogix\Apps"
	$servicename = "FSLogix Apps Services"
	$FSXrulesDest = "$product_path\Rules"
	$FSXfiles2Copy = @("*.fxr", "*.fxa", "*.xml")
}

Process {


	function Copy-FSXRules {
		$ErrorActionPreference = "Stop"
		IF (!([string]::IsNullOrEmpty($LIC_BISF_CLI_RS))) {
			If (Test-Path -Path $LIC_BISF_CLI_RS) {
				Write-Log -Msg "Starting copy of $Product Rules & Assignment files" -showConsole -Color Cyan
				ForEach ($FileCopy in $FSXfiles2Copy) {
					Write-Log -Msg "Copy $Product $FileCopy files"
					Copy-Item -Path "$LIC_BISF_CLI_RS\*" -Filter "$FileCopy" -Destination "$FSXrulesDest"
				}
			}
			ELSE {
				$ErrorActionPreference = "Continue"
				Write-Log -Msg "$Product Central Rules Share '$LIC_BISF_CLI_RS' is not accessible or user '$cu_user' does not have enough rights!" -Type W -ShowConsole
			}
		}
		ELSE {
			$ErrorActionPreference = "Continue"
			Write-Log -Msg "No $Product Central Rules Share defined, didn't copy files!" -Type W
		}
	}

	Function Clear-RedirectedCloudCache {
		Write-Log -Msg "Processing $Product CloudCache" -ShowConsole -Color Cyan
		$frxreg = "HKLM:\SYSTEM\CurrentControlSet\Services\frxccds\Parameters"
		$FRXProxyDirectory = (Get-ItemProperty $frxreg -ErrorAction SilentlyContinue).ProxyDirectory
		$FRXWriteCacheDirectory = (Get-ItemProperty $frxreg -ErrorAction SilentlyContinue).WriteCacheDirectory
		$FRXDirectories = @("$FRXProxyDirectory", "$FRXWriteCacheDirectory")
		ForEach ($FRXDir in $FRXDirectories) {
			Write-Log -Msg "Processing $FRXDir" -ShowConsole -Color DarkCyan -SubMsg
			IF (Test-Path $FRXDir -PathType Leaf) {
				$FRXDrive = $FRXDir.substring(0, 2)
				IF ($FRXDrive -ne $env:SystemDrive) {
					Write-Log -Msg "Drive is different from the System Drive, cleanup now" -ShowConsole -Color DarkCyan -SubMsg
					Remove-Item "$FRXDir\*" -recurse
				}
			}
			ELSE {
				Write-Log -Msg "Directory $FRXDir does not exist"
			}
			ELSE {
				Write-Log -Msg "Drive is not different from System Drive, skipping" -ShowConsole -Color DarkCyan -SubMsg
			}
		}
	}


	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc) {
		Copy-FSXRules
		Clear-RedirectedCloudCache
	}
}
End {
	Add-BISFFinishLine
}