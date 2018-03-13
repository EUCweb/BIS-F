#
# Modulmanifest für das Modul "PSGet_BISF"
#
# Generiert von: Benjamin Ruoff / Matthias Schlimm / Mike Bijl / Florian Frank
#
# Generiert am: 26.11.2017
#

@{

# Die diesem Manifest zugeordnete Skript- oder Binärmoduldatei.
RootModule = 'BISF.psm1'

# Die Versionsnummer dieses Moduls
ModuleVersion = '6.1.0'

# Unterstützte PSEditions
# CompatiblePSEditions = @()

# ID zur eindeutigen Kennzeichnung dieses Moduls
GUID = '632e959f-fff8-40ee-96f4-d8fb3f122a9f'

# Autor dieses Moduls
Author = 'Benjamin Ruoff / Matthias Schlimm / Mike Bijl / Florian Frank'

# Company or vendor of this module
CompanyName = 'Login Consultants'

# Urheberrechtserklärung für dieses Modul
Copyright = '(c) 2016 Benjamin Ruoff / Matthias Schlimm / Mike Bijl / Florian Frank. All rights reserved.'

# Beschreibung der von diesem Modul bereitgestellten Funktionen
Description = 'This module contains functions and global variables needed for the Login Consultants Base Image Script Framework (BISF)
  Author: Benjamin Ruoff
  Date: 11.03.2014

  History
  Last Change: 11.03.2014 BR: Script created -function Get-Adaptername  
  Last Change: 13.03.2014 MS: add function Show-MessageBox (thx to BR)
  Last Change: 18.03.2014 BR: new functions added (Write-Log, Set-Logfile, Invoke-FolderScripts)
  Last Change: 21.03.2014 MS: last code change before release to web
  Last Change: 01.04.2014 MS: added central functions and global environment variables from 10_XX_LIB_Config.ps1
  Last Change: 15.05.2014 MS: add function get-version, to display this in the console window
  Last Change: 06.08.2014 MS: Add function ChangeNetworkProviderOrder
  Last Change: 11.08.2014 MS: change function set-Logfile to a single LogFile, like $LOG = "$regdata_log1\$LogFileName"
  Last Change: 11.08.2014 MS: add $Global:hkcu_software= "HKCU:\SOFTWARE"
  Last Change: 12.08.2014 MS: add function CheckPVSSoftware to check BNDevice.exe
  Last Change: 12.08.2014 MS: move Set-Logfile to 10_XX_LIB_Config.ps1 / remove CheckLogDir
  Last Change: 14.08.2014 MS: add Type for Info, Warning, Error for function Write-Log, exit script if Type = Error
  Last Change: 15.08.2014 MS: function Get-Adaptername: add check AdapterIndex IF (!($AdapterIndex -eq $null))...
  Last Change: 15.08.2014 MS: Change Title to "Base Image Script Framework (BIS-F)"
  Last Change: 15.08.2014 MS: add function get-OSinfo
  Last Change: 15.08.2014 MS: add function CheckXDSoftware
  Last Change: 19.08.2014 MS: line 43: reduce PVSDiskDrive to 2 strings if variable exists -> $env:PVSWriteCacheDisk.Substring(0,2)
  Last Change: 19.08.2014 MS: move function progressbar from 98_XX_PrepPVS_BUILD_vDisk.ps1 to this script 
  Last Change: 19.08.2014 MS: add function get-LogContent
  Last Change: 31.10.2014 MB: Renamed functions: Progressbar -> Show-progressbar / CheckXDSoftware -> Test-XDSoftware / CheckPVSSoftware -> Test-PVSSoftware / ChangeNetworkProviderOrder -> Set-NetworkProviderOrder / CheckPSVersion -> Get-PSVersion 
  Last Change: 31.10.2014 MB: Renamed variables: hklm_sw -> hklm_software / hklm_sys -> hklm_system / hkcu_sw -> hkcu_software / CTX_PVS_SCRIPTS -> CTX_BISF_SCRIPTS / $LogFolderName = "BISLogs" -> $LogFolderName = "BISFLogs" / hklm_software_LIC_CTX_PVS_SCRIPTS -> hklm_software_LIC_CTX_BISF_SCRIPTS
  Last Change: 06.02.2015 MS: add function Get-PendingReboot to BISF.psd1
  Last Change: 24.04.2015 MS: change powershell minimum version to 3.0, because with version 2.0 the psd1 would not loaded corretly
  Last Change: 21.08.2015 MS: Change Request 77 - remove all XX,XA,XD from al files and Scripts
'

# Die für dieses Modul mindestens erforderliche Version des Windows PowerShell-Moduls
PowerShellVersion = '2.0'

# Der Name des für dieses Modul erforderlichen Windows PowerShell-Hosts
# PowerShellHostName = ''

# Die für dieses Modul mindestens erforderliche Version des Windows PowerShell-Hosts
# PowerShellHostVersion = ''

# Die für dieses Modul mindestens erforderliche Microsoft .NET Framework-Version. Diese erforderliche Komponente ist nur für die PowerShell Desktop-Edition gültig.
# DotNetFrameworkVersion = ''

# Die für dieses Modul mindestens erforderliche Version der CLR (Common Language Runtime). Diese erforderliche Komponente ist nur für die PowerShell Desktop-Edition gültig.
# CLRVersion = ''

# Die für dieses Modul erforderliche Prozessorarchitektur ("Keine", "X86", "Amd64").
# ProcessorArchitecture = ''

# Die Module, die vor dem Importieren dieses Moduls in die globale Umgebung geladen werden müssen
# RequiredModules = @()

# Die Assemblys, die vor dem Importieren dieses Moduls geladen werden müssen
# RequiredAssemblies = @()

# Die Skriptdateien (PS1-Dateien), die vor dem Importieren dieses Moduls in der Umgebung des Aufrufers ausgeführt werden.
# ScriptsToProcess = @()

# Die Typdateien (.ps1xml), die beim Importieren dieses Moduls geladen werden sollen
# TypesToProcess = @()

# Die Formatdateien (.ps1xml), die beim Importieren dieses Moduls geladen werden sollen
# FormatsToProcess = @()

# Die Module, die als geschachtelte Module des in "RootModule/ModuleToProcess" angegebenen Moduls importiert werden sollen.
# NestedModules = @()

# Aus diesem Modul zu exportierende Funktionen. Um optimale Leistung zu erzielen, verwenden Sie keine Platzhalter und löschen den Eintrag nicht. Verwenden Sie ein leeres Array, wenn keine zu exportierenden Funktionen vorhanden sind.
FunctionsToExport = '*'

# Aus diesem Modul zu exportierende Cmdlets. Um optimale Leistung zu erzielen, verwenden Sie keine Platzhalter und löschen den Eintrag nicht. Verwenden Sie ein leeres Array, wenn keine zu exportierenden Cmdlets vorhanden sind.
CmdletsToExport = '@()'

# Die aus diesem Modul zu exportierenden Variablen
# VariablesToExport = @()

# Aus diesem Modul zu exportierende Aliase. Um optimale Leistung zu erzielen, verwenden Sie keine Platzhalter und löschen den Eintrag nicht. Verwenden Sie ein leeres Array, wenn keine zu exportierenden Aliase vorhanden sind.
AliasesToExport = @()

# Aus diesem Modul zu exportierende DSC-Ressourcen
# DscResourcesToExport = @()

# Liste aller Module in diesem Modulpaket
# ModuleList = @()

# Liste aller Dateien in diesem Modulpaket
# FileList = @()

# Die privaten Daten, die an das in "RootModule/ModuleToProcess" angegebene Modul übergeben werden sollen. Diese können auch eine PSData-Hashtabelle mit zusätzlichen von PowerShell verwendeten Modulmetadaten enthalten.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        # Tags = @()

        # A URL to the license for this module.
        # LicenseUri = ''

        # A URL to the main website for this project.
        # ProjectUri = ''

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        # ReleaseNotes = ''

        # External dependent modules of this module
        # ExternalModuleDependencies = ''

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo-URI dieses Moduls
HelpInfoURI = 'http://www.loginconsultants.com/de/ueber-uns/news/tech-update/item/base-image-script-framework-bis-f'

# Standardpräfix für Befehle, die aus diesem Modul exportiert werden. Das Standardpräfix kann mit "Import-Module -Prefix" überschrieben werden.
DefaultCommandPrefix = 'BISF'

}

