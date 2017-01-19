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

function ProcessSql($xmlWriter, $comment, $sql, $i, $fileInfo) {
    if ($i -eq 0){
       # $xmlWriter.WriteComment(($comment+"`r`n    "+$sql).Replace("--","//"))
    } else {

        $pattern =  "(?m)^--\s*(?<desc>.+?)\s*\(Query (?<id>[\d]+)\)\s*\((?<name>.+?)\)"
        if ($comment -match $pattern){
            $id   = $Matches["id"]
            $desc = $Matches["desc"]
            $name = $Matches["name"]

            $query =  @{ id= $id; name=$name; description=$desc; file=$fileInfo; level = $queryLevel; text = $sql; comment=$comment }
            $global:Queries += $query;

        } else {
            Write-Host "WARN: can't parse`r`n$comment"
        }
    }
}

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ResultFile = "$PSScriptRoot\Queries.xml"

$xmlWriter = New-Object System.XMl.XmlTextWriter($ResultFile,$Null)
$xmlWriter.Formatting = "Indented"
$xmlWriter.Indentation = "4"
$xmlWriter.WriteStartDocument()
$xmlWriter.WriteStartElement("Queries")

$Files = 
   @{ name = "SQL Server 2005.sql";    version = "9.0.0"   },
   @{ name = "SQL Server 2008 R2.sql"; version = "10.0.0"  },
   @{ name = "SQL Server 2008.sql";    version = "10.50.0" },
   @{ name = "SQL Server 2012.sql";    version = "11.0.0"  },
   @{ name = "SQL Server 2014.sql";    version = "12.0.0"  },
   @{ name = "SQL Server 2016.sql";    version = "13.0.0"  },
   @{ name = "SQL Server vNext.sql";   version = "14.0.0"  }

$Queries = @()

$Files | Foreach-Object {
    $queryLevel = "server"
    $fileName = "$PSScriptRoot\$($_.name)"

    Write-Host "Parsing file $fileName"

    # $xmlWriter.WriteComment($fileName)

    $reader = [System.IO.File]::OpenText($fileName)

    $fileInfo = $_

    try {
        [State]$state = [State]::NONE
        $i = 0
        while($null -ne ($line = $reader.ReadLine())) {
            if ($line.contains("Database specific queries")) {
                $queryLevel = "db"
            }
            switch ($state) {
                NONE {
                    $text = $line
                    if ($line.StartsWith("--") -or $line.length -eq 0) {
                        $state = [State]::COMMENT_FIRST
                    } else {
                        $state = [State]::SQL_FIRST
                    }
                    continue;
                }
                COMMENT_FIRST{
                    if ($line.StartsWith("--") -or $line.length -eq 0) {
                        $text += "`r`n   " + $line
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
                    if ($line.StartsWith("--")  -or $line.length -eq 0) {
                        $text += "`r`n$line"
                    } else {
                        #Write-Host "Parsed comment:`r`n$text`r`n"
                        $comment = $text
                        $text = $line
                        $state = [State]::SQL_FIRST
                    }
                    continue;
                }
                SQL_FIRST{
                    if (!$line.StartsWith("--")) {
                        $text += "`r`n"+$line
                        $state = [State]::SQL
                    } else {
                        ProcessSql $xmlWriter $comment $text ($i++) $fileInfo
                        $text = $line
                        $state = [State]::COMMENT_FIRST
                    }
                    continue;
                }
                SQL{
                    if (!$line.StartsWith("----")) {
                        $text += "`r`n"+$line
                    } else {
                        ProcessSql $xmlWriter $comment $text ($i++) $fileInfo
                        $text = $line
                        $state = [State]::COMMENT_FIRST
                    }
                    continue;
                }
            }
        }
        if (($state -eq [State]::SQL_FIRST) -or ($state -eq [State]::SQL)){
            ProcessSql $xmlWriter $comment $text $i $fileInfo
        }    
    } 
    finally {
        $reader.Close()
    }

}

$QueriesSorted = $Queries | Sort-Object -property @{Expression = {$_.name}; Ascending = $true}, @{Expression = {$_.file.name}; Ascending = $true} 

foreach ($query in $QueriesSorted) 
{
    $xmlWriter.WriteComment($query.comment.Replace("--","//"))
                                   
    $xmlWriter.WriteStartElement("Query")
      
    $xmlWriter.WriteAttributeString("id",          $query.id)
    $xmlWriter.WriteAttributeString("name",        $query.name)
    $xmlWriter.WriteAttributeString("description", $query.description)
    $xmlWriter.WriteAttributeString("file",        $query.file.name)
    $xmlWriter.WriteAttributeString("fileVersion", $query.file.version)
    $xmlWriter.WriteAttributeString("level",       $query.level)
    $xmlWriter.WriteCData("`r`n$($query.text)`r`n")

    $xmlWriter.WriteEndElement();
}

$xmlWriter.WriteEndElement();
$xmlWriter.WriteEndDocument();
$xmlWriter.Flush();
$xmlWriter.Close();