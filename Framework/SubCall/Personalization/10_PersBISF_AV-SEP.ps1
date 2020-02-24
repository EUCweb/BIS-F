<#
	.SYNOPSIS
		Prepapre Symantec Endpoint Protection for Image Managemement Software
	.DESCRIPTION
	  	Create HostID based on MACAddress
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
		Company:  EUCWeb.com

		History:
		24.09.2012 MS: Script created
		18.09.2013 MS: replace $date with $(Get-date) to get current timestamp at running scriptlines write to the logfile
		18.09.2013 MS: replace $PVsWriteCacheDisk to global environment variable $LIC_PVS_HostIDPath
		17.12.2013 MS: change service to smc -start for SEP 12 or higher
		27.01.2014 MS: $HostID_Prfx = "00000000000000000000"
		27.01.2014 MS: Set-Location $SEP_path
		28.01.2014 MS: $service_name = "cmd /c smc -start"
		28.01.2014 MS: $reg_SEP_name
		10.03.2014 MS: Review Code
		11.03.2014 MS: IF (Test-Path ("$SEP_path\smc.exe"))
		18.03.2014 BR: revisited Script
		13.08.2014 MS: remove $logfile = Set-logFile, it would be used in the 10_XX_LIB_Config.ps1 Script only
		17.08.2014 MS: change line 32 to $SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
		31.08.2015 MS: bugfix 89 - symantec fixes the registry location for the SEP-Client to WOW6432Node, fix in line 31-32 and function SetHostID
		01.09.2015 MS: Bugfix 89 sucessfull tested
		06.10.2015 MS: rewritten script with standard .SYNOPSIS, central BISF function couldn't used for services, SEP Service must being started with smc.exe
		09.01.2017 MS: change code to get MacAdress to use function Get-BISMACAddress
		01.07.2018 MS: Hotfix 49: After SEP is started with smc.exe, sometimes the service will not be started. Controlled and logged now with Test-BISFServiceState in Line 58
		18.02.2020 JK: Fixed Log output spelling
		19.02.2020 MS: HF 212 - SEP duplicate HardwareID - Get-BISFMacaddress returns lower- instead of uppercase MACAddress -> compare HardwareID after ServiceStart


	.LINK
		https://eucweb.com
#>

Begin {
	$reg_SEP_string = "Symantec\Symantec Endpoint Protection\SMC\SYLINK\SyLink"
	$Product = "Symantec Enterprise Protection"
	$ServiceName = "SepMasterService"
	$HKLM_reg_SEP_string = "$HKLM_sw_x86\$reg_SEP_string"
	$SEP_path = "$ProgramFilesx86\Symantec\Symantec Endpoint Protection"
	$reg2Check = "SerialNumber"
	$reg_SEP_name = "HardwareID"
	$HostID_Prfx = "00000000000000000000"
	$PSScriptFullName = $MyInvocation.MyCommand.Path
	$PSScriptRoot = Split-Path -Parent $PSScriptFullName
	$PSScriptName = [System.IO.Path]::GetFileName($PSScriptFullName)
}

Process {

	## Start SEP Service
	function StartSEP {
		Write-BISFLog -Msg "Start Service $($ServiceName.DisplayName)"
		& $ProgramFilesx86'\Symantec\Symantec Endpoint Protection\smc.exe' "-start"
		Test-BISFServiceState -ServiceName $ServiceName -Status "Running"
		$testHardwareID = Get-ItemPropertyValue -Path $HKLM_reg_SEP_string -Name $reg_SEP_name
		IF ($testHardwareID -eq $regHostID) {
			Write-BISFLog -Msg "HardwareID in registry is set correctly: $testHardwareID"
		} ELSE {
			Write-BISFLog -Msg "After the AV-Service is started, HardwareID in registry is NOT set correcty: Registry HardwareID $testHardwareID <-> Defined HardwareID $regHostID" -Type W -SubMsg
		}
	}


	## set HostID in Registry
	function SetHostID {
		# 31.08.2015 MS: check if Sep Registry Key exists in registry location
		$TestSEPinReg = Test-BISFRegistryValue -Path $HKLM_reg_SEP_string -Value $reg2Check
		IF ($TestSEPinReg -eq $false) {
			$HKLM_reg_SEP_string = "$hklm_software\$reg_SEP_string"
			$TestSEPinReg = Test-BISFRegistryValue -Path $HKLM_reg_SEP_string -Value $reg2Check
		}

		IF ($TestSEPinReg -eq $true) {
			Write-BISFLog -Msg "Registry Location for specified SEP Keys will be set to $HKLM_reg_SEP_string"

			$mac = Get-BISFMACAddress
			Write-BISFLog -Msg "$reg_SEP_name Prefix: $HostID_Prfx"
			$global:regHostID = $HostID_Prfx + $mac
			Write-BISFLog -Msg "$reg_SEP_name will be defined as: $regHostID"
			Write-BISFLog -Msg "set $reg_SEP_name in Registry $HKLM_reg_SEP_string"
			Set-ItemProperty -Path $HKLM_reg_SEP_string -Name $reg_SEP_name -value $regHostID -ErrorAction SilentlyContinue

		}
		ELSE {
			Write-BISFLog -Msg "Registry Location for specified SEP Keys could not be set to $HKLM_reg_SEP_string" -Type W -SubMsg
			Write-BISFLog -Msg " The Value $reg2Check does not exist in the above location!" -Type W -SubMsg
			Write-BISFLog -Msg "The SEP Service will be started, but each boot will create ghost entries in the SEP Management Server" -Type W -SubMsg
		}
	}
	####################################################################

	#### Main Program
	IF (Test-Path ("$SEP_path\smc.exe") -PathType Leaf) {
		Write-BISFLog -Msg "Symantec Endpoint Protection installed" -ShowConsole -Color Cyan
		SetHostID
		StartSEP
	}
	ELSE {
		Write-BISFLog -Msg "Symantec Endpoint Protection NOT installed"
	}

}


End {
	Add-BISFFinishLine
}