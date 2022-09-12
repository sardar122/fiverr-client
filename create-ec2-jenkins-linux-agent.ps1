Using module '.\mubo_core.psm1';

$index = 1 # Need for uniqueness
$VpcId = ''
$region = 'us-east-2'
$baseDriveSizeGB = 50;

<#-----------------------------------------------------------------------------------------------------------------#>

try {
    $CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
    $AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account;

    # Get private subnet for az a
    $subnetID = (Get-EC2Subnet -Filter @{Name='tag:Name';Values='myunity-mgmt-private-us-east-2a'}).SubnetId;
    $iamInstanceProfile = (Get-CFNStackResource -StackName 'myunity-mgmt-jenkins-windows-0' -LogicalResourceId 'Ec2InstanceProfile').PhysicalResourceId;
    $securityGroupId = Get-OutputKeyValueFromStack `
        -StackName 'myunity-mgmt-jenkins-ecs-service' `
        -KeyName 'HostsSG' `
        -Region $region;

    $stackName="myunity-mgmt-jenkins-linux-$index";
    $templateBody = (Get-TemplateBodyRaw -TemplateName '40-Compute\ec2-linux.yaml');
    Write-Host "Creating $StackName";
    if (-Not (Test-CFNStack -StackName $stackName)) {
        New-CFNStack -StackName "$stackName" `
                -TemplateBody $templateBody `
                -Parameter @( 
                @{ ParameterKey="Application"; ParameterValue="$($AccountParams.Application)" },
                @{ ParameterKey="Environment"; ParameterValue="mgmt" },
                @{ ParameterKey="InstanceType"; ParameterValue="m5.large" },
                @{ ParameterKey="KeyName"; ParameterValue="myunity-mgmt-$region" },
                @{ ParameterKey="SubnetId"; ParameterValue="$subnetID" },
                @{ ParameterKey="SecurityGroupIds"; ParameterValue="$securityGroupId" },
                @{ ParameterKey="CostCenter"; ParameterValue="$($AccountParams.CostCenter)" },
                @{ ParameterKey="ResourceType"; ParameterValue="Support System" },
                @{ ParameterKey="IamInstanceProfile"; ParameterValue="$iamInstanceProfile" },
                @{ ParameterKey="AWSBackupRetention"; ParameterValue="14days" },
                @{ ParameterKey="AutomaticPatches"; ParameterValue="general-prod" },
                @{ ParameterKey="PatchGroup"; ParameterValue="general-amazonlinux2-prod" },
                @{ ParameterKey="BaseDriveSize"; ParameterValue="$baseDriveSizeGB" },
                @{ ParameterKey="Function"; ParameterValue="JenkinsBuildAgent" }
                ) `
                -DisableRollback $true `
                -Region $region;
        Wait-CFNStack -StackName $stackName -Status CREATE_COMPLETE -Timeout $(30  * 60);
        $msg = "Success creating stack.";
    } else {
        $msg = "Stack $stackName already exists.";
    }
    Write-Host $msg;

    # TODO:  Script in attaching to jenkins instance
    # TODO:  Script in Installing Docker
    # see https://confluence.ntst.com:8443/pages/viewpage.action?pageId=24477738#:~:text=sdk%2Derrors/netsdk1064-,AWS%20Linux%20Build%20Node%20Setup,-Created%20an%20Amazon
    <#  Just knows of manual steps
        ssh -i "C:\Users\jhicks1\Desktop\myunity-mgmt-us-east-2.pem" ec2-user@10.66.149.28

sudo yum update

For JDK 17  This is in LTS by Oracal but not offically supported by Jenkins

	wget https://download.java.net/java/GA/jdk17/0d483333a00540d886896bac774ff48b/35/GPL/openjdk-17_linux-x64_bin.tar.gz
	tar xvf openjdk-17_linux-x64_bin.tar.gz
	sudo mv jdk-17 /opt/


	sudo tee /etc/profile.d/jdk.sh <<EOF
	export JAVA_HOME=/opt/jdk-17
	export PATH=\$PATH:\$JAVA_HOME/bin
	EOF

	source /etc/profile.d/jdk.sh
	echo $JAVA_HOME
	java -version
	whereis java


For JDK 11 This an 8 is supported by Jankins.....choosing this for now
	sudo su -
	amazon-linux-extras install java-openjdk11 -y
	java -version

sudo useradd jenkins-slave1
sudo su - jenkins-slave1
ssh-keygen -t rsa -N "" -f /home/jenkins-slave1/.ssh/id_rsa
cd .ssh
cat id_rsa.pub > authorized_keys
chmod 700 authorized_keys

more id_rsa

logout
sudo amazon-linux-extras install docker
sudo service docker start
sudo usermod -a -G docker ec2-user
sudo chkconfig docker on
sudo yum install -y git
sudo reboot

log back in 
    sudo chmod 666 /var/run/docker.sock
    sudo usermod -aG docker myunity-reader
    newgrp docker


On master Server
    ssh -i "C:\Users\jhicks1\Desktop\myunity-mgmt-us-east-2.pem" ec2-user@10.66.150.72
    sudo mkdir -p /var/lib/jenkins/.ssh
    cd /var/lib/jenkins/.ssh
    cd ..
    sudo chmod 777 .ssh
    cd .ssh
    sudo ssh-keyscan -H 10.66.149.28 >>/var/lib/jenkins/.ssh/known_hosts
    sudo chown jenkins:jenkins known_hosts
    sudo chmod 700 known_hosts
    
    #>

} catch {
    Throw $_;
} finally {
    Remove-Module -Name mubo_core -Force;
}