$ScriptFolder = Split-Path -Parent $MyInvocation.MyCommand.Definition

$XmlFile = "$ScriptFolder\results.xml"
$SchemaFile = "$ScriptFolder\SqlServerInfo.xsd"

[scriptblock] $ValidationEventHandler = { Write-Error $args[1].Exception }

$xml = New-Object System.Xml.XmlDocument
$schemaReader = New-Object System.Xml.XmlTextReader $SchemaFile
$schema = [System.Xml.Schema.XmlSchema]::Read($schemaReader, $ValidationEventHandler)
$xml.Schemas.Add($schema) | Out-Null
$xml.Load($XmlFile)
$xml.Validate($ValidationEventHandler)