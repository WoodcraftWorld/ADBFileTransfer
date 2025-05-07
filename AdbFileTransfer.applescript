global adbLocation
try
	do shell script "/opt/homebrew/bin/adb devices" --apple silicon homebrew directory
	set adbLocation to "/opt/homebrew/bin/adb"
on error
	try
		do shell script "/usr/local/bin/adb devices" --intel homebrew directory
		set adbLocation to "/usr/local/bin/adb"
	on error --If a newer or older macOS version causes this error, even with adb installed, please leave an issue on GitHub, and as a temporary fix, run "which adb" in Terminal and replace one of the two above locations with its output.
		display dialog "ADB isn't installed. Please install it from Homebrew with the following command in Terminal after installing Homebrew from http://brew.sh:" default answer "brew install android-platform-tools" buttons {"OK"} default button "OK" cancel button "OK"
	end try
end try
global Device
global serial
global listedDirectory
global listedDirectory2
global AppName
global chosenFile
global chosenFileS
global CopyScript
global FolderDownloadEnabled
global preferencesFolder
set preferencesFolder to (do shell script "echo ~") & "/Library/Application Support/WoodcraftWorld Software/ADBFileTransfer"
try
	do shell script "mkdir -p " & quoted form of text 1 thru -16 of preferencesFolder
	do shell script "mkdir " & quoted form of preferencesFolder
	do shell script "echo Disabled > " & quoted form of preferencesFolder & "/DownloadingFoldersEnabled"
	set FolderDownloadEnabled to "Disabled"
on error
	set FolderDownloadEnabled to (do shell script "cat " & quoted form of preferencesFolder & "/DownloadingFoldersEnabled")
end try
set AppName to "ADB Downloader ©WoodcraftWorld '25"
-- In the future, uploading support may be added.
on showDevices()
	set FolderDownloadEnabled to do shell script "cat " & quoted form of preferencesFolder & "/DownloadingFoldersEnabled"
	set adbDevices to paragraphs of (do shell script adbLocation & " devices | grep -vF \"List of devices\" | grep -v \"^$\" | awk '{print $1, $2}'")
	set end of adbDevices to "Folder downloading: [" & FolderDownloadEnabled & "]"
	set end of adbDevices to "How to enable developer settings"
	set end of adbDevices to "Exit"
	set choice to choose from list adbDevices cancel button name "Refresh" OK button name "Select" with title AppName with prompt "Please select your device. If you can't see it, or it says unauthorized next to it, ensure USB Debugging or USB Tethering has been enabled from Developer Settings and you have allowed USB Debugging or USB Tethering on your device"
	if choice is equal to false then
		showDevices()
	else if choice as string is equal to "Exit" then
		set Device to "exitapp"
	else if choice as string is equal to "How to enable developer settings" then
		do shell script "open " & POSIX path of (path to me) & "/Contents/enable-debugging-guide.app"
		showDevices()
	else if (choice as string) contains "Folder downloading" then
		if FolderDownloadEnabled is equal to "Enabled" then
			do shell script "echo Disabled > " & quoted form of preferencesFolder & "/DownloadingFoldersEnabled"
		else
			do shell script "echo Enabled > " & quoted form of preferencesFolder & "/DownloadingFoldersEnabled"
		end if
		showDevices()
	else
		set Device to choice as string
	end if
end showDevices
showDevices()
if Device is equal to "exitapp" then
	return
end if
set serial to do shell script "echo " & Device & " | awk '{print $1}'"
on listDirectory(Directory)
	set listedDirectory to paragraphs of (do shell script adbLocation & " -s " & serial & " shell ls " & (do shell script "echo " & quoted form of Directory & " | sed 's/ /\\\\\\\\ /g'") & "/")
	repeat with a from 1 to length of listedDirectory
		set isDirectory to true
		try
			set status to do shell script adbLocation & " -s " & serial & " shell ls " & (do shell script "echo " & quoted form of Directory & " | sed 's/ /\\\\\\\\ /g'") & "/" & (do shell script "echo " & quoted form of item a of listedDirectory & " | sed 's/ /\\\\\\\\ /g'") & "/"
		on error
			set isDirectory to false
		end try
		if isDirectory is equal to true then
			set item a of listedDirectory to item a of listedDirectory & " <Directory>"
		end if
	end repeat
	if Directory is equal to "/storage/emulated" or Directory is equal to "/storage" then
		set listedDirectory2 to {}
		repeat with a from 1 to length of listedDirectory
			if item a of listedDirectory is equal to "obb <Directory>" then
				set obb to true
			else if item a of listedDirectory is equal to "0 <Directory>" then
				set end of listedDirectory2 to "Internal Storage"
			else
				-- 
				set end of listedDirectory2 to text 1 thru -13 of item a of listedDirectory
			end if
		end repeat
		
		set listedDirectory to listedDirectory2
		
		
	end if
	if Directory is not equal to "/storage" then
		set listedDirectory to {"<Parent Directory>", "<Storage Devices>"} & listedDirectory
	end if
	set chosenFile to choose from list listedDirectory with title AppName with prompt "Current directory: " & Directory cancel button name "Exit" OK button name "Select" with multiple selections allowed
	if chosenFile is equal to false then
		return
	end if
	if length of chosenFile is equal to 1 then
		set chosenFileS to chosenFile as string
		if Directory is equal to "/storage" or Directory is equal to "/storage/emulated" or Directory is equal to "/storage/self" then
			if chosenFileS is equal to "Internal Storage" then
				listDirectory("/storage/emulated/0")
			else if chosenFileS is equal to "<Parent Directory>" then
				listDirectory(do shell script "echo " & quoted form of Directory & "|sed 's|\\(.*\\)/.*|\\1|'")
			else if chosenFileS is equal to "<Storage Devices>" then
				listDirectory("/storage")
			else
				listDirectory(Directory & "/" & chosenFileS)
			end if
		else
			if chosenFileS contains "<Directory>" then
				set chosenFileS to text 1 thru -13 of chosenFileS
				openOrDownloadFolder(Directory, chosenFileS)
			else if chosenFileS is equal to "<Parent Directory>" then
				listDirectory(do shell script "echo " & quoted form of Directory & "|sed 's|\\(.*\\)/.*|\\1|'")
			else if chosenFileS is equal to "<Storage Devices>" then
				listDirectory("/storage")
			else
				downloadFile(Directory, chosenFileS)
			end if
		end if
	else
		if Directory is not equal to "/storage" or Directory is not equal to "/storage/emulated" or Directory is not equal to "/storage/self" then
			multiDownload(Directory, chosenFile)
		else
			display dialog "Invalid selection" with title AppName buttons {"OK"} default button "OK"
			listDirectory(Directory)
		end if
	end if
end listDirectory
on downloadFile(Directory, FileName)
	set DownloadYes to button returned of (display dialog "File Selected: " & FileName buttons {"Back", "Download"} with title AppName default button "Download")
	if DownloadYes is not equal to "Back" then
		set OutFile to quoted form of POSIX path of (choose file name with prompt "Save file" default name FileName)
		tell application "Terminal"
			do script adbLocation & " -s " & serial & " pull " & quoted form of Directory & "/" & quoted form of FileName & " " & OutFile & "; exit"
			activate
		end tell
		listDirectory(Directory)
	else
		listDirectory(Directory)
	end if
end downloadFile
on openOrDownloadFolder(Directory, FileName)
	if FolderDownloadEnabled is equal to "Disabled" then
		listDirectory(Directory & "/" & FileName)
		return
	end if
	set DownloadYes to button returned of (display dialog "Folder Selected: " & FileName buttons {"Back", "Open", "Download"} with title AppName default button "Open")
	if DownloadYes is equal to "Download" then
		set OutFile to quoted form of POSIX path of (choose file name with prompt "Save folder" default name FileName)
		tell application "Terminal"
			do script adbLocation & " -s " & serial & " pull " & quoted form of Directory & "/" & quoted form of FileName & " " & OutFile & "; exit"
			activate
		end tell
		listDirectory(Directory)
	else if DownloadYes is equal to "Open" then
		listDirectory(Directory & "/" & FileName)
	else
		listDirectory(Directory)
	end if
end openOrDownloadFolder

on multiDownload(Directory, FileNames)
	set DownloadYes to choose from list FileNames with title AppName with prompt "Multiple files selected! Do you want to download all of them?" cancel button name "No" OK button name "Yes" with empty selection allowed and multiple selections allowed
	if DownloadYes is equal to false then
		listDirectory(Directory)
	else
		set SaveFolder to quoted form of POSIX path of (choose folder with prompt "Choose output folder")
		set CopyScript to ""
		repeat with a from 1 to length of FileNames
			if item a in FileNames contains "<Directory>" then
				set CopyScript to CopyScript & adbLocation & " -s " & serial & " pull " & quoted form of Directory & "/" & quoted form of text 1 thru -13 of item a of FileNames & " " & SaveFolder & "/" & quoted form of text 1 thru -13 of item a of FileNames & "; "
			else
				set CopyScript to CopyScript & adbLocation & " -s " & serial & " pull " & quoted form of Directory & "/" & quoted form of item a of FileNames & " " & SaveFolder & "; "
			end if
			
		end repeat
		set CopyScript to CopyScript & "exit"
		tell application "Terminal"
			do script CopyScript
			activate
		end tell
		listDirectory(Directory)
	end if
end multiDownload
listDirectory("/storage")