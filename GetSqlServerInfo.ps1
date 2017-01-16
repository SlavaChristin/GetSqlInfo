param(
    [string]$Server               = '.\sql2012',
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
                             -AbortOnError -MaxCharLength 100000000 #-OutputSqlErrors 1
    } else {
        return Invoke-Sqlcmd -Query $SqlQuery -ServerInstance $Server -Database $Db `
                             -AbortOnError -MaxCharLength 100000000 #-OutputSqlErrors 1
    }
}

function SaveQueryResults($QueryName, $DatabaseName, $xmlWriter, $cdataColumns) 
{
    $query = GetQueryText $QueryName
    
    
    $xmlWriter.WriteStartElement("QueryResults")
    $xmlWriter.WriteAttributeString("name", $QueryName)  
    try  {
        $result = RunQuery $query $DatabaseName
        
        foreach ($row in $result) {
           $xmlWriter.WriteStartElement("Row")
           foreach ($column in $row.Table.Columns) {
               $xmlWriter.WriteStartElement("Property")
               $xmlWriter.WriteAttributeString("name",$column)
               $value = $row.Item($column);
               if ($cdataColumns -contains $column) {
                   $xmlWriter.WriteCData($value)
               } else {
                   $xmlWriter.WriteString($value)
               }
               $xmlWriter.WriteEndElement()
           }
           $xmlWriter.WriteEndElement();
        }
    } catch [Exception] {
        #$_.Exception.GetType().FullName + ":" + $_.Exception.Message + $OFS + $OFS | Out-File -append $ResultFile -encoding utf8
        $xmlWriter.WriteStartElement("Message")
        $xmlWriter.WriteString($_.Exception.Message)
        $xmlWriter.WriteEndElement();
    }
    $xmlWriter.WriteEndElement();
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

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResultFile = "$PSScriptRoot\Results2.xml"


[xml]$Queries = Get-Content $PSScriptRoot\Queries.xml

#Get-Date | Out-File $ResultFile -encoding utf8

$date = Get-Date -Format g

# Create The Document
$xmlWriter = New-Object System.XMl.XmlTextWriter($ResultFile,$Null)
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
$xmlWriter.WriteStartDocument()

$xmlWriter.WriteStartElement("SqlServerInfo")
$xmlWriter.WriteAttributeString("name", $Server)
$xmlWriter.WriteAttributeString("collectedAt",$date)
$xmlWriter.WriteAttributeString("scriptVersion","1.0")
$xmlWriter.WriteAttributeString("collectedBy",[Environment]::UserName)


foreach ($query in $Queries.Queries.Query | where { $_.level -eq "server" })
{      
    $cdataColumns = if ($query.textColumns -eq $null) { @() } else { $query.textColumns.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries) };
   
    SaveQueryResults $query.name "master" $xmlWriter $cdataColumns
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
        $xmlWriter.WriteAttributeString("version",   $appVersion.Version)
        $xmlWriter.WriteAttributeString("dbVersion", $appVersion.DatabaseVersion)
    
        Write-Host "Handling database $($db.name)"

        foreach ($query in $Queries.Queries.Query | where { $_.level -eq "db" })
        {       
              $cdataColumns = if ($query.textColumns -eq $null) { @() } else { $query.textColumns.Split(",",[System.StringSplitOptions]::RemoveEmptyEntries) };
              SaveQueryResults $query.name  $db.name $xmlWriter $cdataColumns
        }
        $xmlWriter.WriteEndElement();
    }
}

$xmlWriter.WriteEndElement();
$xmlWriter.WriteEndDocument();
$xmlWriter.Flush();
$xmlWriter.Close();