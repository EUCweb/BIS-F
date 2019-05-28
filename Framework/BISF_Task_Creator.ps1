param(
	[switch] $silentInstall,
	[switch] $remove
)
<#
	For Powershell 3.0 compatibility.  A custom ScheduledTasks function...
	goal -> Recreate "Get-ScheduledTask for Powershell 3.0 that satisfies my bare necessities.
	cmdlet should retrieve a task with enough properties so the other two recreated functions:
	"Stop-ScheduledTask" and "Disable-ScheduledTask" can operate.  The goal of this is that these functions should be
	able to be completely removed when 2008R2 goes away so we can use the native calls with PS4+.  These are bare minimum implementations
	accepting only a single parameter "taskname"
	#>
function Get-ScheduledTask {
	[CmdletBinding()]
	param(
		[parameter(Position = 0)] [String[]] $TaskName = "*"
	)
	process {
		$TASK_ENUM_HIDDEN = 1
		$TASK_STATE = @{0 = "Unknown"; 1 = "Disabled"; 2 = "Queued"; 3 = "Ready"; 4 = "Running" }
		$ACTION_TYPE = @{0 = "Execute"; 5 = "COMhandler"; 6 = "Email"; 7 = "ShowMessage" }
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = new-object -comobject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			write-warning "$_"
			return
		}
		function get-task($taskFolder) {
			$tasks = $taskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$tasks | foreach-object { $_ }
			try {
				$taskFolders = $taskFolder.GetFolders(0)
				$taskFolders | foreach-object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
			}
		}
		$rootFolder = $TaskService.GetFolder("\")
		$taskList = get-task $rootFolder
		foreach ($task in $taskList) {
			if ($task.name -eq $TaskName) {
				return $task
			}
		}
	}
}

function Stop-ScheduledTask {
	[CmdletBinding()]
	param(
		[parameter(
			ValueFromPipeline = $True
		)] 
		$TaskName
	)
	process {
		if ($TaskName.GetType().Name -eq "__ComObject") { $TaskName = $TaskName.name } 
		$TASK_ENUM_HIDDEN = 1
		$TASK_STATE = @{0 = "Unknown"; 1 = "Disabled"; 2 = "Queued"; 3 = "Ready"; 4 = "Running" }
		$ACTION_TYPE = @{0 = "Execute"; 5 = "COMhandler"; 6 = "Email"; 7 = "ShowMessage" }
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = new-object -comobject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			write-warning "$_"
			return
		}
		function get-task($taskFolder) {
			$tasks = $taskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$tasks | foreach-object { $_ }
			try {
				$taskFolders = $taskFolder.GetFolders(0)
				$taskFolders | foreach-object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
			}
		}
		$rootFolder = $TaskService.GetFolder("\")
		$taskList = get-task $rootFolder
		foreach ($task in $taskList) {
			if ($task.name -eq $TaskName) {
				$task.stop(0)
				return $task
			}
		}
	}
}

function Disable-ScheduledTask {
	[CmdletBinding()]
	param(
		[parameter(
			ValueFromPipeline = $True
		)] 
		$TaskName
	)
	process {
		if ($TaskName -ne $null) { if ($TaskName.GetType().Name -eq "__ComObject") { $TaskName = $TaskName.name } }
			 
		$TASK_ENUM_HIDDEN = 1
		$TASK_STATE = @{0 = "Unknown"; 1 = "Disabled"; 2 = "Queued"; 3 = "Ready"; 4 = "Running" }
		$ACTION_TYPE = @{0 = "Execute"; 5 = "COMhandler"; 6 = "Email"; 7 = "ShowMessage" }
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = new-object -comobject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			write-warning "$_"
			return
		}
		function get-task($taskFolder) {
			$tasks = $taskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$tasks | foreach-object { $_ }
			try {
				$taskFolders = $taskFolder.GetFolders(0)
				$taskFolders | foreach-object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
			}
		}
		$rootFolder = $TaskService.GetFolder("\")
		$taskList = get-task $rootFolder
		foreach ($task in $taskList) {
			if ($task.name -eq $TaskName) {
				if ($task.Enabled -eq $true) { $task.Enabled = $false }
			}
		}
	}
}

# http://www.verboon.info/2013/12/powershell-creating-scheduled-tasks-with-powershell-version-3/
# https://msdn.microsoft.com/en-us/library/windows/desktop/aa382577(v=vs.85).aspx
# need to create via COMobject for PowerShell 3.0 compatibilty
function Create-ScheduledTask {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $True)][String] $TaskName,
		[Parameter(Mandatory = $True)][String] $TaskDescription,
		[Parameter(Mandatory = $True)][String] $TaskCommand,
		[String] $TaskScript,
		[String] $TaskArgument,
		[String] $TaskDomain,
		[Parameter(Mandatory = $True)][String] $TaskUserName,
		[String] $TaskPassword,
		[Switch] $Enabled
	)
	process {
		# Try to create the TaskService object on the local computer; throw an error on failure
		try {
			$TaskService = new-object -comobject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			write-warning "$_"
			return
		}
		


		# The name of the scheduled task
		# $TaskName = "BISF Preparation Startup Task"
		# The description of the task
		# $TaskDescription = "Runs the BISF Prepartion script"
		# The Task Action command
		# $TaskCommand = "c:\windows\system32\WindowsPowerShell\v1.0\powershell.exe"
		# The script to be executed
		# $TaskScript = "C:\Program Files (x86)\Base Image Script Framework (BIS-F)\PrepareBaseImage.cmd"
		# The Task Action command argument
		# $TaskArgument = "-NonInteractive -Executionpolicy unrestricted -file $TaskScript"

		# The time when the task starts, for demonstration purposes we run it 1 minute after we created the task
		#$TaskStartTime = [datetime]::Now.AddMinutes(5) 

		# connect to the local machine. 
		$rootFolder = $TaskService.GetFolder("\")

		$TaskDefinition = $TaskService.NewTask(0) 
		$TaskDefinition.RegistrationInfo.Description = "$TaskDescription"
		$TaskDefinition.RegistrationInfo.Author = "$env:username"
		#$TaskDefinition.Principle.RunLevel = $true
		if ($Enabled) {
			$TaskDefinition.Settings.Enabled = $Enabled
		}
		else {
			$TaskDefinition.Settings.Enabled = $false
		}
		$TaskDefinition.Settings.AllowDemandStart = $true
		$TaskDefinition.Settings.DisallowStartIfOnBatteries = $false
		$TaskDefinition.Settings.ExecutionTimeLimit = "PT0S"  # See Note Below

		$triggers = $TaskDefinition.Triggers
		$trigger = $triggers.Create(8) # Creates a "At System Startup" trigger
		$trigger.Delay = "PT5M" # Delay 5 mins after boot up
		#$trigger.StartBoundary = $TaskStartTime.ToString("yyyy-MM-dd'T'HH:mm:ss")
		$trigger.Enabled = $true

		$Action = $TaskDefinition.Actions.Create(0)
		$action.Path = "$TaskCommand"
		$action.Arguments = "$TaskArgument"

		$ServiceAccount = $false
		switch ($TaskUserName) {
			"NetworkService" { $ServiceAccount = $true; $TaskUserName = "NT Authority\Network Service" }
			"SYSTEM" { $ServiceAccount = $true; $TaskUserName = "NT Authority\SYSTEM" }
			"LocalService" { $ServiceAccount = $true; $TaskUserName = "NT Authority\Local Service" }
		}
		if ($ServiceAccount) {
			$rootFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, 6, $TaskUserName, $null, 5)
		}
		else {
			$rootFolder.RegisterTaskDefinition($TaskName, $TaskDefinition, 6, "$TaskDomain\$TaskUserName", $TaskPassword, 1)
		}

	}
}

function Delete-ScheduledTask {
	[CmdletBinding()]
	param(
		[parameter(
			ValueFromPipeline = $True
		)] 
		$TaskName
	)
	process {
		try {
			$TaskService = new-object -comobject "Schedule.Service"
		}
		catch [System.Management.Automation.PSArgumentException] {
			throw $_
		}
		try {
			$TaskService.Connect()
		}
		catch [System.Management.Automation.MethodInvocationException] {
			write-warning "$_"
			return
		}
		function get-task($taskFolder) {
			$tasks = $taskFolder.GetTasks($Hidden.IsPresent -as [Int])
			$tasks | foreach-object { $_ }
			try {
				$taskFolders = $taskFolder.GetFolders(0)
				$taskFolders | foreach-object { get-task $_ $TRUE }
			}
			catch [System.Management.Automation.MethodInvocationException] {
			}
		}
		$rootFolder = $TaskService.GetFolder("\")
		$rootFolder.DeleteTask($TaskName, 0)
	}
}

if ($silentInstall) {
	if (-not(Get-ScheduledTask -TaskName "BISF Preparation Startup")) { 
		Create-ScheduledTask -TaskName "BISF Preparation Startup" -TaskDescription "BISF Preparation Startup task to enable preparation to begin if the preparation process was interrupted." -TaskCommand "powershell.exe" -TaskArgument "-executionpolicy bypass -file `"C:\Program Files (x86)\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1`"" -TaskUserName SYSTEM
	}
	exit
}

if ($remove) {
	if (Get-ScheduledTask -TaskName "BISF Preparation Startup") { 
		Delete-ScheduledTask -TaskName "BISF Preparation Startup"
	}
	exit
}

#region GUICode
Add-Type -AssemblyName System.Windows.Forms

#region GUI Programming
$handler_OKButtonClick = {
	if ($NetworkServiceRadio.Checked) {
		if (-not(Get-ScheduledTask -TaskName "BISF Preparation Startup")) { 
			Create-ScheduledTask -TaskName "BISF Preparation Startup" -TaskDescription "BISF Preparation Startup task to enable preparation to begin if the preparation process was interrupted." -TaskCommand "powershell.exe" -TaskArgument "-executionPolicy ByPass -File `"C:\Program Files (x86)\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1`"" -TaskUserName SYSTEM
			$BISFTaskCreator.Close()
		}
		else {
			$wshell = New-Object -ComObject Wscript.Shell
			$wshell.Popup("The task already exists, unable to create the scheduled task.", 0, "Error", 0x0)
		}
	}
	else {
		try {
			Create-ScheduledTask -TaskName "BISF Preparation Startup" -TaskDescription "BISF Preparation Startup task to enable preparation to begin if the preparation process was interrupted." -TaskCommand "powershell.exe" -TaskArgument "-executionPolicy ByPass -File `"C:\Program Files (x86)\Base Image Script Framework (BIS-F)\Framework\PrepBISF_Start.ps1`"" -TaskUserName $UsernameTextBox.Text -TaskDomain $DomainTextBox.Text -TaskPassword $PasswordTextBox.Text
			$BISFTaskCreator.Close()
		}
		catch {
			$wshell = New-Object -ComObject Wscript.Shell
			$wshell.Popup("Unable to create the scheduled task.  Please check your credential information.", 0, "Error", 0x0)
		}
	}
}
	
$handler_NetworkServiceRadioButtonClick = {
	$DomainTextBox.Enabled = $false
	$UsernameTextBox.Enabled = $false
	$PasswordTextBox.Enabled = $false
}

$handler_radioServiceAccountButtonClick = {
	$DomainTextBox.Enabled = $true
	$UsernameTextBox.Enabled = $true
	$PasswordTextBox.Enabled = $true
}
#endregion

#region UI
$BISFTaskCreator = New-Object system.Windows.Forms.Form
$BISFTaskCreator.Text = "Create BISF Scheduled Task"
$BISFTaskCreator.TopMost = $true
$BISFTaskCreator.Width = 569
$BISFTaskCreator.Height = 320

$UserName = New-Object system.windows.Forms.Label
$UserName.Text = "Username:"
$UserName.AutoSize = $true
$UserName.Width = 25
$UserName.Height = 10
$UserName.location = new-object system.drawing.point(73, 138)
$UserName.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($UserName)

$UsernameTextBox = New-Object system.windows.Forms.TextBox
$UsernameTextBox.Width = 190
$UsernameTextBox.Height = 20
$UsernameTextBox.location = new-object system.drawing.point(154, 139)
$UsernameTextBox.Font = "Microsoft Sans Serif,10"
$UsernameTextBox.Enabled = $false
$BISFTaskCreator.controls.Add($UsernameTextBox)

$Password = New-Object system.windows.Forms.Label
$Password.Text = "Password:"
$Password.AutoSize = $true
$Password.Width = 25
$Password.Height = 10
$Password.location = new-object system.drawing.point(73, 164)
$Password.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($Password)

$PasswordTextBox = New-Object system.windows.Forms.MaskedTextBox
$PasswordTextBox.Width = 190
$PasswordTextBox.PasswordChar = "*"
$PasswordTextBox.Height = 20
$PasswordTextBox.Enabled = $false
$PasswordTextBox.location = new-object system.drawing.point(154, 163)
$PasswordTextBox.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($PasswordTextBox)

$Domain = New-Object system.windows.Forms.Label
$Domain.Text = "Domain:"
$Domain.AutoSize = $true
$Domain.Width = 25
$Domain.Height = 10
$Domain.location = new-object system.drawing.point(73, 188)
$Domain.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($Domain)

$DomainTextBox = New-Object system.windows.Forms.TextBox
$DomainTextBox.Width = 190
$DomainTextBox.Height = 20
$DomainTextBox.location = new-object system.drawing.point(154, 188)
$DomainTextBox.Enabled = $false
$DomainTextBox.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($DomainTextBox)

$radioServiceAccount = New-Object system.windows.Forms.RadioButton
$radioServiceAccount.Text = "Specify Account:"
$radioServiceAccount.AutoSize = $true
$radioServiceAccount.Width = 104
$radioServiceAccount.Height = 20
$radioServiceAccount.location = new-object system.drawing.point(73, 107)
$radioServiceAccount.Font = "Microsoft Sans Serif,10"
$radioServiceAccount.add_Click($handler_radioServiceAccountButtonClick)
$BISFTaskCreator.controls.Add($radioServiceAccount)

$NetworkServiceRadio = New-Object system.windows.Forms.RadioButton
$NetworkServiceRadio.Text = "Local System Account"
$NetworkServiceRadio.Checked = $true
$NetworkServiceRadio.AutoSize = $true
$NetworkServiceRadio.Width = 104
$NetworkServiceRadio.Height = 20
$NetworkServiceRadio.location = new-object system.drawing.point(73, 73)
$NetworkServiceRadio.Font = "Microsoft Sans Serif,10"
$NetworkServiceRadio.add_Click($handler_NetworkServiceRadioButtonClick)
$BISFTaskCreator.controls.Add($NetworkServiceRadio)

$label15 = New-Object system.windows.Forms.Label
$label15.Text = "Select whom you`'d like the startup task to run as:"
$label15.AutoSize = $true
$label15.Width = 25
$label15.Height = 10
$label15.location = new-object system.drawing.point(73, 39)
$label15.Font = "Microsoft Sans Serif,10"
$BISFTaskCreator.controls.Add($label15)

$button2 = New-Object system.windows.Forms.Button
$button2.Text = "Ok"
$button2.Width = 60
$button2.Height = 30
$button2.location = new-object system.drawing.point(300, 220)
$button2.Font = "Microsoft Sans Serif,10"
$button2.add_Click($handler_OKButtonClick)
$BISFTaskCreator.controls.Add($button2)
#endregion UI

[void]$BISFTaskCreator.ShowDialog()
$BISFTaskCreator.Dispose()

#endregion GUICode