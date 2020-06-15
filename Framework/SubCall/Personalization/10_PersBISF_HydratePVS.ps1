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


	function FileToCache ($File) {
		#Write-BISFLog -Msg "Caching File : $File" -ShowConsole -Color Cyan
		$hydratedFile = [System.IO.File]::ReadAllBytes($File)
	}

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

	foreach ($Path in ($PathsToCache.split("|"))) {
		Write-BISFLog -Msg "Caching files with extensions $ExtensionsToCache in $Path" -ShowConsole -Color Cyan
		foreach ($File in (Get-ChildItem -Path $Path -Recurse -File -Include $ExtensionsToCache.Split(","))) {
			FileToCache -File $File
		}
	}
}

End {
	Add-BISFFinishLine
}
