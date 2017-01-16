 <xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
     xmlns:msxsl="urn:schemas-microsoft-com:xslt" exclude-result-prefixes="msxsl">
     
    <xsl:output method="html"/>
  
    
   <xsl:template match ="/">
     <html>
       <head> 
         <script language="javascript" type="text/javascript"></script>
       </head>
       <body>
         <h2>Server report</h2>
         <table border="1">
       <tr bgcolor="aqua">
         <th style="text-align:Left"> EmployeeId</th>
         <th style="text-align:Left"> Employee Name</th>
         <th style="text-align:Left"> Department</th>
         <th style="text-align:Left"> Phone No Name</th>
         <th style="text-align:Left"> Email ID</th>
         <th style="text-align:Left"> Salary</th>
       </tr>
       <xsl:for-each select="SqlServerInfo/QueryResults">
         <tr>        
           <td>              
             <xsl:value-of select="@name" />
           </td>        
           <td>            
             <xsl:value-of select="EmpName"/>
           </td>        
           <td>            
             <xsl:value-of select="Department"/>
           </td>        
           <td>            
             <xsl:value-of select="PhNo"/>
           </td>        
           <td>            
             <xsl:value-of select="Email"/>
           </td>        
             <td>              
               <xsl:value-of select="Salary"/>
             </td>          
         </tr>
       </xsl:for-each>
     </table>
	 
	 <xsl:for-each select="SqlServerInfo/DatabaseInfo">
		<h2><xsl:value-of select="@name" /></h2>
		<xsl:for-each select="QueryResults">
			<h3><xsl:value-of select="@name" /></h3>
		</xsl:for-each>
	 </xsl:for-each>
	 
	 
         <br/>
         <br/>
         <form id ="form" method="post" >        
         </form>
         </body>
     </html>
   </xsl:template>
 </xsl:stylesheet>
  