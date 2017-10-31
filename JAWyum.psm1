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
            }
        }
 
    switch ($InvocationObject.Keys | ? {$InvocationObject[$_]} ) {
        'CacheOnly' { $Options += "--cacheonly "
            }
        }#end switch

    if (-not $InvocationObject['Confirm'].ToBool() ) {
                $Options += "--assumeyes "
                }
    [string]$sYumInvoke = "yum "+ $Options.Trim() +" "+ $InvocationObject.Command +" "+ $InvocationObject.Packagelist

    "Invoking $($sYumInvoke)" | Write-Verbose
        
    $InvokeResult = Invoke-Expression $sYumInvoke
    "Checking LASTEXITCODE" | Write-Debug
    if ($LASTEXITCODE -ne 0) {
        'Something awful happened, examine stderr output, LASTEXITCODE was ' + $LASTEXITCODE | Write-Verbose
        Write-Error -Message $InvokeResult 
        } 
    else {
        if ($InvocationObject['AsObject']) {
            "Invocation was requested to output as object, calling parser" | Write-Debug
            $InvokeResult | Parse-YumOutput
            }
            else {
            $InvokeResult
            }
        }
     
}#end invoke-yumcommand
 


function Parse-YumOutput {
param ($YumOutput)
    $YumOutput | % `
        {
        if ($_ -match "(^[\S][^ ]+)(?:\s+)([\S][^ ]+)(?:\s+)([\S]+[ ]*$)")
            {
            $oPackage = "" | select Name, Version, Repo, @{N='Installed';E={$false}}
            $oPackage.name = $Matches[1]
            $oPackage.version = $Matches[2]
            $oPackage.repo = $Matches[3]
            if (($Matches[3])[0] -eq '@') { 
                $oPackage.Installed = $true
                $oPackage.repo = ($oPackage.repo).Substring(1,($oPackage.repo).Length -1 )
                }
            $oPackage
            } #end if
        } #end %
} #end function


function Get-YumPackage {
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
        Command = "list"
        PackageList = $PackageList
        CacheOnly = $CacheOnly
        Confirm = $Confirm
        }
    Invoke-YumCommand -InvocationObject $InvocationObject  
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

