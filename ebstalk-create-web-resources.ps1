param(
    [Parameter(Mandatory=$true)][StackProperties]$StackProperties
)


function Main {
    $stackPrefix = 'mubo-web';

    $ApplicationName = Create-EbstalkApplication `
        -StackPrefix $stackPrefix `
        -StackProperties $StackProperties;

    Create-EbstalkEnvironments `
        -StackPrefix $stackPrefix `
        -ApplicationName $ApplicationName `
        -StackProperties $StackProperties;
}

function Create-EbstalkEnvironments{
     param(
        [Parameter(Mandatory=$true)][String]$StackPrefix,
        [Parameter(Mandatory=$true)][String]$ApplicationName,
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )

    $templateBody = (Get-TemplateBodyRaw -TemplateName 'ebstalk-create-environment-backoffice-web.yaml');
    Get-Job | Remove-Job;
    $envCount = $StackProperties.EbStalkEnvironmentCount;
    1..$envCount | ForEach-Object { 
        Write-Host "[EbstalkEnvironment] Starting job to create StackID $_ for application $ApplicationName";
        Start-Job -ScriptBlock ${Function:Create-EbstalkEnvironment} `
            -ArgumentList `
                $StackPrefix `
                ,$ApplicationName `
                ,$_ `
                ,$templateBody `
                ,$($StackProperties | ConvertTo-Json) | Out-Null;
        Start-Sleep -Seconds 1;
    }
    #Wait for all jobs to finish.
    Get-Job | Wait-Job;
    #Get information from each job.
    foreach($job in Get-Job){
        Receive-Job -Id ($job.Id);
    }
    #Remove all jobs created.
    # Get-Job | Stop-Job | Remove-Job;
    Get-Job | Remove-Job;
}

function Create-EbstalkEnvironment{
    param(
        [Parameter(Mandatory=$true)][String]$StackPrefix,
        [Parameter(Mandatory=$true)][String]$ApplicationName,
        [Parameter(Mandatory=$true)][ValidateSet(1, 2)][Int]$EnvironmentIndex,
        [Parameter(Mandatory=$true)][String]$TemplateBody,
        [Parameter(Mandatory=$true)][Object]$StackPropertiesJson
    )

    $StackProperties = $StackPropertiesJson | ConvertFrom-Json;

    if ($EnvironmentIndex -eq 1) { 
        $EnvCnameSuffix = 'front';
    } elseif ($EnvironmentIndex -eq 2) { 
        $EnvCnameSuffix = 'back';
    } else {
        Write-Error "[EbstalkEnvironment] EnvironmentIndex does not have an implemented Cname suffix.";
    }

    $vpcName = (Get-EC2Vpc -VpcId $($StackProperties.VpcIdParameter)).Tags | ? { $_.key -eq "name" } | select -expand Value;

    $stackName="$StackPrefix-$($StackProperties.StackID)-env-$EnvCnameSuffix-stack";
    Write-Host "[EbstalkEnvironment] Creating Environment Stack $StackName Cname: $EnvCnameSuffix for application $ApplicationName";
    if (-Not (Test-CFNStack -StackName $stackName)) {
        New-CFNStack -StackName "$stackName" `
                -TemplateBody $templateBody `
                -Parameter @( 
                @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_web" },
                @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
                @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
                @{ ParameterKey="ResourceName"; ParameterValue="ebs-env" },
                @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
                @{ ParameterKey="EBStalkApplicationNameParameter"; ParameterValue="$ApplicationName" }, 
                @{ ParameterKey="StackIDParameter"; ParameterValue=$StackProperties.StackID },
                @{ ParameterKey="EnvironmentIndexParameter"; ParameterValue="$EnvironmentIndex" },
                @{ ParameterKey="EnvironmentCnameSuffixParameter"; ParameterValue="$EnvCnameSuffix" },
                @{ ParameterKey="VpcIdParameter"; ParameterValue=$StackProperties.VpcIdParameter },
                @{ ParameterKey="PublicSubnetsParameter"; ParameterValue="$([String]::Join(',', $StackProperties.PublicSubnetsParameter))" },
                @{ ParameterKey="PrivateSubnetsParameter"; ParameterValue="$([String]::Join(',', $StackProperties.PrivateSubnetsParameter))" },
                @{ ParameterKey="LbCertArnParameter"; ParameterValue=$StackProperties.LbCertArnParameter },
                @{ ParameterKey="AppELBSecurityGroupParameter"; ParameterValue="$([String]::Join(',', $StackProperties.AppELBSecurityGroupParameter))" },
                @{ ParameterKey="AppSecurityGroupParameter"; ParameterValue="$([String]::Join(',', $StackProperties.AppSecurityGroupParameter))" },
                @{ ParameterKey="BastionHostSecurityGroupParameter"; ParameterValue="$([String]::Join(',', $StackProperties.BastionHostSecurityGroupParameter))" },
                @{ ParameterKey="AutomaticPatches"; ParameterValue=$StackProperties.AutomaticPatches },
                @{ ParameterKey="PatchGroup"; ParameterValue=$StackProperties.PatchGroup },
                @{ ParameterKey="EC2KeyNameParam"; ParameterValue=$vpcName }
                ) `
                -DisableRollback $true `
                -Region $region;
        Wait-CFNStack -StackName $stackName -Status CREATE_COMPLETE -Timeout $(30  * 60);
        $msg = "Success creating Ebstalk Application $EnvCnameSuffix stack environment.";
    } else {
        $msg = "Ebstalk Application $EnvCnameSuffix stack environment exists.";
    }
    Write-Host $msg;
}

function Create-EbstalkApplication{
    param(
        [Parameter(Mandatory=$true)][String]$StackPrefix,
        [Parameter(Mandatory=$true)][StackProperties]$StackProperties
    )
    $stackName = "$StackPrefix-$($StackProperties.StackID)-app-stack";
    $applicationName="$StackPrefix-$($StackProperties.StackID)-app-$($StackProperties.Region)-$($StackProperties.EnvironmentType)";

    Write-Host "[EbstalkInfra] Creating stack: $stackName";
    Write-Host "[EbstalkInfra] Ebstalk application: $applicationName";

    $templateBody = (Get-TemplateBodyRaw -TemplateName 'ebstalk-create-application.yaml');
    if (-Not (Test-CFNStack -StackName $stackName)) {
        New-CFNStack -StackName $stackName `
                -TemplateBody $templateBody `
                -Parameter @( 
                @{ ParameterKey="Application"; ParameterValue="$($StackProperties.Application)_web" },
                @{ ParameterKey="Environment"; ParameterValue="$($StackProperties.EnvironmentType)" },
                @{ ParameterKey="CostCenter"; ParameterValue="$($StackProperties.CostCenter)" },
                @{ ParameterKey="ResourceName"; ParameterValue="ebs-app" },
                @{ ParameterKey="ResourceType"; ParameterValue="$($StackProperties.ResourceType)" },
                @{ ParameterKey="ApplicationPrefixParameter"; ParameterValue=$StackPrefix }, 
                @{ ParameterKey="StackIDParameter"; ParameterValue=$StackProperties.StackID }, 
                @{ ParameterKey="SolutionEnvironmentNameParameter"; ParameterValue=$StackProperties.EnvironmentType },
                @{ ParameterKey="DescriptionParameter"; ParameterValue=$StackProperties.Description }
                ) `
                -DisableRollback $true `
                -Region $StackProperties.Region | Out-Null;
        Wait-CFNStack -StackName $stackName -Status CREATE_COMPLETE -Timeout 300 | Out-Null;
        $msg = "Success creating Ebstalk Application '$applicationName'";
    } else {
        $msg = "Ebstalk Application '$applicationName' exists.";
    }
    Write-Host $msg;
    return $applicationName;
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
Main;
$Stopwatch.Stop();
Write-Host "Web infra deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";