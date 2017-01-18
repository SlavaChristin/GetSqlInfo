 <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl">
     
    <xsl:output method="html"/>
  
    
	<xsl:template match ="/">
		<html>
			<head> 
				<script language="javascript" type="text/javascript"></script>
			</head>
			<body>
				<h1>Server report</h1>
				
				<xsl:for-each select="SqlServerInfo/QueryResults">
				<h2><xsl:value-of select="@name" /></h2>
				<table border="1">
					<tr bgcolor="aqua">
					<xsl:for-each select="Row[1]/Property">
						<th style="text-align:Left"><xsl:value-of select="@name" /></th>
					</xsl:for-each>
					</tr>
					
					<xsl:for-each select="Row">				
					<tr>        
						<xsl:for-each select="Property">				
						<td>              
						<xsl:value-of select="." />
						</td>
						</xsl:for-each>
					</tr>
					</xsl:for-each>					
				</table>
				
				<br/><br/>
				</xsl:for-each>
	 
				<xsl:for-each select="SqlServerInfo/DatabaseInfo">
				<h2>Database <xsl:value-of select="@name" /></h2>
				
				<xsl:for-each select="QueryResults">
				<h2><xsl:value-of select="@name" /></h2>
				<table border="1">
					<tr bgcolor="aqua">
					<xsl:for-each select="Row[1]/Property">
						<th style="text-align:Left"><xsl:value-of select="@name" /></th>
					</xsl:for-each>
					</tr>
					
					<xsl:for-each select="Row">
					<tr>
						<xsl:for-each select="Property">
						<td>              
						<xsl:value-of select="." />
						</td>
						</xsl:for-each>
					</tr>
					</xsl:for-each>					
				</table>
				</xsl:for-each>
				
				<br/><br/>
				</xsl:for-each>
			</body>
     </html>
   </xsl:template>
 </xsl:stylesheet>
  