param(
    [string]$Server               = 'OPS80\BID2WIN',
    [string]$Username             = $null,
    [string]$Password             = $null,
    [string]$IgnoreDatabases      = $null,

    [switch]$Offline              = $false	
)

function GetQueryText($QueryName) 
{
    $QueryText = $Queries.SelectSingleNode("/Queries/Query[@name='$QueryName']")
    
    # TODO Check if query text is empty
    return $QueryText.InnerText
}


function RunQuery($SqlQuery, $Db) 
{
    if ($Verbose) {
		Write-Host "Running query: $SqlQuery"
    }

    if ($Username -and $Password) {
        return Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $Server -Database $Db `
                             -Username $Username -Password $Password `
                             -Verbose -AbortOnError -OutputSqlErrors 1
    } else {
        return Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $Server -Database $Db `
                             -Verbose -AbortOnError -OutputSqlErrors 1
    }
}

function SaveQueryResults($QueryName, $DatabaseName) 
{
    $OFS = "`r`n"
    $query = GetQueryText $QueryName
    "Results for $QueryName " | Out-File -append $ResultFile -encoding utf8
    try  {
        $result = RunQuery $query $DatabaseName
        $result | Format-Table -AutoSize | Out-String -Width 4096 | Out-File -append $ResultFile -encoding utf8
    } catch [Exception] {
        $_.Exception.GetType().FullName + ":" + $_.Exception.Message + $OFS + $OFS | Out-File -append $ResultFile -encoding utf8
    }

}


$ErrorActionPreference = "Stop"

Write-Host "     Server: $Server"
Write-Host "   Username: $Username"

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResultFile = "$PSScriptRoot\Results.txt"


[xml]$Queries = Get-Content $PSScriptRoot\Queries.xml 

Get-Date | Out-File $ResultFile -encoding utf8


foreach ($query in $Queries.Queries.Query | where { $_.level -eq "server" })
{      
    SaveQueryResults $query.name "master"
}

$query = 
@"
    select 
        database_id, 
        name 
    from 
        sys.databases 
    where 
        name not in ('master', 'model', 'msdb','tempdb') 
        and  state=0 /* ONLINE */ 
        and is_distributor=0
"@

$dbList = RunQuery $query "master"

foreach ($db in $dbList) {      
    $appVersion= RunQuery "if object_id('DatabaseVersionInformation') is not null  select Version, DatabaseVersion, DatabaseID from DatabaseVersionInformation" $db.name
       
    if ($appVersion.Version -and $appVersion.DatabaseVersion) {
        "-----------------------------------" | Out-File -append $ResultFile -encoding utf8
        "Database " + $db.name | Out-File -append $ResultFile -encoding utf8  
        "-----------------------------------" | Out-File -append $ResultFile -encoding utf8

        $appVersion.Version 
        $appVersion.DatabaseVersion

        foreach ($query in $Queries.Queries.Query | where { $_.level -eq "db" })
        {       
              SaveQueryResults $query.name  $db.name
        }
    }
}

# 




#Write-Host "Found $($dbs.Count) databases"

#foreach ($db in $dbs)
#{      
#    Write-Host "Processing db $($db.name)"
#}

# $DeploymentScriptFooter = "just text"
# Get-content $ScriptFolder\SeedData\Base.sql | Out-File -filePath $DeploymentScript -append -encoding utf8;
# $DeploymentScriptFooter | Out-File -filePath $DeploymentScript -append -encoding utf8;
