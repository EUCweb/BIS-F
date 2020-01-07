<#
	.SYNOPSIS
		Personalize Sophos AntiVirus for Image Managemement Software
	.DESCRIPTION
	  	Create HostID based on MACAddress and start services
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
		09.01.2017 MS: Script created
		18.08.2017 FF: Use $ServiceNameS instead of $ServiceName for first Test-BISFService

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)

	# Product specified
	$Product = "Sophos AntiVirus"
	$Inst_path = "$ProgramFilesx86\Sophos\Sophos Anti-Virus"
	$ServiceNames = @("Sophos Agent", "Sophos AutoUpdate Service", "Sophos Message Router")
	$HostID_Prfx = "00000000-0000-0000-0000-00"
	$HostID_File = "C:\programdata\Sophos\AutoUpdate\data\machine_ID.txt"

}

Process {

	####################################################################
	####### functions #####
	####################################################################

	function CreateGUID {
		Write-BISFLog -Msg "GUID Prefix: $HostID_Prfx"
		$mac = Get-BISFMACAddress
		$regHostID = $HostID_Prfx + $mac
		Write-BISFLog -Msg "Write Sophos GUID $regHostID to file $HostID_File"
		Out-File -Filepath $HostID_File -inputobject "$regHostID" -Encoding default
	}

	function StartService {
		ForEach ($ServiceName in $ServiceNames) {
			$svc = Test-BISFService -ServiceName "$ServiceName"
			IF ($svc -eq $true) { Invoke-BISFService -ServiceName "$($ServiceName)" -Action Start }
		}
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName $ServiceNames[0] -ProductName "$product"
	IF ($svc -eq $true) {
		CreateGUID
		StartService

	}
}


End {
	Add-BISFFinishLine
}