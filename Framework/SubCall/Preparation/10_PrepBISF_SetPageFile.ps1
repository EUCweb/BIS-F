<#
	.SYNOPSIS
		Sets the page file to a defined location
	.DESCRIPTION
		Sets the page file to a defined location.  Tested on 2016, 2012R2, 2008R2
	.EXAMPLE
	.NOTES
		Author: Trentent Tye
		Company: TheoryPC

		History:
		2017.06.27 TT: Script created
		2017.08.05 TT: Tested on 2008 R2
		2018.01.29 TT: Fixed error appearing even though no such error existed.
		2019.10.11 MS: IF ADMX is not configured or disabled skip any pagefile configuration
		2020.02.17 MS: HF 207 - PageFiel not set

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$pageFileInitialSize = ([int]$LIC_BISF_CLI_PAGEFILE_SIZE * 1024)
	$pageFileMaximumSize = ([int]$LIC_BISF_CLI_PAGEFILE_SIZE * 1024)
	if ($LIC_BISF_CLI_PAGEFILE_DRIVE -eq "$PVSWriteCacheDrive") {
		$pagefileLocation = "$LIC_BISF_CLI_WCD\pagefile.sys"
	}
	else {
		$pageFileLocation = "$LIC_BISF_CLI_PAGEFILE_DRIVE\pagefile.sys"
	}
	$recreatePageFile = $false
}

Process {
	IF ($LIC_BISF_POL_PAGEFILE -eq 1) {
		Write-BISFLog -Msg "Checking PageFile settings" -ShowConsole -Color Cyan
		Write-BISFLog -Msg "Variable LIC_BISF_CLI_PAGEFILE_SIZE  : $LIC_BISF_CLI_PAGEFILE_SIZE" -ShowConsole -Color Cyan  -SubMsg
		Write-BISFLog -Msg "Variable LIC_BISF_CLI_PAGEFILE_DRIVE : $LIC_BISF_CLI_PAGEFILE_DRIVE" -ShowConsole -Color Cyan  -SubMsg
		Write-BISFLog -Msg "Variable LIC_BISF_CLI_WCD            : $LIC_BISF_CLI_WCD" -ShowConsole -Color Cyan  -SubMsg
		Write-BISFLog -Msg "Variable pageFileLocation            : $pageFileLocation" -ShowConsole -Color Cyan  -SubMsg
		Write-BISFLog -Msg "Variable pageFileInitialSize         : $pageFileInitialSize" -ShowConsole -Color Cyan  -SubMsg
		Write-BISFLog -Msg "Variable pageFileMaximumSize         : $pageFileMaximumSize" -ShowConsole -Color Cyan  -SubMsg

		$CurrentPageFile = Get-WmiObject -query "select * from Win32_PageFileSetting"
		$System = Get-WmiObject Win32_ComputerSystem -EnableAllPrivileges

		#we set our pagefile to D:\pagefile.sys with initial and maximum values at 4096MB and disable automatic pagefile management
		if ($System.AutomaticManagedPagefile -eq $true) {
			#system management pagefile found.
			Write-BISFLog -Msg  "System Managed Pagefile found.  Removing..." -ShowConsole -Color DarkCyan -SubMsg
			$System.AutomaticManagedPagefile = $false
			$errorHandling = $ErrorActionPreference
			$errorActionPreference = "SilentlyContinue"
			#$System.put() generates an error even though it succeeds. We'll mask the error by changing error action temporairily.
			$System.Put()
			$errorActionPreference = $errorHandling
		}
		if (($CurrentPageFile.SettingID).count -ne 1) {
			#is there more than 1 pagefile set (eg, pagefiles are set on multiple drives?)
			$recreatePageFile = $true
		}
		if ($CurrentPageFile.initialSize -ne $pageFileInitialSize) {
			Write-BISFLog -Msg  "Configuring Pagefile Initial Size to $pageFileInitialSize" -ShowConsole -Color DarkCyan -SubMsg
			$recreatePageFile = $true
		}
		if ($CurrentPageFile.MaximumSize -ne $pageFileMaximumSize) {
			Write-BISFLog -Msg  "Configuring Pagefile Maximum Size to $pageFileMaximumSize" -ShowConsole -Color DarkCyan -SubMsg
			$recreatePageFile = $true
		}
		if (-not($CurrentPageFile.name -like $pageFileLocation)) {
			#pageFile location not set to D:\pagefile.sys
			Write-BISFLog -Msg  "Configuring Pagefile location to $pageFileLocation" -ShowConsole -Color DarkCyan -SubMsg
			$recreatePageFile = $true
		}

		if ($recreatePageFile -eq $true) {
			$CurrentPageFile = Get-WmiObject -Query "select * from Win32_PageFileSetting"
			if ($CurrentPageFile -ne $null) { $CurrentPageFile.Delete() }

			Set-WMIInstance -class Win32_PageFileSetting -Arguments @{name=$pageFileLocation;InitialSize = $pageFileInitialSize;MaximumSize = $pageFileMaximumSize} | out-null
            Write-BISFLog -Msg  "New Pagefile settings applied:" -ShowConsole -Color DarkCyan -SubMsg
			$CurrentPageFile = Get-WmiObject -Query "select * from Win32_PageFileSetting"
			Write-BISFLog -Msg  "Number of pagefiles: $($($CurrentPageFile.SettingID).count)" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg  "Pagefile location: $($CurrentPageFile.name)" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg  "Pagefile initial size: $($CurrentPageFile.initialSize)" -ShowConsole -Color DarkCyan -SubMsg
			Write-BISFLog -Msg  "Pagefile maximum size: $($CurrentPageFile.MaximumSize)" -ShowConsole -Color DarkCyan -SubMsg
			Set-BISFPreparationState -RebootRequired  #ensure we reboot to enforce values
		}
		if ($recreatePageFile -eq $false) {
			Write-BISFLog -Msg  "Pagefile set to correct values" -ShowConsole -Color DarkCyan -SubMsg
		}
	} ELSE {
		Write-BISFLog -Msg  "Pagefile NOT configured"
	}
}


End {
	Add-BISFFinishLine
}