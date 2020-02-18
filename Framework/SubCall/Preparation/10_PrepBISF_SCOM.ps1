<#
	.SYNOPSIS
		Prepare SCOM Client for Image Managemement
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
	  	17.11.2014 MS: Script created for OpsMagr2k7
		19.02.2015 MS: change line 65 to IF ($svc -And (Test-Path $OpsStateDirOrigin))
		04.05.2015 MS: add SCOM 2012 detection, checks 2007 path only
		30.07.2015 MS: Fix line 39: rename $returnCheckPVSSoftware to $returnTestPVSSoftware
		01.10.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		03.10.2017 MS: Bugfix 214: Test path if $OpsStateDirOrigin before delete, instead of complete C: content if if $OpsStateDirOrigin is not available
		29.03.2018 MS: Bugfix 37: SCOM 2018, uses new cerfifcate store Microsoft Monitoring Agent
		18.02.2020 JK: Fixed Log output spelling

	.LINK
		https://eucweb.com
#>

Begin {
	$OpsStateDir = "$PVSDiskDrive\OpsStateDir"
	$OpsStateDirOrigin2012 = "$env:ProgramFiles\Microsoft Monitoring Agent\Agent\Health Service State"
	$OpsStateDirOrigin2007 = "$ProgramFilesx86\System Center Operations Manager 2007\Health Service State"
	$servicename = "HealthService"
	$Product = "Microsoft SCOM Agent"
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}
####################################################################
####### functions #####
####################################################################

Process {


	function ReconfigureAgent {
		Write-BISFLog -Msg "remove existing certificates for $product"
		Try {
			& Invoke-Expression "certutil -delstore ""Operations Manager"" $env:Computername.$env:userdnsdomain" | Out-Null
		}
		Catch {
			Write-BISFlog -Msg "Certificate Operations Manager can't be removed"
		}

		#required for SCOM 2016 an later too
		Try {
			& Invoke-Expression "certutil -delstore ""Microsoft Monitoring Agent"" 0" | Out-Null
		}
		Catch {
			Write-BISFlog -Msg "Certificate Microsoft Monitoring Agent can't be removed"
		}

		IF ($returnTestPVSSoftware -eq "true") {
			Write-BISFLog -Msg "Citrix PVS Target Device detected, Setting StateDirectory to Path $OpsStateDir"
			Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\services\$servicename\Parameters" -Name "State Directory" -Value "$OpsStateDir"
		}
		ELSE {
			Write-BISFLog -Msg "Citrix PVS Target Device NOT detected, StateDirectory left on original path $OpsStateDirOrigin"
		}

		if (Test-Path $OpsStateDirOrigin) {
			Write-BISFLog -Msg "Delete Path $OpsStateDirOrigin"
			Remove-Item -Path "$OpsStateDirOrigin\*" -recurse
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program

	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true) {
		$OpsStateDirOrigin = @()   # set empty variable to check later if Ops/SCOM installed
		IF (Test-Path $OpsStateDirOrigin2012) { $OpsStateDirOrigin = $OpsStateDirOrigin2012 }
		IF (Test-Path $OpsStateDirOrigin2007) { $OpsStateDirOrigin = $OpsStateDirOrigin2007 }

		IF ($OpsStateDirOrigin -ne $null) {
			Write-BISFLog -Msg "Path $OpsStateDirOrigin detected"
			Invoke-BISFService -ServiceName "$servicename" -Action Stop -StartType manual
			ReconfigureAgent
		}
		ELSE {
			Write-BISFLog -Msg "$Service $ServiceName detected, but path $OpsStateDirOrigin2012 or $OpsStateDirOrigin2007 not found. $product will not be optimized for Imaging" -Type E -SubMsg
		}
	}
}

End {
	Add-BISFFinishLine
}