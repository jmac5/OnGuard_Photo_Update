# Update ID Photos
# jmac@wpi.edu 11/5/21 | Revised for the public 1/24/23

$photoDir = "\\server\directory" #ID Photo Storage Directory.
$server = "leneldb\LENEL" # Lenel DB server
$time_since = (Get-date).AddMinutes(-30).ToString("yyyy-MM-dd HH:mm:ss") #if you want a time delay, say, only changes in the last 30 minutes, define that here.

$Logfile = "\\server\directory\PhotoUpdates.log"

Function Write-log
{
   Param ([string]$logstring)

   Add-content $Logfile -value $logstring
}
$time = Get-Date

Write-log "#########################################################"
Write-log "Photo Update entry for $time"

ForEach($file in Get-ChildItem $photoDir) {   #Work through each picture file in the /Photos Directory
    
    if ($file.CreationTime -gt $time_since) { #if creation date is newer than 30 minutes prior

        $id = $file.BaseName #extract ID number from file name of photo, if you use ID# for file names. 

        $empid = Invoke-Sqlcmd -ServerInstance $server -Query "SELECT EMPID FROM [AccessControl].[dbo].[BADGE] WHERE ID like '$id'" #get the empid off a badge

        $empid = $empid.Item(0) #convert empid into useable value

        $photo = ([System.IO.File]::ReadAllBytes($file.FullName) | Format-Hex | Select-Object -Expand Bytes | ForEach-Object { '{0:x2}' -f $_ }) -join '' #creates LNL_BLOB compatible file
        
        $photo = "0x" + $photo.ToString() # adds 0x to the front so it knows it is Hex
        
        $photoCheck = Invoke-Sqlcmd -ServerInstance $server -Query "IF EXISTS (SELECT LNL_BLOB FROM Accesscontrol.dbo.MMOBJS WHERE EMPID ='$empid') BEGIN SELECT 1 END ELSE BEGIN SELECT 0 END " | Select-Object -ExpandProperty Column1 #see if photo already exists in Lenel DB

        if ($photoCheck -eq 0) {  #photo doesn't exist in DB yet.
            Invoke-Sqlcmd -ServerInstance $server -Query "INSERT INTO [AccessControl].[dbo].[MMOBJS] (empid,object,type,lnl_blob) Values($empid,1,0,$photo)"
            Write-log "Photo Created for $id" #adds a log entry to know what changed
        }else { #photo does exist, but older than last 30 minutes
            Invoke-Sqlcmd -ServerInstance $server -Query "UPDATE [AccessControl].[dbo].[MMOBJS] SET LNL_BLOB = $photo where empid = $empid and object = 1 and type = 0" #update photo in DB
            Write-log "Photo Updated for $id" #adds a log entry to know what changed
        }
    }
}