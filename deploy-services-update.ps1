param(
    [Parameter(Mandatory=$true)][StackProperties]$StackProperties
)

function Main {  
    Deploy-ServiceUpdate `
        -StackProperties $StackProperties;
}

function Deploy-ServiceUpdate {
    param (
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )
    Write-Debug '[Deploy-ServiceUpdate] Deploying service update';
    $logGroupName = Get-LogGroupName -StackID ($StackProperties.StackID) -Region $StackProperties.Region;
    $clusterName = Get-ClusterName -StackID ($StackProperties.StackID) -Region $StackProperties.Region;

    $StackProperties.Services | ForEach-Object {
        $Service = $_;

        #Get the app's ParameterStore entry
        $AppParamName = "/myUnity/Config/Stack_$($StackProperties.StackID)/$($Service)/1.0/json";
        Write-Host "AppParamName $AppParamName";
        Write-Host (Get-SSMParameter -Name $AppParamName -WithDecryption $True).Value
        $AppParamValue = (Get-SSMParameter -Name $AppParamName -WithDecryption $True).Value | ConvertFrom-Json;

        #Create task definition parameter
        $taskDefParameters = @( @{ ParameterKey="ServiceNameParameter"; ParameterValue=$Service },
                                @{ ParameterKey="StackIdParameter"; ParameterValue=$StackProperties.StackID },
                                @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_svc" },
                                @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
                                @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
                                @{ ParameterKey="ResourceName"; ParameterValue="ecs-$($Service)-tskdef" },
                                @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
                                @{ ParameterKey="TaskRoleNameParameter"; ParameterValue=$StackProperties.TaskRoleNameParameter },
                                @{ ParameterKey="ImageTagParameter"; ParameterValue=$StackProperties.TargetVersion }
                                @{ ParameterKey="LogGroupNameParameter"; ParameterValue=$LogGroupName },
                                @{ ParameterKey="CpuParameter"; ParameterValue=$AppParamValue.ServiceHostCpuUnits },
                                @{ ParameterKey="MemoryParameter"; ParameterValue=$AppParamValue.ServiceHostMemoryMB },
                                @{ ParameterKey="AppParamNameParameter"; ParameterValue=$AppParamName },
                                @{ ParameterKey="CacheEndPointUrlParameter"; ParameterValue=$AppParamValue.CacheEndPointUrl },
                                @{ ParameterKey="CacheEndPointPortParameter"; ParameterValue=$AppParamValue.CacheEndPointPort },
                                @{ ParameterKey="CacheApplicationNameParameter"; ParameterValue=$AppParamValue.CacheApplicationName },
                                @{ ParameterKey="CacheTimeoutParameter"; ParameterValue=$AppParamValue.CacheTimeout },
                                @{ ParameterKey="CacheEndpointSslParameter"; ParameterValue=$AppParamValue.CacheEndpointSsl },
                                @{ ParameterKey="CacheProviderAccessKeyParameter"; ParameterValue=$CacheProviderAccessKey },
                                @{ ParameterKey="CacheConnectionTimeoutInMillisecondsParameter"; ParameterValue=$AppParamValue.CacheConnectionTimeoutInMilliseconds },
                                @{ ParameterKey="CacheOperationTimeoutInMillisecondsParameter"; ParameterValue=$AppParamValue.CacheOperationTimeoutInMilliseconds },
                                @{ ParameterKey="LoggingAppNameParameter"; ParameterValue=$AppParamValue.Logging_AppName },
                                @{ ParameterKey="LoggingDirectoryParameter"; ParameterValue=$AppParamValue.Logging_Directory },
                                @{ ParameterKey="LoggingMinimumSeverityLevelParameter"; ParameterValue=$AppParamValue.Logging_MinimumSeverityLevel }
                            )
        
        #Add/Update ecs task definition
        $taskDefStackName = Get-ServiceStackName -StackID ($StackProperties.StackID) -ServicePrefix $Service -Service task-definition;
        $templateBody = (Get-TemplateBodyRaw -TemplateName "ecs-create-task-definition.yaml");
        if (Test-CFNStack -StackName $taskDefStackName)
        {
            Write-Output "Updating task definition stack '$taskDefStackName'."
            try {
                Update-CFNStack `
                    -StackName $taskDefStackName `
                    -Parameter $taskDefParameters `
                    -TemplateBody $templateBody `
                    -Region $StackProperties.Region;
                Wait-CFNStack -StackName $taskDefStackName -Status UPDATE_COMPLETE -Timeout 300 | Out-Null;
            } catch [Amazon.CloudFormation.AmazonCloudFormationException] {
                if($_.Exception.Message -notlike "*No updates are to be performed*")
                {
                    throw $_  # rethrow if it's not the thing we want to suppress
                }
                else {
                    Write-Output "No updates are to be performed on stack '$taskDefStackName'."
                }
            }
        }
        else
        {
            Write-Output "Adding task definition stack '$taskDefStackName'."
            New-Stack `
                -StackName $taskDefStackName `
                -TemplateBody $templateBody `
                -Paramaters $taskDefParameters `
                -DisableRollback $StackProperties.DisableRollback `
                -Region $StackProperties.Region;
            Wait-CFNStack -StackName $taskDefStackName -Status CREATE_COMPLETE -Timeout 300 | Out-Null;
        }

        #Add/Update ecs service
        $ServiceStackName = Get-ServiceStackName -StackID ($StackProperties.StackID) -ServicePrefix $Service -Service service;
        if (Test-CFNStack -StackName $ServiceStackName)
        {
            Write-Output "Updating service stack '$ServiceStackName'."
            $ecsService = (Get-ECSService -Cluster $clusterName -Service "$Service-service").Services[0];
            $td = $($ecsService.TaskDefinition).Substring(0, $($ecsService.TaskDefinition).LastIndexOf(':'));
            Update-ECSService -Cluster $clusterName `
                              -Service $ecsService.ServiceName `
                              -TaskDefinition $td <#This deploys the latest td revision for this stack.  The TD is tagged with the 'ImageVersionTag' key that states the target version.#> `
                              -ForceNewDeployment $true `
                              -Region $StackProperties.Region;
        }
        else
        {
            Write-Output "Adding service stack: '$ServiceStackName'."
            Create-Service -Service $Service `
                           -StackName $ServiceStackName `
                           -StackProperties $StackProperties;
        }

        #Add/Update the autoscaling target
        Write-Output "Add/Update application autoscaling target for '$Service' service."
        $MinCapacity = If ([string]::IsNullOrWhiteSpace($AppParamValue.ServiceScalingMinCapacity)) {2} Else {$AppParamValue.ServiceScalingMinCapacity};
        $MaxCapacity = If ([string]::IsNullOrWhiteSpace($AppParamValue.ServiceScalingMaxCapacity)) {10} Else {$AppParamValue.ServiceScalingMaxCapacity};
        Add-AASScalableTarget -ServiceNamespace "ecs" `
                                -ResourceId "service/$clusterName/$Service-service" `
                                -ScalableDimension "ecs:service:DesiredCount" `
                                -MinCapacity $MinCapacity `
                                -MaxCapacity $MaxCapacity `
                                -Region $StackProperties.Region;

        #Add/Update the autoscaling policy
        Write-Output "Add/Update application autoscaling policy for '$Service' service."
        $TargetValue = If ([string]::IsNullOrWhiteSpace($AppParamValue.ServiceScalingCpuTargetPercent)) {70} Else {$AppParamValue.ServiceScalingCpuTargetPercent};
        $ScaleInCooldown = If ([string]::IsNullOrWhiteSpace($AppParamValue.ServiceScaleInCooldownSeconds)) {600} Else {$AppParamValue.ServiceScaleInCooldownSeconds};
        $ScaleOutCooldown = If ([string]::IsNullOrWhiteSpace($AppParamValue.ServiceScaleOutCooldownSeconds)) {300} Else {$AppParamValue.ServiceScaleOutCooldownSeconds};
        Set-AASScalingPolicy -ServiceNamespace "ecs" `
                                -ResourceId "service/$clusterName/$Service-service" `
                                -ScalableDimension "ecs:service:DesiredCount" `
                                -PolicyName "ServiceScalingPolicyByAverageCPUUtilization" `
                                -PolicyType "TargetTrackingScaling" `
                                -PredefinedMetricSpecification_PredefinedMetricType "ECSServiceAverageCPUUtilization" `
                                -TargetTrackingScalingPolicyConfiguration_TargetValue $TargetValue `
                                -TargetTrackingScalingPolicyConfiguration_ScaleInCooldown $ScaleInCooldown `
                                -TargetTrackingScalingPolicyConfiguration_ScaleOutCooldown $ScaleOutCooldown `
                                -Region $StackProperties.Region;
    }
}

function Create-Service {
    param (
        [Parameter(Mandatory=$true)][String]$Service,
        [Parameter(Mandatory=$true)][String]$StackName,
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )
    $templateBody = (Get-TemplateBodyRaw -TemplateName 'ecs-create-service.yaml');

    New-Stack `
        -StackName $StackName `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_svc" },
            @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
            @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
            @{ ParameterKey="ResourceName"; ParameterValue="ecs-$($Service)-svc" },
            @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
            @{ ParameterKey="ClusterNameParameter"; ParameterValue="$ClusterName" }, 
            @{ ParameterKey="ClusterSecurityGroupParameter"; ParameterValue="$([String]::Join(',', $StackProperties.ClusterSecurityGroup))" }, 
            @{ ParameterKey="SubnetsParameter"; ParameterValue="$([String]::Join(',', $StackProperties.PrivateSubnetsParameter))" }
            @{ ParameterKey="StackIDParameter"; ParameterValue=$StackProperties.StackID },
            @{ ParameterKey="ServiceNameParameter"; ParameterValue=$Service },
            @{ ParameterKey="MaximumPercentParameter"; ParameterValue=$StackProperties.MaximumPercentParameter },
            @{ ParameterKey="MinimumHealthyPercentParameter"; ParameterValue=$StackProperties.MinimumHealthyPercentParameter },
            @{ ParameterKey="DesiredCountParameter"; ParameterValue=0 }
        ) `
        -DisableRollback $StackProperties.DisableRollback `
        -Region $StackProperties.Region;
}


$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
Main;
$Stopwatch.Stop();
$Stopwatch.Elapsed.TotalMinutes.ToString('0.00')