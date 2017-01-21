#$xslt = new-object system.xml.xsl.xslcompiledtransform

Add-Type -AssemblyName System.Web      

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition

#$xsltFile = "$PSScriptRoot\Transform.xslt"

#$xsltFile
#$xslt.load($xsltFile)
#$xslt.Transform("$PSScriptRoot\Results2.xml", "$PSScriptRoot\report.html")

$targetDir = "$PSScriptRoot\report";

if (-Not (Test-Path -Path $targetDir))
{
    New-Item -ItemType directory -Path $targetDir
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
    :main
    while ($xml.read())
    {
        switch ($xml.NodeType)
        {
            ([System.Xml.XmlNodeType]::EndElement) {
                switch($xml.Name)
                {
                    "Row"{
                        $html.RenderEndTag();
                        $rowIndex++
                        break;
                    }
                    "QueryResults"{
                        $html.RenderEndTag();
                        break;
                    }
                }
                if ($level -eq 0){
                    break main;
                }
                break;
            }
            ([System.Xml.XmlNodeType]::Element) # Make sure to put this between brackets
            {
                 $level++;
                 switch($xml.Name)
                 {
                     "SqlServerInfo" { 
                        break;
                     }
                     "QueryResults" {
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::H2);
                        $html.Write($xml.GetAttribute("name"));
                        $html.RenderEndTag();
                        
                        $html.AddAttribute("border", "1");
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Table);
                        
                        $rowIndex = 0
                        break;
                     }
                     "DatabaseInfo"{
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
                     "Row"{
                        if ($rowIndex -eq 0){
                            $html.AddAttribute("bgcolor", "aqua");
                        } 
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Tr);
                        break;
                     }
                     "Property"{
                        $columnName = $xml.GetAttribute("name");
                        if ($rowIndex -eq 0){
                        #<th style="text-align:Left"><xsl:value-of select="@name" /></th>
                            $html.AddAttribute("style", "text-align:Left");
                            $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Th);
                            $html.WriteEncodedText($columnName);
                            $html.RenderEndTag();
                        } else {
                            $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Td);
                            $longText = $xml.GetAttribute("longText") -eq "1"
                            
                            $value = $xml.ReadString();
                            if ($value.length -gt 128 -and $longText){
                                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
                            
                                $html.AddAttribute([System.Web.UI.HtmlTextWriterAttribute]::Href, "./detail-$baseName-$columnName-$rowIndex.txt");
                                $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::A);
                                $html.WriteEncodedText($value.SubString(0,32)+"...");
                                $html.RenderEndTag();
                                
                                $w = [System.IO.StreamWriter] "$targetDir/detail-$baseName-$columnName-$rowIndex.txt"
                                $w.Write($value)
                                $w.Flush()
                                $w.Close();
                            } else {
                                $html.WriteEncodedText($value);
                            }
                            $html.RenderEndTag();
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

$xml = [System.Xml.XmlReader]::Create("$PSScriptRoot\Results.xml")
processQueryResuls $xml "$targetDir\report.html" "Server report"
$xml.close()


