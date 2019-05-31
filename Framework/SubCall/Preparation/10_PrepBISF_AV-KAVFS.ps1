<#
.SYNOPSIS
  Prepare Kaspersky Antivirus for Image Management

.DESCRIPTION
  delete Computer specified entries

.PARAMETER <Parameter_Name>
.INPUTS 
.OUTPUTS

.NOTES
  Version:         	1.0
  Author:           Matthias Schlimm
  Company:			Login Consultants Germany GmbH				
  Creation Date:  	15.12.2015
  Purpose/Change: 	15.12.2015 MS: Initial script development
  Purpose/Change:   23.03.2016 MS: add -Recurse to search for files in subfolders
  Purpose/Change:   12.03.2017 MS: BugFix 112: wrong path to get from executable
  Purpose/Change:
  
.EXAMPLE
  
#>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$servicename = "KAVFS"
	$Product = "Kaspersky AntiVirus"
	$SearchFolder = "C:\Program Files (x86)\Kaspersky Lab"
	$KAVexe1 = "klmover.exe"
	$KAVarg1_1 = "-dupfix"
	$KAVexe2 = "kavshell.exe"
	$KAVarg2_1 ="update /KL"
	$KAVarg2_2 ="task update-bases /start"
	$KAVarg2_3 ="task update-app /start"
	$KAVPath1 = $null
	$KAVPath2 = $null
	
	
}

Process {
	####################################################################
	####### functions #####
	####################################################################

	

	####### end functions #####
	

	#### Main Program
	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		$KAVPath1 = Get-ChildItem -Path "$SearchFolder" -filter "$KAVexe1" -Recurse -ErrorAction SilentlyContinue | % {$_.FullName}
		IF ($KAVPath1 -ne $null)
		{ 
		    $KAVPathname1 = $KAVPath1
			Write-BISFLog -Msg "$Product optimize now for Imaging" -SubMsg -ShowConsole
			
			Write-BISFLog -Msg "Running $KAVPathname1 $KAVarg1_1"
			Start-Process -FilePath "$KAVPathname1" -ArgumentList "$KAVarg1_1" -Wait | Out-Null
		} ELSE {
			Write-BISFLog -Msg "$KAVexe1 couldn't found in any folders above $SearchFolder, correct Imaging can't be guaranteed ! " -type W -SubMsg
		}
		
		$KAVPath2 = Get-ChildItem -Path "$SearchFolder" -filter "$KAVexe2" -Recurse -ErrorAction SilentlyContinue | % {$_.FullName}
		IF ($KAVPath2 -ne $null)
		{ 
		    $KAVPathname2 = $KAVPath2
			Write-BISFLog -Msg "$Product optimize now for Imaging" -SubMsg -ShowConsole
			
			Write-BISFLog -Msg "Running $KAVPathname2 $KAVarg2_1"
			Start-Process -FilePath "$KAVPathname2" -ArgumentList "$KAVarg2_1" -Wait | Out-Null
			
			Write-BISFLog -Msg "Running $KAVPathname2 $KAVarg2_2"
			Start-Process -FilePath "$KAVPathname2" -ArgumentList "$KAVarg2_2" -Wait | Out-Null
			
			Write-BISFLog -Msg "Running $KAVPathname2 $KAVarg2_3"
			Start-Process -FilePath "$KAVPathname2" -ArgumentList "$KAVarg2_3" -Wait | Out-Null
		} ELSE {
			Write-BISFLog -Msg "$KAVexe2 couldn't found in any folders above $SearchFolder, correct Imaging can't be guaranteed ! " -type W -SubMsg
		}	
	}
}

End {
	Add-BISFFinishLine
}

