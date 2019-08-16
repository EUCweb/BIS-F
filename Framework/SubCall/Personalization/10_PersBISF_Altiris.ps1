
<#
	.SYNOPSIS
		Personalize Altiris Agent for Image Managemement Software
	.DESCRIPTION
	  	If image is in shared mode the service will be started
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm
	  	Company: Login Consultants Germany GmbH

		History:
	  	14.10.2014 MS: function created
		29.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		16.08.2019 MS: Add-BISFStartLine

	.LINK
		https://eucweb.com
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$servicename = "Altiris Deployment Agent"
}

Process {
	Add-BISFStartLine -ScriptName $script_name
	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$servicename"
	IF ($svc) {
		Invoke-BISFService -ServiceName "$servicename" -Action Start -CheckDiskMode RW
	}
}

End {
	Add-BISFFinishLine
}