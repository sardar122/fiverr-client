Using module '.\mubo_core.psm1';

CLEAR;

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

    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\ebstalk-create-ec2-role.yml");
    New-StackWithCapabilities `
        -StackName 'ebstalk-create-ec2-role' `
        -TemplateBody $templateBody `
        -Capability @('CAPABILITY_NAMED_IAM') `
        -DisableRollback $true `
        -Region $Region;

    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\ebstalk-create-service-role.yml");
    New-StackWithCapabilities `
        -StackName 'ebstalk-create-service-role' `
        -TemplateBody $templateBody `
        -Capability @('CAPABILITY_NAMED_IAM') `
        -DisableRollback $true `
        -Region $Region;

    $templateBody = (Get-TemplateBodyRaw -TemplateName "20-Security\ebstalk-create-prerequisites.yaml");
    New-StackWithCapabilities `
        -StackName 'ebstalk-create-prerequisites' `
        -TemplateBody $templateBody `
        -Capability @('CAPABILITY_IAM') `
        -Paramaters @( 
            @{ ParameterKey="InstanceId"; ParameterValue=$instanceId },
            @{ ParameterKey="SecretID"; ParameterValue='AD_Service_Account' },
            @{ ParameterKey="ADOrgUnit"; ParameterValue="OU=BeanstalkHosts,OU=Computers,OU=$($AccountParams.Domain),DC=$($AccountParams.Domain),DC=netsmartcloud,DC=lan" },
            @{ ParameterKey="AppTag"; ParameterValue=$AccountParams.Application },
            @{ ParameterKey="DomainName"; ParameterValue=$($AccountParams.Domain) }
        ) `
        -DisableRollback $true `
        -Region $Region;
} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}