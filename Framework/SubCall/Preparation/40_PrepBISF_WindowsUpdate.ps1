<#
    .Synopsis
      Runs Windows Update
    .Description
      Runs Windows Update
      Tested on 2012R2, 2008 R2.  
      
      Configures Windows Update for WSUS
    .EXAMPLE
    .Inputs
    .Outputs
    .NOTES
      Author: Trentent Tye
      Editor: Trentent Tye
      Company: TheoryPC

      History
      Last Change: 2017.08.22 TT: Script created
	  Last Change:
	  .Link

    #>
Begin{
	$script_path = $MyInvocation.MyCommand.Path
	$script_dir = Split-Path -Parent $script_path
	$script_name = [System.IO.Path]::GetFileName($script_path)
}

Process {
###################
#### Functions ####
###################


    function Take-Permissions {
        # Developed for PowerShell v4.0
        # Required Admin privileges
        # Links:
        #   http://shrekpoint.blogspot.ru/2012/08/taking-ownership-of-dcom-registry.html
        #   http://www.remkoweijnen.nl/blog/2012/01/16/take-ownership-of-a-registry-key-in-powershell/
        #   https://powertoe.wordpress.com/2010/08/28/controlling-registry-acl-permissions-with-powershell/

        param($rootKey, $key, [System.Security.Principal.SecurityIdentifier]$sid = 'S-1-5-32-545', $recurse = $true)

        switch -regex ($rootKey) {
            'HKCU|HKEY_CURRENT_USER'    { $rootKey = 'CurrentUser' }
            'HKLM|HKEY_LOCAL_MACHINE'   { $rootKey = 'LocalMachine' }
            'HKCR|HKEY_CLASSES_ROOT'    { $rootKey = 'ClassesRoot' }
            'HKCC|HKEY_CURRENT_CONFIG'  { $rootKey = 'CurrentConfig' }
            'HKU|HKEY_USERS'            { $rootKey = 'Users' }
        }

        ### Step 1 - escalate current process's privilege
        # get SeTakeOwnership, SeBackup and SeRestore privileges before executes next lines, script needs Admin privilege
        $import = '[DllImport("ntdll.dll")] public static extern int RtlAdjustPrivilege(ulong a, bool b, bool c, ref bool d);'
        $ntdll = Add-Type -Member $import -Name NtDll -PassThru
        $privileges = @{ SeTakeOwnership = 9; SeBackup =  17; SeRestore = 18 }
        foreach ($i in $privileges.Values) {
            $null = $ntdll::RtlAdjustPrivilege($i, 1, 0, [ref]0)
        }

        function Take-KeyPermissions {
            param($rootKey, $key, $sid, $recurse, $recurseLevel = 0)

            ### Step 2 - get ownerships of key - it works only for current key
            $regKey = [Microsoft.Win32.Registry]::$rootKey.OpenSubKey($key, 'ReadWriteSubTree', 'TakeOwnership')
            $acl = New-Object System.Security.AccessControl.RegistrySecurity
            $acl.SetOwner($sid)
            $regKey.SetAccessControl($acl)

            ### Step 3 - enable inheritance of permissions (not ownership) for current key from parent
            $acl.SetAccessRuleProtection($false, $false)
            $regKey.SetAccessControl($acl)

            ### Step 4 - only for top-level key, change permissions for current key and propagate it for subkeys
            # to enable propagations for subkeys, it needs to execute Steps 2-3 for each subkey (Step 5)
            if ($recurseLevel -eq 0) {
                $regKey = $regKey.OpenSubKey('', 'ReadWriteSubTree', 'ChangePermissions')
                $rule = New-Object System.Security.AccessControl.RegistryAccessRule($sid, 'FullControl', 'ContainerInherit', 'None', 'Allow')
                $acl.ResetAccessRule($rule)
                $regKey.SetAccessControl($acl)
            }

            ### Step 5 - recursively repeat steps 2-5 for subkeys
            if ($recurse) {
                foreach($subKey in $regKey.OpenSubKey('').GetSubKeyNames()) {
                    Take-KeyPermissions $rootKey ($key+'\'+$subKey) $sid $recurse ($recurseLevel+1)
                }
            }
        }

        Take-KeyPermissions $rootKey $key $sid $recurse
    }



###################
#### Functions ####
###################

    Write-BISFLog -Msg "===========================$script_name===========================" -ShowConsole -Color DarkCyan -SubMsg
    Write-BISFLog -Msg "Windows Update" -ShowConsole -Color Cyan
#### Main Program

    if (($LIC_BISF_CLI_WUAgent -eq "NO") -or ($LIC_BISF_CLI_WUAgent -eq $null)) {
        Write-BISFLog -Msg "Windows Update detection and installation skipped by policy" -ShowConsole -Color DarkCyan -SubMsg
        continue
    }

    #Reset the SUS Client ID
    $WindowsUpdatePath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate"
    $SUSClientValues = @("AccountDomainSid","PingID","SusClientId")
    if (test-path $WindowsUpdatePath) {
        foreach ($value in $SUSClientValues) {
            if (Get-ItemProperty -Path $WindowsUpdatePath -Name $value -ErrorAction SilentlyContinue) {
                Write-BISFLog -Msg "Found value $value, removing..."
                Remove-ItemProperty -Path $WindowsUpdatePath -Name $value -Force
            }
        }
    }

    #Disable Component Based Services Logging -- this speeds up Windows Update and reduces IOPS as CBS seems to be fairly disk heavy
    if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing") {
        if (((Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name "EnableLog") -eq 1) -or `
            ((Get-ItemPropertyValue -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name "EnableDpxLog") -eq 1)) {
            Write-BISFLog -Msg "Disabling Component Based Services Logging." -ShowConsole -Color DarkCyan -SubMsg
            Take-Permissions -rootKey HKLM -key "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" "S-1-1-0" $false
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name "EnableLog" -Value 0 -Force
            Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" -Name "EnableDpxLog" -Value 0 -Force
            Take-Permissions -rootKey HKLM -key "SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing" "S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464" $false
            Stop-Service -Name TrustedInstaller -Force
            Write-BISFLog -Msg "Waiting for TrustedInstaller to restart..." -ShowConsole -Color DarkCyan -SubMsg
			#TrustedInstaller can hang for whatever reason, we'll wait 5 mins then terminate the process if it's stuck
            $i = 0
            do {
                sleep 30
                $i = $i + 1
            } until (((Get-Service -Name TrustedInstaller).Status -eq "Stopped") -or ($i -ge 10))
            if ($i -eq 10) { 
                Write-BISFLog -Msg "Forcibly stopping TrustedInstaller" -ShowConsole -Color DarkCyan -SubMsg
                Stop-Process -Name TrustedInstaller -Force 
            }
            $service = Get-Service -Name TrustedInstaller
            $service.Start()
            $service.WaitForStatus('Running')
        }
    }

    # Start or restart the service
    if ((Get-Service -Name wuauserv).Status -eq "Running") {
        $service = Get-Service -Name wuauserv
        $service.Stop()
        $service.WaitForStatus('Stopped')
        $service.Start()
        $service.WaitForStatus('Running')
    }

    if ((Get-Service -Name wuauserv).Status -ne "Running") {
        Set-Service -Name wuauserv -StartupType Automatic
        $service = Get-Service -Name wuauserv
        if ($service.Status -ne "Running") {
            $service.Start()
            $service.WaitForStatus('Running')
        }
    }

    $ErrorActionPreference = "SilentlyContinue"
    If ($Error) {
	    $Error.Clear()
    }
    $Today = Get-Date

    $UpdateCollection = New-Object -ComObject Microsoft.Update.UpdateColl
    $Searcher = New-Object -ComObject Microsoft.Update.Searcher
    $Session = New-Object -ComObject Microsoft.Update.Session
    
    Write-BISFLog -Msg "Initialising and Checking for Applicable Updates. Please wait ..." -ShowConsole -Color Yellow -SubMsg
    $searchTime = Measure-Command {$Result = $Searcher.Search("IsInstalled=0 and Type='Software' and IsHidden=0")}
    if ($searchTime.TotalSeconds -gt 60) {
        Write-BISFLog -Msg "Search took $($searchTime.Hours) Hours(s) $($searchTime.Minutes) minute(s) $($searchTime.Seconds) second(s)"  -ShowConsole -Color Yellow -SubMsg
    }
    else
    {
        Write-BISFLog -Msg "Search took $($searchTime.TotalSeconds) seconds"  -ShowConsole -Color Yellow -SubMsg
    }
    
    If ($Result.Updates.Count -EQ 0) {
	    Write-BISFLog -Msg "There are no applicable updates for this computer." -ShowConsole -Color DarkCyan -SubMsg
    }
    Else {
        #Set BISF to reboot instead of shutdown
	    Write-BISFLog -Msg "Windows Update Report For Computer: $Env:ComputerName" -ShowConsole -Color DarkCyan -SubMsg
	    Write-BISFLog -Msg  "Report Created On: $Today" -ShowConsole -Color DarkCyan -SubMsg
	    Write-BISFLog -Msg  "==============================================================================" -ShowConsole -Color DarkCyan -SubMsg
	    Write-BISFLog -Msg "Preparing List of Applicable Updates For This Computer ..." -ShowConsole -Color Yellow -SubMsg
	    Write-BISFLog -Msg  "List of Applicable Updates For This Computer" -ShowConsole -Color DarkCyan -SubMsg
	    Write-BISFLog -Msg  "------------------------------------------------" -ShowConsole -Color DarkCyan -SubMsg
	    For ($Counter = 0; $Counter -LT $Result.Updates.Count; $Counter++) {
		    $DisplayCount = $Counter + 1
    		    $Update = $Result.Updates.Item($Counter)
		    $UpdateTitle = $Update.Title
		    Write-BISFLog -Msg  "$DisplayCount -- $UpdateTitle" -ShowConsole -Color DarkCyan -SubMsg
	    }
	    $Counter = 0
	    $DisplayCount = 0
	    Write-BISFLog -Msg "Initialising Download of Applicable Updates ..." -ShowConsole -Color Yellow -SubMsg
	    Write-BISFLog -Msg  "------------------------------------------------" -ShowConsole -Color DarkCyan -SubMsg
	    $searchTime = Measure-Command {$Downloader = $Session.CreateUpdateDownloader()}
        Write-BISFLog -Msg "Download Initialization took $($searchTime.TotalSeconds)" -ShowConsole -Color Yellow -SubMsg
	    $UpdatesList = $Result.Updates
	    $searchTime = Measure-Command {
            For ($Counter = 0; $Counter -LT $Result.Updates.Count; $Counter++) {
		        $UpdateCollection.Add($UpdatesList.Item($Counter)) | Out-Null
		        $ShowThis = $UpdatesList.Item($Counter).Title
		        $DisplayCount = $Counter + 1
		        Write-BISFLog -Msg  "$DisplayCount -- Downloading Update $ShowThis " -ShowConsole -Color DarkCyan -SubMsg
		        $Downloader.Updates = $UpdateCollection
		        $Track = $Downloader.Download()
		        If (($Track.HResult -EQ 0) -AND ($Track.ResultCode -EQ 2)) {
			        Write-BISFLog -Msg  "Download Status: SUCCESS" -ShowConsole -Color Green -SubMsg
		        }
		        Else {
			        Write-BISFLog -Msg  "Download Status: FAILED With Error -- $Error()" -ShowConsole -Color Red -SubMsg
			        $Error.Clear()
		        }	
	        }
        }
        if ($searchTime.TotalSeconds -gt 60) {
            Write-BISFLog -Msg "Download took $($searchTime.Minutes) minute(s) $($searchTime.Seconds) second(s)" -ShowConsole -Color Yellow -SubMsg
        }
        else
        {
            Write-BISFLog -Msg "Download took $($searchTime.TotalSeconds) seconds" -ShowConsole -Color Yellow -SubMsg
        }

        
	    $Counter = 0
	    $DisplayCount = 0
	    Write-BISFLog -Msg "Starting Installation of Downloaded Updates ..." -ShowConsole -Color Yellow -SubMsg
	    Write-BISFLog -Msg  "Installation of Downloaded Updates" -ShowConsole -Color DarkCyan -SubMsg
	    Write-BISFLog -Msg  "------------------------------------------------" -ShowConsole -Color DarkCyan -SubMsg
        $searchTime = Measure-Command {	
            ForEach ($Update in $UpdateCollection) {
                $Track = $Null
                $DisplayCount = $DisplayCount + 1
                $WriteThis = $Update.Title
		        Write-BISFLog -Msg  "$DisplayCount -- Installing Update: $WriteThis" -ShowConsole -Color DarkCyan -SubMsg
                $Installer = New-Object -ComObject Microsoft.Update.Installer
                $UpdateToInstall = New-Object -ComObject Microsoft.Update.UpdateColl
                $UpdateToInstall.Add($Update) | out-null
		        $Installer.Updates = $UpdateToInstall
		        Try {
			        $Track = $Installer.Install()
			        Write-BISFLog -Msg  "Update Installation Status: SUCCESS" -ShowConsole -Color Green -SubMsg
		        }
		        Catch {
			        [System.Exception]
			        Write-BISFLog -Msg  "Update Installation Status: FAILED With Error -- $Error()" -ShowConsole -Color Red -SubMsg
			        $Error.Clear()
                }
		    }
        }
        if ($searchTime.TotalSeconds -gt 60) {
            Write-BISFLog -Msg "Install took $($searchTime.Hours) Hour(s) $($searchTime.Minutes) minute(s) $($searchTime.Seconds) second(s)" -ShowConsole -Color Yellow -SubMsg
        }
        else
        {
            Write-BISFLog -Msg "Install took $($searchTime.TotalSeconds) seconds" -ShowConsole -Color Yellow -SubMsg
        }
        if ($DisplayCount -ge 1) {
            Set-BISFPreparationState -RebootRequired
			Write-BISFLog "Updates were installed.  Rebooting..."
            start-process shutdown.exe -ArgumentList "-r -t 0 -f /d U:0:0 /c `"BISF: A pending reboot was detected.  The system is being rebooted.`"" -Wait
            pause
        }
    }
}

End {
	Add-BISFFinishLine
}