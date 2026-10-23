Describe 'ConvertFrom-AzureLocalArcAgentJson' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalArcAgentState.ps1')
    }

    It 'reports Healthy when the agent is Connected' {
        $json = '{"status":"Connected","agentVersion":"1.47.0","lastHeartbeat":"2026-10-01T09:00:00Z"}'

        $state = ConvertFrom-AzureLocalArcAgentJson -Json $json

        $state.Status | Should -Be 'Healthy'
        $state.AgentStatus | Should -Be 'Connected'
        $state.Details | Should -Match 'Version: 1.47.0'
    }

    It 'reports Critical when the agent is Disconnected, even with exit code 0' {
        $state = ConvertFrom-AzureLocalArcAgentJson -Json '{"status":"Disconnected"}' -ExitCode 0

        $state.Status | Should -Be 'Critical'
    }

    It 'reports Critical when the agent is Expired' {
        (ConvertFrom-AzureLocalArcAgentJson -Json '{"status":"Expired"}').Status | Should -Be 'Critical'
    }

    It 'reports Unknown for an unrecognised status' {
        (ConvertFrom-AzureLocalArcAgentJson -Json '{"status":"Provisioning"}').Status | Should -Be 'Unknown'
    }

    It 'reports Unknown when the output is not JSON' {
        $state = ConvertFrom-AzureLocalArcAgentJson -Json 'Resource Name : node01' -ExitCode 0

        $state.Status | Should -Be 'Unknown'
        $state.Details | Should -Match 'Unable to parse'
    }

    It 'reports Unknown when there is no output' {
        (ConvertFrom-AzureLocalArcAgentJson -Json '' -ExitCode 1).Status | Should -Be 'Unknown'
    }

    It 'never includes tenant or subscription identifiers in the details' {
        $json = '{"status":"Connected","tenantId":"00000000-1111-2222-3333-444444444444","subscriptionId":"55555555-6666-7777-8888-999999999999"}'

        $state = ConvertFrom-AzureLocalArcAgentJson -Json $json

        $state.Details | Should -Not -Match '00000000-1111'
        $state.Details | Should -Not -Match '55555555-6666'
    }
}

Describe 'Get-AzureLocalArcAgentState' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalArcAgentState.ps1')
    }

    It 'reports NotAvailable when azcmagent cannot be found' {
        $missing = Join-Path ([System.IO.Path]::GetTempPath()) 'no-such-dir/azcmagent.exe'

        $state = Get-AzureLocalArcAgentState -AzcmagentPath $missing

        $state.Status | Should -Be 'NotAvailable'
    }
}
