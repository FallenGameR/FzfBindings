# Copyright (c) Aleksandr Kostikov
# Licensed under the MIT License.

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'FzfBindings.psm1'

    # Version number of this module.
    ModuleVersion = '0.1.3.20230502'

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
        "Clear-GitBranch",
        "Get-GitBranch",
        "Get-GitPrBranch",
        "Invoke-CodeFzf",
        "Invoke-HistoryFzf",
        "Push-LocationFzf",
        "Search-RipgrepFzf",
        "Select-GitBranch",
        "Send-GitBranch",
        "Set-LocationFzf",
        "Show-Help",
        "Show-PreviewFzf",
        "Start-ProcessFzf",
        "Stop-ProcessFzf"
    )

    # Modules that must be imported into the global environment prior to importing this module
    RequiredModules = @()

    # List of all files packaged with this module
    FileList = @(
        ".\FzfBindings.psd1",
        ".\FzfBindings.psm1",
        ".\Initialize-GitFzf.ps1",
        ".\Initialize-ShellFzf.ps1",
        ".\notes.md",
        ".\readme.md",
        ".\Bin\.gitignore",
        ".\Bin\Walker\walker.exe",
        ".\Data\excluded_folders",
        ".\Data\picture_extensions",
        ".\Preview\Show-FileEntry.ps1",
        ".\Preview\Show-GitBranch.ps1",
        ".\Walk\Get-FileEntry.ps1",
        ".\Walk\Get-Folder.ps1"
    )
}