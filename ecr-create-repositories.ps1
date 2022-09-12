Using module '.\mubo_core.psm1';

$Region = 'us-east-2'

function Main {
    $repositories = @(
        #'bo-svc-archive'
        #'bo-svc-audit'
        #'filebeat'
        'bo-svc-guardiant_collector'
        'bo-svc-hl7'
        'bo-svc-interop_inbound'
        'bo-svc-interop_outbound'
        'bo-svc-job_scheduler'
        'bo-svc-remote_comm_agent'
        'bo-svc-telephony'
        'bo-svc-workflow'
        'bo-svc-offline_mtf'
    )
    $repositories | ForEach-Object {
        $svnName = $_;
        New-ECR -TemplatePath '30-DataPersistance\ecr-create_myunity.yaml' `
            -ServiceName $svnName;
    }
}

function New-ECR {
    param(
        [Parameter(Mandatory=$true)][String]$TemplatePath,
        [Parameter(Mandatory=$true)][String]$ServiceName
    )
    $templateBody = (Get-TemplateBodyRaw -TemplateName $TemplatePath);
    $stackName = $([String]::Join('-', $AccountParams.StackNamePrefix, 'ecr', $ServiceName.Replace('_','-')))
    New-Stack `
        -StackName $stackName `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$AccountParams.Application },    
            @{ ParameterKey="ResourceName"; ParameterValue="$ServiceName Service ecr" },
            @{ ParameterKey="ServiceName"; ParameterValue=$ServiceName },
            @{ ParameterKey="Environment"; ParameterValue=$AccountParams.EnvironmentProd.ToLower() },
            @{ ParameterKey="CostCenter"; ParameterValue=$AccountParams.CostCenter },
            @{ ParameterKey="PurchaseOrder"; ParameterValue='-' },
            @{ ParameterKey="Client"; ParameterValue='Multitenant' },
            @{ ParameterKey="ResourceType"; ParameterValue="Shared Service" },
            @{ ParameterKey="ProductFamily"; ParameterValue=$AccountParams.ProductFamily },
            @{ ParameterKey="ProductSKU"; ParameterValue=$AccountParams.ProductSKU },
            @{ ParameterKey="NonProdAccountId"; ParameterValue='434495414204' },
            @{ ParameterKey="ProdAccountId"; ParameterValue='988099092108' }
        ) `
        -DisableRollback $true `
        -Region $Region;
    $output = Get-OutputKeyValueFromStack -StackName $stackName -KeyName Repository -Region $Region;
    Write-Host "Created Elastic Container Repository '$output'; stack '$stackName'";
}

$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account

try {
    Clear-Host;
    $ErrorActionPreference = 'Stop';

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
    Main;
    $Stopwatch.Stop();
    Write-Host "ecr deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}