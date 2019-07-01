Import-Module ImportExcel #Если не установлен, можно установить командой Install-Module ImportExcel
Import-Module ActiveDirectory 




#Поиск всех серверных ОС домена.
$Host_names = Get-ADComputer -Filter {OperatingSystem -like '*server*'} -Properties OperatingSystem |  foreach name 

$Export_path = 'E:\Tasks\scripts\Audit_file_share.xlsx'
$logs = 'E:\Tasks\scripts\Audit_file_share_log.log'


foreach($Host_name in $Host_names) {
$ErrorActionPreference = 'SilentlyContinue'
$date_start = Get-Date -Format g
Write-Host "Анализирую файловые ресурсы хоста $Host_name,$date_start" -ForegroundColor Yellow
#Определяем шары хоста.
 $Paths_shared = net view "\\$Host_name" /all | select -Skip 7 | where {$_ -match 'disk*'} | foreach {$_ -match '^(.+?)\s+Disk*'|out-null;$matches[1]}  |foreach {
'\\'+$Host_name+'\' + $matches[1] 
}
#Проверяем права доступа к шарам полученным ранее.
$Paths_shared_and_Right_users = foreach ($path_share in $Paths_shared) {

$Right_for_users = (Get-Acl -Path $path_share -ErrorAction SilentlyContinue).Access |  where {$_.IdentityReference -match 'Пользователи|Все|Users|all'}| select `
		@{Label="Right";Expression={$_.FileSystemRights}} -Unique | foreach Right 
[PSCustomObject] @{
SharePath = $path_share
Last_Write_Time = Get-Item $path_share| foreach {$_.LastWriteTime} 
Right_User = [string]$Right_for_users -replace '\r*\n', '' 
}


Clear-Variable -Name Right_for_users
} 

$DirS = $Paths_shared_and_Right_users | where { $_.Right_User -notlike $null} 

$Result = foreach($Dir in $DirS.SharePath.trim()){
#Поиск файл определенного формата, объемом не более 10 мб (10000000) или  формата файла который обычно более 10мб.Например ISO-файлы
$File_names= Get-ChildItem -Recurse -Force -Path  $Dir -Include *.config, *.bat, *.txt,*.ps1, *.py , *.csv, *.sql, *.vbs, *.pfx,*.p12, *.pem, *.crt, *.cer, *.key, *.vhdx,*.vhd,*.ISO,*.vmdk,*.vmsn,*.vdi,*.bak,*.bkp,*.ost,*.pst |`
Where-Object {$_.Length -lt '10000000' -or $_.name -match '.vhd|.ISO|.vmdk|.vmsn|.bak|.bkp|.vdi|.ost|.pst'} 
Clear-Variable Matches
foreach ($File_name in $File_names) {
#Проверяем содержимое файла подходящего под условия.
$Check_contents_file =  if($File_name.Extension -notmatch '.pfx|.p12|.pem|.crt|.cer|.key|.vhdx|.vhd|.ISO|.vmdk|.vmsn|.vdi|.bak|.bkp|.ost|.pst') { $File_name | Get-Content}
#Если файл содержит текст условия -выведи путь и название файла
if ($Check_contents_file | where {$_ -match 'login|pass|creden|user|пароль|пользоват|key'}) {
[PscustomObject] @{
Path = $File_name  | foreach Directory
FileName = $File_name  | foreach  name
Target = $Matches[0]
Comment = "Сработка по содержимому файла"
}
}
#Если название содержит условие  - выведи путь и название файла
elseif ($File_name.Name -match 'Pass|Пароль|Учетн|Учетк|Credent|Пароль|Логин|root|key|УЗ|User|.pfx$|.p12$|.pem$|.crt$|.cer$|.key$|.vhdx$|.vhd$|.ISO$|.vmdk$|.vmsn$|.bak$|.bkp$|.vdi$|.ost$|.pst$') {
[PscustomObject] @{
Path = $File_name  | foreach Directory
FileName = $File_name  | foreach  name
Target = $Matches[0]
Comment = "Сработка по названию/формату файла"
}
}
}
}
$DirS   | Export-Excel $Export_path -Append -WorksheetName 'Right' 
$Result | Export-Excel $Export_path -Append -WorksheetName 'Target'

Clear-Variable -Name Result
Clear-Variable -Name DirS
$date = Get-Date -Format g
Write-Host "Файловые ресурсы хоста были проанализированы $Host_name,$date"  -ForegroundColor Green
"$Host_name;$date"  >> $logs
 
}

