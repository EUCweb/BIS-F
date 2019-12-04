#requires -version 3
<#
	.SYNOPSIS
		Prepare SCCM Client for Image Managemement
	.DESCRIPTION
		Delete computer specific entries
	.EXAMPLE
		./10_PrepBISF_SCCM.ps1
	.NOTES
		Author: Matthias Schlimm
		Company:  EUCWeb.com

		History:
		26.03.2014 MS: Script created for SCCM 2012 R2
		01.04.2014 MS: Change Console message
		02.05.2014 MS: BUG code-error certstore SMS not deleted > & Invoke-Expression 'certutil -delstore SMS "SMS"'
		11.08.2014 MS: Remove Write-Host change to Write-BISFLog
		13.08.2014 MS: Remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		19.02.2015 MS: Syntax error and error handling
		06.03.2015 MS: Delete CCM Package Cache
		05.05.2015 MS: #temp. deactivate Remove-CCMCache , some errors more testing
		01.09.2015 MS: Bugfix 42 - fixing deleteCCMCahce, this must be running before service stops
		30.09.2015 MS: Rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		10.05.2019 JP: Added command to remove hardware inventory as recommended by Citrix https://support.citrix.com/article/CTX238513
		10.05.2019 JP: Converted wmic commands to Get-CimInstance and reworked script synthax
		14.05.2019 JP: The CcmExec service is no longuer set to manual
		08.12.2019:JP: Fixed error on line 74, thanks toBrian Timp

	.LINK
		https://eucweb.com
#>

Begin {
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
	[string]$appVendor = 'Microsoft'
	[string]$appName = "SCCM Agent"
	[string]$appInstallPath = "$env:windir\CCM"
	[string]$appService = 'CcmExec'
	[string]$appRegKey = "$hklm_software\Microsoft\SystemCertificates\SMS\Certificates"
}

Process {

	function Remove-CCMData {
		Write-BISFLog -Msg "$appVendor $appName SMSCFG.ini was deleted"
		Remove-Item -Path "$env:windir\SMSCFG.ini" -Force -ErrorAction SilentlyContinue

		Write-BISFLog -Msg "$appVendor $appName certificates from SMS store were removed"
		Remove-Item -Path $appRegKey\* -Force

		Write-BISFLog -Msg "$appVendor $appName site key information was reset"
		Get-CimInstance -Namespace root\ccm\locationservices -Class TrustedRootKey | Remove-CimInstance

		Write-BISFLog -Msg "$appVendor $appName hardware inventory was deleted"
		Get-CimInstance -Namespace root\ccm\invagt -Class InventoryActionStatus | Where-Object { $_.InventoryActionID -eq "{00000000-0000-0000-0000-000000000001}" } | Remove-CimInstance

		Write-BISFLog -Msg "$appVendor $appName scheduler history deleted"
		Get-CimInstance -Namespace root\ccm\scheduler -Class CCM_Scheduler_History | Where-Object { $_.ScheduleID -eq "{00000000-0000-0000-0000-000000000001}" } | Remove-CimInstance
	}

	# Original source http://www.david-obrien.net/2013/02/how-to-configure-the-configmgr-client
	function Remove-CCMCache {
		[CmdletBinding()]
		$UIResourceMgr = New-Object -ComObject UIResource.UIResourceMgr
		$Cache = $UIResourceMgr.GetCacheInfo()
		$CacheElements = $Cache.GetCacheElements()
		foreach ($Element in $CacheElements) {
			Write-BISFLog -Msg "$appVendor $appName deleted Cache Element with PackageID $($Element.ContentID)"
			Write-BISFLog -Msg "from folder $($Element.Location)"
			$Cache.DeleteCacheElement($Element.CacheElementID)
		}
	}

	$svc = Test-BISFService -ServiceName $appService
	IF ($svc -eq $true) {
		Remove-CCMCache # 01.09.2015 MS: Remove-CCMCache must be run before stopping the service
		Invoke-BISFService -ServiceName $appService -Action Stop
		Remove-CCMData
	}
}

End {
	Add-BISFFinishLine
}