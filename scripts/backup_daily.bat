@echo off
REM Sauvegarde quotidienne hors-site
set BACKUP_DIR=D:\Backups\DentalClinic
set PB_URL=http://127.0.0.1:8090
set ADMIN_EMAIL=admin@cabinet.local
set ADMIN_PASS=ChangeMe123

if not exist "%BACKUP_DIR%" mkdir "%BACKUP_DIR%"

curl -s -X POST %PB_URL%/api/collections/users/auth-with-password ^
  -H "Content-Type: application/json" ^
  -d "{\"identity\":\"%ADMIN_EMAIL%\",\"password\":\"%ADMIN_PASS%\"}" > "%TEMP%\auth.json"

for /f "tokens=2 delims=:" %%a in ('findstr /r "\"token\"" "%TEMP%\auth.json"') do set TOKEN=%%a
set TOKEN=%TOKEN:"=%
set TOKEN=%TOKEN:,=%

curl -s -X POST %PB_URL%/api/backups ^
  -H "Authorization: %TOKEN%" ^
  -H "Content-Type: application/json" ^
  -d "{\"name\":\"auto_%date:~-4%%date:~3,2%%date:~0,2%\"}"

xcopy "%~dp0pocketbase\pb_data\backups\*" "%BACKUP_DIR%\" /Y /I
echo Sauvegarde terminee