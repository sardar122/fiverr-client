param(
    [Parameter(Mandatory=$true)][String]$TFSBranch,
    [Parameter(Mandatory=$true)][String]$SourceVersion,
    [Parameter(Mandatory=$true)][String]$TargetVersion,
    [Parameter(Mandatory=$true)][String]$S3Bucket,
    [Parameter(Mandatory=$true)][String]$LocalFolder
)

function Main {
############################################
Write-Host 'Downloading core zips from s3...';
############################################
Import-Module AWSPowerShell;

Write-Host 'Downloading web app zip...';
Read-S3Object -BucketName "$S3Bucket/$TFSBranch" -Key "ebs-web-app_$SourceVersion.zip" -File "$LocalFolder\ebs-web-app_$TargetVersion.zip"; 

Write-Host 'Downloading web bootstrapper zip...';
Read-S3Object -BucketName "$S3Bucket/$TFSBranch" -Key "ebs-web-bootstrapper_$SourceVersion.zip" -File "$LocalFolder\ebs-web-bootstrapper_$TargetVersion.zip"; 

Write-Host 'Downloading dbupgrade zip...';
Read-S3Object -BucketName "$S3Bucket/$TFSBranch" -Key "dbupgrade_$SourceVersion.zip" -File "$LocalFolder\dbupgrade_$TargetVersion.zip"; 

Write-Host 'Downloading crm filewatcher zip...';
Read-S3Object -BucketName "$S3Bucket/$TFSBranch" -Key "crm-filewatcher_$SourceVersion.zip" -File "$LocalFolder\crm-filewatcher_$TargetVersion.zip"; 
}

Main