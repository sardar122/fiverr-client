Using module '.\mubo_core.psm1';

$Region = 'us-east-2'

try {

    $CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
    $AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account;

    # get existing resources
    if ($CallerIdentity.Account -eq 434495414204) {
        $instanceId = (Get-CFNStackResourceList -StackName "$($AccountParams.StackNamePrefix)-mgmt-bastion-windows-0" -LogicalResourceId "Ec2Instance" -Region $Region).PhysicalResourceId;
    } elseif ($CallerIdentity.Account -eq 988099092108) {
        $instanceId = Get-OutputKeyValueFromStack -StackName "pvmuboshw00-east-2" -KeyName 'Ec2Instance' -Region $Region;
    } else {  
        $json = $null;
        Write-Error "Account '$AccountNumber' not implemented." -ErrorAction Stop;
    }

    $VpcId = Get-OutputKeyValueFromStack -StackName 'myunity-mgmt-vpc' -KeyName VpcId -Region $Region;

    # Create myUnity Bastion Security Group
    $sn = [String]::Join('-', $AccountParams.StackNamePrefix, $AccountParams.EnvironmentMgmt, 'bastion-app-rdp');
    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\sg-ec2-bastion-myunity.yaml");

    New-Stack `
        -StackName $sn `
        -TemplateBody $templateBody `
        -Paramaters @( 
            @{ ParameterKey="Application"; ParameterValue=$AccountParams.Application },
            @{ ParameterKey="ResourceName"; ParameterValue='bastion sg' },
            @{ ParameterKey="CostCenter"; ParameterValue=$AccountParams.CostCenter },
            @{ ParameterKey="Environment"; ParameterValue=$AccountParams.EnvironmentMgmt },
            @{ ParameterKey="ResourceType"; ParameterValue='Support System' },
            @{ ParameterKey="VpcId"; ParameterValue=$VpcId }
        ) `
        -DisableRollback $true `
        -Region $Region;
    $BastionSg = Get-OutputKeyValueFromStack -StackName $sn -KeyName SecurityGroup -Region $Region;

    # Attach Bastion SG to Bastion Server.
    $CurrentGroups = @(((Get-EC2Instance -InstanceId $InstanceId).Instances[0]).SecurityGroups | %{ $_.GroupId })
    if ($CurrentGroups -notcontains $BastionSg ) {
        $CurrentGroups += $BastionSg;
        Edit-EC2InstanceAttribute -InstanceId $InstanceId -Group $CurrentGroups;
    }

} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}