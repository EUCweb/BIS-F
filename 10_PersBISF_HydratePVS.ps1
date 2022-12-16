<#
    .Synopsis
      Enables pre-caching of files for PVS systems
    .Description
      Enables pre-caching of files for PVS systems
      Tested on Server 2019
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES

      History
		  2019.08.16 TT: Script created
		  18.08.2019 MS: integrate into BIS-F
		  03.02.2020 MS: HF 201 - Hydration not startig if configured
		  23.05.2020 MS: HF 231 - Skipping file precache if vDisk is in private Mode
	  .Link
		  https://github.com/EUCweb/BIS-F/issues/129

	  .Link
		  https://eucweb.com
    #>

Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$PathsToCache = $LIC_BISF_CLI_PVSHydration_Paths
	$ExtensionsToCache = $LIC_BISF_CLI_PVSHydration_Extensions
}

Process {


	$WriteCacheType = Get-BISFPVSWriteCacheType
	if ($WriteCacheType -eq 0) {   # private Mode
		Write-BISFLog -Msg "PVS vDisk is in Private Mode. Skipping file precache."  -ShowConsole -Color Yellow
		Return
	}

	if (-not(Test-BISFPVSSoftware)) {
		Write-BISFLog -Msg "PVS Software not found. Skipping file precache."  -ShowConsole -Color Yellow
		Return
	}
	if (-not($LIC_BISF_CLI_PVSHydration -eq "YES")) {
		Write-BISFLog -Msg "File precache configuration not found. Skipping."  -ShowConsole -Color Yellow
		Return
	}

    
    # Multithreaded PVS Re-Hydrate, use all but one CPU for thread count
    
    Write-BISFLog -Msg "PVS Re-Hydration Process Started"
    $maxConcurrentJobs = $(Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
    Write-BISFLog -Msg "Using $maxConcurrentJobs threads"
    foreach($RootPath in ($PathsToCache.split("|"))) { $sub_folder_list = $sub_folder_list + (gci $RootPath).FullName }
    Write-BISFLog -Msg "$($sub_folder_list.Count) folders found to hydrate"
    foreach($sub_folder_path in $sub_folder_list){
        $running_jobs = @(Get-Job | Where-Object { $_.State -eq 'Running' })
        if ($running_jobs.Count -ge $maxConcurrentJobs) {
            Write-BISFLog -Msg "Max Threads Reached, waiting for job to finish before starting next one"
            $running_jobs | Wait-Job -Any | Out-Null
        }
        $running_jobs = @(Get-Job | Where-Object { $_.State -eq 'Running' })
        Write-BISFLog -Msg "Hydrating: $sub_folder_path"
        Start-Job -ScriptBlock {
            foreach ($File in (Get-ChildItem -Path $using:sub_folder_path -Recurse -File -Include $($using:ExtensionsToCache).Split(","))){
                $hydratedFile = [System.IO.File]::ReadAllBytes($File)
            }
        }
    }    
}

End {
	Add-BISFFinishLine
}
