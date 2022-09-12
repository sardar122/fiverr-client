Param( [Parameter(Mandatory=$false)][string]$VolumeName = "",
       [Parameter(Mandatory=$false)][string]$VolumeId = "",
       [Parameter(Mandatory=$false)][int32]$Iops = 3000,
       [Parameter(Mandatory=$false)][int32]$Throughput = 125)

Import-Module AWSPowerShell

[bool]$VolumeNameSpecified = ![string]::IsNullOrWhitespace($VolumeName);
[bool]$VolumeIdSpecified = ![string]::IsNullOrWhitespace($VolumeId);
[Amazon.EC2.Model.Volume[]]$Volumes = $null;
[Amazon.EC2.Model.Volume]$Volume = $null;

if (!$VolumeNameSpecified -and !$VolumeIdSpecified) {
    Write-Host "VolumeName or VolumeId must be specified.";
    exit 1;
}
elseif ($VolumeNameSpecified -and $VolumeIdSpecified) {
    Write-Host "Specify either VolumeName or VolumeId, but not both.";
    exit 1;
}
elseif ($VolumeNameSpecified) {
    #If VolumeName was specified, use it to discover the VolumeId
    $Volumes = Get-EC2Volume -Filter @{ Name="tag:Name" ; Value="$VolumeName" }
    if ($Volumes.Count -eq 0) {
        Write-Host "Unable to find VolumeName: $VolumeName";
        exit 1;
    }
    elseif ($Volumes.Count -gt 1) {
        Write-Host "More than one volume matched VolumeName: $VolumeName";
        exit 1;
    }
    else {
        $VolumeId = $Volumes[0].VolumeId
    }
}

#Now we should have a VolumeId, supplied or discovered
$Volumes = Get-EC2Volume -VolumeId $VolumeId;
if ($Volumes.Count -eq 0) {
    Write-Host "Unable to find VolumeId: $VolumeId";
    exit 1;
}
elseif ($Volumes.Count -gt 1) {
    Write-Host "More than one volume matched VolumeId: $VolumeId";
    exit 1;
}
$Volume = $Volumes[0];

#Check VolumeState
if (!($Volume.State.Value -eq "available" -or $Volume.State.Value -eq "in-use")) {
    Write-Host "VolumeState must be Available or InUse. Volume.State: $($Volume.State.Value)";
    exit 1;
}

Edit-EC2Volume -VolumeId $VolumeId -Iops $Iops -Throughput $Throughput;