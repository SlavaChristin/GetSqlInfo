$ErrorActionPreference = "Stop"
    
Add-Type -AssemblyName System.Web      

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$targetDir = "$PSScriptRoot\report";

if (-Not (Test-Path -Path $targetDir))
{
    New-Item -ItemType directory -Path $targetDir
}

function writeValue($html, $columnName, $value, $longText) 
{
    $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Td);
    if ($longText){
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                            
        $html.AddAttribute([System.Web.UI.HtmlTextWriterAttribute]::Href, "./detail-$baseName-$columnName-$rowIndex.txt");
        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::A);
        $html.WriteEncodedText("show");
        $html.RenderEndTag();
                                
        $w = [System.IO.StreamWriter] "$targetDir/detail-$baseName-$columnName-$rowIndex.txt"
        $w.Write($value);
        $w.Flush();
        $w.Close();
    } 
    else
    {
        $html.WriteEncodedText($value);
    }
    $html.RenderEndTag();

}


function processQueryResuls([System.Xml.XmlReader] $xml, $fileName, $header) {
    # new-object System.IO.StringWriter 
    $stream = [System.IO.StreamWriter] $fileName 
    $html = new-object System.Web.UI.HtmlTextWriter($stream)
    $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Html);
    $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Head) 
    $html.WriteLine("<META http-equiv=`"Content-Type`" content=`"text/html; charset=utf-8`"><script language=`"javascript`" type=`"text/javascript`"></script>")
    $html.RenderEndTag();
    $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Body);
    $html.WriteLine("<h1>$header</h1>")
    
    $rowIndex = 0
    $level = 0
    $firstRow = @()
    :main
    while ($xml.read())
    {
        switch ($xml.NodeType)
        {
            ([System.Xml.XmlNodeType]::EndElement) {
                switch($xml.Name)
                {
                    "Row"
                    {
                        $html.RenderEndTag();
                        if ($rowIndex -eq 0) 
                        {
                            $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Tr);
                            foreach ($row in $firstRow) {
                                writeValue $html $row.columnName $row.value $row.longText


                            }
                            #$firstRow += @{ columnName=$columnName;longText=$longText; value=$value }
                            $html.RenderEndTag();
                        }
                        $rowIndex++;
                        break;
                    }
                    "QueryResults"
                    {
                        $html.RenderEndTag();
                        break;
                    }
                }
                if ($level -eq 0)
                {
                    break main;
                }
                break;
            }
            ([System.Xml.XmlNodeType]::Element) # Make sure to put this between brackets
            {
                 $level++;
                 switch($xml.Name)
                 {
                     "SqlServerInfo" 
                     { 
                        break;
                     }
                     "QueryResults" 
                     {
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::H2);
                        $html.Write($xml.GetAttribute("name"));
                        $html.RenderEndTag();
                        
                        $html.AddAttribute("border", "1");
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Table);
                        
                        $rowIndex = 0
                        $firstRow = @()

                        break;
                     }
                     "DatabaseInfo"
                     {
                        $html.writeLine("<br/>");
                        
                        $dbName = $xml.GetAttribute("name")
                        
                        $html.write("Database ");
                        $html.AddAttribute([System.Web.UI.HtmlTextWriterAttribute]::Href, "./database-$dbName.html");
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::A);
                        $html.write($dbName);
                        $html.RenderEndTag();
                        processQueryResuls $xml "$targetDir/database-$dbName.html" "Database $dbName"
                        break;
                     }
                     "Row" 
                     {
                        if ($rowIndex -eq 0) {
                            $html.AddAttribute("bgcolor", "aqua");
                        } 
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Tr);
                        break;
                     }
                     "Property"
                     {
                        $columnName = $xml.GetAttribute("name");
                        $longText = $xml.GetAttribute("longText") -eq "1"
                        $value = $xml.ReadString();

                        if ($rowIndex -eq 0) 
                        {
                            $html.AddAttribute("style", "text-align:Left");
                            $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Th);
                            $html.WriteEncodedText($columnName);
                            $html.RenderEndTag();

                            $firstRow += @{ columnName=$columnName;longText=$longText; value=$value }
                        } 
                        else 
                        {
                            writeValue $html $columnName $value $longText
                        }
                        break;
                     }
                    
                 }
                break;
            }
        }
    }
    $html.RenderEndTag();
    $html.RenderEndTag();
    $stream.Flush();
    $stream.Close();
}

Remove-Item "$targetDir\*"

$xml = [System.Xml.XmlReader]::Create("$PSScriptRoot\results.xml")
processQueryResuls $xml "$targetDir\report.html" "Server report"
$xml.close()
