$xslt = new-object system.xml.xsl.xslcompiledtransform

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

$xsltFile = "$PSScriptRoot\Transform.xslt"

$xsltFile
$xslt.load($xsltFile)
$xslt.Transform("$PSScriptRoot\Results2.xml", "$PSScriptRoot\report.html")