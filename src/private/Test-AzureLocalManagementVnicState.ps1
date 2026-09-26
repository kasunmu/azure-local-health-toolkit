function Test-AzureLocalManagementVnicState {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$IntentName,

        [Parameter()]
        [string]$ExpectedName
    )

    if (-not $ExpectedName) {
        $ExpectedName = "vManagement($IntentName)"
    }

    $expectedOsAlias = "vEthernet ($ExpectedName)"

    $result = [ordered]@{
        IntentName               = $IntentName
        ExpectedName             = $ExpectedName
        ExpectedNetAdapterFound  = $false
        ExpectedVMAdapterFound   = $false
        GuidStyleAdapterDetected = $false
        GuidStyleAdapters        = @()
        Status                   = 'Unknown'
        Details                  = ''
    }

    $guidPattern = '^[{(]?[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}[)}]?$'
    $wrappedGuidPattern = '^vEthernet \([{(]?[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}[)}]?\)$'
    $guidNames = [System.Collections.Generic.List[string]]::new()

    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        try {
            $netAdapters = @(Get-NetAdapter -ErrorAction Stop)

            $result.ExpectedNetAdapterFound = [bool](
                $netAdapters | Where-Object {
                    $_.Name -eq $ExpectedName -or
                    $_.Name -eq $expectedOsAlias
                }
            )

            foreach ($adapter in $netAdapters) {
                if (
                    $adapter.Name -match $guidPattern -or
                    $adapter.Name -match $wrappedGuidPattern
                ) {
                    $guidNames.Add($adapter.Name)
                }
            }
        }
        catch {
            $result.Details = "Unable to query Windows network adapters: $($_.Exception.Message)"
        }
    }

    if (Get-Command Get-VMNetworkAdapter -ErrorAction SilentlyContinue) {
        try {
            $vmAdapters = @(Get-VMNetworkAdapter -ManagementOS -ErrorAction Stop)

            $result.ExpectedVMAdapterFound = [bool](
                $vmAdapters | Where-Object Name -eq $ExpectedName
            )

            foreach ($adapter in $vmAdapters) {
                if ($adapter.Name -match $guidPattern) {
                    $guidNames.Add($adapter.Name)
                }
            }
        }
        catch {
            if (-not $result.Details) {
                $result.Details = "Unable to query Management OS VM network adapters: $($_.Exception.Message)"
            }
        }
    }

    $result.GuidStyleAdapters = @($guidNames | Sort-Object -Unique)
    $result.GuidStyleAdapterDetected = $result.GuidStyleAdapters.Count -gt 0

    if ($result.ExpectedNetAdapterFound -or $result.ExpectedVMAdapterFound) {
        $result.Status = 'Healthy'
        $result.Details = "Expected Management OS vNIC name '$ExpectedName' is present."
    }
    elseif ($result.GuidStyleAdapterDetected) {
        $result.Status = 'Warning'
        $result.Details = "Expected Management OS vNIC name '$ExpectedName' was not found and one or more GUID-style virtual adapter names were detected."
    }
    elseif (-not $result.Details) {
        $result.Status = 'Warning'
        $result.Details = "Expected Management OS vNIC name '$ExpectedName' was not found."
    }

    [pscustomobject]$result
}
