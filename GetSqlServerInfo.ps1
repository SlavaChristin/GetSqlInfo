param(
    [string]$Server               = 'OPSDEPLOY-13',
    [string]$Username             = $null,
    [string]$Password             = $null,
    [string]$IgnoreDatabases      = $null,

    [switch]$Offline              = $false	
)


function RunQuery($SqlQuery, $Db) 
{
    if ($Verbose) {
		Write-Host "Running query: $SqlQuery"
    }

    if ($Username -and $Password) {
        return Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $Server -Database $Db `
                             -Username $Username -Password $Password -QueryTimeout 200 `
                             -AbortOnError -MaxCharLength 100000000 #-OutputSqlErrors 1
    } else {
        return Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $Server -QueryTimeout 200 -Database $Db `
                             -AbortOnError -MaxCharLength 100000000 #-OutputSqlErrors 1
    }
}

function SaveQueryResults($Query, $DatabaseName, $xmlWriter, $cdataColumns) 
{
    $QueryName = $Query.name

    $QueryText = $Query.InnerText
    
    $xmlWriter.WriteStartElement("QueryResults")
    $xmlWriter.WriteAttributeString("name", $QueryName)  
    try  {
        $StartTime=(GET-DATE)
        
        $result = RunQuery $QueryText $DatabaseName

        $EndTime=(GET-DATE)        
        $TimeDiff = ($StartTime-$EndTime).duration()
        $xmlWriter.WriteAttributeString("executionTime", $TimeDiff)  

        Write-Host "$($TimeDiff): Finished query $QueryName $($Query.file)  $($Query.fileVersion)" -foregroundcolor "green"

        foreach ($row in $result) {
           $xmlWriter.WriteStartElement("Row")
           foreach ($column in $row.Table.Columns) {
               $xmlWriter.WriteStartElement("Property")
               $xmlWriter.WriteAttributeString("name",$column)
               $value = $row.Item($column);
               if ($cdataColumns -contains $column) {
                   $xmlWriter.WriteAttributeString("longText","1")
                   $xmlWriter.WriteCData($value)
               } else {
                   $xmlWriter.WriteString($value)
               }
               $xmlWriter.WriteEndElement()
           }
           $xmlWriter.WriteEndElement();
        }
        
    } catch [Exception] {
        $Message = $_.Exception.Message
        Write-Host "Cannot process query $QueryName $($Query.file) : $Message" -foregroundcolor "red"
        #$_.Exception.GetType().FullName + ":" + $_.Exception.Message + $OFS + $OFS | Out-File -append $ResultFile -encoding utf8
        $xmlWriter.WriteStartElement("Message")
        $xmlWriter.WriteString($Message)
        $xmlWriter.WriteEndElement();
    }
    $xmlWriter.WriteEndElement();
}

function compareSqlVersions($versionA, $versionB) {
    $a1,$a2,$a3,$a4 = $versionA.split('.', 4)
    $b1,$b2,$b3,$b4 = $versionB.split('.', 4)
    if (!$b4) {
       $b4 = "0"
    }
    if (!$a4) {
        $a4 = "0"
    }

    if ([int]$a1 -gt [int]$b1) {
        return 1;
    } elseif ([int]$a1 -lt [int]$b1) {
        return -1;
    }

    if ([int]$a2 -gt [int]$b2) {
        return 2;
    } elseif ([int]$a2 -lt [int]$b2) {
        return -2;
    }

    if ([int]$a3 -gt [int]$b3) {
        return 3;
    } elseif ([int]$a3 -lt [int]$b3) {
        return -3;
    }

    if ([int]$a4 -gt [int]$b4) {
        return 4;
    } elseif ([int]$a4 -lt [int]$b4) {
        return -4;
    }

    return 0;
}

#if ( (Get-PSSnapin -Name SqlServerCmdletSnapin100 -ErrorAction SilentlyContinue) -eq $null ){
#    Add-PsSnapin SqlServerCmdletSnapin100
#}
#if ( (Get-PSSnapin -Name SqlServerProviderSnapin100 -ErrorAction SilentlyContinue) -eq $null ){
#    Add-PsSnapin SqlServerProviderSnapin100
#}

$ErrorActionPreference = "Stop"

Write-Host "     Server: $Server"
Write-Host "   Username: $Username"

$ScriptLocation = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResultFile = "$ScriptLocation\results.xml"

$serverVersion = (RunQuery "select SERVERPROPERTY('ProductVersion') as version" "master").version
Write-Host "Server version is $serverVersion"

[xml]$Queries = Get-Content $ScriptLocation\Queries\Queries.xml

$queriesToRun = @{}
$queriesActiveVersion = @{}

foreach ($query in $Queries.Queries.Query | where { (compareSqlVersions $serverVersion  $_.fileVersion)  -ge 0 })
{
    if (!$queriesToRun[$query.name]) {
        $queriesToRun[$query.name] = $query
    } elseif ((compareSqlVersions $query.fileVersion $queriesToRun[$query.name].fileVersion)  -ge 0) {
        $queriesToRun[$query.name] = $query
    }
        
}

# foreach ($query in $queriesToRun.Values) 
#{
#    Write-Host "$($query.name) $($query.minVersion)"
#}


$date = Get-Date -Format s

Write-Host "Saving results to $ResultFile"
# Create The Document
$xmlWriter = New-Object System.XMl.XmlTextWriter($ResultFile, $Null)
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
$xmlWriter.WriteStartDocument()

$xmlWriter.WriteStartElement("SqlServerInfo")
$xmlWriter.WriteAttributeString("name", $Server)
$xmlWriter.WriteAttributeString("collectedAt", $date)
$xmlWriter.WriteAttributeString("scriptVersion", "1.0")
$xmlWriter.WriteAttributeString("collectedBy", [Environment]::UserName)
$xmlWriter.WriteAttributeString("xmlns:xsi", "http://www.w3.org/2001/XMLSchema-instance")
$xmlWriter.WriteAttributeString("xsi:noNamespaceSchemaLocation", "SqlServerInfo.xsd")


foreach ($query in $queriesToRun.Values | where { $_.level -eq "server" })
{      
    $cdataColumns = if ($query.longTextColumns -eq $null) { @() } else { $query.longTextColumns.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries) };
    SaveQueryResults $query "master" $xmlWriter $cdataColumns
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
    
        $xmlWriter.WriteStartElement("DatabaseInfo")
        $xmlWriter.WriteAttributeString("name", $db.name)
        # $xmlWriter.WriteAttributeString("version",   $appVersion.Version)
        # $xmlWriter.WriteAttributeString("dbVersion", $appVersion.DatabaseVersion)
    
        Write-Host "Handling database $($db.name)"

        foreach ($query in $queriesToRun.Values | where { $_.level -eq "db" })
        {       
              $cdataColumns = if ($query.longTextColumns -eq $null) { @() } else { $query.longTextColumns.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries) };
              SaveQueryResults $query  $db.name $xmlWriter $cdataColumns
        }
        $xmlWriter.WriteEndElement();
    }
}

$xmlWriter.WriteEndElement();
$xmlWriter.WriteEndDocument();
$xmlWriter.Flush();
$xmlWriter.Close();