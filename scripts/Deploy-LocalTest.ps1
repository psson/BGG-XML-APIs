$ModulePath="$env:USERPROFILE\Documents\Powershell\Modules"
$ScriptPath="$env:USERPROFILE\Documents\WorkingPS"

# Copy modules
Copy-Item -Path .\Modules\* -Destination $ModulePath -Recurse -Force
# Copy scripts
Copy-Item -Path .\* -Destination $ScriptPath -Filter *.ps1 -Force