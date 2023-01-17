# Copyright (c) Aleksandr Kostikov
# Licensed under the MIT License.

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'FzfBindings.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.0.20230117'

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
    CmdletsToExport = '*'

    # Variables to export from this module
    VariablesToExport = '*'

    # Aliases to export from this module
    AliasesToExport = @(
        Set-Alias hlp Show-Help
        Set-Alias pf Show-PreviewFzf
        Set-Alias startf Start-ProcessFzf
        Set-Alias cdf Set-LocationFzf
        Set-Alias killf Stop-ProcessFzf
        Set-Alias pushf Push-LocationFzf
        Set-Alias hf Invoke-HistoryFzf
        Set-Alias codef Invoke-CodeFzf
        Set-Alias rgf Search-RipgrepFzf
    )

    # Functions to export from this module
    FunctionsToExport = @(
        Show-Help
        Show-PreviewFzf
        Start-ProcessFzf
        Set-LocationFzf
        Stop-ProcessFzf
        Push-LocationFzf
        Invoke-HistoryFzf
        Invoke-CodeFzf
        Search-RipgrepFzf
        Get-GitBranch
        Get-GitPrBranch
        Select-GitBranch
        Send-GitBranch # start URL
        Clear-GitBranch
        Select-GitBranchFzf
    )

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # List of all files packaged with this module
    FileList = @(
    )
}