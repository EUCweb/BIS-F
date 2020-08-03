<#
    .SYNOPSIS
        Activate Office against the KMS server
	.DESCRIPTION
    .EXAMPLE
    .NOTES
		Author: Matthias Schlimm
      	Company:  EUCWeb.com

		History:
      	13.01.2015 BR: Script created for Office 2010 and Office 2013
		06.10.2015 MS: Rewritten script with standard .SYNOPSIS
		07.12.2016 MS: Added Office 2016 support
		01.11.2017 MS: get Office activation state and License state back to the BIS-F log
		22.03.2018 MS: Feature 15 - support for Office 365 ClicktoRun
		28.03.2019 MS: FRQ 86 - Office 2019 support
		03.10.2019 MS: ENH 84 - if hosting on azure, Displays the device join status
		07.01.2020 MS: HF 174 - Office detection general change
		18.02.2020 JK: Fixed Log output spelling
		01.08.2020 MS: HF 269 - Office detection takes too long, using reg instead of WMI
		02.08.2020 MS: HF 270 - PersBISF_Start.ps1 Script Causing all installed Applications to Reconfigure

	.LINK
        https://eucweb.com
#>


Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {

	# Check Office installation
	$OfficeProducts = @("Microsoft Office Professional Plus","Microsoft Office Standard","Click-to-Run Licensing Component")
	[array]$OfficeInstallRoot = $null
	ForEach ($OfficeProduct in $OfficeProducts) {
        $Office = (Get-BISFSoftwareInfo -Publisher "Microsoft" -Name "$OfficeProduct")[-1] | select DisplayVersion,DisplayName
		IF ($null -ne $Office) {
            $OFName = $Office.DisplayName
		    $OFVersion = $Office.DisplayVersion						#Version : 16.0.4266.1001
		    $OFVersionShort = $OFVersion.substring(0, 4)  	#Version : 16.0
		    IF ($OFName -like "*Click-to-Run*") { $O365 = $true } ELSE { $O365 = $false }
		    Write-BISFLog -Msg "$OFName - $OFVersion installed" -ShowConsole -Color Cyan
		    IF ($O365 -eq $false) {
			    If ([Environment]::Is64BitOperatingSystem) {
				    $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\$($OFVersionShort)\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path
			    }
			    If ($OfficeInstallRoot -isnot [system.object]) { $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\$($OFVersionShort)\Common\InstallRoot -Name Path -ErrorAction SilentlyContinue).Path }
		    }
		    ELSE {
			    If ([Environment]::Is64BitOperatingSystem) {
				    $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Wow6432Node\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).InstallPath
			    }
			    If ($OfficeInstallRoot -isnot [system.object]) { $OfficeInstallRoot += (Get-ItemProperty -Path Registry::HKLM\SOFTWARE\Microsoft\Office\ClickToRun -Name InstallPath -ErrorAction SilentlyContinue).InstallPath }
		    }
		    Write-BISFLog -Msg "Installpath $OfficeInstallRoot " -ShowConsole -Color DarkCyan -SubMsg
		    $OSPP = Get-ChildItem -Path $OfficeInstallRoot -filter "OSPP.vbs" -Recurse -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }
		    Write-BISFLog -Msg "OSPP is installed in $OSPP"
		    # Activate the office version
		    Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$OSPP"" /act" -ActText "Start triggering activation"
		    Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\cscript.exe" -Args "//NoLogo ""$OSPP"" /dstatus" -ActText "Get Office Licensing state"
		    IF ($O365 -eq $true) {
			    $O365onAzure = Test-BISFAzureVM
			    IF ($O365onAzure -eq $true) {
				    Write-BISFLog -Msg "Office is hosted on Microsoft Azure VM" -ShowConsole -Color DarkCyan -SubMsg
				    Start-BISFProcWithProgBar -ProcPath "$env:windir\system32\dsregcmd.exe" -Args "/status" -ActText "Office - Displays the device join status"
			    }
			    ELSE {
				    Write-BISFLog -Msg "Office is NOT hosted on a Microsoft Azure VM" -Color DarkCyan -SubMsg
			    }
		    }
       } ELSE {
        Write-BISFLog "$OfficeProduct is NOT installed"
       }
	}

	IF ($null -eq $OfficeInstallRoot ) {
		Write-BISFLog -Msg "No Office installation detected" -Type W
	}

}

End {
	Add-BISFFinishLine
}