$stackID='t1';
$region='us-east-2'
$clusterName = "mubo-svcs-$stackID-$region-cluster"
$DesiredCount = 1;
$targetService = $null;
#$targetService = 'workflow';
#$targetService = 'interop-outbound-service'

#get services in cluster
if (-Not ([String]::IsNullOrWhiteSpace($targetService))) {
    $svcs = (Get-ECSClusterService -Cluster $clusterName -Region $region) | Where-Object {$_ -like "*$targetService*"}
} else {
    $svcs = Get-ECSClusterService -Cluster $clusterName -Region $region
}

$svcs | ForEach-Object {
    try {
        Write-host "Adjusting desired count for service '$_' to $DesiredCount."
        $svc = (Get-ECSService -Cluster $clusterName -Service $_ -Region $region).Services[0];

        if ($svc -ne $null) {
            Update-ECSService `
                -Cluster $clusterName `
                -DesiredCount $DesiredCount `
                -Service $svc.ServiceName `
                -Region $region;
        }
    } catch {
        Write-Error "Error: Adjusting desired count for service '$_' to $DesiredCount failed."
    }
}