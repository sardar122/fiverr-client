param(
	[Parameter(Mandatory=$true)][string]$trxPath=''
)
$ErrorActionPreference = 'Stop'

$resultsPath = "$trxPath";

Write-Host "Test results path: $resultsPath";
if (Test-Path -Path $resultsPath -Filter *.trx) {
	Get-ChildItem -Path $resultsPath -Filter *.trx | ForEach-Object {
		[Xml]$content = Get-Content -Path $_.FullName
		    $content.TestRun.Results.UnitTestResult | Where-Object { $_.outcome -eq 'failed' } | Select-Object testName, Output | ForEach-Object { 
			$output = $_.testName;
			if (-Not ([System.String]::IsNullOrWhiteSpace($_.Output.ErrorInfo.Message))) { 
				$output += " Message: " + $_.Output.ErrorInfo.Message;
			}
			if (-Not ([System.String]::IsNullOrWhiteSpace($_.Output.ErrorInfo.StackTrace))) { 
				$output += "`nStackTrace: " + $_.Output.ErrorInfo.StackTrace;
			}
			Write-Error "Failed test: $output";
        };
	}
} else {
	Write-Error "Stage failed, but no test results were found.";
}