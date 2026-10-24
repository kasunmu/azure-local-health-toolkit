Describe 'Get-AzureLocalHealth.ps1' {
    BeforeAll {
        $script:scriptPath = Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'Get-AzureLocalHealth.ps1'
    }

    It 'completes without throwing when Azure Local cmdlets are unavailable' {
        # On a machine without the cluster, storage, Network ATC or Arc tooling
        # every check should degrade to NotAvailable instead of stopping the run.
        { & $script:scriptPath } | Should -Not -Throw
    }

    It 'returns one result object per check with the expected properties' {
        $results = @(& $script:scriptPath)

        $results.Count | Should -BeGreaterThan 0
        foreach ($property in 'Category', 'Name', 'Status', 'Details', 'Timestamp') {
            $results[0].PSObject.Properties.Name | Should -Contain $property
        }
    }

    It 'only uses supported status values' {
        $allowed = 'Healthy', 'Warning', 'Critical', 'Unknown', 'NotAvailable'

        foreach ($result in @(& $script:scriptPath)) {
            $allowed | Should -Contain $result.Status
        }
    }

    It 'exports valid JSON when OutputPath is supplied' {
        $path = Join-Path ([System.IO.Path]::GetTempPath()) ("alht-{0}.json" -f [guid]::NewGuid())
        try {
            & $script:scriptPath -OutputPath $path -Format Json | Out-Null

            $exported = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            @($exported).Count | Should -BeGreaterThan 0
        }
        finally {
            Remove-Item -LiteralPath $path -ErrorAction SilentlyContinue
        }
    }
}
