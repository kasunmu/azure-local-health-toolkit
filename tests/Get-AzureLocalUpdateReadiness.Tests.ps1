Describe 'ConvertTo-AzureLocalUpdateEnvironmentResult' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalUpdateReadiness.ps1')
        $script:now = [datetime]'2026-10-24T09:00:00'
    }

    It 'reports a healthy, up-to-date system' {
        $environment = [pscustomobject]@{
            State             = 'AppliedSuccessfully'
            CurrentVersion    = '12.2609.1002.18'
            CurrentSbeVersion = '4.1.2409.1'
            HealthState       = 'Success'
            HealthCheckDate   = [datetime]'2026-10-23T22:00:00'
            HealthCheckResult = @()
        }

        $results = @(ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now)

        $results.Count | Should -Be 2
        ($results | Where-Object Name -eq 'Update state').Status | Should -Be 'Healthy'
        ($results | Where-Object Name -eq 'Update state').Details | Should -Match '12.2609.1002.18'
        ($results | Where-Object Name -eq 'Update readiness checks').Status | Should -Be 'Healthy'
    }

    It 'reports Critical when the last update failed' {
        $environment = [pscustomobject]@{ State = 'UpdateFailed'; HealthState = 'Success'; HealthCheckDate = $script:now }

        $result = ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now |
            Where-Object Name -eq 'Update state'

        $result.Status | Should -Be 'Critical'
        $result.Details | Should -Match 'Get-SolutionUpdateRun'
    }

    It 'reports Warning while an update is in progress' {
        $environment = [pscustomobject]@{ State = 'UpdateInProgress'; HealthState = 'InProgress' }

        $results = @(ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now)

        ($results | Where-Object Name -eq 'Update state').Status | Should -Be 'Warning'
        ($results | Where-Object Name -eq 'Update readiness checks').Status | Should -Be 'Warning'
    }

    It 'reports Critical when readiness checks failed' {
        $environment = [pscustomobject]@{ State = 'UpdateAvailable'; HealthState = 'Failure'; HealthCheckDate = $script:now }

        (ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now |
            Where-Object Name -eq 'Update readiness checks').Status | Should -Be 'Critical'
    }

    It 'downgrades successful but stale readiness results to Warning' {
        $environment = [pscustomobject]@{
            State           = 'UpdateAvailable'
            HealthState     = 'Success'
            HealthCheckDate = $script:now.AddDays(-10)
        }

        $result = ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now -HealthCheckMaxAgeDays 7 |
            Where-Object Name -eq 'Update readiness checks'

        $result.Status | Should -Be 'Warning'
        $result.Details | Should -Match 'older than 7 days'
    }

    It 'summarises failed readiness checks by severity' {
        $environment = [pscustomobject]@{
            State             = 'UpdateAvailable'
            HealthState       = 'Failure'
            HealthCheckDate   = $script:now
            HealthCheckResult = @(
                [pscustomobject]@{ Title = 'Storage Pool Summary'; Status = 'SUCCESS'; Severity = 'CRITICAL' },
                [pscustomobject]@{ Title = 'Test Network intent'; Status = 'FAILURE'; Severity = 'CRITICAL' },
                [pscustomobject]@{ Title = 'Test Cluster Quorum'; Status = 'FAILURE'; Severity = 'WARNING' }
            )
        }

        $result = ConvertTo-AzureLocalUpdateEnvironmentResult -Environment $environment -Now $script:now |
            Where-Object Name -eq 'Failed readiness checks'

        $result.Status | Should -Be 'Critical'
        $result.Details | Should -Match '2 check\(s\) not passing \(1 critical, 1 warning\)'
        $result.Details | Should -Match 'Test Network intent'
        $result.Details | Should -Not -Match 'Storage Pool Summary'
    }

    It 'treats missing properties as Unknown instead of throwing under strict mode' {
        Set-StrictMode -Version Latest
        try {
            $results = @(ConvertTo-AzureLocalUpdateEnvironmentResult -Environment ([pscustomobject]@{}) -Now $script:now)
        }
        finally {
            Set-StrictMode -Off
        }

        ($results | Where-Object Name -eq 'Update state').Status | Should -Be 'Unknown'
        ($results | Where-Object Name -eq 'Update readiness checks').Status | Should -Be 'Unknown'
    }
}

Describe 'ConvertTo-AzureLocalSolutionUpdateResult' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalUpdateReadiness.ps1')
    }

    It 'returns one Healthy result when everything is installed' {
        $updates = @(
            [pscustomobject]@{ DisplayName = 'Azure Local 2608'; Version = '12.2608.1001.4'; State = 'Installed' }
        )

        $results = @(ConvertTo-AzureLocalSolutionUpdateResult -Update $updates)

        $results.Count | Should -Be 1
        $results[0].Status | Should -Be 'Healthy'
        $results[0].Details | Should -Match 'No pending'
    }

    It 'handles an empty update list' {
        (ConvertTo-AzureLocalSolutionUpdateResult -Update @()).Status | Should -Be 'Healthy'
    }

    It 'reports a ready update as Healthy with its version' {
        $result = ConvertTo-AzureLocalSolutionUpdateResult -Update @(
            [pscustomobject]@{ DisplayName = 'Azure Local 2609'; Version = '12.2609.1002.18'; State = 'Ready' }
        )

        $result.Status | Should -Be 'Healthy'
        $result.Name | Should -Be 'Azure Local 2609'
        $result.Details | Should -Match '12.2609.1002.18'
    }

    It 'reports a failed installation as Critical and names the action plan instance' {
        $update = [pscustomobject]@{
            DisplayName = 'Azure Local 2609'
            Version     = '12.2609.1002.18'
            State       = 'InstallationFailed'
            ResourceId  = 'redmond/Solution12.2609.1002.18'
        }
        $runs = @{
            'redmond/Solution12.2609.1002.18' = [pscustomobject]@{
                ResourceId  = 'redmond/Solution12.2609.1002.18/6f2b2c55-0000-4c1e-9f00-1234567890ab'
                State       = 'Failed'
                TimeStarted = '2026-10-20T01:00:00'
            }
        }

        $result = ConvertTo-AzureLocalSolutionUpdateResult -Update @($update) -LatestRuns $runs

        $result.Status | Should -Be 'Critical'
        $result.Details | Should -Match 'Last run: Failed'
        $result.Details | Should -Match '6f2b2c55-0000-4c1e-9f00-1234567890ab'
        $result.Details | Should -Match 'Start-SolutionUpdate'
    }

    It 'reports failed readiness checks on an update with specific guidance' {
        $result = ConvertTo-AzureLocalSolutionUpdateResult -Update @(
            [pscustomobject]@{ Version = '12.2609.1002.18'; State = 'HealthCheckFailed' }
        )

        $result.Status | Should -Be 'Critical'
        $result.Name | Should -Be 'Update 12.2609.1002.18'
        $result.Details | Should -Match 'Readiness checks failed'
        $result.Details | Should -Not -Match 'Start-SolutionUpdate'
    }

    It 'reports an update waiting for SBE content as Warning' {
        $result = ConvertTo-AzureLocalSolutionUpdateResult -Update @(
            [pscustomobject]@{ Version = '12.2609.1002.18'; State = 'AdditionalContentRequired' }
        )

        $result.Status | Should -Be 'Warning'
        $result.Details | Should -Match 'Solution Builder Extension'
    }

    It 'shows progress for an installing update' {
        $result = ConvertTo-AzureLocalSolutionUpdateResult -Update @(
            [pscustomobject]@{ Version = '12.2609.1002.18'; State = 'Installing'; UpdateStateProperties = '42% complete' }
        )

        $result.Status | Should -Be 'Warning'
        $result.Details | Should -Match '42% complete'
    }
}

Describe 'Get-AzureLocalUpdateReadiness' {
    BeforeAll {
        . (Join-Path (Join-Path (Split-Path -Parent $PSScriptRoot) 'src') 'private/Get-AzureLocalUpdateReadiness.ps1')

        # Lifecycle Manager and cluster cmdlets only exist on Azure Local nodes.
        $script:createdStubs = [System.Collections.Generic.List[string]]::new()
        foreach ($name in 'Get-Cluster', 'Get-SolutionUpdateEnvironment', 'Get-SolutionUpdate', 'Get-SolutionUpdateRun') {
            if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
                Set-Item -Path "Function:global:$name" -Value { }
                $script:createdStubs.Add($name)
            }
        }
    }

    AfterAll {
        foreach ($name in $script:createdStubs) {
            Remove-Item -Path "Function:\$name" -ErrorAction SilentlyContinue
        }
    }

    # Pester 4 scopes mocks to the enclosing Describe or Context, Pester 5 to each It.
    # Contexts keep the two groups of mocks apart under both versions.
    Context 'when Lifecycle Manager is missing' {
        It 'warns that deployment is incomplete when a cluster node has no Lifecycle Manager' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-SolutionUpdateEnvironment' }
            Mock Get-Cluster { [pscustomobject]@{ Name = 'AZLOCAL-DEMO' } }

            $result = Get-AzureLocalUpdateReadiness

            $result.Name | Should -Be 'Lifecycle Manager'
            $result.Status | Should -Be 'Warning'
            $result.Details | Should -Match 'deployment has not completed'
        }

        It 'reports NotAvailable off-cluster when there is no Lifecycle Manager' {
            Mock Get-Command { $null } -ParameterFilter { $Name -eq 'Get-SolutionUpdateEnvironment' }
            Mock Get-Cluster { throw 'The cluster service is not running.' }

            (Get-AzureLocalUpdateReadiness).Status | Should -Be 'NotAvailable'
        }
    }

    Context 'on a deployed cluster' {
        It 'combines environment and update results on a deployed cluster' {
            Mock Get-SolutionUpdateEnvironment {
                [pscustomobject]@{ State = 'UpdateAvailable'; CurrentVersion = '12.2608.1001.4'; HealthState = 'Success'; HealthCheckDate = Get-Date }
            }
            Mock Get-SolutionUpdate {
                [pscustomobject]@{ DisplayName = 'Azure Local 2609'; Version = '12.2609.1002.18'; State = 'Ready'; ResourceId = 'x/Solution12.2609.1002.18' }
            }

            $results = @(Get-AzureLocalUpdateReadiness)

            $results.Name | Should -Contain 'Update state'
            $results.Name | Should -Contain 'Update readiness checks'
            $results.Name | Should -Contain 'Azure Local 2609'
            @($results | Where-Object Status -ne 'Healthy').Count | Should -Be 0
        }

        It 'reports Unknown instead of throwing when Get-SolutionUpdateEnvironment fails' {
            Mock Get-SolutionUpdateEnvironment { throw 'Access denied' }

            $result = Get-AzureLocalUpdateReadiness

            $result.Status | Should -Be 'Unknown'
            $result.Details | Should -Match 'Access denied'
        }
    }
}
