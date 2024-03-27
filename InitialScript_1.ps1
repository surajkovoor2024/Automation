<#
    .SYNOPSIS
        Copy items from central server and execute configuration scripts
    .DESCRIPTION
        1. This script will create PS_automation folder and sub folder inside that
        2. Add Central server into Trusted host for central server logging
        3. Copy item from central server
        4. execute configuration script
    .AUTHOR
       SHRITEJ MURMADKAR
    .VERSION
        1.0
#>
#Placing/Replacing Variable files inside Webserver folder
xcopy /I /Y /F \\10.199.0.26\CCSharing\ConfigurableFiles\* \\10.199.0.26\CCSharing\WebServer\

#Store working directory to $HOME
$Path = Split-Path $MyInvocation.MyCommand.Path
Remove-Variable -Force HOME
Set-Variable HOME $Path

#create directory for storing log files
new-item "C:\PS_automation" -itemtype directory
new-item "C:\PS_automation\PSLogs" -itemtype directory
new-item "C:\PS_automation\PSLogs\Logs" -itemtype directory
new-item "C:\PS_automation\PSLogs\Transcript" -itemtype directory
$Application_Name = "WEBSERVER"
$Configurable_FileName = "ConfigurableFiles"

Start-Transcript -Path "C:\PS_automation\PSLOGS\Transcript\InitialScript_Transcript.txt" -Append

$Logfile = "C:\PS_automation\PSLogs\Logs\WebMaster.log"
Function LogWrite {
    Param ([string]$logstring)
    $TimeStamp = Get-Date -Format MM/dd/yy-HH:mm:ss
    Add-content $Logfile -value "[$TimeStamp]:$logstring"
}

#To check WinRM service status
Write-Host("INFO: Checking status of WinRM service")
LogWrite("INFO: Checking status of WinRM service")
$WinRM = (Get-Service WinRM).status
if ($WinRM -ne "Running") {
    Write-Host("INFO: Starting WinRM service")
    LogWrite("INFO: Starting WinRM service")
    Start-Service WinRM
    Write-Host("SUCCESS: WinRM service started succesfully")
    LogWrite("SUCCESS: WinRM service started succesfully")
}
else {
    Write-Host "INFO: WinRM Service is running"
    LogWrite "INFO: WinRM Service is running"
}
$ITSettingsfilepath = "$Path\ITSettings.xml"
[XML]$ITSettingsfile = Get-Content -Path $ITSettingsfilepath -ErrorAction Stop
$Environment = $ITSettingsfile.variables.ENV
$Server_Name     = $ITSettingsfile.variables.$Environment.Server_name
$Folder_Name     = $ITSettingsfile.variables.$Environment.Folder_Name


#Calling ConfigFile.xml
$ConfigFilePath  = "$Path\ConfigFile.xml"
[XML]$ConfigFile = Get-Content -Path $ConfigFilePath -ErrorAction Stop
$Env = $ConfigFile.variables.ENV
$Central_Server = $ConfigFile.variables.$Env.centralserverIpaddress

#Adding server to trusted host
Set-Item WSMan:\localhost\Client\TrustedHosts -Value $Central_Server -Force 

Start-Sleep -Seconds 5
copy-item -path "\\$Server_Name\$Folder_Name\$Application_Name\*" -destination "C:\PS_automation\" -force -Verbose
copy-item -path "\\$Server_Name\$Folder_Name\$Configurable_FileName\*" -destination C:\PS_automation\ -force
timeout /t 15
# Checking if files get copied or not
$Path = "C:\PS_automation\*"
$count = Get-item -Path $Path 
$number = $count.Count
$number
if ($number -match "31") {
    Write-Host "SUCCESS : Files copied successfully"
    LogWrite ("SUCCESS : Files copied successfully")
}
else {
    Write-Host "ERROR : Failed coying files"
    LogWrite ("ERROR : Failed coying files")
    Write-Host "INFO : Retrying again to copy the files"
    LogWrite "INFO : Retrying again to copy the files"
    copy-item -path "\\$Server_Name\$Folder_Name\$Application_Name\*" -destination "C:\PS_automation\" -force -Verbose
    copy-item -path "\\$Server_Name\$Folder_Name\$Configurable_FileName\*" -destination C:\PS_automation\ -Force -Verbose
}

###--setting folder permission--###
$path = 'C:\PS_automation\'
$acl = Get-Acl -Path $path
$accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow')
$acl.SetAccessRule($accessrule)
Set-Acl -Path $path -AclObject $acl

#/* trigger Application script */
&"C:\PS_automation\AddIpScript_2.ps1"
&"C:\PS_automation\NtpSyncScript_3.ps1" 
#&"C:\PS_automation\SSMAgentInstallScript_4.ps1"
Set-ExecutionPolicy -Scope Process -Executionpolicy Bypass -Force
&"C:\PS_automation\MasterScript_5.ps1"
# End of script X