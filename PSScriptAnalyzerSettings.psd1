@{
    # WinMedic lint policy.
    #
    # WMT-GUI.ps1 is inherited from upstream and carries thousands of style
    # findings. Gating on those would mean either a permanently red build or a
    # 44k-line reformat that destroys upstream merges. So the whole repo is
    # gated on Errors only, while Modules/ - code we write - is additionally
    # gated on Warnings in a second CI pass. New code is held to the higher bar
    # from the start; the monolith improves as it gets touched.

    Severity     = @('Error', 'Warning', 'Information')

    ExcludeRules = @(
        # The GUI is event-driven: handlers assign to script-scoped state that
        # PSScriptAnalyzer cannot see being read from XAML-bound code.
        'PSUseDeclaredVarsMoreThanAssignments',

        # Verb-Noun is followed for new code but the inherited body has many
        # non-approved verbs; renaming them would break upstream merges.
        'PSUseApprovedVerbs',

        # Interactive maintenance tool: Write-Host is the intended channel for
        # console output before the GUI window exists.
        'PSAvoidUsingWriteHost',

        # Several maintenance actions genuinely need Invoke-Expression against
        # vendor tooling; those sites are reviewed individually.
        'PSAvoidUsingInvokeExpression'
    )

    Rules        = @{
        PSPlaceOpenBrace           = @{ Enable = $false }
        PSPlaceCloseBrace          = @{ Enable = $false }
        PSUseConsistentIndentation = @{ Enable = $false }
        PSUseConsistentWhitespace  = @{ Enable = $false }
    }
}
