$ErrorActionPreference = "Stop"
    
Add-Type -AssemblyName System.Web      

$PSScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$targetDir = "$PSScriptRoot\report";
$detailIndex = 0

if (-Not (Test-Path -Path $targetDir))
{
    New-Item -ItemType directory -Path $targetDir
}

function writeValue($html, $columnName, $value, $longText) 
{
    $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Td);
    if ($longText)
    {                    
        $global:detailIndex++;

        $html.AddAttribute([System.Web.UI.HtmlTextWriterAttribute]::Href, "./detail-$detailIndex.txt");
        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::A);
        $html.WriteEncodedText("show");
        $html.RenderEndTag();
                                
        $w = [System.IO.StreamWriter] "$targetDir/detail-$detailIndex.txt"

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


function processQueryResuls([System.Xml.XmlReader] $xml, $fileName, $header) 
{
    $local:stream = [System.IO.StreamWriter] $fileName

    $local:html = new-object System.Web.UI.HtmlTextWriter($stream)
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
                            foreach ($row in $firstRow) 
                            {
                                writeValue $html $row.columnName $row.value $row.longText
                            }
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
                        if ($dbName) {
                            $html.Write($dbName);
                            $html.Write('::');                                
                        }
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
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::H1);
                        $html.write("Database $dbName");
                        $html.RenderEndTag();
                        break;
                     }
                     "Message"
                     {
                        $html.RenderBeginTag([System.Web.UI.HtmlTextWriterTag]::Span);
                        $html.Write('<strong style="color:red">');
                        $html.WriteEncodedText("Error: $($xml.ReadString())" );
                        $html.Write('</strong>');
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
processQueryResuls $xml "$targetDir\_report.html" "Server report"
$xml.close()
