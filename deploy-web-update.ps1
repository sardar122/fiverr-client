param(
    [Parameter(Mandatory=$true)][StackProperties]$StackProperties,
    [Parameter(Mandatory=$true)][String]$S3_bucket,
    [Parameter(Mandatory=$true)][String]$S3Key
)

# $stack = 't3'
# $targetVersion = 'latest'
# $ebExtensionsKey = "ebs-web-bootstrapper_$targetVersion.zip"
# $s3_bucket = '434495414204-myunity-bo-dev-build-outputs'

function Main {
    $eb_application = Get-EBApplication | Where-Object { $_.ApplicationName -like "*-$($StackProperties.StackID)-app*" };
    $eb_back_environment_stack = Get-EBEnvironment `
        -ApplicationName $eb_application.ApplicationName | Where-Object {$_.Status -ne 'Terminated' -and $_.CNAME -like "*-$($StackProperties.StackID)-back*" };
    $eb_front_environment_stack = Get-EBEnvironment `
        -ApplicationName $eb_application.ApplicationName | Where-Object {$_.Status -ne 'Terminated' -and $_.CNAME -like "*-$($StackProperties.StackID)-front*" };

    # Create new application version
    $verLabel = [System.DateTime]::Now.Ticks.ToString();
    $newVerParams = @{
          ApplicationName       = $eb_application.ApplicationName
          VersionLabel          = $verLabel
          SourceBundle_S3Bucket = $S3_bucket
          SourceBundle_S3Key    = $S3Key
    };
    New-EBApplicationVersion @newVerParams;

    # Trigger update on web site back stack
    Update-EBEnvironment `
        -ApplicationName $eb_application.ApplicationName `
        -EnvironmentName $eb_back_environment_stack.EnvironmentName `
        -VersionLabel $verLabel `
        -Force;

    Do {
        Start-Sleep -Seconds 5;
    }
    While (
        (Get-EBEnvironment `
            -ApplicationName $eb_application.ApplicationName `
            -EnvironmentId $eb_back_environment_stack.EnvironmentId `
            -EnvironmentName $eb_back_environment_stack.EnvironmentName).Status -eq 'Updating'
    );
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew();
Main;
$Stopwatch.Stop();
$Stopwatch.Elapsed.TotalMinutes.ToString('0.00')