# Author: Shyam Vanga
# Date: 11/12/2021
# This will complete the end to end Tableau Application maintenance including reading the configurations and applying the same
# This file will be called with Task scheduler and will complete the necessary application maintenance activities

# Variable Declaration
$hostName = [System.Net.Dns]::GetHostName()
if ($hostName -eq 'CHQS-b52GygrXic') {
#if ($hostName -eq 'tabcore-ch2-a4p') {
	$tabservname = "QA"
}
elseif ($hostName -eq 'tabngen-ch2-a4p') {
	$tabservname = "PROD"
}
elseif ($hostName -eq 'tabgnco-ch2-a3s') {
	$tabservname = "DR"
}

#$logPath= "C:\scripts\powerShell\"
$date = Get-Date
$today = $date. ToString ("yyyy-MM-dd")
$logFileName = "Tableau-"+$tabservname+"-"$today+".log"
$tableau-maintenance-LogFile = New-Item -Path 'C:\scripts\powerShell\' -Name $logFileName -ItemType 'file' -Force

# This starts writing the log file
Start-Transcript -Path $tableau-maintenance-LogFile

Write-Host "#### Maintenance preparation work started on $tabservname####"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### Defining the Variables ###"

#Email Varialbes
$fromaddress = "TableauAlerts@cms.com"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the From value to: $fromaddress"

#$toaddress = "Tableau Admin@cms.com"
$toaddress = "svanga@cms.com"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the To value to: $toaddress"

#$attachment = get-item "D:\scriptsTableauRestore.log"
$smtpserver = "cms.com"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the SMTP Server value to: $smtpserver"

$tsmadmin = tableau
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Executing TSM as user: $tsmadmin"

$tsmpassword = password
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Using $tsmadmin password: ***SECRET***"

$archivedays = 7
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the log archive retention period to $archivedays days"

$backupdays = 7
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the backup retention period to: $backupdays days"

$mydate = (Get-Date).toString("yyyyMMdd")
$ziplogFileName = "tableau-"+$tabservname+"-Ziplogs-"+$mydate
Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Setting the Ziplog File name to: $ziplogFileName"

#$sourcePath = $log_archive_path+"/"+ŞziplogFileName+".zip"
$external_logarchive_path = "\vnx01-as-2\tabapp_dump\Backups\"+$tabservname+" Ziplogs"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the external_logarchive_path to: $external_logarchive_path"

$backup_filename = "tableau-"+$tabservname+"-backup"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the backup_filename to: $backup_filename"

$external_backup_path = "D:\Backup"
Write-Host (Get-Date).toString("yyyy/MM/dd HHmm:ss") "Setting the external_backup_path to: $external_backup_path"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### End of Defining the Variable ###"
Write-Host "----------------------------------------------------------------------------"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### Start of tsm maintenance LOGS SECTION ###"

#Get the path of the log_archive folder
Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Getting the location of the default log archive directory"
$log_archive_path = tsm configuration get -k basefilepath.log_archive -u $tsmadmin -p $tsmpassword
Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Log archive path is: $log_archive_path"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Archiving Tableau Server log files"
tsm maintenance ziplogs -all -d -f $ziplogFileName -u $tsmadmin -p $tsmpassword

if ($?) {
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance ziplogs got created"
	
	Write-Host "Source Path -- > $log_archive_path+"/"+"*.zip""
	Write-Host "Destination Path -- > $external_logarchive_path"

	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Moving the ziplog file to Y drive"
	Move-item $log_archive_path+"/"+"*.zip" $external_logarchive_path -Force
	
	if ($?){
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Zip file got moved to external path $external_logarchive_path successfully"
		
		#Check for previous log archives and remove files older than N days
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Cleaning out archive files older than $archivedays days"
		$limit = (Get-Date).AddDays(-$archivedays)
		#$path = "C:\path\to\your\folder" 
		Get-ChildItem -Path $external_logarchive_path -File -Recurse | Where-Object {$_.LastWriteTime -lt $limit} | Remove-Item -Force
		
		if($?){
			Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "$archivedays days log archives got deleted from external path $external_logarchive_path successfully"
			$Subject = " $tabservname tsm maintenance ziplogs got completed successfully - $today"
			$Body = " $tabservname tsm maintenance ziplogs got completed successfully along with moving the ziplog to $external_logarchive_path path and cleaning out archive files older than $archivedays days  - $today"
			#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
		}
		else{
			Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Removing $archivedays days log archives got failed at external path $external_logarchive_path"
			$Subject = " *** Alert *** $tabservname tsm maintenance ziplogs got failed - $today"
			$Body = " $tabservname tsm maintenance ziplogs got completed successfully along with moving the ziplog to $external_logarchive_path path, but cleaning out archive files older than $archivedays days got failed - $today"
			#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
		}
	}
	else{
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Moving Zip file to external path $external_logarchive_path got failed"
		$Subject = " *** Alert *** $tabservname tsm maintenance ziplogs got failed - $today"
		$Body = " $tabservname tsm maintenance ziplogs got completed successfully, but moving Zip file to external path $external_logarchive_path got failed - $today"
		#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
	}
}
else{
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance ziplogs got failed"
	$Subject = " *** Alert *** $tabservname tsm maintenance ziplogs got failed - $today"
	#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Subject -SmtpServer $smtpserver;
	Write-Error "tsm maintenance ziplogs got failed" -ErrorAction Stop
}

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### End of tsm maintenance LOGS SECTION ###"
Write-Host "----------------------------------------------------------------------------"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### Start of tsm maintenance CLEANUP SECTION ###"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Cleaning up Tableau Server log and temp files"
tsm maintenance cleanup -l  -t -u $tsmadmin -p $tsmpassword
if ($?) {
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance Cleanup completed succesfully."
	$Subject = "$tabservname tsm maintenance cleanup completed - $today"
	#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $maintenanceBody -SmtpServer $smtpserver;
}
else{
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance Cleanup got failed."
	$Subject = " ** Alert *** $tabservname tsm maintenance cleanup got failed - $today"
	#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Subject -SmtpServer $smtpserver;
	Write-Error "tsm maintenance cleanup -all got failed" -ErrorAction Stop
}

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### End of tsm maintenance CLEANUP SECTION ###"
Write-Host "----------------------------------------------------------------------------"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### Start of tsm maintenance BACKUP SECTION ###"

#Get the path of the Backup folder
Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Getting the location of the default log archive directory"
$backup_path = tsm configuration get -k basefilepath.backuprestore -u $tsmadmin -p $tsmpassword
Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Backup path is: $backup_path"

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Exporting Tableau Server settings"
#tsm settings export -f "$backup_path\settings-$mydate.json" -u $tsmadmin -p $tsmpassword
tsm settings export -f "$external_backup_path\settings-$mydate.json" -u $tsmadmin -p $tsmpassword

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Backing up Tableau Server data"
tsm maintenance backup -f "$backup_filename" -d -u $tsmadmin -p $tsmpassword

if ($?) {
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance backup file got created"
	
	Write-Host "Source Path -- > $backup_path+"/"+"*.tsbak""
	Write-Host "Destination Path -- > $external_backup_path"

	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Moving the ziplog file to Y drive"
	Move-item $backup_path+"/"+"*.tsbak" $external_backup_path -Force
	
	if ($?){
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Backup file got moved to external path $external_backup_path successfully"
		
		#Check for previous backup files and remove files older than N days
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Cleaning out backup files older than $backupdays days"
		$limit = (Get-Date).AddDays(-$backupdays)
		#$path = "C:\path\to\your\folder" 
		Get-ChildItem -Path $external_backup_path -File -Recurse | Where-Object {$_.LastWriteTime -lt $limit} | Remove-Item -Force
		
		if($?){
			Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "$backupdays days backup files got deleted from external path $external_backup_path successfully"
			$Subject = " $tabservname tsm maintenance backup got completed successfully - $today"
			$Body = " $tabservname tsm maintenance backup got completed successfully along with moving the backup file to $external_backup_path path and cleaning out backup files older than $backupdays days  - $today"
			#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
		}
		else{
			Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Removing $backupdays days backup files got failed at external path $external_backup_path"
			$Subject = " *** Alert *** $tabservname tsm maintenance backup got failed - $today"
			$Body = " $tabservname tsm maintenance backup got completed successfully along with moving the backup file to $external_backup_path path, but cleaning out backup files older than $backupdays days got failed - $today"
			#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
		}
	}
	else{
		Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "Moving backup file to external path $external_backup_path got failed"
		$Subject = " *** Alert *** $tabservname tsm maintenance backup got failed - $today"
		$Body = " $tabservname tsm maintenance backup got completed successfully, but moving backup file to external path $external_backup_path got failed - $today"
		#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Body -SmtpServer $smtpserver;
	}
}
else{
	Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "tsm maintenance backup got failed"
	$Subject = " *** Alert *** $tabservname tsm maintenance backup got failed - $today"
	#Send-MailMessage -From $fromaddress -To $toaddress -Subject $Subject -Body $Subject -SmtpServer $smtpserver;
	Write-Error "tsm maintenance backup got failed" -ErrorAction Stop
}

Write-Host (Get-Date).toString("yyyy/MM/dd HH:mm:ss") "### End of tsm maintenance BACKUP SECTION###"
Write-Host "----------------------------------------------------------------------------"