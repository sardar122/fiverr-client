param(
	[Parameter(Mandatory=$true)][string]$vsTestLocation='',
	[Parameter(Mandatory=$true)][string]$searchFolder='',
	[Parameter(Mandatory=$false)][string]$customAdaptersPath='',
	[Parameter(Mandatory=$false)][string]$settingsFile='',
	[Parameter(Mandatory=$true)][string]$includeFilter='',
    [Parameter(Mandatory=$false)][string]$excludeFilter='',
    [Parameter(Mandatory=$true)][string]$resultsPath=''
)

$ErrorActionPreference = "Stop"

write-host SearchFolder: $searchFolder
write-host CustomAdaptersPath: $customAdaptersPath
write-host SettingsFile: $settingsFile
write-host IncludeFilter: $includeFilter
write-host ExcludeFilter: $excludeFilter

#clean up old trx files.
Get-ChildItem -Path "$resultsFiles" -Include *.trx -File -Recurse | ForEach-Object { $_.Delete()}


$testDlls = Get-ChildItem "$searchFolder" -Include "$includeFilter" -Exclude "$excludeFilter" -Recurse 

    foreach ($file in $testDlls){
        $testDllArgs += """$file""" + ' '
    }

    $arguments = $testDllArgs;

    if($settingsFile){
        $arguments += "/Settings:`"$settingsFile`" ";
    }

    $arguments += "/logger:trx /TestAdapterPath:`"$customAdaptersPath`"";

    $command = "`& `"$vsTestLocation`" $arguments"

    write-host($command);
    try{
    invoke-expression $command -ErrorAction Stop
    if ($LastExitCode -ne 0)
        {
             throw "An error occurred executing tests!" 
        }
}
catch {
    write-error "An error occurred executing tests!" 
    exit $LastExitCode;
}
