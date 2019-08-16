<#
.SYNOPSIS
  Generalize the Tanium Client prior to sealing the XenApp PVS Target image.

.NOTES
  Author:         mtoussiant@dxc.com

		13.06.2017 - MT :Initial script created
	  	30.08.2018 - MT Script update to set the service to Automatic and correct a file deletion issue
		14.08.2019 - MS: ENH 118: Add Tanium Support into BIS-F
		16.08.2019 MS: Add-BISFStartLine

.LINK
	https://eucweb.com

#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "Tanium"
	$ServiceName = "Tanium Client"
}

Process {
	Add-BISFStartLine -ScriptName $script_name
	####################################################################
	####### functions #####
	####################################################################



	####### end functions #####
	function Stop-Service {
		Invoke-BISFService -ServiceName $ServiceName -Action Stop -StartType Automatic

	}

	function Remove-Data {

		#Set ComputerID to 0
		Set-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client' -Name ComputerID -Value 0

		#Delete RegistrationCount
		Remove-ItemProperty -Path  'HKLM:\SOFTWARE\Wow6432Node\Tanium\Tanium Client' -Name RegistrationCount

		#Delete the Strings folder if exists
		If(Test-Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Strings") {
			Remove-Item -Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Strings" -Recurse -Force
		}

		#Delete the log0.txt file
		If(Test-Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\log0.txt") {
			Remove-Item -Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\log0.txt"
		}


		#Empty the Downloads folder
		If(Test-Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Downloads") {
			Remove-Item -Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Downloads\*" -Recurse -Force
		}

		#Delete all files in the Tools\Scans and Tools\Content Logs folders.
		If(Test-Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Tools\Scans") {
			Remove-Item -Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Tools\Scans\*" -Recurse -Force
		}
		If(Test-Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Tools\Content Logs") {
			Remove-Item -Path "${env:ProgramFiles(x86)}\tanium\Tanium Client\Tools\Content Logs\*" -Recurse -Force
		}

	}
	#### Main Program

	$svc = Test-BISFService -ServiceName $ServiceName -ProductName "$product"
	IF ($svc -eq $true) {
		Stop-Service
		Remove-Data

	}

}

End {
	Add-BISFFinishLine
}
