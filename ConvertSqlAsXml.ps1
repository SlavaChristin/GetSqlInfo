Add-Type -TypeDefinition @"
   public enum State
   {
      NONE,
      COMMENT_FIRST,
      COMMENT,
      SQL_FIRST,
      SQL
   }
"@

function ProcessSql($xmlWriter, $comment, $sql, $i) {
    if ($i -eq 0){
       $xmlWriter.WriteComment(($comment+"`r`n    "+$sql).Replace("--","//"))
       $pattern =  "^IF NOT EXISTS \(SELECT \* WHERE CONVERT\(varchar\(128\), SERVERPROPERTY\(`'ProductVersion`'\)\) LIKE `'(?<version>.+?)`'\)"
       if ($sql -match $pattern){
            $version = $Matches["version"]
            Set-Variable -Name version -Value $version -Scope 1
       } else {
            Write-Host "WARN: Version is not found"
       }
    } else {
        $xmlWriter.WriteComment($comment.Replace("--","//"))
        $pattern =  "(?m)^--\s*(?<desc>.+?)\s*\(Query (?<id>[\d]+)\)\s*\((?<name>.+?)\)"
        if ($comment -match $pattern){
            $id = $Matches["id"]
            $desc = $Matches["desc"]
            $name = $Matches["name"]
            $version = Get-Variable -Name version -Scope 1 -ValueOnly

            $xmlWriter.WriteStartElement("Query")
            $xmlWriter.WriteAttributeString("id",$id)
            $xmlWriter.WriteAttributeString("name",$name)
            $xmlWriter.WriteAttributeString("description",$desc)
            $xmlWriter.WriteAttributeString("version-raw",$version)
            $xmlWriter.WriteCData($sql)
            $xmlWriter.WriteEndElement();
        } else {
            Write-Host "WARN: can't parse`r`n$comment"
        }
    }
    
}

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResultFile = "$PSScriptRoot\Q.xml"

$xmlWriter = New-Object System.XMl.XmlTextWriter($ResultFile,$Null)
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement("Queries")

Get-ChildItem "$PSScriptRoot" -Filter *.sql | Foreach-Object {  $_.FullName
    $reader = [System.IO.File]::OpenText("C:\qu2\GetSqlInfo\SQL Server 2008 R2 Diagnostic Information Queries (CY 2017).sql")
    try {
        [State]$state = [State]::NONE
        $i = 0
        while($null -ne ($line = $reader.ReadLine())) {
            switch ($state){
                NONE {
                    $text = $line
                    if ($line.StartsWith("--") -or $line.length -eq 0){
                        $state = [State]::COMMENT_FIRST
                    } else {
                        $state = [State]::SQL_FIRST
                    }
                    continue;
                }
                COMMENT_FIRST{
                    if ($line.StartsWith("--") -or $line.length -eq 0){
                        $text += "`r`n"+$line
                        $state = [State]::COMMENT
                    } else {
                        #Write-Host "Parsed comment:`r`n$text`r`n"
                        $comment = $text
                        $text = $line
                        $state = [State]::SQL_FIRST
                    }
                    continue;
                }
                COMMENT{
                    if ($line.StartsWith("--")  -or $line.length -eq 0){
                        $text += "`r`n"+$line
                    } else {
                        #Write-Host "Parsed comment:`r`n$text`r`n"
                        $comment = $text
                        $text = $line
                        $state = [State]::SQL_FIRST
                    }
                    continue;
                }
                SQL_FIRST{
                    if (!$line.StartsWith("--")){
                        $text += "`r`n"+$line
                        $state = [State]::SQL
                    } else {
                        ProcessSql $xmlWriter $comment $text ($i++)
                        $text = $line
                        $state = [State]::COMMENT_FIRST
                    }
                    continue;
                }
                SQL{
                    if (!$line.StartsWith("--")){
                        $text += "`r`n"+$line
                    } else {
                        ProcessSql $xmlWriter $comment $text ($i++)
                        $text = $line
                        $state = [State]::COMMENT_FIRST
                    }
                    continue;
                }
            }
        }
        if (($state -eq [State]::SQL_FIRST) -or ($state -eq [State]::SQL)){
            ProcessSql $comment $text $i
        }
    
        
    }
    finally {
        $reader.Close()
    }

}

$xmlWriter.WriteEndElement();
$xmlWriter.WriteEndDocument();
$xmlWriter.Flush();
$xmlWriter.Close();

