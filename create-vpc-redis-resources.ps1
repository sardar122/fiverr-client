Using module '.\mubo_core.psm1';

$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account

$stackname = $AccountParams.StackNamePrefix
$Environment = $AccountParams.EnvironmentNonProd <# [dev|qa|nonprod|prod] #>
$ApplicationName = $AccountParams.Application
$CostCenter = $AccountParams.CostCenter
$ResourceType = 'Application'
$Region = 'us-east-2'



function Main {
    $vpcOutputs = Get-OutputKeysFromStack -StackName "$stackName-$Environment-vpc" -Region $Region;
    $vpcId = Get-OutputKeyValueFromStack -KeyName 'VpcId' -Outputs $vpcOutputs;
    $privateSubnets = Get-OutputKeyValueFromStack -KeyName 'PrivateSubnetIds' -Outputs $vpcOutputs;

    $stackNamePrefix = [String]::Join('-', $stackname, $Environment, 'redis')

    $slowLogGroup = New-LogGroupStack -StackNamePrefix $stackNamePrefix -LogName 'slow-logs' -RetentionInDays 1;
    $engineLogGroup = New-LogGroupStack -StackNamePrefix $stackNamePrefix -LogName 'engine-logs' -RetentionInDays 1;
    $securityGroup = New-SecurityGroupStack -StackNamePrefix $stackNamePrefix -VpcId $vpcId;
    $subnetGroup = New-SubNetGroupStack -StackNamePrefix $stackNamePrefix -Subnets $privateSubnets;
    $secretName = New-SecretsManagerSecretStack -StackNamePrefix $stackNamePrefix;
    New-ReplicationGroupStack `
        -StackNamePrefix $stackNamePrefix `
        -SubnetGroup $subnetGroup `
        -SecurityGroup $securityGroup `
        -SecretName $secretName `
        -SlowLogGroup $slowLogGroup `
        -EngineLogGroup $engineLogGroup;
}

function New-LogGroupStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackNamePrefix,
        [Parameter(Mandatory=$true)][String]$LogName,
        [Parameter(Mandatory=$true)][String]$RetentionInDays
    )
    $resourceName = $LogName
    $sn = "$StackNamePrefix-log-group-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "00-Alerting-and-CloudWatch-Logs\cloudwatch-log-group.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="RetentionInDays"; ParameterValue=$RetentionInDays }
        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName LogGroup -Region $Region;
}

function New-SecurityGroupStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackNamePrefix,
        [Parameter(Mandatory=$true)][String]$VpcId
    )
    $sn = "$StackNamePrefix-sg";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\sg-redis.yaml");

    # add vpc cidr ingress rule so that it is not manual add
    $CidrBlock = (Get-EC2Vpc -VpcId $VpcId).CidrBlock;

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue='redis' },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="VpcId"; ParameterValue=$vpcId },
            @{ ParameterKey="VpcCidrBlock"; ParameterValue=$CidrBlock }
        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SecurityGroup -Region $Region;
}

function New-SubNetGroupStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackNamePrefix,
        [Parameter(Mandatory=$true)][String]$Subnets
    )
    $resourceName = 'subnet-group'
    $sn = "$StackNamePrefix-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "30-DataPersistance\elasticache-subnet-group.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="SubnetIds"; ParameterValue=$Subnets }

        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SubnetGroup -Region $Region;
}

function New-SecretsManagerSecretStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackNamePrefix
    )
    $sn = "$StackNamePrefix-replication-group-secrets-manager-secret";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security/secret.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ApplicationName },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceName"; ParameterValue='replication-group' },
            @{ ParameterKey="Username"; ParameterValue='' },
            @{ ParameterKey="PasswordLength"; ParameterValue=32 },
            @{ ParameterKey="ExcludeCharacters"; ParameterValue='' },
            @{ ParameterKey="ExcludePunctuation"; ParameterValue="true" },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType }
        ) `
        -DisableRollback $true `
        -Region $Region;
    Get-OutputKeyValueFromStack -StackName $sn -KeyName SecretName -Region $Region;
}

function New-ReplicationGroupStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackNamePrefix,
        [Parameter(Mandatory=$false)][String]$CacheNodeType = 'cache.t3.micro',
        [Parameter(Mandatory=$true)][String]$SubnetGroup,
        [Parameter(Mandatory=$false)][String]$ReplicasPerNodeGroup = '1',
        [Parameter(Mandatory=$true)][String]$SecurityGroup,
        [Parameter(Mandatory=$false)][String]$SnapshotRetentionLimit = '5',
        [Parameter(Mandatory=$false)][String]$SnapshotWindow = '09:00-10:00',
        [Parameter(Mandatory=$false)][String]$PreferredCacheClusterAZs = 'us-east-2a',
        [Parameter(Mandatory=$false)][String]$SecondaryCacheClusterAZs = 'us-east-2c',
        [Parameter(Mandatory=$true)][String]$SecretName,
        [Parameter(Mandatory=$true)][String]$SlowLogGroup,
        [Parameter(Mandatory=$true)][String]$EngineLogGroup
    )
    $resourceName = 'replication-group'
    $sn = "$StackNamePrefix-$resourceName";
    $templateBody = (Get-TemplateBodyRaw -TemplateName "30-DataPersistance\elasticache-redis-replication-group.yaml");




    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$ApplicationName },
            @{ ParameterKey="ResourceName"; ParameterValue=$resourceName },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="CacheNodeType"; ParameterValue=$CacheNodeType },
            @{ ParameterKey="CacheSubnetGroupName"; ParameterValue=$SubnetGroup },
            @{ ParameterKey="ReplicasPerNodeGroup"; ParameterValue=$ReplicasPerNodeGroup },
            @{ ParameterKey="AutoMinorVersionUpgrade"; ParameterValue="true" },
            @{ ParameterKey="ElastiCacheSecurityGroupIds"; ParameterValue=$SecurityGroup },
            @{ ParameterKey="SnapshotRetentionLimit"; ParameterValue=$SnapshotRetentionLimit },
            @{ ParameterKey="SnapshotWindow"; ParameterValue=$SnapshotWindow },
            @{ ParameterKey="Secret"; ParameterValue=$SecretName },
            @{ ParameterKey="PreferredCacheClusterAZs"; ParameterValue=$PreferredCacheClusterAZs },
            @{ ParameterKey="SecondaryCacheClusterAZs"; ParameterValue=$SecondaryCacheClusterAZs },
            @{ ParameterKey="CloudWatchLogGroupSlowLogs"; ParameterValue=$SlowLogGroup },
            @{ ParameterKey="CloudWatchLogGroupEngineLogs"; ParameterValue=$EngineLogGroup }
        ) `
        -TimeoutSeconds 900 `
        -DisableRollback $true `
        -Region $Region;
}

try {
    Clear-Host;
    $ErrorActionPreference = 'Stop';

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
    Main;
    $Stopwatch.Stop();
    Write-Host "Redis deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}
