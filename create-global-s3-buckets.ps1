Using module '.\mubo_core.psm1';

$Region = 'us-east-2'

function Main {
    $buckets = @{
        'myunity-workfilereploc'='myunity-workfilereploc'
        'sql-backup-restore-non-prod'='backups-nonprod'
        'sql-backup-restore-prod'='backups-prod'
    }
    $buckets.Keys | ForEach-Object {
    $commonName = $_
    $bucketName = $buckets[$_]
    New-S3Bucket -TemplatePath 's3.yaml' `
        -StackName $commonName `
        -BucketName $bucketName `
        -ServiceName $bucketName `
        -ResourceName $commonName `
        -Client 'Multitenant';
    }

    $commonNames = @(
        'content-packages'
        'myunity-bo-released-packages'
        'myunity-bo-upd'
        'myunity-seed-databases'
    )
    $commonNames | ForEach-Object {
        $commonName = $_;
        New-S3Bucket -TemplatePath 's3.yaml' `
            -StackName $commonName `
            -BucketName $commonName `
            -ServiceName $commonName `
            -ResourceName $commonName `
            -Client 'Infrastructure';
    }
}

function New-S3Bucket {
    param(
        [Parameter(Mandatory=$true)][String]$TemplatePath,
        [Parameter(Mandatory=$true)][String]$StackName,
        [Parameter(Mandatory=$true)][String]$BucketName,
        [Parameter(Mandatory=$true)][String]$ServiceName,
        [Parameter(Mandatory=$true)][String]$ResourceName,
        [Parameter(Mandatory=$true)][String]$Client
    )
    $templateBody = (Get-TemplateBodyRaw -TemplateName $TemplatePath);
    $stackName = $([String]::Join('-', $AccountParams.StackNamePrefix, 's3', $StackName))
    New-Stack `
        -StackName $stackName `
        -TemplateBody $templateBody `
        -Paramaters @(
            @{ ParameterKey="ServiceName"; ParameterValue=$ServiceName },
            @{ ParameterKey="Application"; ParameterValue=$AccountParams.Application },
            @{ ParameterKey="ResourceName"; ParameterValue=$ResourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$AccountParams.CostCenter },
            @{ ParameterKey="PurchaseOrder"; ParameterValue='-' },
            @{ ParameterKey="Client"; ParameterValue=$Client },
            @{ ParameterKey="ResourceType"; ParameterValue="Shared Service" },
            @{ ParameterKey="Environment"; ParameterValue=$AccountParams.EnvironmentProd },
            @{ ParameterKey="ProductFamily"; ParameterValue=$AccountParams.ProductFamily },
            @{ ParameterKey="ProductSKU"; ParameterValue=$AccountParams.ProductSKU }
        ) `
        -DisableRollback $true `
        -Region $Region;
    $output = Get-OutputKeyValueFromStack -StackName $stackName -KeyName S3Bucket -Region $Region;
    Write-Host "Created s3 bucket '$output'; stack '$stackName'"
}

$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account

try {
    Clear-Host;
    $ErrorActionPreference = 'Stop';

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
    Main;
    $Stopwatch.Stop();
    Write-Host "s3 bucket deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}