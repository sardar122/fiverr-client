Using module '.\mubo_core.psm1';

# Input variables
$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop; # Get current account
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account # Get account specific details. e.g. domain, cost center, etc.
$Region = 'us-east-2'
$Environment = $AccountParams.EnvironmentProd <# [dev|qa|nonprod|prod] #>


function Main {
    param(
        [Parameter(Mandatory=$true)][PScustomObject[]]$AccountParams,
        [Parameter(Mandatory=$true)][String]$Region,
        [Parameter(Mandatory=$true)][String]$Environment
    )

    # Additional Variables
    $Application = $AccountParams.Application
    $CostCenter = $AccountParams.CostCenter
    $ResourceType = 'Shared Service'
    $VpcStackName = "myunity-$Environment-vpc"
    $VpcId = Get-OutputKeyValueFromStack -StackName $VpcStackName -KeyName VpcId -Region $Region;
    $AWSBackupRetention = 'none'
    $ActiveDirectoryId = Get-DSDirectory | Where-Object{$_.ShortName -eq $AccountParams.Domain} | Select-Object -ExpandProperty DirectoryId
    $AutomaticBackupRetentionDays = '5'
    $DeploymentType = 'SINGLE_AZ_1'
    $Az = $AccountParams.AvailabilityZoneTertiary
    if($AccountParams.IsProductionAccount) {
        $SubnetName = "myunity-$($Environment)-rds-$($Region)$($Az)"
    }
    else {
        $SubnetName = "myunity-$($Environment)-private-$($Region)$($Az)"
    }
    $SubnetIds = Get-Ec2Subnet -Filter @{Name='tag:Name'; Values=$SubnetName} | Select-Object -ExpandProperty SubnetId
    $StorageCapacity = '32'
    $StorageType = 'SSD'
    $ThroughputCapacity = '8'


    # Stack - Create security groups
    New-SecurityGroupStack `
        -Application $Application `
        -CostCenter $CostCenter `
        -Environment $Environment `
        -ResourceType $ResourceType `
        -VpcId $VpcId

    # Stack - Create FSX File System to use as File Witness in AOAG
    New-FsxFileSystemStack `
        -AWSBackupRetention $AWSBackupRetention `
        -ActiveDirectoryId $ActiveDirectoryId `
        -Application $Application `
        -AutomaticBackupRetentionDays $AutomaticBackupRetentionDays `
        -CostCenter $CostCenter `
        -DeploymentType $DeploymentType `
        -Environment $Environment `
        -ResourceType $ResourceType `
        -StorageCapacity $StorageCapacity `
        -StorageType $StorageType `
        -SubnetIds $SubnetIds `
        -ThroughputCapacity $ThroughputCapacity
}


function New-SecurityGroupStack {
    param(
        [Parameter(Mandatory=$true)][String]$Application,
        [Parameter(Mandatory=$true)][String]$CostCenter,
        [Parameter(Mandatory=$true)][String]$Environment,
        [Parameter(Mandatory=$true)][String]$ResourceType,
        [Parameter(Mandatory=$true)][String]$VpcId
    )

    # Build stack name
    $StackName = "myunity-$Environment-filewitness-sg"
    # Retrieve CFN template
    $templateBody = (Get-TemplateBodyRaw -TemplateName '20-Security\sg-fsx-aoag-filewitness.yaml');

    # Create stack
    New-Stack `
        -StackName $StackName `
        -TemplateBody $templateBody `
        -Paramaters @(
            @{ ParameterKey="Application"; ParameterValue=$Application },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="ResourceName"; ParameterValue=$StackName },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="VpcId"; ParameterValue=$VpcId}
        ) `
        -DisableRollback $true `
        -Region $Region;

}


function New-FsxFileSystemStack {
    param(
        [Parameter(Mandatory=$true)][String]$AWSBackupRetention,
        [Parameter(Mandatory=$true)][String]$ActiveDirectoryId,
        [Parameter(Mandatory=$true)][String]$Application,
        [Parameter(Mandatory=$true)][String]$AutomaticBackupRetentionDays,
        [Parameter(Mandatory=$true)][String]$CostCenter,
        [Parameter(Mandatory=$true)][String]$DeploymentType,
        [Parameter(Mandatory=$true)][String]$Environment,
        [Parameter(Mandatory=$true)][String]$ResourceType,
        [Parameter(Mandatory=$true)][String]$StorageCapacity,
        [Parameter(Mandatory=$true)][String]$StorageType,
        [Parameter(Mandatory=$true)][String]$SubnetIds,
        [Parameter(Mandatory=$true)][String]$ThroughputCapacity
    )

    $ResourceNumber = switch ($Environment) {
        'live' { '0' }
        'uat'  { '1' }
        'qa'  { '0' }
        'dev'  { '1' }
        Default { throw "Unable to determine number to use in resoure name.  Environment [$Environment] is invalid." }
    }
    # Build stack name
    $StackName = "mssql-filewitness-$($ResourceNumber)-$($Region)$($Az)"
    # Retrieve CFN template
    $templateBody = (Get-TemplateBodyRaw -TemplateName '30-DataPersistance\fsx-aoag-filewitness.yaml');

    # Get ID of security group to assign to the FSX file system's ENI.  The group was created by the previous stack.
    $SecurityGroupsStackOutputs = Get-OutputKeysFromStack -StackName "myunity-$Environment-filewitness-sg" -Region $Region;
    $FileSystemSecurityGroup = Get-OutputKeyValueFromStack -KeyName 'SecurityGroupFileWitness' -Outputs $SecurityGroupsStackOutputs;

    # Create stack
    New-Stack `
        -StackName $StackName `
        -TemplateBody $templateBody `
        -Paramaters @(
            @{ ParameterKey="AWSBackupRetention"; ParameterValue=$AWSBackupRetention },
            @{ ParameterKey="ActiveDirectoryId"; ParameterValue=$ActiveDirectoryId },
            @{ ParameterKey="Application"; ParameterValue=$Application },
            @{ ParameterKey="AutomaticBackupRetentionDays"; ParameterValue=$AutomaticBackupRetentionDays },
            @{ ParameterKey="CostCenter"; ParameterValue=$CostCenter },
            @{ ParameterKey="DeploymentType"; ParameterValue=$DeploymentType },
            @{ ParameterKey="Environment"; ParameterValue=$Environment },
            @{ ParameterKey="FileSystemSecurityGroup"; ParameterValue=$FileSystemSecurityGroup },
            @{ ParameterKey="ResourceName"; ParameterValue=$StackName },
            @{ ParameterKey="ResourceType"; ParameterValue=$ResourceType },
            @{ ParameterKey="StorageCapacity"; ParameterValue=$StorageCapacity },
            @{ ParameterKey="StorageType"; ParameterValue=$StorageType },
            @{ ParameterKey="SubnetIds"; ParameterValue=$SubnetIds },
            @{ ParameterKey="ThroughputCapacity"; ParameterValue=$ThroughputCapacity }
        ) `
        -TimeoutSeconds 1800 `
        -DisableRollback $true `
        -Region $Region;

}



try {
    Clear-Host;
    $ErrorActionPreference = 'Stop';

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
    Main -AccountParams $AccountParams -Region $Region -Environment $Environment
    $Stopwatch.Stop();
    Write-Host "AOAG File Witness resources deployment time: $($Stopwatch.Elapsed.TotalMinutes.ToString('0.00'))";
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}