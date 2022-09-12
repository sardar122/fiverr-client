Using module '.\mubo_core.psm1';

$stackID='t7'
$region='us-east-2'


<################################################################################################################>
$ErrorActionPreference = 'Stop';

$sp = [StackProperties]::new();
function Main {
    <#############  First Pass  #################>
    $stacks = @()
    $sp.Services | ForEach-Object { $stacks += (Get-ServiceStackName -StackID $stackID -ServicePrefix $_  -Service service) };
    $stacks += @(
        "mubo-web-$stackID-env-front-stack",
        "mubo-web-$stackID-env-back-stack");
    Delete-Stacks `
        -stackNames $stacks `
        -region $region;

    <#############  Second Pass  #################>

    $stacks = @()
    $sp.Services | ForEach-Object { $stacks += (Get-ServiceStackName -StackID $stackID -ServicePrefix $_  -Service task-definition) }
    $stacks +=  @(
            "mubo-svcs-$stackID-cluster-stack"
            "mubo-svcs-$stackID-log-group-stack"
            "mubo-web-$stackID-app-stack"
        )
    Delete-Stacks `
        -stackNames $stacks `
        -region $region;
    
}

function Delete-Stacks {
    param(
        [Parameter(Mandatory=$true)][String[]]$stackNames,
        [Parameter(Mandatory=$true)][String]$region
    )

    $sb = {
        param(
            [Parameter(Mandatory=$true)][String]$stackName,
            [Parameter(Mandatory=$true)][String]$region
        )

        $threadID="[$([guid]::NewGuid())]";

        if (Test-CFNStack -StackName $stackName -Region $region) {
            Write-Host "$threadID Deleteing stack $stackName.";
            Remove-CFNStack -StackName $stackName -Force -Region $region;
            Wait-CFNStack -StackName $stackName -Status DELETE_COMPLETE -Timeout 900 -Region $region;
            Write-Host "$threadID Deleteing stack '$stackName' complete.";
        } else {
            Write-Host "$threadID Stack $stackName was not found!" -ForegroundColor Red;
        }
    }

    $stackNames | ForEach-Object { 
        $sn = $_;
        Write-Host "Starting job to delete stack '$sn'.";
        Start-Job -ScriptBlock $sb -ArgumentList $sn,$region | Out-Null;
        sleep 1;
    }
    #Wait for all jobs to finish.
    Get-Job | Wait-Job
    #Get information from each job.
    foreach($job in Get-Job){
        $info= Receive-Job -Id ($job.Id)
    }
    #Remove all jobs created.
    # Get-Job | Stop-Job | Remove-Job
    Get-Job | Remove-Job
}

Main;