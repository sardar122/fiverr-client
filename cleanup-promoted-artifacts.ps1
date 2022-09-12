param(
    [Parameter(Mandatory=$true)][String]$LocalFolder
)

Write-Host "Deleting all files in the $LocalFolder directory...";
Remove-Item -Path "$LocalFolder\\*.*";