# ProcExp
Procreate Timelapse Batch Exporter from either .procreate files or application content. Scripted in [AutoHotkey](https://www.autohotkey.com/).

> [**Download release here**](https://github.com/azurry/ProcExp/releases) (.exe + dependencies)
>
> [Download source](https://github.com/azurry/ProcExp/archive/master.zip) (.ahk + dependencies)

| .procreate file method               | App content method[^stack bug]       |
| ------------------------------------ | ------------------------------------ |
| ![](https://i.imgur.com/qQ4CYDB.png) | ![](https://i.imgur.com/W1eM9Qp.png) |

[^Stack bug]: Currently bugged for files outside "Stack" folders, they get appended to the last stack. First thing in gallery may have to be a stack for this method to work at all.

### Changelog

|      | Date (hh:mm yy-mm-dd) | Description                                                  |
| ---- | --------------------- | ------------------------------------------------------------ |
| v1   | 23:29 19-12-17        | ParseXML + KeepOnlyE parsing to a temp file                  |
| v2   | 18:47 20-01-19        | binary PLIST to XML (finder.archive) using plutil, parsing to a variable instead of a file, user file selection and info |
| v3   | 3:45 20-01-20         | testing/debugging, PLIST to XML variable, completely rewritten ParseXML |
| v4   | 6:07 20-01-20         | implemented inefficient AssignCanvasNames that has to convert all Document.archive to XML for detection |
| v4.5 | 6:39 20-01-20         | expanded Todo with so much stuff I won't sleep for a week if I try to come back to this project |
| v5   | 8:54 20-01-20         | added GUI in a separate file                                 |
| v6   | 22:03 20-01-20        | added all necessary FFMPEG functionality, file encoding fixed, KeepOnlyE is now FilterGaleries with user regex, app content method fully working |
| v7   | 23:11 20-01-20        | merged main script with GUI script, implemented all GUI functionality for app content method |
| v8   | 0:30 20-01-21         | added .procreate file extraction and location, no FFMPEG for it yet, also FFMPEG button gets disabled/enabled and changes methods based on selected tab |
| v9   | 3:31 20-01-21         | fixed FFMPEG concatenation order (builtin AHK file looping goes 1,10,12,...,2,20,3,4,5 = wrong timelapse segment order), fixed timelapse tooltip counter |
| v10  | 19:48 20-01-21        | implemented FFMPEG export for .procreate files method + git/github init commit |

### Todo

I'm currently happy with the state of this project for myself, so I can't really be bothered to do these things any time soon if at all.
Open an Issue on GitHub if you want to get these things fixed.

- **BUGS**
  - **fix canvases that aren't in stacks** and stacks with the default "Stack" name getting appended to a previous stack
    - also count the possibility of the first line in content being a UUID if the first item in procreate is not a gallery
    - can be solved by rechecking how the finder.archive works and then implementing a placeholder gallery name [NO_GALLERY] for these
    - then during FFMPEGexport export [NO_GALLERY] timelapses directly to root folder
  - find out if the **correct rotation of segments** is somewhere in their metadata and fixable during export
  - Replace 7z/plutil/ffmpeg for **32-bit compatibility**
- **CHECKS**
  - Add AsignCanvasNamesStatus(content) function to regex check all lines if they have asigned filenames, if one or more doesn't, return 0 else 1
  - Use AsignCanvasNamesStatus(content) in LoadUUID to (user choice) either stop loading the file or AssignCanvasNames() to the loaded content from it
  - Add UUIDfolderCounter(dir) and ProcreateFileCounter(dir) to determine ParseFinder and ProcFolder continuation (in other words check if appcontent and procreate files actually exist)
  - also add ExtractedFileCounter to determine existence of timelapse segment files within extracted folders for ProcExtractedLocate
- **REFACTOR**
  - can't be bothered with this lol
  - content variable should be renamed to UUIDtable
  - FileSelectFolder / FileSelectFile with checks to a function
- **QUALITY-OF-LIFE**
  - Progress bar subGUI for loading Finder.archive and exporting FFMPEG instead of a Tooltip
  - Replace RegEx with StrReplace where possible for efficiency

### Credits

Code, banner image and a ton of time spent by Azurry (http://azurry.com)
Scripted in AutoHotkey (https://www.autohotkey.com)

Procreate logo by Savage Interactive Pty Ltd.
(https://procreate.art)

AutoHotkey Base64 Image Function by SKAN for inline banner image
(https://autohotkey.com/board/topic/85709-base64enc-base64dec-base64-encoder-decoder)

Scripted and GUI layed out in AutoGUI IDE for AutoHotkey
(https://www.autohotkey.com/boards/viewtopic.php?t=10157)
(https://sourceforge.net/projects/autogui)

##### Included Dependencies

Apple Inc's plutil and associated libraries for PLIST conversion
Usually part of Apple Application Support (part of iTunes)
(https://www.apple.com/itunes)

FFMPEG for .mp4 concatenation
(https://www.ffmpeg.org)

7z (7zip) for .procreate file extraction
(https://www.7-zip.org)

### "License"

You're free to fork and do whatever you want to the ProcExp.ahk file.
Credit is appreciated (by [linking to this repo](https://github.com/azurry/ProcExp) and/or [my github profile](https://github.com/azurry)).
Also, no warranty provided. Use at your own risk.