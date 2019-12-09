<#
<<<<<<< HEAD
	.SYNOPSIS
		Prepare Microsoft AppV for Image Managemement
	.DESCRIPTION
	  	Reconfigure the Microsoft AppV
	.EXAMPLE
	.NOTES
		Author: Matthias Schlimm

		History:
		21.08,2015 MS: function created
		30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		03.03.2016 MS: Issue 113 - AppVClient Cache did not resolve to correct service status, thx to @valentinop
		10.01.2017 MS: add CLI command or MessageBox to delete PreCached App-V Packages
		24.11.2017 MS: add SubMSg do Write-BISFLog -Msg "The App-V PackageInstallationRoot $PckInstRoot Folder not exist, nothing to clean up." -Type W -SubMsg
		14.08.2019 MS: FRQ 3 - Remove Messagebox and using default setting if GPO is not configured

	.LINK
		https://eucweb.com
=======
    .SYNOPSIS
        Prepare Microsoft AppV for Image Managemement
	.Description
      	reconfigure the Microsoft AppV 
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
		Author: Matthias Schlimm
      	Company: Login Consultants Germany GmbH
		
		History
      	Last Change: 21.08,2015 MS: function created
		Last Change: 30.09.2015 MS: rewritten script with standard .SYNOPSIS, use central BISF function to configure service
		Last Change: 03.03.2016 MS: Issue 113 - AppVClient Cache did not resolve to correct service status, thx to @valentinop
		Last Change: 10.01.2017 MS: add CLI command or MessageBox to delete PreCached App-V Packages
		Last Change: 24.11.2017 MS: add SubMSg do Write-BISFLog -Msg "The App-V PackageInstallationRoot $PckInstRoot Folder not exist, nothing to clean up." -Type W -SubMsg 
		Last Change:
	.Link
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
#>


Begin {
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
	$Product = "Microsoft App-V Client"
	$servicename = "AppVClient"
}

Process {
<<<<<<< HEAD

	function PrepareAgent {
=======
	function PrepareAgent 
	{
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
		$AppvsvcStatus = Get-Service -Name $servicename
		If ($AppvsvcStatus.Status -ne "Running")
		{
			Write-BISFLog "The client service is not running.The Script cannot clean up package files." -Type W -SubMsg
		} ELSE {
			$HKLM_Path = "HKLM:\Software\Microsoft\AppV\Client"
			$Installpath = Get-ItemProperty -path "$HKLM_Path" | % {$_.InstallPath}
			$ModuleFile = "AppvClient.psd1"
			$ModulePath  = "$Installpath\AppvClient\$ModuleFile"
			$PckInstRoot = Get-ItemProperty -path "$HKLM_Path\Streaming" | % {$_.PackageInstallationRoot}
			$PckInstRoot = [Environment]::ExpandEnvironmentVariables($PckInstRoot)
<<<<<<< HEAD
			if (!$PckInstRoot) {
				Write-BISFLog -Msg "PackageInstallationRoot is required for removing packages" -Type E -SubMsg
			}
			IF (Test-Path $PckInstRoot) {

				Write-BISFLog -Msg "Check GPO Configuration" -SubMsg -Color DarkCyan
				$varCLI = Get-Variable -Name LIC_BISF_CLI_AR -ValueOnly
				IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) {
					Write-BISFLog -Msg "GPO Valuedata: $varCLI"
				}
				ELSE {
					Write-BISFLog -Msg "GPO not configured.. using default setting""
					$AppVRemoval = "NO
=======
			if (!$PckInstRoot)
			{
				Write-BISFLog -Msg "PackageInstallationRoot is required for removing packages" -Type E -SubMsg       
			}
			IF (Test-Path $PckInstRoot)
			{
				
				Write-BISFLog -Msg "Check Silentswitch..."
				$varCLI = Get-Variable -Name LIC_BISF_CLI_AR -ValueOnly
				IF (($varCLI -eq "YES") -or ($varCLI -eq "NO")) 
				{
					Write-BISFLog -Msg "Silentswitch would be set to $varCLI" 
				} ELSE {
           			Write-BISFLog -Msg "Silentswitch not defined, show MessageBox" 
					$AppVRemoval = Show-BISFMessageBox -Msg "Would you like to remove the PreCached App-V Packages on the Base Image ? " -Title "Microsoft App-V" -YesNo -Question
        			Write-BISFLog -Msg "$AppVRemoval would be choosen [YES = Remove PreCached App-V Packages] [NO = Do not remove Remove PreCached Ap-pV Packages]"
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
				}
				if (($AppVRemoval -eq "YES" ) -or ($varCLI -eq "YES"))
				{
					$packageFiles = Get-ChildItem ([System.Environment]::ExpandEnvironmentVariables($PckInstRoot));
<<<<<<< HEAD
					if (!$packageFiles -or $packageFiles.Count -eq 0) {
						Write-BISFLog -Msg "No package files found, nothing to clean up." -Type W -SubMsg
					}
					ELSE {
						Write-BISFLog -Msg "Removing App-V packages" -ShowConsole -Color DarkGreen -SubMsg
=======
					if (!$packageFiles -or $packageFiles.Count -eq 0)
					{
							Write-BISFLog -Msg "No package files found, nothing to clean up." -Type W -SubMsg
					} ELSE {
						Write-BISFLog -Msg "Removing App-V packages" -ShowConsole -Color DarkGreen -SubMsg 
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
						$error.clear();
						# load the client
						Import-Module $ModulePath;
						# shutdown all active Connection Groups
						Write-BISFLog -Msg "Stopping all connection groups.";
						Get-AppvClientConnectionGroup -all | Stop-AppvClientConnectionGroup -Global;

						# shutdown all active Connection Groups
						Write-BISFLog -Msg "Stopping all connection groups.";
						Get-AppvClientConnectionGroup -all | Stop-AppvClientConnectionGroup -Global;

						# poll while there are still active connection groups
						$connectionGroups = Get-AppvClientConnectionGroup -all
						$connectionGroupsInUse = $FALSE;
						do
						{
							$connectionGroupsInUse = $FALSE;
							ForEach ($connectionGroup in $connectionGroups)
							{
								if ($connectionGroup.InUse -eq $TRUE)
								{
									$connectionGroupsInUse = $TRUE;
									Write-BISFLog -Msg "Stopping connection group " $connectionGroup.Name;
									Stop-AppvClientConnectionGroup $connectionGroup -Global;
<<<<<<< HEAD

=======
                                
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
									# allow 1 second for the VE to tear down before we continue polling
									sleep 1;
								}
							}
						} while ($connectionGroupsInUse);

						# shutdown all active Packages
						Write-BISFLog -Msg "Stopping all packages.";
						Get-AppvClientPackage -all | Stop-AppvClientPackage -Global;

						# poll while there are still active packages
						$packages = Get-AppvClientPackage -all;
						$packagesInUse = $FALSE;
						do
						{
							$packagesInUse = $FALSE;
							ForEach ($package in $packages)
							{
								if ($package.InUse -eq $TRUE)
								{
									$packagesInUse = $TRUE;
									Write-BISFLog -Msg "Stopping package " $package.Name;
									Stop-AppvClientPackage $package -Global;

								   # allow 1 second for the VE to tear down before we continue polling
									sleep 1;
								}
							}
						} while ($packagesInUse);
<<<<<<< HEAD

=======
    
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
						Write-BISFLog -Msg "Removing all App-V Connection Groups";
						ForEach ($connectionGroup in Get-AppvClientConnectionGroup -all) 
						{
							Remove-AppvClientConnectionGroup $connectionGroup;
						}

						Write-BISFLog -Msg "Removing all App-V Packages";
						ForEach ($package in Get-AppvClientPackage -all)
						{
							Remove-AppvClientPackage $package;
						}
<<<<<<< HEAD
					}
				}
				ELSE {
=======
					}	
				} ELSE {
>>>>>>> 0f9eb41cc3803821f5779a0f8d265524fea7ec35
					Write-BISFLog -Msg "Skip removing the preCached App-V Packages"

				}
				$Error.Clear();
			} ELSE {
				Write-BISFLog -Msg "The App-V PackageInstallationRoot $PckInstRoot Folder not exist, nothing to clean up." -Type W -SubMsg
			}
		}
	}

	#### Main Program

	$svc = Test-BISFService -ServiceName "$servicename" -ProductName "$product"
	IF ($svc -eq $true)
	{
		PrepareAgent
	}
}


End {
	Add-BISFFinishLine
}