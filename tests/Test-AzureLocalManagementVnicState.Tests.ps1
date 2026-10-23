Describe 'Test-AzureLocalManagementVnicState' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Test-AzureLocalManagementVnicState.ps1')

        # Networking cmdlets do not exist on Linux CI runners. Stubs let Pester mock them.
        $script:createdStubs = [System.Collections.Generic.List[string]]::new()
        if (-not (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue)) {
            function global:Get-NetAdapter { }
            $script:createdStubs.Add('Get-NetAdapter')
        }
        if (-not (Get-Command Get-VMNetworkAdapter -ErrorAction SilentlyContinue)) {
            function global:Get-VMNetworkAdapter { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')] param([switch]$ManagementOS) }
            $script:createdStubs.Add('Get-VMNetworkAdapter')
        }
    }

    AfterAll {
        foreach ($name in $script:createdStubs) {
            Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
        }
    }

    It 'reports Healthy when the expected vManagement adapter exists' {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'vEthernet (vManagement(mgmt_compute))' } }
        Mock Get-VMNetworkAdapter { [pscustomobject]@{ Name = 'vManagement(mgmt_compute)' } }

        $state = Test-AzureLocalManagementVnicState -IntentName 'mgmt_compute'

        $state.Status | Should -Be 'Healthy'
        $state.ExpectedName | Should -Be 'vManagement(mgmt_compute)'
    }

    It 'reports Warning and lists GUID-named adapters when the expected name is missing' {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'vEthernet ({3F2504E0-4F89-11D3-9A0C-0305E82C3301})' } }
        Mock Get-VMNetworkAdapter { [pscustomobject]@{ Name = '3F2504E0-4F89-11D3-9A0C-0305E82C3301' } }

        $state = Test-AzureLocalManagementVnicState -IntentName 'mgmt_compute'

        $state.Status | Should -Be 'Warning'
        $state.GuidStyleAdapterDetected | Should -BeTrue
        @($state.GuidStyleAdapters).Count | Should -Be 2
    }

    It 'reports Warning when the expected name is missing and no GUID names exist' {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'Ethernet 1' } }
        Mock Get-VMNetworkAdapter { [pscustomobject]@{ Name = 'Something else' } }

        $state = Test-AzureLocalManagementVnicState -IntentName 'mgmt_compute'

        $state.Status | Should -Be 'Warning'
        $state.GuidStyleAdapterDetected | Should -BeFalse
    }

    It 'honours a custom expected name' {
        Mock Get-NetAdapter { [pscustomobject]@{ Name = 'MgmtCustom' } }
        Mock Get-VMNetworkAdapter { }

        $state = Test-AzureLocalManagementVnicState -IntentName 'mgmt' -ExpectedName 'MgmtCustom'

        $state.Status | Should -Be 'Healthy'
    }
}
