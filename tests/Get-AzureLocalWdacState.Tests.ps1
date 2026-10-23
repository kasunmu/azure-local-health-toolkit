Describe 'Get-AzureLocalWdacStatus' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalWdacState.ps1')
    }

    It 'reports Healthy when kernel and user mode are both enforced' {
        Get-AzureLocalWdacStatus -KernelModeValue 2 -UserModeValue 2 | Should -Be 'Healthy'
    }

    It 'reports Warning when user mode is in audit' {
        Get-AzureLocalWdacStatus -KernelModeValue 2 -UserModeValue 1 | Should -Be 'Warning'
    }

    It 'reports Warning when WDAC is off' {
        Get-AzureLocalWdacStatus -KernelModeValue 0 -UserModeValue 0 | Should -Be 'Warning'
    }

    It 'reports Unknown for values outside the documented range' {
        Get-AzureLocalWdacStatus -KernelModeValue 7 -UserModeValue 2 | Should -Be 'Unknown'
    }

    It 'reports Unknown when a value is missing' {
        Get-AzureLocalWdacStatus -KernelModeValue $null -UserModeValue 2 | Should -Be 'Unknown'
    }
}

Describe 'Get-AzureLocalWdacState' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalWdacState.ps1')

        # Get-CimInstance does not exist on Linux. A stub lets Pester mock it.
        $script:createdCimStub = $false
        if (-not (Get-Command Get-CimInstance -ErrorAction SilentlyContinue)) {
            function global:Get-CimInstance { [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')] param($Namespace, $ClassName) }
            $script:createdCimStub = $true
        }
    }

    AfterAll {
        if ($script:createdCimStub) {
            Remove-Item -Path Function:\Get-CimInstance -ErrorAction SilentlyContinue
        }
    }

    It 'maps enforcement values to friendly names and a status' {
        Mock Get-CimInstance {
            [pscustomobject]@{
                CodeIntegrityPolicyEnforcementStatus         = 2
                UsermodeCodeIntegrityPolicyEnforcementStatus = 1
            }
        }

        $state = Get-AzureLocalWdacState

        $state.KernelMode | Should -Be 'Enforced'
        $state.UserMode | Should -Be 'Audit'
        $state.Status | Should -Be 'Warning'
    }

    It 'returns NotAvailable with the reason when the query fails' {
        Mock Get-CimInstance { throw 'Invalid namespace' }

        $state = Get-AzureLocalWdacState

        $state.Status | Should -Be 'NotAvailable'
        $state.Error | Should -Match 'Invalid namespace'
    }
}
