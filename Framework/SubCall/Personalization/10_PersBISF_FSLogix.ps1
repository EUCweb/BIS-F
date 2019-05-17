<#
	.SYNOPSIS
		Copy the FsLogic rules from central share
	.DESCRIPTION
	.EXAMPLE
	.NOTES
		Author:         Matthias Schlimm
		Company: Login Consultants Germany GmbH

		History:
		03.06.2015 MS: Initial script development
		13.08.2015 MS: copy fslogix rules and assignment files from central share to the fslogix apps rule folder on computer startup
		17.08.2015 MS: The fslogix rules are copied from the central share but not applied, in thefslogix personalization script, the copy must be performed after starting the fslogix service, to resolve this issue
		21.08.2015 MS: Do not checked PVS or MCS DiskMode, Service is already running or would be start if stopped
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
	.LINK
		https://eucweb.com
#>
Begin {
	$ErrorActionPreference = "SilentlyContinue"

	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "FsLogix Apps"
	$product_path = "${env:ProgramFiles}\FSLogix\Apps"
	$servicename = "FSLogix Apps Services"
	$FSXrulesDest = "$product_path\Rules"
	$FSXfiles2Copy = @("*.fxr", "*.fxa")
}

Process {

		
	function Copy-FSXRules {
		$ErrorActionPreference = "Stop"
		$regval = (Get-ItemProperty $hklm_software_LIC_CTX_BISF_SCRIPTS -ErrorAction SilentlyContinue).LIC_BISF_FSXRulesShare 
		IF ($regval -ne $null) {
			If (Test-Path -Path $regval) {
				Write-Log -Msg "Starting copy fsLogix Rules & Assignment files" -showConsole -Color Cyan
				ForEach ($FileCopy in $FSXfiles2Copy) {
					Write-Log -Msg "Copy fsLogix $FileCopy files"
					Copy-Item -Path "$regval\*" -Filter "$FileCopy" -Destination "$FSXrulesDest"           
				}
			}
			ELSE {
				$ErrorActionPreference = "Continue"
				Write-Log -Msg "$Product Central Rules Share '$regval' does not accesible or user '$cu_user' does not have enough rights !!" -Type W -ShowConsole
			}
		}
		ELSE {
			$ErrorActionPreference = "Continue"
			Write-Log -Msg "No fsLogix Central Rules Share defined, did not copy rules and assignment files !!" -Type W 
		}
	}



	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc) {
		Copy-FSXRules
	}
}
End {
	Add-BISFFinishLine
}