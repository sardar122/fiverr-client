Using module '.\mubo_core.psm1';
$ErrorActionPreferance = 'Stop'

$SecretId = 'AD_Service_Account'


$CallerIdentity = Get-STSCallerIdentity -ErrorAction Stop;
$AccountParams = Get-AccountParameters -AccountNumber $CallerIdentity.Account;

$json = '{
    "username": "ntst.ad.svc",
    "password": "",
    "domain": "",
    "fqdn": ""
}' | ConvertFrom-Json

$json.password = ("!@#$%^&*0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz".tochararray() | sort {Get-Random})[0..20] -join ''

if ($AccountParams.IsProductionAccount -eq $true) {
    $domain = $AccountParams.Domain;
    $json.domain = $domain;
    $json.fqdn = "$domain.netsmartcloud.lan";
    $OU="OU=Service Accounts,OU=$domain,DC=$domain,DC=netsmartcloud,DC=lan";
} else {
    $domain = $AccountParams.Domain;
    $json.domain = $domain;
    $json.fqdn = "$domain.netsmartcloud.lan";
    $OU="OU=ServiceAccounts,OU=Users,OU=$domain,DC=$domain,DC=netsmartcloud,DC=lan";
}

try {
    Get-SECSecret -SecretId $SecretId -ErrorAction SilentlyContinue;
} catch {
    New-SECSecret `
        -Description 'AD Service Account used to join and unjoin domain' `
        -Name $SecretId `
        -SecretString ($json | ConvertTo-Json).ToString();

    New-ADUser -Name "NTST AD Service Account" `
        -DisplayName "NTST AD Service Account" `
        -UserPrincipalName "$($json.username)@$($json.fqdn)" `
        -SamAccountName $json.username `
        -GivenName "NTST AD" `
        -Surname "Service Account" `
        -AccountPassword (ConvertTo-SecureString -string $json.password -AsPlainText -Force) `
        -Enabled $true `
        -Path $OU `
        -ChangePasswordAtLogon $false `
        –PasswordNeverExpires $true `
        -CannotChangePassword $true `
        -Description 'AD Service Account used to join and unjoin domain' `
        -server $json.fqdn;

    Add-ADGroupMember -Identity 'AWS Delegated Administrators' -Members $json.username;
}