$ModulePath="$env:USERPROFILE\Documents\Powershell\Modules"
$ModulePathWinPS="$env:USERPROFILE\Documents\WindowsPowershell\Modules"
$ScriptPath="$env:USERPROFILE\Documents\WorkingPS"

# Copy modules
Copy-Item -Path .\Modules\* -Destination $ModulePath -Recurse -Force
# Copy modules to WinPS
Copy-Item -Path .\Modules\* -Destination $ModulePathWinPS -Recurse -Force
# Copy scripts
Copy-Item -Path .\* -Destination $ScriptPath -Filter *.ps1 -Force