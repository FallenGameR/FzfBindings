# Copyright (c) Aleksandr Kostikov
# Licensed under the MIT License.

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'FzfBindings.psm1'

    # Version number of this module.
    ModuleVersion = '1.16.20250618'

    # ID used to uniquely identify this module
    GUID = 'fb98390c-1080-4d3a-ab8a-439d02e995f6'

    # Author of this module
    Author = 'Aleksandr Kostikov, Alex.Kostikov@gmail.com'

    # Copyright statement for this module
    Copyright = '(c) Aleksandr Kostikov'

    # Description of the functionality provided by this module
    Description = 'Cross platform powershell bindings for fzf'

    # Minimum version of the Windows PowerShell engine required by this module
    PowerShellVersion = '5.0'

    # Cmdlets to export from this module
    CmdletsToExport = @()

    # Variables to export from this module
    VariablesToExport = @()

    # Script files (.ps1) that are run in the caller's environment prior to importing this module.
    ScriptsToProcess = @(
        "Requirements.ps1"
    )

    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    NestedModules = @(
        "Defaults.ps1",
        "Utils.ps1",
        "Git.ps1",
        "Shell.ps1"
    )

    # Aliases to export from this module
    AliasesToExport = @(
        "cdf",
        "clrf",
        "codef",
        "cof",
        "hf",
        "hlp",
        "killf",
        "pf",
        "prf",
        "pushf",
        "rgf",
        "startf"
    )

    # Functions to export from this module
    FunctionsToExport = @(
        "Initialize-FzfArgs",
        "Clear-GitBranch",
        "Get-GitBranch",
        "Resolve-GitMasterBranch",
        "Invoke-FzfCode",
        "Invoke-FzfHistory",
        "Push-FzfLocation",
        "Search-FzfRipgrep",
        "Select-GitBranch",
        "Send-GitBranch",
        "Set-FzfLocation",
        "Show-BatHelp",
        "Show-FzfFilePreview",
        "Start-FzfProcess",
        "Stop-FzfProcess",
        "Use-Fzf",
        "Update-GitLineEndingsMitigation",
        "Repair-ConsoleMode"
    )
}
