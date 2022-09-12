Using module '.\mubo_core.psm1';

<#

param(
    [Parameter(Mandatory=$true)][StackProperties]$StackProperties,
    [Parameter(Mandatory=$true)][String]$S3_bucket
)

#>

$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account


$stackname = 'mubo-sg'; <# Do not change this.  If you do you must account for it in mue-deploy-mssql-ec2-security-resources.#>
$EBSApplicationName = 'myUnity';
$ECSApplicationName = 'ecs-fargate';
$CostCenter = $AccountParams.CostCenter;
#$Environment = $AccountParams.EnvironmentProd;
$Environment = $AccountParams.EnvironmentNonProd;
$ResourceType = 'Application';
$Region = 'us-east-2';
$stackPrefix = $AccountParams.StackNamePrefix.ToLower();
$VpcId = Get-OutputKeyValueFromStack -StackName "$stackPrefix-$Environment-vpc" -KeyName 'VpcId' -Region $Region;
$BastionSg = Get-OutputKeyValueFromStack `
    -StackName $([String]::Join('-', $AccountParams.StackNamePrefix, $AccountParams.EnvironmentMgmt, 'bastion-app-rdp')) `
    -KeyName SecurityGroup -Region $Region;

if ($CallerIdentity.Account -eq 434495414204) {
    $AnsibleSg = Get-OutputKeyValueFromStack -StackName "$stackPrefix-mgmt-ec2-ansible" -KeyName 'AnsibleSG' -Region $Region;
} elseif ($CallerIdentity.Account -eq 988099092108) {
    $AnsibleSg = Get-OutputKeyValueFromStack -StackName "$stackPrefix-mgmt-ec2-ansible-0" -KeyName 'AnsibleSG' -Region $Region;
} else {  
    $json = $null;
    Write-Error "Account '$AccountNumber' not implemented." -ErrorAction Stop;
}

$stackname = [String]::Join('-', $stackname, $Environment)

function Main {
    $sgElbsAlb = New-SgElbeanstalkAlb;
    $sgElbsAlb
    $sgFargate = New-SgEcsFargate;
    $sgFargate
    $sgElbs = New-SgElbeanstalk -ElBeanstalkAlbSg $sgElbsAlb;
    $sgElbs
}

function New-SgElbeanstalkAlb {
    $resourceName = 'elbeanstalk-alb'
    $sn = "$stackname-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\sg-elbeanstalk-alb.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$EBSApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$costCenter },
            @{ ParameterKey="Environment"; ParameterValue=$environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="VpcId"; ParameterValue=$vpcId }

        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SecurityGroup -Region $Region;
}

function New-SgEcsFargate {
    $resourceName = 'ecs-fargate'
    $sn = "$stackname-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\sg-ecs-fargate.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ECSApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$costCenter },
            @{ ParameterKey="Environment"; ParameterValue=$environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="VpcId"; ParameterValue=$vpcId }

        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SecurityGroup -Region $Region;
}

function New-SgElbeanstalk {
    param(
        [Parameter(Mandatory=$true)][String]$ElBeanstalkAlbSg
    )
    $resourceName = 'elbeanstalk'
    $sn = "$stackname-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\sg-elbeanstalk.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$EBSApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$costCenter },
            @{ ParameterKey="Environment"; ParameterValue=$environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="VpcId"; ParameterValue=$vpcId },
            @{ ParameterKey="BastionSg"; ParameterValue=$BastionSg },
            @{ ParameterKey="AnsibleSg"; ParameterValue=$AnsibleSg },
            @{ ParameterKey="ElbeanstalkAlbSg"; ParameterValue=$ElBeanstalkAlbSg }
        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SecurityGroup -Region $Region;
}

try {
    Clear-Host;
    $ErrorActionPreference = 'Stop';

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
    Main;
    $Stopwatch.Stop();
    Write-Host "Security group deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}