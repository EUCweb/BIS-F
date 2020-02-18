<#
	.SYNOPSIS
		Prepare Altiris Agent for Image Management
	.DESCRIPTION
	  	Reconfigure the Altiris Deployment Agent. If Service is installed, it would be stopped and set to manual startup
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company:  EUCWeb.com

		History:
	  	14.10.2014 MS: function created
		02.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		09.11.2016 MS: add preparation for Altiris Inventory Agent
		12.07.2017 FF: Create $RegKeys as an array (was a hashtable before)
		18.02.2020 JK: Fixed Log output spelling

	.LINK
		https://eucweb.com
#>


Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$servicename1 = "Altiris Deployment Agent"

	$servicename2 = "AeXNSClient"
	$productname2 = "Altiris Inventory Agent"
	$RegKeys = @("HKLM:\SOFTWARE\Altiris\Altiris Agent", "HKLM:\SOFTWARE\Altiris\eXpress", "HKLM:\SOFTWARE\Altiris\eXpress\NS Client")

}

Process {

	$svc1 = Test-BISFService -ServiceName "$servicename1" -ProductName "$servicename1"
	IF ($svc1 -eq $true) {
		Invoke-BISFService -ServiceName "$servicename1" -Action Stop -StartType manual
	}


	$svc2 = Test-BISFService -ServiceName "$servicename2" -ProductName "$productname2"
	IF ($svc2 -eq $true) {
		Invoke-BISFService -ServiceName "$servicename2" -Action Stop -StartType manual
		foreach ($RegKey in $RegKeys) {
			Try {
				Remove-ItemProperty -Path $Regkey -Name "MachineGUID" -ErrorAction Stop
				Write-BISFLog -Msg "$($RegKey) Successfully deleted" -showconsole -Color DarkCyan -SubMsg
			}
			catch [System.Security.SecurityException] {
				Write-BISFLog -Msg "Permission Denied for $($RegKey)" -ForegroundColor Red -SubMsg
			}
		}
	}

}

End {
	Add-BISFFinishLine
}