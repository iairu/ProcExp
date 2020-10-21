/*
Procreate Batch Timelapse Export
made by iairu

Changelog:
    v1 23:29 19-12-17 - ParseXML + KeepOnlyE parsing to a temp file
    v2 18:47 20-01-19 - binary PLIST to XML (finder.archive) using plutil, parsing to a variable instead of a file, user file selection and info
    v3 3:45 20-01-20 - testing/debugging, PLIST to XML variable, completely rewritten ParseXML
    v4 6:07 20-01-20 - implemented inefficient AssignCanvasNames that has to convert all Document.archive to XML for detection
    v4.5 6:39 20-01-20 - expanded Todo with so much stuff I won't sleep for a week if I try to come back to this project
    v5 8:54 20-01-20 - added GUI in a separate file
    v6 22:03 20-01-20 - added all necessary FFMPEG functionality, file encoding fixed, KeepOnlyE is now FilterGaleries with user regex, app content method fully working
    v7 23:11 20-01-20 - merged main script with GUI script, implemented all GUI functionality for app content method
    v8 0:30 20-01-21 - added .procreate file extraction and location, no FFMPEG for it yet, also FFMPEG button gets disabled/enabled and changes methods based on selected tab
    v9 3:31 20-01-21 - fixed FFMPEG concatenation order (builtin AHK file looping goes 1,10,12,...,2,20,3,4,5 = wrong timelapse segment order), fixed timelapse tooltip counter
    v10 19:48 20-01-21 - implemented FFMPEG export for .procreate files method

Todo:
    fix canvases that aren't in stacks and stacks with the default "Stack" name getting appended to a previous stack
    - also count the possibility of the first line in content being a UUID if the first item in procreate is not a gallery
    - can be solved by rechecking how the finder.archive works and then implementing a placeholder gallery name [NO_GALLERY] for these
    - then during FFMPEGexport export [NO_GALLERY] timelapses directly to root folder
    Add AsignCanvasNamesStatus(content) function to regex check all lines if they have asigned filenames, if one or more doesn't, return 0 else 1
    Use AsignCanvasNamesStatus(content) in LoadUUID to (user choice) either stop loading the file or AssignCanvasNames() to the loaded content from it
    Add UUIDfolderCounter(dir) and ProcreateFileCounter(dir) to determine ParseFinder and ProcFolder continuation (in other words check if appcontent and procreate files actually exist)
    also add ExtractedFileCounter to determine existence of timelapse segment files within extracted folders for ProcExtractedLocate
    content variable should be renamed to UUIDtable
    find out if the correct rotation of segments is somewhere in their metadata and fixable during export
    Replace 7z/plutil/ffmpeg if it happens to be 64-bit
    Progress bar subGUI for loading Finder.archive and exporting FFMPEG instead of a Tooltip
    
    

Complex GUI functionality:
    Most likely won't do this, because it's pretty useless with the current options.
    Filtering
    - 2 view methods that can be changed on the fly: thumbnail view and tree view for:
    - Treeview:  A GUI with checkbox and search filters for individual gallery and/or canvas selection -- will use TV_Add(), later search+redrawing
    - Thumbview: A GUI with thumbnails for individual canvases and a dropdown for gallery selection + later autocompleting combobox for search
*/

#SingleInstance Force
SetWorkingDir %A_ScriptDir%
GoSub, LoadPNGDATA
Bytes := Base64Dec( BIN, PNGDATA )
VarZ_Save( BIN, Bytes, A_Temp . "\procreate_timelapse_export_BANNER.png" )
VarSetcapacity( PNGDATA, 0 )

Gui -MaximizeBox
Gui Color, White
Gui Add, Picture, x0 y0, %A_Temp%\procreate_timelapse_export_BANNER.png

; // INTRODUCTION
Gui Add, GroupBox, x8 y88 w461 h91, Introduction
;Gui Add, Text, x32 y112 w299 h58, Batch exporting all the Procreate footage is no easy process.`nClick the "More info" button for a set of instructions.`n`nScripted by iairu in 2020.
Gui Add, Text, x32 y112 w299 h58, Export all .procreate files in "Procreate" format for which you want timelapses and put them into the same folder on PC.`n`nClick the "More info" button for "app content" method.
Gui Add, Button, x352 y112 w80 h23 gMoreInfo, Mo&re Info
Gui Add, Button, x352 y140 w80 h23 gCredits, &Credits

; // OBTAINING INFORMATION
;Gui Add, GroupBox, x8 y184 w461 h171, 2 -- Obtaining information
Gui Add, Tab3, x8 y184 w461 h171 vselectedTab gButtonFFMPEGcontextToggle, Using .procreate files|Using app content

Gui Tab, 1
Gui Add, Text, x32 y218, All .procreate files in the selected folder will be automatically unzipped and processed.`nA new subfolder "_Extracted" will be made for this task. Do not remove the subfolder`n until you export your timelapses, or you will have to start again.
Gui Font, Bold
Gui Add, Button, x32 y278 w416 h23 +Default gProcFolder, &Select a folder with .procreate files
Gui Font
Gui Add, Button, x32 y302 w416 h23 gProcExtractedLocate, or Loc&ate an existing "_Extracted" folder

Gui Tab, 2
Gui Add, Text, x32 y218 w129 h23 +0x200, RegEx Gallery Folder Filter:
Gui Add, Edit, x165 y218 w85 h21 vuserRegex, .*e$
Gui Add, CheckBox, x259 y216 w187 h23 vfilenameToggle, Don't assign filenames (be careful)
Gui Font, Bold
Gui Add, Button, x32 y248 w416 h23 gParseFinder, &Select Finder.archive and get a filtered UUID table
Gui Font
Gui Add, Button, x32 y272 w416 h23 gLoadUUID, or Loa&d already saved UUID table (won't apply RegEx filter)
Gui Add, Button, x32 y312 w416 h23 +Disabled gSaveUUID vButtonSaveUUID, S&ave the newly obtained UUID table to continue later
Gui Tab

; // TIMELAPSE EXPORT
Gui Add, GroupBox, x8 y360 w461 h108, Timelapse export
Gui Add, Text, x32 y384 w417 h35, Here you select a folder where all the gallery folders and timelapses will be saved. Exporting may take some time, because the timelapse segments have to be merged.
Gui Add, Button, x32 y424 w416 h23 +Disabled gExportFFMPEG vButtonExportFFMPEG, Save and &Export timelapses with FFMPEG

Gui Show, w481 h480, Procreate Timelapse Export
Return




; // GUI APPCONTENT METHOD BUTTONS
ParseFinder:
    Gui, Submit, NoHide
    if (userRegex == "")
        userRegex := ".*$"
    ;plistPath = C:\Desktop\Procreate Timelapse Remote Auto Batch Export\_input\syncd\Finder.archive ; for debugging, otherwise selected by user
    FileSelectFile plistPath,,Finder.archive,Select Finder.archive file, Finder.archive (*.archive)
    If (plistPath == "")
        return
    If !FileExist(plistPath) {
        MsgBox % "Specified file doesn't exist"
        return
    }
    procPath :=
    SplitPath, plistPath,, appcontentPath
    content := PLISTtoXMLvar(plistPath) ; uses apple's plutil for conversion
    content := ParseXMLvar(content) ; only <string> content and crop useless parts
    content := FilterGalleries(content, userRegex) ; GUI submitted userRegex
    if (!filenameToggle) {
        content := AssignCanvasNames(content, appcontentPath) ; gets all the canvas names from Document.archive files through Regex and plutil
        if (content != "" && appcontentPath != "") {
            GuiControl, Enable, ButtonSaveUUID
            GuiControl, Enable, ButtonExportFFMPEG
        }
    }
    else {
        content := OnlyKeepUUIDs(content)
        if (content != "") {
            GuiControl, Enable, ButtonSaveUUID
            GuiControl, Disable, ButtonExportFFMPEG
        }
    }
    return

LoadUUID:
    Gui, Submit, NoHide
    If !FileExist(A_ScriptDir . "\apple_plutil\plutil.exe") {
        MsgBox,16,, % "ERROR`napple_plutil/plutil.exe is missing and necessary for binary PLIST conversion"
        return
    }
    if (userRegex == "")
        userRegex := ".*$"

    FileSelectFile loadPath,,,Select a UUID file to load, Procreate UUID table (*.pxuuid)
    If (loadPath == "")
        return
    If !FileExist(loadPath) {
        MsgBox % "Specified file doesn't exist"
        return
    }
    FileRead, content, %loadPath%
    
    FileSelectFolder, appcontentPath,,,Select app content folder
    If (appcontentPath == "")
        return
    If !FileExist(appcontentPath) {
        MsgBox % "Specified folder doesn't exist"
        return
    }
    
    procPath :=
    if (content != "")
        GuiControl, Enable, ButtonSaveUUID
    if (content != "" && appcontentPath != "")
        GuiControl, Enable, ButtonExportFFMPEG
    return
    
SaveUUID:
    Gui, Submit, NoHide
    FileSelectFile savePath,S,Procreate Timelapse Export UUID,Select where to save the UUID file, Procreate UUID table (*.pxuuid)
    If (savePath == "")
        return
    If FileExist(savePath . ".pxuuid")
        FileDelete, %savePath%.pxuuid
    FileAppend, %content%, %savePath%.pxuuid
    return


; // GUI PROCREATE METHOD BUTTONS
ProcFolder:
    Gui, Submit, NoHide
    If !FileExist(A_ScriptDir . "\7z\7z.exe") {
        MsgBox,16,, % "ERROR`n7z/7z.exe is missing and necessary for extraction"
        return
    }
    FileSelectFolder, procPath,,,Select a folder with .procreate files
    If (procPath == "")
        return
    If !FileExist(procPath) {
        MsgBox % "Specified folder doesn't exist"
        return
    }
    appcontentPath :=
    extractedPath := procPath . "\_Extracted"
    ExtractAllProcreate(procPath, extractedPath)
    If FileExist(extractedPath)
        GuiControl, Enable, ButtonExportFFMPEG
    return

ProcExtractedLocate:
    Gui, Submit, NoHide
    FileSelectFolder, extractedPath,,,Select a "_Extracted" folder
    If (extractedPath == "")
        return
    If !FileExist(extractedPath) {
        MsgBox % "Specified folder doesn't exist"
        return
    }
    appcontentPath :=
    If FileExist(extractedPath)
        GuiControl, Enable, ButtonExportFFMPEG
    return

ButtonFFMPEGcontextToggle:
    Gui, Submit, NoHide
    if ((RegexMatch(selectedTab, "\.procreate") && FileExist(extractedPath)) || (RegexMatch(selectedTab, "app content") && content != "" && appcontentPath != ""))
        GuiControl, Enable, ButtonExportFFMPEG
    else
        GuiControl, Disable, ButtonExportFFMPEG
    return
    
; // GUI FFMPEG BUTTON (LAST STEP) 
ExportFFMPEG:
    Gui, Submit, NoHide
    If !FileExist(A_ScriptDir . "\ffmpeg\ffmpeg.exe") {
        MsgBox,16,, % "ERROR`nffmpeg/ffmpeg.exe is missing and necessary to merge the timelapses"
        return
    }
    ;outputPath = C:\Desktop\output ; for debugging, otherwise selected by user
    FileSelectFolder, outputPath,,,Select timelapse output folder
    If (outputPath == "")
        return
    If !FileExist(outputPath) {
        MsgBox % "Specified folder doesn't exist"
        return
    }
    
    tempFFMPEG := A_Temp . "\procreate_timelapse_export_FFMPEG.txt"
    If RegexMatch(selectedTab, "\.procreate")
        FFMPEGExportProcreateExtracted(extractedPath, tempFFMPEG, outputPath)
    else if RegexMatch(selectedTab, "app content")
        FFMPEGExportAppContent(content, appcontentPath, tempFFMPEG, outputPath)
    FileDelete, %tempFFMPEG%
    
    return





; // GUI INFO BUTTONS AND GENERIC BEHAVIOR
GuiEscape:
GuiClose:
    FileDelete, %A_Temp%\procreate_timelapse_export_BANNER.png
    ExitApp

Credits:
    Text = 
    (LTrim
        Code, banner image and a ton of time spent by iairu (http://iairu.com)
        Scripted in AutoHotkey (https://www.autohotkey.com)
        
        Apple Inc's plutil and associated libraries for PLIST conversion
        Usually part of Apple Application Support (part of iTunes)
        (https://www.apple.com/itunes)
        
        FFMPEG for .mp4 concatenation
        (https://www.ffmpeg.org)
        
        7z (7zip) for .procreate file extraction
        (https://www.7-zip.org)
        
        Procreate logo by Savage Interactive Pty Ltd.
        (https://procreate.art)
        
        AutoHotkey Base64 Image Function by SKAN for inline banner image
        (https://autohotkey.com/board/topic/85709-base64enc-base64dec-base64-encoder-decoder)
        
        Scripted and GUI layed out in AutoGUI IDE for AutoHotkey
        (https://www.autohotkey.com/boards/viewtopic.php?t=10157)
        (https://sourceforge.net/projects/autogui)
        
    )
    MsgBoxEx(Text, "Credits - Procreate Timelapse Export", "Back", 0, "", "-SysMenu", WinExist("A"), 0, "s9", "Segoe UI")
    return

MoreInfo:
    Text =
    (LTrim
        APP CONTENT METHOD TUTORIAL
        
        This method is very complex. Useful if you are a geek and want to export everything
        at once. Otherwise stick to the .procreate file format method.
        
        Unlike Procreate Method, this one keeps the gallery folder (stack) structure.
    
        --- Where to get the app content:
        
        These steps are possible only on a jailbroken iDevice or possibly? through iTunes.
        You will need a local copy of all Procreate contents located in:
        /var/mobile/Containers/Data/Application/[Procreate UUID]/Library/Application Support
        This folder contains UUID folders, a Finder.archive file and a few other things.
        
        --- How to get the app content:
        
        You can find the folder more easily using Apps Manager in the Filza iOS app available
        through Cydia (paid). All you need to do in the Apps Manager is select name of the app
        (Procreate) and navigate to Library/Application Support.
        
        Due to the size of all the files, mailing this stuff is off-limits. Use either cloud
        storage or network (SMB/SSH/FTP) file sharing. If this is all too complex for you, 
        you can try the free plan of Resilio Sync, which is fairly easy to setup. Or you could
        copy the files to the Files app and get them out using iTunes.
        
        --- (WinSCP Filters for effective sync):
        
        This only applies if you use the SMB/SSH/FTP sharing method and have an app (in this
        example WinSCP) that can sync only specific folders/files using filters.
        
        If your gallery has tens of gigabytes (like mine), this saves a ton of time.
        
        Instead of copying the whole app content to the PC, only copy the galleries/stacks you
        want using a retroactive WinSCP filter:
        
        - 1) Only get the Finder.archive from your iDevice, apply a RegEx filter,
             check don't assign filenames and Save UUID without asigned filenames
        - 2) Copy UUID file contents to the "Include Directories" list in "Transfer settings"
             in WinSCP for a filter + only sync .m4v .mp4 and .archive files
        - 3) After the sync is done select the Finder.archive in the newly synced dir with
             all the UUID folders (this DO assign filenames)
        - 4) Make sure to apply the same RegEx filter as last time, else problems may occur
        - 5) Export FFMPEG or save UUID to export later
        
        --- What to do afterwards:
        
        As soon as you get the copy you can proceed to Finder.archive selection.
        The procedure will take a while, mostly due to unoptimized algorithms.
        Make sure to keep all the folders and items together.
        This script will take care of figuring out all the names and locations of stuff.
        
        --- Actually getting the timelapses:
        
        After all of this you can either continue to export your timelapses or do so later
        by saving the UUID table.
        
        --- Why all the hassle?
        
        Apple doesn't like people playing around in their file system. And app devs usually
        don't like it either, but you can't expect them to develop every little feature.
        
        Most importantly of all, I had a ton of timelapses to export and didn't want to
        mindlessly tap around on my iPad. Instead I mindlessly wrote this complex script.
    )
    MsgBoxEx(Text, "More info - Procreate Timelapse Export", "Back", 0, "", "-SysMenu", WinExist("A"), 0, "s9", "Segoe UI")
    return








; // FUNCTION DEFINITIONS
PLISTtoXMLvar(plistPath) {
    SplitPath, plistPath,, dir, ext, name
    FileCopy, %dir%\%name%.%ext%, %dir%\%name%XML.plist, 1 ; to keep the original plist, because plutil rewrites the input file
    RunWait, %A_ScriptDir%\apple_plutil\plutil -convert xml1 "%dir%\%name%XML.plist",,Hide
    FileRead, xml, *P65001 %dir%\%name%XML.plist
    FileDelete, %dir%\%name%XML.plist
    Return % xml
}
ParseXMLvar(xml) {
    pos := 1
    match = start
    while (match != ""){
        pos := RegExMatch(xml, "U)<string>(.*)<\/string>", match, pos) + 1
        o .= match1 . "`n"
    }
    o := RegexReplace(o, "(NSKeyedArchiver|\$null|NSUUID|NSObject|FinderModelDocument|NSMutableArray|NSArray|FinderModelController)\n", "")
    return o
}
FilterGalleries(content, userRegEx := ".*$") {
    Loop, Parse, content, `n, `r
    {
        l := A_LoopField
        
        If RegexMatch(l,userRegEx) { ; if line ends with what user specified
            o .= l . "`n"       ; add line to output
            u := 1              ; allow uuid matching
        }
        else If (u == 1) && RegexMatch(l,"-.*-.*-.*-.*$") {
            o .= l . "`n"       ; add line to output
        }
        else { ; if line doesn't end with userRegex don't allow UUID matching
            u := 0
        }
    }
    return o
}
AssignCanvasNames(content, appcontentPath) {
    untitled_counter := 0
    Loop, Parse, content, `n, `r
    {
        l := A_LoopField
        If RegexMatch(l, "^[A-Z0-9]{8}-(?:[A-Z0-9]{4}-){3}[A-Z0-9]{12}$") {
            gallery_canvas_counter++
            Tooltip, Getting canvas name #%A_Index% (%gallery_canvas_counter% in %gallery_name%)
            xml := PLISTtoXMLvar(appcontentPath . "\" . A_LoopField . "\Document.archive")
            RegexMatch(xml,"U)([^>]*)<\/string>\n\t*<string>{[0-9]*, [0-9]*}", match)
            If (match1 == "") {
                untitled_counter++
                match1 = Untitled %untitled_counter%
            }
            o .= l . " " . match1 . "`n"
        }
        else {
            gallery_name := A_LoopField
            gallery_canvas_counter := 0
            untitled_counter := 0
            o .= l . "`n"
        }
    }
    Tooltip
    return o
}
OnlyKeepUUIDs(content) {
   Loop, Parse, content, `n, `r
    {
        l := A_LoopField
        If RegexMatch(l, "^[A-Z0-9]{8}-(?:[A-Z0-9]{4}-){3}[A-Z0-9]{12}$")
            o .= l . "`n"
    }
    return o
}
EscapeUnsupportedCharacters(filename, escapeSlashes := 1) {
    If (escapeSlashes) {
        filename := StrReplace(filename, "\", "_")
        filename := StrReplace(filename, "/", "_")
    }
    filename := StrReplace(filename, ":", "_")
    filename := StrReplace(filename, "*", "_")
    filename := StrReplace(filename, "?", "_")
    filename := StrReplace(filename, """", "_")
    filename := StrReplace(filename, "<", "_")
    filename := StrReplace(filename, ">", "_")
    filename := StrReplace(filename, "|", "_")
    filename := StrReplace(filename, ",", "``,")
    return filename
}
FFMPEGExportAppContent(content, appcontentPath, FFMPEGtempFile, outputPath) {
    If !FileExist(outputPath)
        FileCreateDir, %outputPath%
    exportedCount := 0
    Loop, Parse, content, `n, `r
    {
        l := A_LoopField
        If RegexMatch(l, "^([A-Z0-9]{8}-(?:[A-Z0-9]{4}-){3}[A-Z0-9]{12})\s(.*)$", match) {
            ; match1 = UUID of the canvas folder
            ; match2 = name of the canvas
            videoFolderPath := appcontentPath . "\" . match1 . "\video\segments"
            canvasName := match2
            
            If (galleryName == "")
                galleryName = _Unspecified Gallery
            
            If !FileExist(videoFolderPath) ; some canvases don't have timelapse footage
                continue
            else {
                exportedCount++
                galleryExportedCount++
                Tooltip, Exporting timelapse #%exportedCount% (%canvasName% | %galleryExportedCount% in %galleryName%)
                FFMPEGFolderToConcatList(FFMPEGtempFile, videoFolderPath)
                canvasName := EscapeUnsupportedCharacters(canvasName)
                galleryName := EscapeUnsupportedCharacters(galleryName)
                FFMPEGConcatenate(outputPath . "\" . galleryName, canvasName, "mp4", FFMPEGtempFile)
            }
        }
        else {
            galleryName := A_LoopField
            galleryExportedCount := 0
        }
    }
    Tooltip
}
FFMPEGExportProcreateExtracted(extractedPath, FFMPEGtempFile, outputPath) {
    If !FileExist(outputPath)
        FileCreateDir, %outputPath%
    exportedCount := 0
    Loop, Files, %extractedPath%\* , D
    {
        videoFolderPath := extractedPath . "\" . A_LoopFileName . "\video\segments"
        canvasName := A_LoopFileName
        
        If !FileExist(videoFolderPath) ; some canvases don't have timelapse footage
            continue
        else {
            exportedCount++
            Tooltip, Exporting timelapse #%exportedCount% (%canvasName%)
            FFMPEGFolderToConcatList(FFMPEGtempFile, videoFolderPath)
            FFMPEGConcatenate(outputPath, canvasName, "mp4", FFMPEGtempFile)
        }
    }
    Tooltip
}
FFMPEGFolderToConcatList(outputFile, inputFolder, fileRegex := ".*") {
    
    /* -- previous method incorrectly sorts numbers (1,10,12,...,2,20,21,...,3,...)
    Loop, Files, %inputFolder%\*.*
        If RegexMatch(A_LoopFileName, fileRegex)
            o .= "file '" . inputFolder . "\" . A_LoopFileName . "'`n"
    */
    
    segment_no := 1
    Loop {
        ext :=
        
        Loop, Files, %inputFolder%\segment-%segment_no%.*
            SplitPath A_LoopFileName,,,ext
            
        If (ext == "")
            break
        else
            o .= "file '" . inputFolder . "\segment-" . segment_no . "." . ext . "'`n"
            
        segment_no++
    }
    
    replace_error := FileReplace(outputFile, o)
    if (replace_error) {
        MsgBox % "Can't rewrite FFMPEG temp file because it's locked`nFFMPEG Hung up somewhere... kill the app manually, then continue"
    }
}
FFMPEGConcatenate(outputPath,outputName,outputExt,concatList) {
    If !FileExist(outputPath)
        FileCreateDir, %outputPath%
    If FileExist(outputPath . "\" . outputName . "." . outputExt)
        FileDelete, % outputPath . "\" . outputName . "." . outputExt
    
    RunWait %comSpec% /k ""%A_ScriptDir%\ffmpeg\ffmpeg.exe" -f concat -safe 0 -i "%concatList%" -c copy "%outputPath%\%outputName%.%outputExt%" && exit",,hide
}
ExtractAllProcreate(procFolderPath, outputPath) {
    if FileExist(outputPath)
        FileRemoveDir %outputPath%,1
    Loop, Files, %procFolderPath%\*.procreate
    {
        SplitPath, A_LoopFileFullPath,,,, filename_noext
        Tooltip, Extracting %A_LoopFileName%
        RunWait %comSpec% /k ""%A_ScriptDir%\7z\7z.exe" x "%procFolderPath%\%A_LoopFileName%" -o"%outputPath%\%filename_noext%" && exit",,hide
    }
    Tooltip
}
FileReplace(f,content, attemptcount := 10, errorcount := 0) {
    If (errorcount >= attemptcount)
        Return 1
    FileDelete, %f%
    If (FileExist(f) && Errorlevel) {
        Sleep 500
        FileReplace(f,content,attemptcount,errorcount+1)
    }
    else {
        FileAppend, %content%, %f%
        Return 0
    }
}




; // THIRD PARTY FUNCTION DEFINITIONS
Base64dec( ByRef OutData, ByRef InData ) {
; https://autohotkey.com/board/topic/85709-base64enc-base64dec-base64-encoder-decoder/
 DllCall( "Crypt32.dll\CryptStringToBinary" ( A_IsUnicode ? "W" : "A" ), UInt,&InData
        , UInt,StrLen(InData), UInt,1, UInt,0, UIntP,Bytes, Int,0, Int,0, "CDECL Int" )
 VarSetCapacity( OutData, Req := Bytes * ( A_IsUnicode ? 2 : 1 ) )
 DllCall( "Crypt32.dll\CryptStringToBinary" ( A_IsUnicode ? "W" : "A" ), UInt,&InData
        , UInt,StrLen(InData), UInt,1, Str,OutData, UIntP,Req, Int,0, Int,0, "CDECL Int" )
Return Bytes
}

VarZ_Save( ByRef Data, DataSize, TrgFile ) { ; By SKAN
; http://www.autohotkey.com/community/viewtopic.php?t=45559
 hFile :=  DllCall( "_lcreat", ( A_IsUnicode ? "AStr" : "Str" ),TrgFile, UInt,0 )
 IfLess, hFile, 1, Return "", ErrorLevel := 1
 nBytes := DllCall( "_lwrite", UInt,hFile, UInt,&Data, UInt,DataSize, UInt )
 DllCall( "_lclose", UInt,hFile )
Return nBytes
}

LoadPNGDATA:
PNGData=
(
iVBORw0KGgoAAAANSUhEUgAAAeEAAABUCAMAAACC5H9OAAAKRWlDQ1BJQ0MgcHJvZmlsZQAAeNqdU2dUU+kWPffe9EJLiICUS29SFQggUkKLgBSRJiohCRBKiCGh2RVRwRFFRQQbyKCIA46OgIwVUSwMigrYB+Qhoo6Do4iKyvvhe6Nr1rz35s3+tdc+56zznbPPB8AIDJZIM1E1gAypQh4R4IPHxMbh5C5AgQokcAAQCLNkIXP9IwEA+H48PCsiwAe+AAF40wsIAMBNm8AwHIf/D+pCmVwBgIQBwHSROEsIgBQAQHqOQqYAQEYBgJ2YJlMAoAQAYMtjYuMAUC0AYCd/5tMAgJ34mXsBAFuUIRUBoJEAIBNliEQAaDsArM9WikUAWDAAFGZLxDkA2C0AMElXZkgAsLcAwM4QC7IACAwAMFGIhSkABHsAYMgjI3gAhJkAFEbyVzzxK64Q5yoAAHiZsjy5JDlFgVsILXEHV1cuHijOSRcrFDZhAmGaQC7CeZkZMoE0D+DzzAAAoJEVEeCD8/14zg6uzs42jrYOXy3qvwb/ImJi4/7lz6twQAAA4XR+0f4sL7MagDsGgG3+oiXuBGheC6B194tmsg9AtQCg6dpX83D4fjw8RaGQudnZ5eTk2ErEQlthyld9/mfCX8BX/Wz5fjz89/XgvuIkgTJdgUcE+ODCzPRMpRzPkgmEYtzmj0f8twv//B3TIsRJYrlYKhTjURJxjkSajPMypSKJQpIpxSXS/2Ti3yz7Az7fNQCwaj4Be5EtqF1jA/ZLJxBYdMDi9wAA8rtvwdQoCAOAaIPhz3f/7z/9R6AlAIBmSZJxAABeRCQuVMqzP8cIAABEoIEqsEEb9MEYLMAGHMEF3MEL/GA2hEIkxMJCEEIKZIAccmAprIJCKIbNsB0qYC/UQB00wFFohpNwDi7CVbgOPXAP+mEInsEovIEJBEHICBNhIdqIAWKKWCOOCBeZhfghwUgEEoskIMmIFFEiS5E1SDFSilQgVUgd8j1yAjmHXEa6kTvIADKC/Ia8RzGUgbJRPdQMtUO5qDcahEaiC9BkdDGajxagm9BytBo9jDah59CraA/ajz5DxzDA6BgHM8RsMC7Gw0KxOCwJk2PLsSKsDKvGGrBWrAO7ifVjz7F3BBKBRcAJNgR3QiBhHkFIWExYTthIqCAcJDQR2gk3CQOEUcInIpOoS7QmuhH5xBhiMjGHWEgsI9YSjxMvEHuIQ8Q3JBKJQzInuZACSbGkVNIS0kbSblIj6SypmzRIGiOTydpka7IHOZQsICvIheSd5MPkM+Qb5CHyWwqdYkBxpPhT4ihSympKGeUQ5TTlBmWYMkFVo5pS3aihVBE1j1pCraG2Uq9Rh6gTNHWaOc2DFklLpa2ildMaaBdo92mv6HS6Ed2VHk6X0FfSy+lH6JfoA/R3DA2GFYPHiGcoGZsYBxhnGXcYr5hMphnTixnHVDA3MeuY55kPmW9VWCq2KnwVkcoKlUqVJpUbKi9Uqaqmqt6qC1XzVctUj6leU32uRlUzU+OpCdSWq1WqnVDrUxtTZ6k7qIeqZ6hvVD+kfln9iQZZw0zDT0OkUaCxX+O8xiALYxmzeCwhaw2rhnWBNcQmsc3ZfHYqu5j9HbuLPaqpoTlDM0ozV7NS85RmPwfjmHH4nHROCecop5fzforeFO8p4ikbpjRMuTFlXGuqlpeWWKtIq1GrR+u9Nq7tp52mvUW7WfuBDkHHSidcJ0dnj84FnedT2VPdpwqnFk09OvWuLqprpRuhu0R3v26n7pievl6Ankxvp955vef6HH0v/VT9bfqn9UcMWAazDCQG2wzOGDzFNXFvPB0vx9vxUUNdw0BDpWGVYZfhhJG50Tyj1UaNRg+MacZc4yTjbcZtxqMmBiYhJktN6k3umlJNuaYppjtMO0zHzczNos3WmTWbPTHXMueb55vXm9+3YFp4Wiy2qLa4ZUmy5FqmWe62vG6FWjlZpVhVWl2zRq2drSXWu627pxGnuU6TTque1mfDsPG2ybaptxmw5dgG2662bbZ9YWdiF2e3xa7D7pO9k326fY39PQcNh9kOqx1aHX5ztHIUOlY63prOnO4/fcX0lukvZ1jPEM/YM+O2E8spxGmdU5vTR2cXZ7lzg/OIi4lLgssulz4umxvG3ci95Ep09XFd4XrS9Z2bs5vC7ajbr+427mnuh9yfzDSfKZ5ZM3PQw8hD4FHl0T8Ln5Uwa9+sfk9DT4FntecjL2MvkVet17C3pXeq92HvFz72PnKf4z7jPDfeMt5ZX8w3wLfIt8tPw2+eX4XfQ38j/2T/ev/RAKeAJQFnA4mBQYFbAvv4enwhv44/Ottl9rLZ7UGMoLlBFUGPgq2C5cGtIWjI7JCtIffnmM6RzmkOhVB+6NbQB2HmYYvDfgwnhYeFV4Y/jnCIWBrRMZc1d9HcQ3PfRPpElkTem2cxTzmvLUo1Kj6qLmo82je6NLo/xi5mWczVWJ1YSWxLHDkuKq42bmy+3/zt84fineIL43sXmC/IXXB5oc7C9IWnFqkuEiw6lkBMiE44lPBBECqoFowl8hN3JY4KecIdwmciL9E20YjYQ1wqHk7ySCpNepLskbw1eSTFM6Us5bmEJ6mQvEwNTN2bOp4WmnYgbTI9Or0xg5KRkHFCqiFNk7Zn6mfmZnbLrGWFsv7Fbou3Lx6VB8lrs5CsBVktCrZCpuhUWijXKgeyZ2VXZr/Nico5lqueK83tzLPK25A3nO+f/+0SwhLhkralhktXLR1Y5r2sajmyPHF52wrjFQUrhlYGrDy4irYqbdVPq+1Xl65+vSZ6TWuBXsHKgsG1AWvrC1UK5YV969zX7V1PWC9Z37Vh+oadGz4ViYquFNsXlxV/2CjceOUbh2/Kv5nclLSpq8S5ZM9m0mbp5t4tnlsOlqqX5pcObg3Z2rQN31a07fX2Rdsvl80o27uDtkO5o788uLxlp8nOzTs/VKRU9FT6VDbu0t21Ydf4btHuG3u89jTs1dtbvPf9Psm+21UBVU3VZtVl+0n7s/c/romq6fiW+21drU5tce3HA9ID/QcjDrbXudTVHdI9VFKP1ivrRw7HH77+ne93LQ02DVWNnMbiI3BEeeTp9wnf9x4NOtp2jHus4QfTH3YdZx0vakKa8ppGm1Oa+1tiW7pPzD7R1ureevxH2x8PnDQ8WXlK81TJadrpgtOTZ/LPjJ2VnX1+LvncYNuitnvnY87fag9v77oQdOHSRf+L5zu8O85c8rh08rLb5RNXuFearzpfbep06jz+k9NPx7ucu5quuVxrue56vbV7ZvfpG543zt30vXnxFv/W1Z45Pd2983pv98X39d8W3X5yJ/3Oy7vZdyfurbxPvF/0QO1B2UPdh9U/W/7c2O/cf2rAd6Dz0dxH9waFg8/+kfWPD0MFj5mPy4YNhuueOD45OeI/cv3p/KdDz2TPJp4X/qL+y64XFi9++NXr187RmNGhl/KXk79tfKX96sDrGa/bxsLGHr7JeDMxXvRW++3Bd9x3He+j3w9P5Hwgfyj/aPmx9VPQp/uTGZOT/wQDmPP87zWUggAAABl0RVh0U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAOEaVRYdFhNTDpjb20uYWRvYmUueG1wAAAAAAA8P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIenJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtZXRhIHhtbG5zOng9ImFkb2JlOm5zOm1ldGEvIiB4OnhtcHRrPSJBZG9iZSBYTVAgQ29yZSA1LjYtYzE0MiA3OS4xNjA5MjQsIDIwMTcvMDcvMTMtMDE6MDY6MzkgICAgICAgICI+IDxyZGY6UkRGIHhtbG5zOnJkZj0iaHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmRmOmFib3V0PSIiIHhtbG5zOnhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUeXBlL1Jlc291cmNlUmVmIyIgeG1sbnM6eG1wPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvIiB4bXBNTTpPcmlnaW5hbERvY3VtZW50SUQ9InhtcC5kaWQ6ZGM0OGZjYTYtMWQ5NS03ZjRiLTllZGItYjBhOWZjMjEzMTc2IiB4bXBNTTpEb2N1bWVudElEPSJ4bXAuZGlkOkUzRUQxQzlEM0I0RDExRUFCQ0E1RkFEQkFFMThCREQxIiB4bXBNTTpJbnN0YW5jZUlEPSJ4bXAuaWlkOkUzRUQxQzlDM0I0RDExRUFCQ0E1RkFEQkFFMThCREQxIiB4bXA6Q3JlYXRvclRvb2w9IkFkb2JlIFBob3Rvc2hvcCBDQyAyMDE4IChXaW5kb3dzKSI+IDx4bXBNTTpEZXJpdmVkRnJvbSBzdFJlZjppbnN0YW5jZUlEPSJ4bXAuaWlkOmQ1YzcwOGUxLWJhOTctZmU0MS05OWE2LTcxZTkzMDUzMjk1OSIgc3RSZWY6ZG9jdW1lbnRJRD0iYWRvYmU6ZG9jaWQ6cGhvdG9zaG9wOjJlMmI4NjVlLWRlMzAtMmE0Ny05NjNmLTE3ZmNjYzcyNTYzYiIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g6eG1wbWV0YT4g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
)
Return

MsgBoxEx(Text, Title := "", Buttons := "", Icon := "", ByRef CheckText := "", Styles := "", Owner := "", Timeout := "", FontOptions := "", FontName := "", BGColor := "", Callback := "") {
    Static hWnd, y2, p, px, pw, c, cw, cy, ch, f, o, gL, hBtn, lb, DHW, ww, Off, k, v, RetVal
    Static Sound := {2: "*48", 4: "*16", 5: "*64"}

    Gui New, hWndhWnd LabelMsgBoxEx -0xA0000
    Gui % (Owner) ? "+Owner" . Owner : ""
    Gui Font
    Gui Font, % (FontOptions) ? FontOptions : "s9", % (FontName) ? FontName : "Segoe UI"
    Gui Color, % (BGColor) ? BGColor : "White"
    Gui Margin, 10, 12

    If (IsObject(Icon)) {
        Gui Add, Picture, % "x20 y24 w32 h32 Icon" . Icon[1], % (Icon[2] != "") ? Icon[2] : "shell32.dll"
    } Else If (Icon + 0) {
        Gui Add, Picture, x20 y24 Icon%Icon% w32 h32, user32.dll
        SoundPlay % Sound[Icon]
    }

    Gui Add, Link, % "x" . (Icon ? 65 : 20) . " y" . (InStr(Text, "`n") ? 24 : 32) . " vc", %Text%
    GuicontrolGet c, Pos
    GuiControl Move, c, % "w" . (cw + 30)
    y2 := (cy + ch < 52) ? 90 : cy + ch + 34

    Gui Add, Text, vf -Background ; Footer

    Gui Font
    Gui Font, s9, Segoe UI
    px := 42
    If (CheckText != "") {
        CheckText := StrReplace(CheckText, "*",, ErrorLevel)
        Gui Add, CheckBox, vCheckText x12 y%y2% h26 -Wrap -Background AltSubmit Checked%ErrorLevel%, %CheckText%
        GuicontrolGet p, Pos, CheckText
        px := px + pw + 10
    }

    o := {}
    Loop Parse, Buttons, |, *
    {
        gL := (Callback != "" && InStr(A_LoopField, "...")) ? Callback : "MsgBoxExBUTTON"
        Gui Add, Button, hWndhBtn g%gL% x%px% w90 y%y2% h26 -Wrap, %A_Loopfield%
        lb := hBtn
        o[hBtn] := px
        px += 98
    }
    GuiControl +Default, % (RegExMatch(Buttons, "([^\*\|]*)\*", Match)) ? Match1 : StrSplit(Buttons, "|")[1]

    Gui Show, Autosize Center Hide, %Title%
    DHW := A_DetectHiddenWindows
    DetectHiddenWindows On
    WinGetPos,,, ww,, ahk_id %hWnd%
    GuiControlGet p, Pos, %lb% ; Last button
    Off := ww - (((px + pw + 14) * A_ScreenDPI) // 96)
    For k, v in o {
        GuiControl Move, %k%, % "x" . (v + Off)
    }
    Guicontrol MoveDraw, f, % "x-1 y" . (y2 - 10) . " w" . ww . " h" . 48

    Gui Show
    Gui +SysMenu %Styles%
    DetectHiddenWindows %DHW%

    If (Timeout) {
        SetTimer MsgBoxExTIMEOUT, % Round(Timeout) * 1000
    }

    If (Owner) {
        WinSet Disable,, ahk_id %Owner%
    }

    GuiControl Focus, f
    Gui Font
    WinWaitClose ahk_id %hWnd%
    Return RetVal

    MsgBoxExESCAPE:
    MsgBoxExCLOSE:
    MsgBoxExTIMEOUT:
    MsgBoxExBUTTON:
        SetTimer MsgBoxExTIMEOUT, Delete

        If (A_ThisLabel == "MsgBoxExBUTTON") {
            RetVal := StrReplace(A_GuiControl, "&")
        } Else {
            RetVal := (A_ThisLabel == "MsgBoxExTIMEOUT") ? "Timeout" : "Cancel"
        }

        If (Owner) {
            WinSet Enable,, ahk_id %Owner%
        }

        Gui Submit
        Gui %hWnd%: Destroy
    Return
}
