<#
    .Synopsis
     Prepare Frontrange Agent for Imaging Management
    .Description
      lookup for the Frontrange DSM Core Service and prepare the Agent for Imaging
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Matthias Schlimm
      Editor: Matthias Schhlimm
      Company: Login Consultants Germany GmbH

      History
      Last Change: 17.02.2015 MS: Script created
      Last Change: 30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
      Last Change: 04.11.2015 MS: syntax error -> replace WriteBISF-Log with Write-BISFLog
	  Last Change: 10.12.2015 MS: Change Productname from "Frantrange DSM " to "Heat DSM"	
	  .Link
    #>

Begin{
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "Heat DSM"
	$product_path = "$ProgramFilesx86\NetInst"
	$PrepApp = "niprep.exe"
	$servicename = "esiCore"
}

Process {
	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		Write-BISFLog -Msg "Preperaring $Product for Imaging" -ShowConsole -Color DarkCyan -SubMsg
		IF (Test-Path ("$product_path\$PrepApp") -PathType Leaf )
		{
			Write-BISFLog -Msg "Preparing $Product for Imaging "
			& Start-Process -FilePath "$product_path\$PrepApp" -ArgumentList "/r" -Wait
		} ELSE {
			Write-BISFLog -Msg "$product_path\$PrepApp not exists. Image Preperation could not be performed !!!" -Type E -SubMsg
		}

	}
}


End {
	Add-BISFFinishLine
}
