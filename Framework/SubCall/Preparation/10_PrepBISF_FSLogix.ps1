<#
	.SYNOPSIS
		Prepare FSLogix Apps for Image Management
	.DESCRIPTION
		The script detects the installationn of FSLogix  and deletes the FSLogix Rules on the Master Image.
		You can set a Central Rules Share to copy centralized Rules during the BIS-F personlization phase to the Images.
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		03.06.2015 MS: Initial script development
		13.08.2015 MS: Central rules share defined and stored in registry location to use at computer startup
		21.08.2015 MS: Remove to set FSLogix service to manual, stopped service only.
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		06.03.2017 MS: Bugfix read Variable $varCLI = ...
		15.02.2017 MS: Bugfix 237: When in the GPO specify "Configure FSLogix central rule share" to Disabled, the script still prompt for the path when is executed
		15.05.2019 JP: Fixed format and deleted junk lines
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured
		13.02.2020 JK: Fixed Grammar

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
}

Process {

	function ClearConfig {
		Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
		$varCLIFS = $LIC_BISF_CLI_FS
		IF (($varCLIFS -eq "YES") -or ($varCLIFS -eq "NO")) {
			Write-BISFLog -Msg "GPO value data: $varCLIFS"
		}
		ELSE {
			Write-BISFLog -Msg "GPO is not configured.. using default setting" -SubMsg -Color DarkCyan
			$MPFS = "NO"
		}

		if (($MPFS -eq "YES" ) -or ($varCLIFS -eq "YES")) {
			Write-BISFLog -Msg "Delete $product Rules" -ShowConsole -Color DarkCyan -SubMsg
			Remove-Item -Path "$product_path\Rules\*" -Recurse
		}
		ELSE {
			Write-BISFLog -Msg "Skipping $product Rules deletion"
		}
	}

	function Set-RulesShare {
		# Set the FSLogix central rules share in the BIS-F registry location, to get on BIS-F personalisation on each device
		Write-BISFLog -Msg "$Product Rules Share - Checking GPO Configuration" -SubMsg -Color DarkCyan
		$varCLIRS = $LIC_BISF_CLI_RSb
		$varCLIRS = $LIC_BISF_CLI_RSb
		$varCLIRS = $LIC_BISF_CLI_RSb
		IF ($varCLIRS -ne "") {
			Write-BISFLog -Msg "GPO value data: $varCLIRS"
			$fslogixRulesShare = $LIC_BISF_CLI_RS
		}
		ELSE {
			Write-BISFLog -Msg "$Product GPO not configured.. using default settings" -SubMsg -Color DarkCyan
			$fslogixRulesShare = ""
		}

		if ($fslogixRulesShare -ne "") {
			Write-BISFLog -Msg "The $Product Central Rules Share is set to $fslogixRulesShare" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg "Set $Product Central Rules Share in the registry $hklm_software_LIC_CTX_BISF_SCRIPTS, Name LIC_BISF_FSXRulesShare, value $fslogixRulesShare"
			Set-ItemProperty -Path $hklm_software_LIC_CTX_BISF_SCRIPTS -Name "LIC_BISF_FSXRulesShare" -value "$fslogixRulesShare" -Force

		}
		ELSE {
			Write-BISFLog -Msg "No $Product Central Rules Share defined"
		}
	}

	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true) {
		Invoke-BISFService -ServiceName "$servicename" -Action Stop
		ClearConfig
		Set-RulesShare
	}
}

End {
	Add-BISFFinishLine
}