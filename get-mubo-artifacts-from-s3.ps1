param(
    [Parameter(Mandatory=$true)][String]$S3Bucket,
    [Parameter(Mandatory=$false)][String]$S3Folder,
    [Parameter(Mandatory=$true)][String]$ArtifactToGet,
    [Parameter(Mandatory=$false)][String]$TargetVersion,
    [Parameter(Mandatory=$false)][String]$UPDName,
    [Parameter(Mandatory=$false)][String]$CPackName,
    [Parameter(Mandatory=$true)][String]$LocalFolder
)

function Main {
    ############################################
    Write-Host 'Downloading zip(s) from s3...';
    ############################################
    Import-Module AWSPowerShell;
    
    switch ($ArtifactToGet)
    {
        "help" {
            Write-Host 'Downloading help zip...';
            Read-S3Object -BucketName "$S3Bucket" -Key "myUnity_bo_help_$TargetVersion.zip" -File "$LocalFolder\myUnity_bo_help_$TargetVersion.zip"; 
            Break;
        }
        "crm" {
            Write-Host 'Downloading CRM zip...';
            Read-S3Object -BucketName "$S3Bucket/$S3Folder" -Key "crm-$TargetVersion.zip" -File "$LocalFolder\crm-$TargetVersion.zip"; 
            Break;
        }
        "upd" {
            Write-Host 'Downloading UPD zip...';
            $UPDName = $UPDName -Replace ".zip" -Replace "_Hosting";
            Read-S3Object -BucketName "$S3Bucket" -Key "${UPDName}_Hosting.zip" -File "$LocalFolder\${UPDName}_Hosting.zip"; 
            Break;
        }
        "cpack" {
            Write-Host 'Downloading Content Pack zip...';
            $CPackName = $CPackName -Replace ".zip";
            Read-S3Object -BucketName "$S3Bucket/$S3Folder" -Key "$CPackName.zip" -File "$LocalFolder\$CPackName.zip"; 
            Break;
        }
        Default {
            Write-Host 'The ArtifactToGet value was not recognized.';
        }
    }
}

Main