@{
    # Fail CI on anything at Warning level or above.
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # The standalone helpers in scripts/ are interactive console tools and
        # deliberately write human-readable output to the host. The main health
        # collector emits objects and does not use Write-Host.
        'PSAvoidUsingWriteHost',

        # Test files define global stubs (for example Get-NetAdapter) so Pester
        # can mock cmdlets that do not exist on Linux CI runners.
        'PSAvoidGlobalFunctions'
    )
}
