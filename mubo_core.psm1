function Get-ServiceStackPrefix {
    Return 'mubo-svcs';
}

function Get-ServiceStackName {
    param(
        [Parameter(Mandatory=$true)][String]$StackID,
        [Parameter(Mandatory=$false)][String]$ServicePrefix,
        [Parameter(Mandatory=$true)]
            [ValidateSet('log-group','cluster','task-definition','service')]
            [String]$Service
    )
    New-StackName -StackPrefix (Get-ServiceStackPrefix) `
        -StackID $StackID `
        -ServicePrefix $ServicePrefix `
        -Service $Service;
}
function Get-WebStackName {
    param(
        [Parameter(Mandatory=$true)][String]$StackID,
        #[Parameter(Mandatory=$false)][String]$ServicePrefix = '',
        [Parameter(Mandatory=$true)]
            [ValidateSet('log-group','cluster','task-definition','service')]
            [String]$Service
    )
    New-StackName -StackPrefix 'mubo_web' `
        -StackID $StackID `
        -ServicePrefix $ServicePrefix `
        -Service $Service;
}
function New-StackName {
    param(
            [Parameter(Mandatory=$true)][String]$StackPrefix,
            [Parameter(Mandatory=$true)][String]$StackID,
            [Parameter(Mandatory=$false)][String]$ServicePrefix = $Null,
            [Parameter(Mandatory=$true)]
                [ValidateSet('log-group','cluster','task-definition','service')]
                [String]$Service
    ) 

    if (@('task-definition','service') -contains $Service -and [String]::IsNullOrWhiteSpace($ServicePrefix)) {
        Write-Error "$Service must be prefixed with the sevice name."
    }

    if (-not ([String]::IsNullOrWhiteSpace($ServicePrefix))) {
        $svc = [String]::Join('-', @($ServicePrefix, $Service));
    } else {
        $svc = $Service;
    }

    ([String]::Join('-', @($StackPrefix, $StackID, $svc, 'stack'))).ToLower();
}

function New-StackWithCapabilities  {
    param (
        [Parameter(Mandatory=$true)][String]$StackName,
        [Parameter(Mandatory=$true)][String]$TemplateBody,
        [Parameter(Mandatory=$false)][Object[]]$Paramaters = $null,
        [Parameter(Mandatory=$true)][String[]]$Capability,
        [Parameter(Mandatory=$true)][Bool]$DisableRollback,
        [Parameter(Mandatory=$true)][String]$Region,
        [Parameter(Mandatory=$false)][Int]$TimeoutSeconds
    )
    try {
        if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = 300 }

        if (-Not (Test-CFNStack -StackName $StackName)) {
            Write-Host "Creating stack: '$StackName'";
            if ($Paramaters) {
                New-CFNStack -StackName $StackName `
                    -Capability $Capability `
                    -TemplateBody $TemplateBody `
                    -Parameter $Paramaters `
                    -DisableRollback $DisableRollback `
                    -Region $Region | Out-Null;
            } else {
                New-CFNStack -StackName $StackName `
                    -Capability $Capability `
                    -TemplateBody $TemplateBody `
                    -DisableRollback $DisableRollback `
                    -Region $Region | Out-Null;
            }
            Wait-CFNStack -StackName $stackName -Status CREATE_COMPLETE -Timeout $TimeoutSeconds | Out-Null;

            Write-Host "Success creating stack '$StackName'.";
        } else {
            Write-Host "Stack '$StackName' exists.";
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red;
        Write-Host $_.ScriptStackTrace -ForegroundColor Red;
        Write-Error "An error occured creating stack $StackName.";
    }
}

function New-Stack {
    param (
        [Parameter(Mandatory=$true)][String]$StackName,
        [Parameter(Mandatory=$true)][String]$TemplateBody,
        [Parameter(Mandatory=$false)][Object[]]$Paramaters = $null,
        [Parameter(Mandatory=$true)][Bool]$DisableRollback,
        [Parameter(Mandatory=$true)][String]$Region,
        [Parameter(Mandatory=$false)][Int]$TimeoutSeconds
    )
    try {
        if ($TimeoutSeconds -eq 0) { $TimeoutSeconds = 300 }

        if (-Not (Test-CFNStack -StackName $StackName)) {
            Write-Host "Creating stack: '$StackName'";
            if ($Paramaters) {
                New-CFNStack -StackName $StackName `
                    -TemplateBody $TemplateBody `
                    -Parameter $Paramaters `
                    -DisableRollback $DisableRollback `
                    -Region $Region | Out-Null;
            } else {
                New-CFNStack -StackName $StackName `
                    -TemplateBody $TemplateBody `
                    -DisableRollback $DisableRollback `
                    -Region $Region | Out-Null;
            }
            Wait-CFNStack -StackName $stackName -Status CREATE_COMPLETE -Timeout $TimeoutSeconds | Out-Null;

            Write-Host "Success creating stack '$StackName'.";
        } else {
            Write-Host "Stack '$StackName' exists.";
        }
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red;
        Write-Host $_.ScriptStackTrace -ForegroundColor Red;
        Write-Error "An error occured creating stack $StackName.";
    }
}

function Get-OutputKeysFromStack {
    param(
        [Parameter(Mandatory=$true)][String]$StackName,
        [Parameter(Mandatory=$true)][String]$Region
    ) 
    $OutputValue = (Get-CFNStack `
        -StackName $StackName `
        -Region $Region).Outputs `
            | Select-Object -Property OutPutKey, OutputValue;
    Return $OutputValue;
}

function Get-OutputKeyValueFromStack {
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory=$true,ParameterSetName='Default')]
            [String]$StackName,
        [Parameter(Mandatory=$true,ParameterSetName='Default')]
        [Parameter(Mandatory=$true,ParameterSetName='KVP')]
            [String]$KeyName,
        [Parameter(Mandatory=$true,ParameterSetName='Default')]
            [String]$Region,
        [Parameter(Mandatory=$true,ParameterSetName='KVP' )]
            [Object[]]$Outputs
    ) 
    if ($PSCmdlet.ParameterSetName -eq 'KVP') {
        $OutputValue = $Outputs `
                | Where-Object { $_.OutputKey -eq $KeyName} `
                | Select-Object -First 1 -Property OutputValue;
    } else {
        $OutputValue = Get-OutputKeysFromStack `
            -StackName $StackName `
            -Region $Region `
                | Where-Object { $_.OutputKey -eq $KeyName} `
                | Select-Object -First 1 -Property OutputValue;
    }
    Return $OutputValue.OutputValue.ToString();
}

function Get-ScriptDirectory {
    param([Parameter(Mandatory=$false)][String]$PostPath = '') 

    try {
        [System.IO.Path]::Combine($(Split-Path $MyInvocation.ScriptName), $postPath)
    } catch {
        [System.IO.Path]::Combine($(Get-Location), $postPath)
    }
}

function Get-TemplateBodyRaw {
    param (
        [Parameter(Mandatory=$true)][String]$TemplateName
    )
    $(Get-Content -Path "$([system.IO.Path]::Combine($(Get-ScriptDirectory), '..' , 'Cloudformation', $TemplateName))" -Raw);
}

function Get-ClusterName {
    param(
        [Parameter(Mandatory=$true)][String]$StackID,
        [Parameter(Mandatory=$false)][String]$Region
    )
    $stackName = Get-ServiceStackName -StackID $StackID -Service cluster;
    Get-OutputKeyValueFromStack -StackName $stackName -KeyName 'ClusterName' -Region $Region;
}

function Get-LogGroupName {
    param(
        [Parameter(Mandatory=$true)][String]$StackID,
        [Parameter(Mandatory=$false)][String]$Region
    )
    $stackName = Get-ServiceStackName -StackID $StackID -Service log-group;
    Get-OutputKeyValueFromStack -StackName $stackName -KeyName 'LogGroupName' -Region $Region;
}

function Get-AccountParameters {
    param(
         [Parameter(Mandatory=$true)][Int64]$AccountNumber
    )

    $json = '{
        "AccountNumber": "",
	    "StackNamePrefix": "myunity",
        "Application": "myunity",
	    "CostCenter": "",
        "EnvironmentProd": "",
        "EnvironmentNonProd": "",
        "EnvironmentMgmt": "mgmt",
        "AvailabilityZonePrimary": "",
        "AvailabilityZoneSecondary": "",
        "AvailabilityZoneTertiary": "",
        "ProductFamily": "myunity",
        "ProductSKU": "-",
        "Domain": "",
        "IsProductionAccount": ""
    }' | ConvertFrom-Json;

    $json.AccountNumber = $AccountNumber;

    if ($AccountNumber -eq 434495414204) {
        $json.CostCenter = '5027 RD - myUnity Homecare and Hospice';
        $json.EnvironmentProd = 'qa';
        $json.EnvironmentNonProd = 'dev';
        $json.AvailabilityZonePrimary = 'a'
        $json.AvailabilityZoneSecondary = 'b'
        $json.AvailabilityZoneTertiary = 'c'
        $json.Domain = 'myunity-test';
        $json.IsProductionAccount = $false;
        return $json;
    } elseif ($AccountNumber -eq 988099092108) {
        $json.CostCenter = '2016 Hosting - Post Acute';
        $json.EnvironmentProd = 'prod';
        $json.EnvironmentNonProd = 'uat';
        $json.AvailabilityZonePrimary = 'a'
        $json.AvailabilityZoneSecondary = 'c'
        $json.AvailabilityZoneTertiary = 'b'
        $json.Domain = 'myunity-prod';
        $json.IsProductionAccount = $true;
        return $json;
    } else {  
        $json = $null;
        Write-Error "Account '$AccountNumber' not implemented." -ErrorAction Stop;
    }
}

class StackProperties {
    [ValidatePattern('^[tsp][1-9][0-9]*$')][String]$StackID;
    [ValidateSet('us-east-2')][String]$Region;
    [String[]]$ClusterSecurityGroup;
    [String]$TaskRoleNameParameter;
    [String]$TargetVersion;
    [String]$Description;
    [ValidateSet('dev','test','staging','uat','train','prod')][String]$EnvironmentType;
    [String]$VpcIdParameter;
    [String[]]$PublicSubnetsParameter;
    [String[]]$PrivateSubnetsParameter;
    [String]$LbCertArnParameter;
    [ValidateSet(1,2)][Int]$EbStalkEnvironmentCount = 2;
    [Int]$ServiceLogsRetentionDaysParameter = 7;
    [Int]$MaximumPercentParameter = 100;
    [Int]$MinimumHealthyPercentParameter = 0;
    [Int]$DesiredCountParameter = 0;
    [Bool]$DisableRollback;
    [String[]]$Services = @(
        'Workflow'
        'Telephony'
        'Guardiant'
        'HL7'
        'InteropOutbound'
        'InteropInbound'
        'RemoteCommAgent'
        'JobScheduler'
        'OfflineMtf');
    #TODO: Implement Audit, Archive, HL7 exchange service (CRM)
    [String]$AppELBSecurityGroupParameter;
    [String]$AppSecurityGroupParameter;
    [String]$BastionHostSecurityGroupParameter;
    [String]$DB_Name;
    [String]$Application;
    [String]$ResourceType;
    [String]$CostCenter;
    [String]$AutomaticPatches;
    [String]$PatchGroup;

    StackProperties () {
    }

    StackProperties (
        [String]$StackID,
        [String]$Region,
        [String[]]$ClusterSecurityGroup,
        [String]$TaskRoleNameParameter,
        [String]$TargetVersion,
        [String]$Description,
        [String]$EnvironmentType,
        [String]$VpcIdParameter,
        [String[]]$PublicSubnetsParameter,
        [String[]]$PrivateSubnetsParameter,
        [String]$LbCertArnParameter,
        [Bool]$DisableRollback,
        [String]$AppELBSecurityGroupParameter,
        [String]$AppSecurityGroupParameter,
        [String]$BastionHostSecurityGroupParameter,
        [String]$DB_Name,
        [String]$Application,
        [String]$ResourceType,
        [String]$CostCenter
    ){
        $this.StackID = $StackID;
        $this.Region = $Region;
        $this.ClusterSecurityGroup = $ClusterSecurityGroup;
        $this.TaskRoleNameParameter = $TaskRoleNameParameter;
        $this.TargetVersion = $TargetVersion;
        $this.Description = $Description;
        $this.EnvironmentType = $EnvironmentType;
        $this.VpcIdParameter = $VpcIdParameter;
        $this.PublicSubnetsParameter = $PublicSubnetsParameter;
        $this.PrivateSubnetsParameter = $PrivateSubnetsParameter;
        $this.LbCertArnParameter = $LbCertArnParameter;
        $this.DisableRollback = $DisableRollback;
        $this.AppELBSecurityGroupParameter = $AppELBSecurityGroupParameter;
        $this.AppSecurityGroupParameter = $AppSecurityGroupParameter;
        $this.BastionHostSecurityGroupParameter = $BastionHostSecurityGroupParameter;
        $this.DB_Name = $DB_Name;
        $this.Application = $Application;
        $this.ResourceType = $ResourceType;
        $this.CostCenter = $CostCenter;
    }
}