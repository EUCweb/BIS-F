<#
	.SYNOPSIS
		Prepare Matrix 42 Empirum Agent for Image Management
	.DESCRIPTION
	  	Delete computer specific entries
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
	  	16.09.2014 MS: Script created
		27.10.2014 MS: Fix wrong $cachelocation from XML-File (thx to David Rosenthal)
		12.12.2014 MS: syntax error at line 33
		30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		28.05.2019 MK: added a more stable verification for the empirum services and $cachelocation\Packages\* to file removal

	.LINK
		https://eucweb.com
#>

Begin {
	$EmpirumPaths = @("C:\Windows\System32\Empirum", "C:\Program Files\Matrix42\Universal Agent Framework")
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Svc1 = "Eris"
	$Svc2 = "MATRIXAUT"
	$Svc3 = "Matrix42UAF"
	$product = "Matrix42 Empirum"
}

Process {

	function StopService {
		$svc = Test-BISFService -ServiceName "$Svc1"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$Svc1" -Action Stop
		}

		$svc = Test-BISFService -ServiceName "$Svc2"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$Svc2" -Action Stop
		}

		$svc = Test-BISFService -ServiceName "$Svc3"
		IF ($svc -eq $true) {
			Invoke-BISFService -ServiceName "$Svc3" -Action Stop
		}
	}
	function deleteAgentData {
		ForEach ($EmpirumPath in $EmpirumPaths) {
			$ErrorActionPreference = 'SilentlyContinue'
			[xml]$xmlfile = Get-Content "$EmpirumPath\AgentConfig.xml"
			$cachelocation = Select-Xml "//Transport/Protocols/CommonParameters/LocalCache[@Platform='Windows']" $xmlfile | % { $_.Node.'#text' }
			Write-Log -Msg "get cachelocation from XML-File $xmlfile $cachelocation"
			IF ($cachelocation -match "(%.*%)\\") {
				$cachelocation = $cachelocation -replace "%(.*%)\\", "$(cmd /C echo $matches[0])"
			}

		Write-Log -Msg "remove Empirum Agent LocalCache in path $cachelocation" -Color Cyan
		Remove-Item "$cachelocation\DDC\Machine\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\DDC\User\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\DDS\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\Values\MachineValues\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\Values\UserValues\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\Packages\*" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "$cachelocation\PatchManagement\Repository\Patches*" -Force -Recurse -ErrorAction SilentlyContinue

		Write-Log -Msg "remove Empirum Agent specified registry entries" -Color Cyan
		Remove-Item "HKLM:\Software\MATRIX42\AGENT" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "HKLM:\Software\MATRIX42\ApplicationUsageTracking" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "HKLM:\Software\MATRIX42\ComManager\CACHE\Items" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "HKLM:\Software\MATRIX42\EmpInv" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "HKLM:\Software\MATRIX42\Empirum Installer" -Force -Recurse -ErrorAction SilentlyContinue
		Remove-Item "HKLM:\Software\MATRIX42\RebootPackagesPending" -Force -Recurse -ErrorAction SilentlyContinue
	}

	####################################################################
	####### end functions #####
	####################################################################

	#### Main Program
	$svc = Test-BISFService -ServiceName "$Svc1" -ProductName "$product"
	IF ($svc -eq $true) {
		StopService
		DeleteAgentData
	}

	$svc = Test-BISFService -ServiceName "$Svc2" -ProductName "$product"
	IF ($svc -eq $true) {
		StopService
		DeleteAgentData
	}

	$svc = Test-BISFService -ServiceName "$Svc3" -ProductName "$product"
	IF ($svc -eq $true) {
		StopService
		DeleteAgentData
	}
}

End {
	Add-BISFFinishLine
}