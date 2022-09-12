param(
    [Parameter(Mandatory=$true)][String]$ec2_instance_id,
    [Parameter(Mandatory=$true)][String]$DriveLetter,
    [Parameter(Mandatory=$true)][String]$DriveLabel
)

$runPSCommand = Send-SSMCommand `
    -InstanceIds @("$ec2_instance_id") `
    -DocumentName "AWS-RunPowerShellScript" `
    -Comment "testing" `
    -Parameter @{'commands'=@('
        $ErrorActionPreference = "Stop"
        try {
            # Windows side: locate the ebs volume you just attached
            $diskNumber = (Get-Disk | ? { ($_.PartitionStyle -eq "RAW") }).Number
            
            if ($diskNumber -eq $null) {
                Write-Error "Could not retrieve drive number.";
            }
        
            # initialize the disk
            Initialize-Disk -Number $diskNumber
            Write-Host "Initialized DiskNumber `"$diskNumber`""
                    
            # create max-space partition, assign drive letter, make "active"
            $part = New-Partition -DiskNumber $diskNumber -UseMaximumSize -DriveLetter "' + $DriveLetter + '"
            Write-Host "Partitioned DiskNumber `"$diskNumber`" with drive letter `"' + $DriveLetter + '`""
                    
            # format the new drive
            Format-Volume -DriveLetter $part.DriveLetter -NewFileSystemLabel "' + $DriveLabel + '" -Confirm:$FALSE
            Write-Host "Formatted volume "' + $DriveLabel + '" ($($part.DriveLetter):)"
        } catch {
            Write-Error "An error occurred during drive mount. ($_)"
        }
    ')}

    do {  
        Start-Sleep -Seconds 5;      
        $return = Get-SSMCommandInvocation `
            -CommandId $runPSCommand.CommandId `
            -Details $true `
            -InstanceId $ec2_instance_id | Select-Object -ExpandProperty CommandPlugins
    } while ($return.ResponseCode -eq -1)

    Write-Host "Command Status: $($return.Status)"
    Write-Host "Command Output: $($return.Output)"
    if ($return.ResponseCode -ne 0) {
        Write-Error "Mounting the volume to the Ec2 instance failed.  Please review logs."
    }