param(
    [Parameter(Mandatory=$true)][String]$build_name,
    [Parameter(Mandatory=$true)][String]$build_number, #or version if called from cut-release
    [Parameter(Mandatory=$true)][String]$crm,
    [Parameter(Mandatory=$true)][String]$myUnity_bo_help,
    [Parameter(Mandatory=$true)][String]$version_file_destination
)
$versionJsonFileName = 'version_info.json';

$verFileContent = @{build_name = "$build_name"; build_number = "$build_number"; crm = "$crm"; myUnity_bo_help= "$myUnity_bo_help"}
$verFileContent | ConvertTo-Json | Set-Content "$version_file_destination\\$versionJsonFileName"