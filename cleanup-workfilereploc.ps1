Param( [string]$BucketName = "")

#Default retention is 7 days. Anything else not named in a filter, notably including /Reports/, will be purged after 7 days.
[string[]]$InfiniteRetention = @('CustomReports', 'Images', 'ProductImages', 'Logos', 'MultiMedia', 'TrainingMedia', 'CRM/Document Library');
[string[]]$365DayRetention = @('HL7', 'ReimbRules');
[string[]]$90DayRetention = @('Billing', 'ImportedFiles', 'Payroll', 'CCD/Inbound', 'RTAChecks', 'Clinical', 'PatientImport');

#Pattern matching for special files
[string[]]$InfiniteFileRetention = @('*GLX_*.txt', '*.rdl');
[string[]]$365DayFileRetention = @();
[string[]]$90DayFileRetention = @();


[datetime]$365DayCutoff = (Get-Date).AddDays(-365);
[datetime]$90DayCutoff = (Get-Date).AddDays(-90);
[datetime]$7DayCutoff = (Get-Date).AddDays(-7);

function ShouldDelete {
    [cmdletbinding()]
	Param( [string]$EnterpriseKey,
           [Amazon.S3.Model.S3Object]$S3Object )
       
    [string]$Filter = $null;
    #Keep anything <7 days old
    if ($S3Object.LastModified -gt $7DayCutoff) {
        #Write-Host "Keeping. Changed in the last 7 days:    LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
        return $false;
    }

    #Keep infinite retention items
    foreach ($Filter in $InfiniteRetention) {
        if ($S3Object.Key.IndexOf("$EnterpriseKey$Filter/") -eq 0) {
            #Write-Host "Keeping. InfiniteRetention match found:    LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
            return $false;
        }
    }
    foreach ($Filter in $InfiniteFileRetention) {
        if ($S3Object.Key -like $Filter) {
            #Write-Host "Keeping. InfiniteFileRetention match found:   LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
            return $false;
        }
    }

    #keep 90 day rentention items
    if ($S3Object.LastModified -gt $90DayCutoff) {
        foreach ($Filter in $90DayRetention) {
            if ($S3Object.Key.IndexOf("$EnterpriseKey$Filter/") -eq 0) {
                #Write-Host "Keeping. 90DayRetention match found:       LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
                return $false;
            }
        }
        foreach ($Filter in $90DayFileRetention) {
            if ($S3Object.Key -like $Filter) {
                #Write-Host "Keeping. 90DayFileRetention match found:   LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
                return $false;
            }
        }
    }
    
    #keep 365 day rentention items
    if ($S3Object.LastModified -gt $365DayCutoff) {
        foreach ($Filter in $365DayRetention) {
            if ($S3Object.Key.IndexOf("$EnterpriseKey$Filter/") -eq 0) {
                #Write-Host "Keeping. 365DayRetention match found:      LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
                return $false;
            }
        }
        foreach ($Filter in $365DayFileRetention) {
            if ($S3Object.Key -like $Filter) {
                #Write-Host "Keeping. 365DayFileRetention match found:  LastModified=$($S3Object.LastModified), Key=$($S3Object.Key)";
                return $false;
            }
        }

    }

    return $true;
}

function ProcessEnterprise {
    [cmdletbinding()]
	Param( [string]$BucketName,
           [string]$EnterpriseKey )
    
    [string]$NextMarker = $null;
    Do
    {
        #1000 records max per get-s3object request, so loop until NextMarker is null.
        [Amazon.S3.Model.S3Object[]]$S3Objects = Get-S3Object -BucketName $BucketName -KeyPrefix $EnterpriseKey -Marker $NextMarker;
        $NextMarker= $AWSHistory.LastServiceResponse.NextMarker;

        [Amazon.S3.Model.S3Object]$Item = $null
        foreach ($S3Object in $S3Objects) {
            if ((ShouldDelete -EnterpriseKey $EnterpriseKey -S3Object $S3Object)) {
                #Write-Host "Delete: $($S3Object.Key)";
                Remove-S3Object -BucketName $BucketName -Key $S3Object.Key -Force;
            }
        }
    } While ($NextMarker)
}

function ProcessBucket {
    [cmdletbinding()]
	Param( [string]$BucketName )

    

    [string[]]$EnterpriseKeys = Get-S3Object -BucketName $BucketName -KeyPrefix 's3:/enterprises/' -Delimiter '/' -Select CommonPrefixes;
    [string]$EntepriseKey;

    foreach ($EnterpriseKey in $EnterpriseKeys) {
        ProcessEnterprise -BucketName $BucketName -EnterpriseKey $EnterpriseKey;
    }
}


function TestBucket {
    [cmdletbinding()]
	Param( [string]$BucketName )

    if(Test-S3Bucket -BucketName $BucketName) {
        Write-Host "Bucket found: $BucketName";
    } else {
        Write-Host "Bucket not found, cannot continue: $BucketName";
        [Environment]::Exit("1");
    }
}

TestBucket -BucketName $BucketName;
ProcessBucket -BucketName $BucketName;

Write-Output "Done!"