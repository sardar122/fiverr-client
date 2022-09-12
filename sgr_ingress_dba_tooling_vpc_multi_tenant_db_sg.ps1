
#$multiTenantStackName = 'dev-ec2-mssql-sg-multitenant'
#$multiTenantStackName = 'qa-ec2-mssql-sg-multitenant'
$multiTenantStackName = 'uat-ec2-mssql-sg-multitenant'

$Region = 'us-east-2';

$multiTenantSgGroupId = ((Get-CFNStack `
        -StackName $multiTenantStackName `
        -Region $Region).Outputs | Where-Object { $_.OutputKey -eq 'SqlSecurityGroup'} `
                | Select-Object -First 1 -Property OutputValue).OutputValue ;


$dbaToolsGroupId = ((Get-CFNStack `
        -StackName 'mubo-sg-ec2-dba-tools-mssql' `
        -Region $Region).Outputs | Where-Object { $_.OutputKey -eq 'SecurityGroup'} `
                | Select-Object -First 1 -Property OutputValue).OutputValue ;

function Grant-SecurityGroupIngress {
    param(
        [string]$TargetSgGroupId,
        [string]$SourceSgGroupId,
        [string]$IpProtocol,
        [string]$Port
    )

    $vpc  = ((Get-Ec2Vpc -VpcId (Get-EC2SecurityGroup -GroupId $multiTenantSgGroupId).VpcId).Tags | ? { $_.key -eq "Environment" } ).value

    $ug = New-Object Amazon.EC2.Model.UserIdGroupPair
    $ug.GroupId = $SourceSgGroupId
    $ug.Description = "SCRIPT ADDED - $vpc vpc MSX and TSX SQL Server Communication"

    $IpPermission = New-Object Amazon.EC2.Model.IpPermission
    $IpPermission.IpProtocol = $IpProtocol
    $IpPermission.ToPort = $Port
    $IpPermission.FromPort = $Port
    $IpPermission.UserIdGroupPairs = $ug

    Grant-EC2SecurityGroupIngress -GroupId $TargetSgGroupId -IpPermission $IpPermission -Region $region | Out-Null;	
}

function Add-SecurityGroupIngress {
    param (
        [string]$TargetSgGroupId,
        [string]$SourceSgGroupId,
        [string]$IpProtocol,
        [string]$Port
    )
    if (-Not ( Get-EC2SecurityGroupRule -Filter @(
                @{Name='group-id';Values=$TargetSgGroupId} `
            ) | Where-Object { ($_.IpProtocol -eq $ipProtocol) -and ($_.FromPort -eq $port) -and ($_.ToPort -eq $port) -and ($_.ReferencedGroupInfo.GroupId -eq $multiTenantSgGroupId) })) {
        Write-Host "Adding sgr for port: $Port and source:$SourceSgGroupId."
        Grant-SecurityGroupIngress -TargetSgGroupId $TargetSgGroupId -SourceSgGroupId $SourceSgGroupId -IpProtocol $IpProtocol -Port $Port
    } else {
        Write-Host "Sgr for port: $Port and source:$SourceSgGroupId already exists." -ForegroundColor Yellow
    }
}

Add-SecurityGroupIngress -TargetSgGroupId $dbaToolsGroupId -SourceSgGroupId $multiTenantSgGroupId -IpProtocol 'tcp' -Port 139;
Add-SecurityGroupIngress -TargetSgGroupId $dbaToolsGroupId -SourceSgGroupId $multiTenantSgGroupId -IpProtocol 'tcp' -Port 1433;