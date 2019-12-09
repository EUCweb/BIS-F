<#
    .SYNOPSIS
        Activate Office against the KMS server
	.Description
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Benjamin Ruoff
      	Company:  EUCWeb.com

<<<<<<< HEAD
		History:
      	13.01.2015 BR: Script created for Office 2010 and Office 2013
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		07.12.2016 MS: Added Office 2016 support
		01.11.2017 MS: get Office activation state and License state back to the BIS-F log
		22.03.2018 MS: Feature 15 - support for Office 365 ClicktoRun
		28.03.2019 MS: FRQ 86 - Office 2019 support
		03.10.2019 MS: ENH 84 - if hosting on azure, Displays the device join status
	.LINK
        https://eucweb.com
=======
		History
      	Last Change: 13.01.2015 BR: Script created for Office 2010 and Office 2013
		Last Change: 06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		Last Change: 07.12.2016 MS: Added Office 2016 support
		Last Change: 01.11.2017 MS: get Office activation state and License state back to the BIS-F log
		Last Change: 28.03.2019 MS: FRQ 86 - Office 2019 support
	.Link
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
#>


Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {

	# Check the installation path of Office 2010
	$Office2010InstallRoot = $null
	If ([Environment]::Is64BitOperatingSystem) {
		$Office2010InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\14.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
	}
	If ($Office2010InstallRoot -isnot [system.object]) {$Office2010InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\14.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

	# Check the installation path of Office 2013
	$Office2013InstallRoot = $null
	If ([Environment]::Is64BitOperatingSystem) {
		$Office2013InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\15.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
	}
	If ($Office2013InstallRoot -isnot [system.object]) {$Office2013InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\15.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

	# Check the installation path of Office 2016
	$Office2016InstallRoot = $null
	If ([Environment]::Is64BitOperatingSystem) {
		$Office2016InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\16.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
	}
	If ($Office2016InstallRoot -isnot [system.object]) {$Office2016InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\16.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }

	# Check the installation path of Office 2019
	$Office2019InstallRoot = $null
	If ([Environment]::Is64BitOperatingSystem) {
		$Office2019InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\17.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
	}
<<<<<<< HEAD
	If ($Office2019InstallRoot -isnot [system.object]) { $Office2019InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\17.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }


	# Check the installation path of Office 365 ClickToRun
	$Office365InstallRoot = $null
	If ([Environment]::Is64BitOperatingSystem) {
		$Office365InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).Path
	}
	If ($Office365InstallRoot -isnot [system.object]) { $Office365InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).Path }
=======
	If ($Office2019InstallRoot -isnot [system.object]) {$Office2019InstallRoot = (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\17.0\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35



	# Activate the office version if installed
	$result = $null
	IF ($Office2010InstallRoot -is [System.Object]) {
		Write-BISFLog -msg "Office 2010 is installed" -ShowConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2010InstallRoot)OSPP.VBS"" /act" -ActText "Start triggering activation"
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2010InstallRoot)OSPP.VBS"" /dstatus" -ActText "Get Office Licensing state"
	}
 ELSE {
		Write-BISFLog -msg "Office 2010 is NOT installed"
	}

	IF ($Office2013InstallRoot -is [System.Object]) {
		Write-BISFLog -msg "Office 2013 is installed" -ShowConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2013InstallRoot)OSPP.VBS"" /act" -ActText "Start triggering activation"
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2013InstallRoot)OSPP.VBS"" /dstatus" -ActText "Get Office Licensing state"
	}
 ELSE {
		Write-BISFLog -msg "Office 2013 is NOT installed"
	}


	IF ($Office2016InstallRoot -is [System.Object]) {
		Write-BISFLog -msg "Office 2016 is installed" -ShowConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2016InstallRoot)OSPP.VBS"" /act" -ActText "Start triggering activation"
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2016InstallRoot)OSPP.VBS"" /dstatus" -ActText "Get Office Licensing state"
	}
 ELSE {
		Write-BISFLog -msg "Office 2016 is NOT installed"
	}

	IF ($Office2019InstallRoot -is [System.Object]) {
		Write-BISFLog -msg "Office 2019 is installed" -ShowConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2019InstallRoot)OSPP.VBS"" /act" -ActText "Start triggering activation"
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office2019InstallRoot)OSPP.VBS"" /dstatus" -ActText "Get Office Licensing state"
	}
 ELSE {
		Write-BISFLog -msg "Office 2019 is NOT installed"
	}

<<<<<<< HEAD
	IF ($Office365InstallRoot -is [System.Object]) {
		Write-BISFLog -msg "Office 365 is installed" -ShowConsole -Color Cyan
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office365InstallRoot)OSPP.VBS"" /act" -ActText "Start triggering activation"
		Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$($Office365InstallRoot)OSPP.VBS"" /dstatus" -ActText "Get Office Licensing state"

		$O365onAzure = Test-BISFAzureVM
		IF ($O365onAzure -eq $true) {
			Write-BISFLog -Msg "Office 365 is hosting on Microsoft Azure" -ShowConsole -Color DarkCyan -SubMsg
			Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/status" -ActText "Office - Displays the device join status"
		}
		ELSE {
			Write-BISFLog -Msg "Office 365 is NOT hosting on Microsoft Azure" -Color DarkCyan -SubMsg
		}

	}
 ELSE {
		Write-BISFLog -msg "Office 365 is NOT installed"
	}

=======
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35

}

End {
	Add-BISFFinishLine
}
