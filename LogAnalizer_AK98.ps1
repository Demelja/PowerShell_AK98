# Author: deemmel@gmail.com AKA Dee-Man
# 01/10/2021
# release 19/10/2021
#
# The script should be started inside a directory with zipped log-file (<number>_<data>.zip). 
# Script action result is txt-file filled with TECH_ERROR records.
#
#
# The Magic is over there => ( $record_line -like "*TECH_ERROR*" -Or $record_line -like "*MailErrorGlobal*" )
#
# log-file is "eMMC2 > LogArchive > Archive_...... > logdata > debug > control.log.txt"
#


# 
function Expand-Tar($tarFile, $dest) {

    if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
        Install-Package -Scope CurrentUser -Force 7Zip4PowerShell > $null
    }

    Expand-7Zip $tarFile $dest
}


#
# $PSScriptRoot - Contains the full path to the script that invoked the current command
# $ExtractPath - temporary directory for unpacking
# $ArchivePath - result file
$LogsPath_Main = $PSScriptRoot
$ExtractPath_Main = Join-Path $LogsPath_Main "Temp"
$LogPath_Sub = Join-Path $ExtractPath_Main "eMMC2"
$LogPath_Sub = Join-Path $LogPath_Sub "LogArchive"
$ExtractPath_Sub = Join-Path $LogPath_Sub "Temp"
$ArchiveFile = New-Item -Type File -Force -Path $LogsPath_Main -Name "tech_errors.txt"


$main_archive = Get-ChildItem -Path $LogsPath_Main | Where-Object { $_.PSIsContainer -eq $false -and $_.Extension -eq '.zip' } | Sort-Object -Property { $_.CreationTime } -Descending

Write-Host "`n Total: " $main_archive.Count " files for " $ExtractPath_Main "`n"

ForEach ( $arch in $main_archive ) { 

    New-Item -Type Directory -Force -Path $ExtractPath_Main | Out-Null

    try { Expand-Tar $arch.FullName $ExtractPath_Main }
    catch { 
        "`n===== " | Out-File -Append $ArchiveFile
        $arch.Name | Out-File -Append $ArchiveFile
    }

    $list_archive = Get-ChildItem -Path $LogPath_Sub | Where-Object { $_.PSIsContainer -eq $false -and $_.Extension -eq '.zip' } | Sort-Object -Property { $_.CreationTime } -Descending

    Write-Host "`n Total: " $list_archive.Count " sub-files for " $LogPath_Sub "`n"

    ForEach ( $archive in $list_archive ) {
        
        New-Item -Type Directory -Force -Path $ExtractPath_Sub | Out-Null
        "`n--------" | Out-File -Append $ArchiveFile
        $archive.Name | Out-File -Append $ArchiveFile

        try { Expand-Tar $archive.FullName $ExtractPath_Sub }
        catch {
            "`n>>>>> " | Out-File -Append $ArchiveFile
            $archive.Name | Out-File -Append $ArchiveFile
            " Message: File is corrupted. Crc check has failed" | Out-File -Append $ArchiveFile
        }

        $archive_name = $archive.BaseName
        $LogPath_Debug = Join-Path $ExtractPath_Sub "eMMC2"
        $LogPath_Debug = Join-Path $LogPath_Debug "LogArchive"
        $LogPath_Debug = Join-Path $LogPath_Debug $archive_name
        $LogPath_Debug = Join-Path $LogPath_Debug "logdata"
        $LogPath_Debug = Join-Path $LogPath_Debug "debug"
        
        $list_debug_file = Get-ChildItem $LogPath_Debug | Where-Object { $_.PSIsContainer -eq $false -and $_.Extension -eq '.txt' }
        
        ForEach ( $debug_file in $list_debug_file ) {

            ForEach ( $record_line in Get-Content $debug_file.FullName ) {
            
                if ( $record_line -like "*MailErrorGlobal*" ) {
                    #Write-Host $record_line
                    #$record_line | Out-File -Append $ArchiveFile
                    $str_datetime = $record_line.Substring( 0, 28 )
                    $str_node = $record_line.Substring( $record_line.IndexOf( "nodeNumber" ) + 11, 1 )
                    $str_errcategory = $record_line.Substring( $record_line.IndexOf( "errCategory" ) + 12, 2 )
                    if ( $str_errcategory[1] -eq "," ) { $str_errcategory = "0" + $str_errcategory[0] }

                    $str_errsubcategory = $record_line.Substring( $record_line.IndexOf( "errSubCategory" ) + 15, 2 )
                    if ( $str_errsubcategory[1] -eq "," ) { $str_errsubcategory = "0" + $str_errsubcategory[0] }
                    
                    $str_errindex = $record_line.Substring( $record_line.IndexOf( "errIndex" ) + 9, 2 )
                    if ( $str_errindex[1] -eq "," ) { $str_errindex = "0" + $str_errindex[0] }
                    
                    #$str_datetime + " >>> 0" + $str_node + $str_errcategory + " 0" + $str_errsubcategory + " 0" + $str_errindex + " >>> " + $record_line | Out-File -Append $ArchiveFile
                    $str_datetime + " >>> 0" + $str_node + $str_errcategory + " 0" + $str_errsubcategory + " 0" + $str_errindex | Out-File -Append $ArchiveFile
                }

            }

        }

        Write-Host $archive.BaseName

    }

    Remove-Item $ExtractPath_Main -Force -Recurse

}
