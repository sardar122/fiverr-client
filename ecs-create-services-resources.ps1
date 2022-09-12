param(
    [Parameter(Mandatory=$true)][StackProperties]$StackProperties
)

function Main {
    $logGroupName = Create-CloudWatchLog -StackProperties $StackProperties;

    $clusterName = Create-ServicesCluster -StackProperties $StackProperties;
}

function Create-CloudWatchLog {
    param(
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )
    $stackName = Get-ServiceStackName -StackID ($StackProperties.StackID) -Service log-group;
    $templateBody = (Get-TemplateBodyRaw -TemplateName 'cloudwatch-create-log-group.yaml');

    New-Stack `
        -StackName $stackName `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_svc" },
            @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
            @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
            @{ ParameterKey="ResourceName"; ParameterValue="ecs-log" },
            @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
            @{ ParameterKey="StackIDParameter"; ParameterValue=$StackProperties.StackID },
            @{ ParameterKey="RetentionDaysParameter"; ParameterValue=$StackProperties.ServiceLogsRetentionDaysParameter },
            @{ ParameterKey="AwsServiceParameter"; ParameterValue='ecs' },
            @{ ParameterKey="ProductServiceParameter"; ParameterValue='myunity-services-linux' }
        ) `
        -DisableRollback $StackProperties.DisableRollback `
        -Region $StackProperties.Region;

    Get-OutputKeyValueFromStack -StackName $stackName -KeyName 'LogGroupName' -Region $StackProperties.Region
}

function Create-ServicesCluster {
    param(
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )
    $templateBody = (Get-TemplateBodyRaw -TemplateName 'ecs-create-cluster.yaml');
    $stackName = Get-ServiceStackName -StackID ($StackProperties.StackID) -Service cluster;

    New-Stack `
        -StackName $stackName `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_svc" },
            @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
            @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
            @{ ParameterKey="ResourceName"; ParameterValue="ecs-svc-clstr" },
            @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
            @{ ParameterKey="ClusterNameParameter"; ParameterValue="$(Get-ServiceStackPrefix)" }, 
            @{ ParameterKey="StackIDParameter"; ParameterValue="$($StackProperties.StackID)" }
        ) `
        -DisableRollback $StackProperties.DisableRollback `
        -Region $StackProperties.Region;
    Get-OutputKeyValueFromStack -StackName $stackName -KeyName 'ClusterName' -Region $StackProperties.Region;
}


$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
Main;
$Stopwatch.Stop();
Write-Host "Service infra deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";