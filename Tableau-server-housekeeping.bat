:: Authored by Shyam Vanga
:: Date 05/22/2025

@ECHO OFF
cls
setlocal ENABLEDELAYEDEXPANSION
SET LogPath=D:\Scripts\Logs\

FOR /F %%a IN ('powershell -NoProfile -Command "Get-Date -f 'yyyyMMdd_hhmmss'"') DO (SET "LT=%%a")

ECHO on
call :tableau-server-housekeeping >> %LogPath%Tableau_Prod_Bkp_%LT%.log
exit /b 0

:tableau-server-housekeeping

ECHO OFF
ECHO %date% %time%: ##### Maintenance started #####
ECHO.

:: Checks that the script is being run with Admin rights. 
:check_admin
NET SESSION >NUL 2>&1
if %ERRORLEVEL% NEQ 0 (
  ECHO %date% %time% : This script must be run as Administrator. Cancelling.
  EXIT /B 1
)

:: Let's grab a consistent date in the same format that Tableau Server writes the date to the end of the backup file name
:set_date
FOR /f "tokens=2 delims==" %%a in ('wmic OS Get localdatetime /value') DO SET "dt=%%a"
SET "YY=%dt:~2,2%" & SET "YYYY=%dt:~0,4%" & SET "MM=%dt:~4,2%" & SET "DD=%dt:~6,2%"
SET "HH=%dt:~8,2%" & SET "Min=%dt:~10,2%" & SET "Sec=%dt:~12,2%"
SET "mydate=%YYYY%-%MM%-%DD%"

SET tsmadmin=tableau
ECHO %date% %time% : Executing TSM as user: "%tsmadmin%"

SET tsmpassword=password
ECHO %date% %time% : Using %tsmadmin% password: "***SECRET***"

SET archivedays=7
ECHO %date% %time% : Setting the log archive retention period to "%archivedays%" days

SET backupdays=7
ECHO %date% %time% : Setting the backup retention period to: "%backupdays%" days

SET backup_filename=Tableau_Prod_Bkp
ECHO %date% %time% : Setting the backup_filename to: "%backup_filename%"

SET external_backup_path=D:\Backup
ECHO %date% %time% : Setting the external_backup_path to: "%external_backup_path%"

SET smtp=smtp_server_name
ECHO %date% %time% : Setting the smtp value to: "%smtp%"

SET to=svanga@cms.com
ECHO %date% %time% : Setting the To value to: "%to%"

SET from=TableauProd@cms.com
ECHO %date% %time% : Setting the From value to: "%from%"

ECHO.

:check_username
IF "%tsmadmin%" == "" (
	ECHO ERROR: Please specify a valid TSM user. Cancelling. 
	GOTO EOF
	)

:check_password
IF "%tsmpassword%" == "" (
	ECHO ERROR: Please specify a valid TSM password. Cancelling.
	GOTO EOF
	)

:check_retention_period
IF "%archivedays%" == "" (
	ECHO ERROR: Please specify a valid log archive retention period. Cancelling.
	GOTO EOF
	)

:check_backup_retention_period
IF "%backupdays%" == "" (
	ECHO ERROR: Please specify a valid backup retention period. Cancelling.
	GOTO EOF
	)
		

:: The new TSM backup command will not overwrite a file of the same name
:: Given we are appending today's date to the end of the backup filename this should not be a problem if you are backing up daily
:: However, if you are backing up more frequently than that, for testing for example, you may want to overwrite the existing file 
:: Using the '-o' parameter with this script will overwrite the existing file
:: So let's check if this was used

goto comment

SET overwrite_requested=-o
ECHO %date% %time% : Setting overwrite request to: "%overwrite_requested%"

:check_backup_filename
IF "%backup_filename%" == "" (
	ECHO ERROR: Please specify a valid backup_filename. Cancelling.
	GOTO EOF
	)	

:check_overwrite
ECHO %date% %time% : Checking if overwrite was requested
IF NOT DEFINED overwrite_requested ( 
	ECHO ERROR: Please specify true/false for overwrite flag. Cancelling. 
	GOTO EOF
	)
IF NOT %overwrite_requested% == true GOTO no_overwrite
IF %overwrite_requested% == true GOTO overwrite 

:: It was used so let's delete the current file if it's there
:overwrite
ECHO %date% %time% : Overwrite was requested. Cleaning out any existing file with the same name
IF EXIST "%backuppath%\%backup_filename%-%mydate%.tsbak" DEL /F "%backuppath%\%backup_filename%-%mydate%.tsbak" >nul 2>&1
GOTO set_backup_dir

:: It wasn't used so let's just go ahead and backup
:no_overwrite
ECHO %date% %time% : Overwrite was not requested, proceeding

:comment
	
:: Grab the location of the log archive directory
:set_archive_dir
ECHO %date% %time% : Getting the location of the default log archive directory
FOR /F "tokens=* USEBACKQ" %%F IN (`tsm configuration get -k basefilepath.log_archive -u %tsmadmin% -p %tsmpassword%`) DO (SET "archivepath=%%F")
ECHO The default archive path is: 
ECHO %archivepath%
ECHO.

:: Grab the location of the backup directory
:set_backup_dir
ECHO %date% %time% : Getting the location of the default backup directory
FOR /F "tokens=* USEBACKQ" %%F IN (`tsm configuration get -k basefilepath.backuprestore -u %tsmadmin% -p %tsmpassword%`) DO (SET "backuppath=%%F")
ECHO The default backup path is: 
ECHO %backuppath%
ECHO.

:: In v2018.2.0 the slashes in the default path are the wrong direction, so let's fix this
:fix_archive_dir
SET "archivepath=%archivepath:/=\%"
ECHO The corrected archive path is now: 
ECHO %archivepath% 
ECHO.

:fix_backup_dir
SET "backuppath=%backuppath:/=\%"
ECHO The corrected backup path is now: 
ECHO %backuppath% 
ECHO.

ECHO %date% %time%: ##### LOGS SECTION #####
ECHO.

:: Check for previous log archives and remove files older than N days
:delete_old_files
ECHO %date% %time% : Cleaning out archive files older than %archivedays% days
FORFILES -p "%archivepath%" -s -m *.zip /D -%archivedays% /C "cmd /c del @path" 2>nul
ECHO.

:: Then we archive the logs
:archive
ECHO %date% %time% : Archiving Tableau Server log files
CALL tsm maintenance ziplogs -a  -o -f logs-%mydate% -u %tsmadmin% -p %tsmpassword%
ECHO.

:end_msg
IF %ERRORLEVEL% EQU 0 (
	ECHO %date% %time% : Log archival completed succesfully. 
	GOTO endof_log_archival
	)
IF %ERRORLEVEL% GTR 0 (
	SET subject='Log archival failed with exit code - %ERRORLEVEL%'
	SET body='Log archival failed with exit code - %ERRORLEVEL%'
	echo C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
	C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
	ECHO %date% %time% : Log archival failed with exit code %ERRORLEVEL%
	GOTO EOF
) 

:endof_log_archival
ECHO %date% %time%: ##### END OF LOGS SECTION #####  
ECHO.

ECHO %date% %time%: ##### CLEANUP SECTION #####
ECHO.

:cleanup
ECHO %date% %time% : Cleaning up Tableau Server log and temp files
CALL tsm maintenance cleanup -l  -t -u %tsmadmin% -p %tsmpassword%
ECHO.

:end_msg
IF %ERRORLEVEL% EQU 0 (
	ECHO %date% %time% : Cleanup completed succesfully. 
	GOTO endof_cleanup
)
IF %ERRORLEVEL% GTR 0 (
	SET subject='Cleanup failed with exit code - %ERRORLEVEL%'
	SET body='Cleanup failed with exit code - %ERRORLEVEL%'
	echo C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
	C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
	ECHO %date% %time% : Cleanup failed with exit code %ERRORLEVEL%
	GOTO EOF
) 

:endof_cleanup
ECHO %date% %time%: ##### END OF CLEANUP SECTION #####
ECHO.

ECHO %date% %time%: ##### BACKUP SECTION #####
ECHO.

:: Then we take the backup
:bakup
ECHO %date% %time% : Backing up Tableau Server data
CALL tsm maintenance backup -f "%backup_filename%" -d -u %tsmadmin% -p %tsmpassword%
ECHO.

:: Then we backup the settings config file
:settings_bakup
CALL tsm settings export -f "%backuppath%\settings-%mydate%.json" -u %tsmadmin% -p %tsmpassword% 
::%backup_filename% -d -u %tsmadmin% -p %tsmpassword%
ECHO.

:: Check for previous settings file and remove files older than N days
:delete_old_config_files
ECHO %date% %time% : Cleaning out settings files older than %backupdays% days
FORFILES -p "%backuppath%" -s -m *.json /D -%backupdays% /C "cmd /c del @path" 2>nul
ECHO.

:: Check for previous backups and remove backup files older than N days
:delete_old_files
ECHO %date% %time% : Cleaning out backup files older than %backupdays% days
FORFILES -p "%external_backup_path%" -s -m *.tsbak /D -%backupdays% /C "cmd /c del @path" 2>nul
ECHO.

ECHO %date% %time% : Copying todays backup file to %external_backup_path%
FORFILES -p "%backuppath%" -m *.tsbak /D +0 /C "cmd /c @copy @path %external_backup_path%"
ECHO.

ECHO %date% %time% : Moving old backup files to %external_backup_path%
FORFILES -p "%backuppath%" -m *.tsbak /D -1 /C "cmd /c @move @path %external_backup_path%"

ECHO.

:end_msg
IF %ERRORLEVEL% EQU 0 (
	ECHO %date% %time% : Backup completed succesfully.
	ECHO %date% %time%: ##### END OF BACKUP SECTION #####
	ECHO.

	ECHO Tableau Production Backup got completed succesfully.
	ECHO %date% %time%: ##### Maintenance completed #####

	EXIT /B 0
	)
IF %ERRORLEVEL% GTR 0 (
	ECHO %date% %time% : Backup failed with exit code %ERRORLEVEL%
	GOTO EOF
	) 

:EOF
SET subject='FAILED: Tableau Production Backup got failed'
SET body='Tableau Production Backup did not got completed'

echo C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe Send-MailMessage -From "%from%" -to "%to%" -Subject !subject! -Body !body! -SmtpServer "%smtp%"
ECHO Tableau Production Backup did not got completed.
EXIT /B 3