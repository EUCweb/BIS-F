<#
	.SYNOPSIS
		Personalize SCOM Client for Image Managemement Software
	.DESCRIPTION

	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
	  	17.11.2014 MS: Script created for OpsMagr2k7
		06.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		04.03.2016 MS: fixed issue SCOM service would be start on every Image Mode if installed
		19.10.2018 MS: Bugfix 72: MCS Deployment: SCOM Agent - creates OpsStateDir in C: drive
		18.02.2020 JK: Fixed Log output spelling

	.LINK
		https://eucweb.com
#>

Begin {
	$OpsStateDir = "$PVSDiskDrive\OpsStateDir"
	$servicename = "HealthService"
	$Product = "Microsoft SCOM Agent"
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {

	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$Product"
	IF ($svc) {
		$OpsStateDir = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\$servicename\Parameters")."State Directory"
		IF ($returnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Citrix PVS Target Device detected, Set StateDirectory to Path $OpsStateDir"
			If (!(Test-Path -Path $OpsStateDir)) {
				Write-BISFLog -Msg "Create Directory $OpsStateDir"
				New-Item -path "$OpsStateDir" -ItemType Directory -Force
			}
		}
		ELSE {
			Write-BISFLog -Msg "Citrix PVS Target Device NOT detected, leaving StateDirectory on original path $OpsStateDir"
		}
		Invoke-BISFService -ServiceName "$servicename" -Action Start
	}
}

End {
	Add-BISFFinishLine
}