@{
    # WinMedic lint policy.
    #
    # WMT-GUI.ps1 is inherited from upstream and carries thousands of style
    # findings. Gating on those would mean either a permanently red build or a
    # 44k-line reformat that destroys upstream merges. So the whole repo is
    # gated on Errors only, while Modules/ - code we write - is additionally
    # gated on Warnings in a second CI pass. New code is held to the higher bar
    # from the start; the monolith improves as it gets touched.

    # No Severity key here on purpose. When this file declares one it overrides
    # the -Severity argument, which silently turned the "errors only" CI gate
    # into an everything gate. Each CI step passes the severity it wants.

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
        # WinMedic runs on whatever Windows ships: PowerShell 5.1 on a stock
        # Windows 10/11 install. CI parses with pwsh 7, which happily accepts
        # syntax 5.1 rejects at parse time, so state the target explicitly.
        PSUseCompatibleSyntax      = @{
            Enable         = $true
            TargetVersions = @('5.1')
        }

        PSPlaceOpenBrace           = @{ Enable = $false }
        PSPlaceCloseBrace          = @{ Enable = $false }
        PSUseConsistentIndentation = @{ Enable = $false }
        PSUseConsistentWhitespace  = @{ Enable = $false }
    }
}
