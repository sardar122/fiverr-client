Using module '.\mubo_core.psm1';
$ErrorActionPreferance = 'Stop';

$AnsibleSvcPswd = $null;
$CommVltSvc = $null;

function Main {
	$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
	$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account;
	
	if ($AccountParams.IsProductionAccount -eq $true) {
		$domain = $AccountParams.Domain;
		$fqdn = "$domain.netsmartcloud.lan";
		$OU="OU=Service Accounts,OU=$domain,DC=$domain,DC=netsmartcloud,DC=lan";
	} else {
		$domain = $AccountParams.Domain;
		$fqdn = "$domain.netsmartcloud.lan";
		$OU="OU=ServiceAccounts,OU=Users,OU=$domain,DC=$domain,DC=netsmartcloud,DC=lan";
	}

	$un = 'NPC.INF.P.AnsibleSvc';
	Save-SecSecretString `
		-SecretId 'AnsibleTools' `
		-Description 'Ansible Service Account' `
		-SecretString "{
	`"ansible_service_account_user`": `"$un`",
	`"ansible_service_account_password`": `"$AnsibleSvcPswd`"
}";
	Save-AdServiceAccountWithAwsDelegatedAdmin `
		-Service 'Ansible' `
		-UserName $un `
		-Password $pass `
		-Fqdn $fqdn `
		-Ou $OU;

	$un = 'AWS.INF.P.CommVltSvc';
	Save-SecSecretString `
		-SecretId 'CommVault' `
		-Description 'CommVault Service Account' `
		-SecretString "{
	`"username`": `"$un`",
	`"password`": `"$CommVltSvc`"
}";
	Save-AdServiceAccountWithAwsDelegatedAdmin `
		-Service 'CommVault' `
		-UserName $un `
		-Password $pass `
		-Fqdn $fqdn `
		-Ou $OU;

	Save-AdSecurityGroup `
		-GroupName 'NPC.INF.MDB.DL' `
		-OU $OU `
		-Scope 'DomainLocal' `
		-Category 'Security' `
		-Description 'DBA Group' ;

	Save-AdSecurityGroup `
		-GroupName 'NPC.ADVARCH.VI.SQL' `
		-OU $OU `
		-Scope 'DomainLocal' `
		-Category 'Security' `
		-Description 'Security Group' ;
}

function Save-SecSecretString {
	param(
		[Parameter(Mandatory=$true)][String]$SecretId,
		[Parameter(Mandatory=$true)][String]$Description,
		[Parameter(Mandatory=$true)][String]$SecretString
	)

	$sec = $null;
	try {
		$sec = Get-SECSecret -SecretId $SecretId -ErrorAction SilentlyContinue;
	} catch {}

	# if Secret exists update
	if ($sec -ne $null) {
		Update-SECSecret `
			-SecretId $SecretId `
			-SecretString $SecretString `
			-Description $Description;
	} elseif ($sec -eq $null) {
		New-SECSecret `
			-Description $Description `
			-Name $SecretId `
			-SecretString $SecretString;
	}
}

function Save-AdServiceAccountWithAwsDelegatedAdmin {
	param(
		[Parameter(Mandatory=$true)][String]$Service,
		[Parameter(Mandatory=$true)][String]$UserName,
		[Parameter(Mandatory=$true)][String]$Password,
		[Parameter(Mandatory=$true)][String]$Fqdn,
		[Parameter(Mandatory=$true)][String]$Ou
	)

	# if exists update
	if ($null -eq ([ADSISearcher] "(sAMAccountName=$UserName)").FindOne()) {
		New-ADUser -Name "$Service Service Account" `
			-DisplayName "$Service Service Account" `
			-UserPrincipalName "$($UserName)@$($fqdn)" `
			-SamAccountName $UserName `
			-GivenName "$Service" `
			-Surname "Service Account" `
			-AccountPassword (ConvertTo-SecureString -string $Password -AsPlainText -Force) `
			-Enabled $true `
			-Path $Ou `
			-ChangePasswordAtLogon $false `
			–PasswordNeverExpires $true `
			-CannotChangePassword $true `
			-Description "$Service Service Account" `
			-server $Fqdn;

		Add-ADGroupMember -Identity 'AWS Delegated Administrators' -Members $UserName;
	} else {
		Write-Host "User '$UserName' already exists." -ForegroundColor Yellow;
		Set-ADAccountPassword `
			-Identity $UserName `
			-Reset `
			-NewPassword (ConvertTo-SecureString -AsPlainText $Password -Force)
	}
}

function Save-AdSecurityGroup {
	param(
		[Parameter(Mandatory=$true)][String]$GroupName,
		[Parameter(Mandatory=$true)][String]$OU,
		[Parameter(Mandatory=$true)][String]$Scope,
		[Parameter(Mandatory=$true)][String]$Category,
		[Parameter(Mandatory=$true)][String]$Description
	)
	if ($null -eq (Get-ADGroup -LDAPFilter "(sAMAccountName=$($GroupName))")) {
        Write-Output "Creating...Security Group '$($GroupName)'."
        $groupProps = @{

          Name          = $GroupName
          Path          = $OU
          GroupScope    = $Scope
          GroupCategory = $Category
          Description   = $Description

          }

        New-ADGroup @groupProps;
    } else {
        Write-Host "Security Group '$($GroupName)' already exists." -ForegroundColor Yellow;
    }    
}

if ($AnsibleSvcPswd -eq $null) {
	Write-Error '$AnsibleSvcPswd must be set.  This should be a known value so that test and prod match.'
}
if ($CommVltSvc -eq $null) {
	Write-Error '$CommVltSvc must be set.  This should be a known value so that test and prod match.'
}

Main;