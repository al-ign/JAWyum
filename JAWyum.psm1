function Invoke-YumCommand {    
[CmdletBinding(DefaultParameterSetName="Command")]    
    param (
    [parameter(Mandatory=$true, ParameterSetName="Command", ValueFromPipeline=$True, Position = 0)] 
    [String]$Command,
    [Parameter(Mandatory=$false,ValueFromPipeline=$True, ValueFromRemainingArguments=$true)]
    [Alias('PackageName')]
    [string[]]$PackageList,
    [switch]$CacheOnly,
    [switch]$Confirm = $false,
    [switch]$AsObject,
    [switch]$Quiet,
    [parameter(Mandatory=$true, ParameterSetName="InvocationObject")]
    [Hashtable]$InvocationObject
    )
 
    if ($PSCmdlet.ParameterSetName -eq 'Command') {
        "Converting command to Invocation Object" | Write-Debug
        $InvocationObject = @{
            AsObject = $AsObject
            Command = $Command
            PackageList = $PackageList
            CacheOnly = $CacheOnly
            Confirm = $Confirm
            Options = [string]''
            }
        }
 
    switch ($InvocationObject.Keys | ? {$InvocationObject[$_]} ) {
        'CacheOnly' { $Options += "--cacheonly "
            }
        }#end switch

    if (-not $InvocationObject['Confirm'] ) {
                $Options += "--assumeyes "
                }
    [string]$sYumInvoke = "yum "+ $Options +" "+ $InvocationObject.Command +" "+ $InvocationObject.Packagelist

    "Invoking $($sYumInvoke)" | Write-Verbose
    
    $CLIOutput = Invoke-Expression $sYumInvoke
  
    $YumOutput = @{
        Output = $CLIOutput
        LastExitCode = $LASTEXITCODE
        }
     
    $YumOutput

     
}#end invoke-yumcommand
 

filter  Parse-YumOutput {
   
        if ($_ -match "(^[\S]+\.[\S]+[^ ]+)(?:\s+)([\S][^ ]+)(?:\s+)(@)*([\S]+[ ]*$)")
            {
            "" | select `
            @{N='Name'; E={$Matches[1]}},
            @{N='Version'; E={$Matches[2]}},
            @{N='Repo'; E={$Matches[4]}},
            @{N='Installed'; E= {
                if ($Matches[3]) { 
                    $true
                    }
                    else {
                    $false
                    }
                    }#end E
                }#end @
            } #end if
       
} #end function

function Get-YumPackage {
[CmdletBinding(DefaultParameterSetName="None")]
param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$True, ValueFromRemainingArguments=$true)]
    [string[]]$PackageList,
    [parameter(Mandatory=$false, ParameterSetName="Installed")]
    [switch]$Installed,
    [parameter(Mandatory=$false, ParameterSetName="Updates")]
    [switch]$Updates,
    [parameter(Mandatory=$false, ParameterSetName="Available")]
    [switch]$Available,
    [switch]$CacheOnly
    )
    $Command = 'list'
    if ($PSCmdlet.ParameterSetName -eq 'Installed') {
        $Command = 'list installed' }
    if ($PSCmdlet.ParameterSetName -eq 'Updates') {
        $Command = 'list updates' }
    if ($PSCmdlet.ParameterSetName -eq 'Available') {
        $Command = 'list available' }
 
    $InvocationObject = @{
        AsObject = $AsObject
        Command = $Command
        PackageList = $PackageList
        CacheOnly = $CacheOnly
        Confirm = $false
        }
    
    $Invoke = Invoke-YumCommand -InvocationObject $InvocationObject  
    
    if ($invoke.LastExitCode -eq 0) {
        $Invoke.Output | Write-Debug
        $Invoke.Output | Parse-YumOutput
        }
        else {
        $invoke.Output
        }
} #end get package


function Install-YumPackage {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$True, ValueFromRemainingArguments=$true)]
    [string[]]$PackageList,
    [switch]$CacheOnly,
    [switch]$Confirm = $false,
    [switch]$AsObject
    )
    $InvocationObject = @{
        AsObject = $AsObject
        Command = "install"
        PackageList = $PackageList
        CacheOnly = $CacheOnly
        Confirm = $Confirm
        }
    Invoke-YumCommand -InvocationObject $InvocationObject  
} #end get package


<#
function Get-YumPackage {
[CmdletBinding()]
param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [string[]]$PackageName,
    [switch]$Installed,
    [switch]$CacheOnly
    )
    
    foreach ($Package in $PackageName) {
        "Package name $Package" | Write-Verbose
        #Construct yum argument list
        [string]$sYumParameters = "-q "

        if ($CacheOnly) {
            $sYumParameters += "-C "}

        if ($Installed) {
            $sYumInstalled = "installed "}

        [string]$sYumInvoke = "yum "+ $sYumParameters+"list "+ $sYumInstalled +""+ $Package

        "Invoking $($sYumInvoke)" | Write-Verbose
        
        $sYumOutput = Invoke-Expression $sYumInvoke
        Parse-YumOutput -YumOutput $sYumOutput
    } #end foreach
} #end get package
 

function Install-YumPackage {
 [CmdletBinding()]
 param (
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [string[]]$PackageName,
    [switch]$CacheOnly
    )
     foreach ($Package in $PackageName) {
        "Package name $Package" | Write-Verbose
        #Construct yum argument list
        [string]$sYumParameters = "-y "

        if ($CacheOnly) {
            $sYumParameters += "-C "}
 

        [string]$sYumInvoke = "yum "+ $sYumParameters+"install "+ $Package

        "Invoking $($sYumInvoke)" | Write-Verbose
        
        Invoke-Expression $sYumInvoke
        
    } #end foreach
}#end install yumpackage
#>
function Get-YumRepository {
    [CmdletBinding(DefaultParameterSetName='Name')]
    param(
    [parameter(Mandatory=$false,ParameterSetName="Name", ValueFromPipeline=$True, Position = 0)] 
    [String]$Name,
    [parameter(Mandatory=$False, ParameterSetName="ListEnabled")]
    [switch]$ListEnabled
    )
    function Get-YumEnabledRepositories {
      try {
            $YumList = yum-config-manager | Select-String -Pattern '=+\s+repo\:' 
            @($YumList -replace '=+\s+repo\:\s+(.+)\s=+','$1')
            }#end try
        catch {
            if ($Error[0].FullyQualifiedErrorId -eq 'CommandNotFoundException') {
                $ErrMsg = 'yum-config-manager executable cannot be found, check "Get-YumPackage -PackageName yum-utils"'
                }
            else {
                $ErrMsg = "Unknown error is occured,"+`
                " LASTEXITCODE is $($LASTEXITCODE)"+`
                " shelloutput is:"+`
                $($MySqldOutput)
                }#end if
            Throw $ErrMsg
            }#end catch
 
    }#end helper func

    if ($PSCmdlet.ParameterSetName -eq 'ListEnabled') {
        Get-YumEnabledRepositories
        }#end if $PSCmdlet ListEnabled

    if ($PSCmdlet.ParameterSetName -eq 'Name') {
        try {
            $YumList = Get-YumEnabledRepositories
            }
        catch {
            }
            $RepoFiles = gci /etc/yum.repos.d/ -Filter '*.repo'
            $RepositoryList = foreach ($RepoFile in $RepoFiles) {
                switch -regex -file $RepoFile.fullname {
                    "^\[(.+)\]$" {
                    
                        '' | select `
                            @{N='Name';E={$matches[1].Trim()}},
                            @{N='File';E={$RepoFile.BaseName}},
                            @{N='Path';E={$RepoFile.FullName}},
                            @{N='Enabled';E={$YumList -contains $matches[1].Trim()}}
                        continue
                        }

                    }#end switch
                }#end %
            if ($Name) {
                $RepositoryList | ? Name -Like $Name 
                }
                else {
                $RepositoryList
                }
        } #end if $PSCmdlet Name
    }#end Function

function Enable-YumRepository {
    [CmdletBinding()]
    param(
    [Parameter(ValueFromPipeLine=$true)]
    $Name
    )
    if ($Name.Name) {
        $Name = $Name.Name
        }
    yum-config-manager --enable $Name
    }#end Function

function Disable-YumRepository {
    [CmdletBinding()]
    param(
    [Parameter(ValueFromPipeLine=$true)]
    $Name
    )
    if ($Name.Name) {
        $Name = $Name.Name
        }
    yum-config-manager --disable $Name
    }#end Function

