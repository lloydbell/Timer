##########################################################
# Powerscript tools to help touch things
########################################################### 
$global:AppTitle = "Number Tracker"
$global:SingleLine = ""
$global:DoubleLine = ""
$global:BlankLine = ""
$global:SeperatorLine = ""
$global:TextPrefix = "  "
$global:MaxDigits = 5
$global:MaxColumns = 7
$global:FilesDirectory = "files"
$global:DefaultFileExtention = "json"
$global:ArchivedFileExtention = "arc"
$global:StorageFormat = "Json"
$global:DateFormat = "dd/MM/yyyy"
$global:DateTimeFormat = "dd/MM/yyyy HH:mm:ss"
$global:HardDelete = $False
$global:ScreenWidth = $False
$global:CurrentlyCurrentlyActiveFile = $null
$global:SortOrder = 0
$global:Debug = $True
##########################################################
# Variables
$global:Credentials
##########################################################
Function Init {
	ChangeConsoleTitle $global:AppTitle
	UpdateScreenWidth
	ScanAllFiles $True $True
}

Function UpdateScreenWidth{
	$global:ScreenWidth = $host.UI.RawUI.WindowSize.Width
	$global:MaxColumns = $global:ScreenWidth / $global:MaxDigits
	$global:MaxColumns = [math]::floor($global:MaxColumns)

	for ($i = 0; $i -lt $global:ScreenWidth; $i++) {
		$global:SingleLine += "-"
		$global:DoubleLine += "="
		$global:SeperatorLine += "_"
		$global:BlankLine += " "
	}
}

Function ChangeConsoleTitle($newName){
	$host.UI.RawUI.WindowTitle = $newName
}

Function GetOffsetForCenter($words){
	$n = $global:ScreenWidth / 2
	$n -= $words.Length / 2
	$n = [math]::round($n)

	$output = ""

	for ($i = 0; $i -lt $n; $i++) {
		$output += " "
	}

	return $output
}

Function WriteDebug($msg)
{
	if($global:Debug -eq $True){
		Write-Host "  {$msg}  " -ForegroundColor Cyan
	}
}

Function WriteTitleBar($title) {
	Clear-Host
	$offset = GetOffsetForCenter $title
	Write-Host $global:SeperatorLine -ForegroundColor DarkYellow
	Write-Host $global:BlankLine -ForegroundColor DarkYellow
	Write-Host "$offset$title" -ForegroundColor DarkYellow
	Write-Host $global:SeperatorLine -ForegroundColor DarkYellow	
}

Function WriteMenuOPtion($option, $text){
	Write-Host $global:MenuPrefix "($option) " -ForegroundColor Yellow -NoNewline
	Write-Host "$text" -ForegroundColor White -NoNewline
}
Function WriteMenuOptions ($fileCount){
	Write-Host $global:SingleLine -ForegroundColor DarkYellow	
	Write-Host "`t" -NoNewline
	WriteMenuOPtion "A" "Add"
	if($fileCount -gt 0){
		WriteMenuOPtion "D" "Delete"
		WriteMenuOPtion "R" "Report"
		WriteMenuOPtion "T" "Today"
		WriteMenuOPtion "S" "Sort"
	}	
	WriteMenuOPtion "H" "Help"
	WriteMenuOPtion "Q" "Quit"
	Write-Host ""
	Write-Host $global:SingleLine -ForegroundColor DarkYellow	
}

Function WriteReportHeader {	
	WriteTitleBar "Billables Report"
	Write-Host "`t Id`t| dd/mm/yyyy`t| Minutes`t| Billable             "  -ForegroundColor DarkYellow
	Write-Host "$global:DoubleLine" -ForegroundColor DarkYellow		
}


Function ChangeSortOrder{

	$global:SortOrder += 1
	if($global:SortOrder -gt 2){
		$global:SortOrder = 0
	}

}

function NewFileOutline($id){	
	$now = GetTimestamp
	$outline = @{Id=$id;CreatedDate=$now;Events=@()}
	return $outline
}

Function GetNewEvent($start, $stop){
	$newEvent = @{Start=$start;Stop=$stop}
	return $newEvent
}

Function MainMenu {
	
	$sortString = $null 
	$files = $null
	#WriteDebug "SortOrder  = $global:SortOrder "
	if($global:SortOrder -eq 0){
		$files = GetFiles | Sort-Object -Property LastWriteTime		
		$sortString = " oldest first." 
	}
	elseif($global:SortOrder -eq 1)
	{
		$files = GetFiles | Sort-Object -Property LastWriteTime -Descending		
		$sortString = " newest first." 
	}
	else {
		$files = GetFiles	
		$sortString = " name." 	
	}
	$fileCount = $files.Count
	$menuTitle = "Tracking $fileCount files - Sorted by $sortString"
	WriteTitleBar $menuTitle


	$columnCount = 0
	if ($fileCount -eq 0) {
		Write-Host $global:TextPrefix -NoNewline
		Write-Host "You havn't added any numbers to track!" -ForegroundColor Green
	}
	else {	
		foreach ($file in $files) {	
			if($columnCount -eq 0){
				Write-Host "`t" -ForegroundColor White -NoNewline
			}
			$fileName = $file.BaseName

			if ($fileName -eq $(GetCurrentlyActiveFile)) {
				Write-Host "$fileName" -ForegroundColor Green -NoNewline						
			}
			else {
				Write-Host "$fileName" -ForegroundColor White -NoNewline
			}
			$columnCount++
			if ($columnCount -lt $global:MaxColumns) {
				Write-Host "`t" -ForegroundColor White -NoNewline
			}
			else {
				Write-Host "" -ForegroundColor White
				$columnCount = 0
			}

		}
		Write-Host "" -ForegroundColor White
	}
	WriteMenuOptions $files.Count

	$origpos = $host.UI.RawUI.CursorPosition
	$choice = $null
	while ($null -eq $choice) {
		$choice = GetInput $True		
	}
	$host.UI.RawUI.CursorPosition = $origpos
	Write-Host "                  " -NoNewline
	$host.UI.RawUI.CursorPosition = $origpos

	$isInt = CheckForInt $choice
	if ($isInt) {
		if ($choice.Length -eq $global:MaxDigits) {
			CheckForMatchingFile $choice		
		}
	}
	else {
		if ($choice -eq 'a') {
			AddNewFile
		}
		elseif ($choice -eq 'd') {
			DeleteFile
		}
		elseif ($choice -eq "q") {
			Quit			
		}		
		elseif ($choice -eq "h") {
			ShowHelp			
		}
		elseif ($choice -eq "r") {
			DisplayReport			
		}
		elseif ($choice -eq "s") {
			ChangeSortOrder			
		}				
	}	
	
	MainMenu
	return
}

Function GetInput($allowChars) {

	$choice = ""
	$loop = $True
	$origpos = $host.UI.RawUI.CursorPosition
	while ($loop) {
		
		$key = WaitForKeyPress
		if([string]::IsNullOrWhiteSpace($key) -eq $True){
			continue
		}
		$validKey = ValidateKey $key
		if ($null -eq $validKey) {
			#check for backspace, esc, enter
			if($key -eq "Backspace")
			{
				$length = $choice.Length
				if($length -gt 0)
				{
					$choice = $choice.Substring(0, $length -1)
				}
			}
			elseif ($key -eq "Escape") 
			{
				return "ESC"
			}			
		}
		else {		
			$choice += $validKey			
		}
	
		# Over write the display of the character	
		$host.UI.RawUI.CursorPosition = $origpos
		Write-Host "                " -NoNewline
		$host.UI.RawUI.CursorPosition = $origpos
		Write-Host "$choice" -NoNewline		
				
		
		$isInt = CheckForInt $choice
		if ($isInt) {
			$length = $choice.Length
			if ($length -eq $global:MaxDigits) {
				return $choice
			}
		}
		else {
			if ($allowChars) {
				if ($choice -eq 'a') { return $choice }
				elseif ($choice -eq 'd') { return $choice }		
				elseif ($choice -eq "q") { return $choice }		
				elseif ($choice -eq "h") { return $choice }
				elseif ($choice -eq "r") { return $choice }
				elseif ($choice -eq "s") { return $choice }				
			}	
			return $null	
		}		
	}
		
	
}

Function ScanAllFiles ($findActiveFile, $closeOldFiles) {

	try {
		Write-Host "Checking files " -NoNewline
		$files = GetFiles
		if ($files.Count -eq 0) {
			return
		}

		$now = GetTimestamp		
		#$today = GetToday
		#$endOfToday = [datetime]::ParseExact("$today 16:30:00", $global:DateTimeFormat, $null)
		$changes = $False
		foreach ($file in $files) {	
			#Write-Host " $file " -NoNewline
			$path = GetFilePath $file				
	
			$content = (Get-Content -Path $path -Raw) | ConvertFrom-Json
			$id = $($content.Id)
			$events = [System.Collections.Generic.List[psobject]]@($content.Events)
			$count = $events.Count
			if($count -eq 0){
				continue
			}
			$saveFile = $False
			for ($i = 0; $i -lt $events.Count; $i++) {
				$entry = $events[$i]		
				$stop = $entry.Stop
				$stopNull = ([string]::IsNullOrWhiteSpace($stop))
				if ($stopNull -eq $false) {
					continue
				}

				$start = $entry.Start
				$startNull = ([string]::IsNullOrWhiteSpace($start))

				if($startNull -eq $False){
	
					if($closeOldFiles){
						$daysEnd = Get-Date -Date $start -Hour 16 -Minute 30 -Second 0
						if($daysEnd -lt $now -and $start -lt $daysEnd){
							Write-Host "CLOSING AUTOMATICALLY $id" -ForegroundColor Black
							$entry.Stop = $daysEnd		
							$saveFile = $True
						}
					}
					if($findActiveFile){
						$daysStart = Get-Date -Hour 7 -Minute 0 -Second 0
						$daysEnd = Get-Date -Hour 16 -Minute 30 -Second 0	
						# TODO: Improve this by looking for more then one result
						if($daysEnd -gt $now -and $start -gt $daysStart){
							SetCurrentlyActiveFile $file
						}

					}
				}												
			}	
			if($saveFile -eq $True){
				$content | ConvertTo-Json -Depth 5 | Out-File $path -Force
				$changes = $true
			}
	
		}
		Write-Host ""		
		if($changes -eq $True){
			PromptAnyKey
		}
		
	}
	catch {
		Write-Host "Error confimring file contents." -ForegroundColor Red	
		Write-Host $_.Exception  -ForegroundColor Red	
		PromptAnyKey
	}
	
}

Function CheckForMatchingFile($in) {
	# check to see if it matches a filename
	$path = GetFilePath $in			
	$existingFile = Test-Path -Path $path
	if ($existingFile -eq $True) {
		UpdateFile $in
		Rest 2
	}			
	else {			
		Write-Host $global:TextPrefix -NoNewline
		Write-Host "$in is not a valid choice." -ForegroundColor Red
		PromptAnyKey
	}
		
}

Function ValidateKey($k) {
	$testKey = [string]$k
	$testKey = $testKey.ToLower()
	Switch ($testKey) {	
		d0 { return "0" }		
		d1 { return "1" }
		d2 { return "2" }
		d3 { return "3" }
		d4 { return "4" }
		d5 { return "5" }
		d6 { return "6" }
		d7 { return "7" }
		d8 { return "8" }
		d9 { return "9" }
		numpad0 { return "0" }		
		numpad1 { return "1" }
		numpad2 { return "2" }
		numpad3 { return "3" }
		numpad4 { return "4" }
		numpad5 { return "5" }
		numpad6 { return "6" }
		numpad7 { return "7" }
		numpad8 { return "8" }
		numpad9 { return "9" }		
		a { return "a" }
		d { return "d" }
		d { return "e" }
		q { return "q" }
		h { return "h" }
		r { return "r" }
		s { return "s" }
	}		
	return $null
}

Function GetTimestamp {
	$stamp = Get-Date
	return $stamp
}
Function GetToday {
	$today = Get-Date
	return $today.Date
}
function GetFileDir {
	$targetPath = "$pwd\$global:FilesDirectory"
	
	$found = Test-Path -Path $targetPath
	if ($found -ne $True) {
		New-Item -ItemType Directory -Path $targetPath
	}
		
	return $targetPath
}

Function GetFilePath($target){
	$dir = GetFileDir
	if($target.Length -eq $global:MaxDigits){
		return "$dir\$target.$global:DefaultFileExtention"
	}
	return "$dir\$target"
}

Function GetFiles {
	$dir = GetFileDir
	$files = Get-ChildItem -Path $dir -Filter "*.$global:DefaultFileExtention"
	return $files
}

Function CheckForInt($ToCheck) {    
	Try {
		$holder = [System.Convert]::ToInt32($ToCheck)
		if ($holder -lt 0) {
			return $False
		}
		return $True
	}
	Catch {
		return $False
	}
}

Function PromptAnyKey {
	Write-Host $global:TextPrefix -NoNewline
	Write-Host "Press any key to continue"
	WaitForKeyPress
}

Function WaitForKeyPress{
	$keyInfo = $null
	while ($null -eq $keyInfo) {			
		$keyInfo = [System.Console]::ReadKey($true)	
	}
	$key = $keyInfo.Key
	$key = [string]$key
	return $key
}

Function AddNewFile($doStart) {
	Write-Host "Enter a number" -ForegroundColor Yellow
	$choice = $null	
	while ($null -eq $choice)
	{
		$choice = GetInput $False
		if($choice -eq "ESC"){
			return
		}
		
		if($choice.Length -lt $global:MaxDigits){
			Write-Host "Id must be $global:MaxDigits long." -ForegroundColor Yellow	
			$choice = $null
			PromptAnyKey				
		}
	}

	Write-Host " - " -NoNewline

	$path = GetFilePath $choice
	
	$existingFile = Test-Path -Path $path
	if ($existingFile -eq $True) {
		Write-Host "Id $choice already exists." -ForegroundColor Yellow	
		PromptAnyKey
		return
	}
	
	try {
		# Create the new file
		$content = NewFileOutline $choice
		New-Item -Path $path -ItemType File
		$content | ConvertTo-Json -Depth 5 | Out-File $path -Force

		if($doStart -eq $True){
			UpdateFile $choice
		}		
		Write-Host "Added" -ForegroundColor Green
		Rest 2		
		return $True
	}
	Catch {
		Write-Host "Unable to create file." -ForegroundColor Red	
		Write-Host $_.Exception  -ForegroundColor Red	
		PromptAnyKey
		return $False
	}	
}

Function DeleteFile {
	$choice = Read-Host $global:TextPrefix "Enter the id to delete and press enter"	
	if($choice -eq "ESC"){
		return
	}
	$path = GetFilePath $choice
	
	$existingFile = Test-Path -Path $path
	if ($existingFile -eq $False) {
		Write-Host "Id $choice wasn't found." -ForegroundColor Yellow	
		PromptAnyKey
		return
	}
	
	try {
		if ($global:HardDelete -eq $True) {
			Remove-Item -Path $path
			Write-Host $global:TextPrefix "Deleted $choice" -ForegroundColor Green			
			Rest 2
		}
		else {
			$newName = "$choice.$global:ArchivedFileExtention"
			Rename-Item -Path $path -NewName $newName			
		}
		return	
	}
	Catch {
		Write-Host $global:TextPrefix "Unable to delete file." -ForegroundColor Red	
		Write-Host $_.Exception  -ForegroundColor Red
		PromptAnyKey
		return	
	}	

	
}

Function DisplayReport {
	
	$files = GetFiles
		
	if ($files.Count -eq 0) {
		Write-Host $linePrefix -NoNewline
		Write-Host $global:MenuPrefix -NoNewline
		Write-Host "Nothing to report!" -ForegroundColor Green
		PromptAnyKey
		return
	}

	WriteReportHeader

	try {
		#Write-Host "Generating Report"
		$files = GetFiles
		if ($files.Count -eq 0) {
			return
		}
		$now = GetTimestamp	
		$dates

		foreach ($file in $files) {	
			#Write-Host " $file " -NoNewline
			$path = GetFilePath $file
			$day1 = $now.ToString("dd-MM-yyyy")
			$day2 = $now.AddDays(-1).ToString("dd-MM-yyyy")
			$day3 = $now.AddDays(-2).ToString("dd-MM-yyyy")
			$day4 = $now.AddDays(-3).ToString("dd-MM-yyyy")
			$day5 = $now.AddDays(-4).ToString("dd-MM-yyyy")
			#Write-Host	"Day1 = $day1"
			#Write-Host	"Day2 = $day2"
			#Write-Host	"Day3 = $day3"
			#Write-Host	"Day4 = $day4"
			#Write-Host	"Day5 = $day5"

			$billables = [ordered]@{$day1 = 0; $day2 = 0; $day3 = 0; $day4 = 0; $day5 = 0}

			#Write-Host $billables
				
			$content = (Get-Content -Path $path -Raw) | ConvertFrom-Json
			$id = $($content.Id)
			$events = [System.Collections.Generic.List[psobject]]@($content.Events)
			$count = $events.Count
			if($count -eq 0){
				continue
			}
			for ($i = 0; $i -lt $events.Count; $i++) {
				$entry = $events[$i]		

				$start = $entry.Start				
				$startNull = ([string]::IsNullOrWhiteSpace($start))

				$stop = $entry.Stop
				$stopNull = ([string]::IsNullOrWhiteSpace($stop))				

				if($startNull -eq $False -and $stopNull -eq $False){
					
					#Write-Host "start = $start"
					$year  = $start.Year
					$month = $start.Month
					if($month -lt 10){
						$month = "0$month"
					}
					$day = $start.Day
					if($day -lt 10){
						$day = "0$day"
					}					

					$key = "$day-$month-$year"
					$keyFound = $False

					if($key -eq $day1){
						$keyFound = $True
					}
					elseif ($key -eq $day2) {
						$keyFound = $True
					}
					elseif ($key -eq $day3) {
						$keyFound = $True
					}
					elseif ($key -eq $day4) {
						$keyFound = $True
					}
					elseif ($key -eq $day5) {
						$keyFound = $True
					}													
					#Write-Host "key: $key - Found: $keyFound"
					if($keyFound -eq $True)
					{
						$seconds = (New-TimeSpan -Start $start -End $stop).Seconds
						$minutes = [math]::Ceiling($seconds/60)
						#Write-Host "Adding $minutes to $key based on $start - $stop"
						$billables[$key] += $minutes;
					}
				}												
			}	
			$firstLine = $True
			foreach ($entry in $billables.GetEnumerator()) {
				$billed = 0
				$minutes = $($entry.Value)
				if($minutes -gt 0){
					$billed = [math]::Ceiling($minutes / 15)
					$billed = $billed * 15
					if($firstLine -eq $True){
						Write-Host $global:SeperatorLine -ForegroundColor DarkYellow	
						Write-Host "`t$id" -ForegroundColor Yellow -NoNewline
						$firstLine = $False	
					}
					else {
						Write-Host "`t" -NoNewline
					}
					Write-Host "`t $($entry.Name) `t      $minutes `t`t" -NoNewline
					Write-Host " $billed" -ForegroundColor Green
				}
				
			}
		}		
		Write-Host $global:SeperatorLine -ForegroundColor DarkYellow
	}
	catch {
		Write-Host "Error confimring file contents." -ForegroundColor Red	
		Write-Host $_.Exception  -ForegroundColor Red	
		PromptAnyKey
	}

	
	PromptAnyKey	
}

Function WriteStartMessage($target){
	$date = GetTimestamp
	Write-Host $global:TextPrefix "$target started at $date " -ForegroundColor Green
}
Function WriteStopMessage($target){
	$date = GetTimestamp
	Write-Host $global:TextPrefix "$target stopped at $date " -ForegroundColor Green
}

Function UpdateFile($target) {
	try{
		$currentFile = GetCurrentlyActiveFile		
		if([string]::IsNullOrWhiteSpace($currentFile)){
			StartFile $target
			WriteStartMessage $target
			return
		}

		if($target -eq $currentFile){
			StopFile $target
			WriteStopMessage $target
			return
		}

		# Stop current file
		if([string]::IsNullOrWhiteSpace($currentFile) -eq $False)
		{			
			StopFile $currentFile
			WriteStopMessage $currentFile
		}

		# start requested file
		StartFile $target
		WriteStartMessage $target
	}
	catch {
		Write-Host $global:TextPrefix "Unable to update file." -ForegroundColor Red
		Write-Host $_.Exception  -ForegroundColor Red
		PromptAnyKey
	}	
	return
}
Function SetCurrentlyActiveFile($target){
	$global:CurrentlyActiveFile = $target
	return $global:CurrentlyActiveFile
}

Function GetCurrentlyActiveFile{
	return $global:CurrentlyActiveFile
}

Function StartFile($target){
	try {
		
		$path = GetFilePath $target
		$existingFile = Test-Path -Path $path

		if ($existingFile -eq $False) {
			Write-Host "Unable to find file $path" -ForegroundColor Red	
			PromptAnyKey
			return
		}	

		$content = (Get-Content -Path $path -Raw) | ConvertFrom-Json
		$events = $content.Events
		$count = $events.Count
	
		$now = GetTimestamp
		$saveFile = $False
		if($count -eq 0)	{
			$newEvent = GetNewEvent $now ''
			$content.Events += $newEvent
			$saveFile = $True
		}
		else {
			$lastEvent = $content.Events[-1]
			if($null -eq $lastEvent.Stop){
				$content.Events[-1].Stop = $now
				$saveFile = $True
			}
			else{
				$newEvent = GetNewEvent $now ""
				$content.Events += $newEvent
				$saveFile = $True
			}
		}
		
		if($saveFile){
			$content | ConvertTo-Json -Depth 5 | Out-File $path -Force
			SetCurrentlyActiveFile $target
		}
	}
	catch {
		Write-Host $global:TextPrefix "Unable to start file." -ForegroundColor Red
		Write-Host $_.Exception  -ForegroundColor Red
		PromptAnyKey
	}	
	return	

}

Function StopFile($target){
	
	Write-Host "StopFile($target)"
	try {
		
		$path = GetFilePath $target

		$existingFile = Test-Path -Path $path
		if ($existingFile -eq $False) {
			Write-Host "Unable to find file $path" -ForegroundColor Red	
			PromptAnyKey
			return
		}	

		$content = (Get-Content -Path $path -Raw) | ConvertFrom-Json
		$events = $content.Events
		$count = $events.Count
		$now = GetTimestamp

		$saveFile = $False
		if($count -eq 0)	{
			Write-Host "Unable to stop $target. No events found." -ForegroundColor Red	
			PromptAnyKey
			return
		}
		else {
			$lastEvent = $content.Events[-1]
			if($null -ne $lastEvent.Start -and ($null -eq $lastEvent.Stop -or [string]::IsNullOrWhiteSpace($lastEvent.Stop) -eq $True)){
				$content.Events[-1].Stop = $now
				$saveFile = $True
			}
		}
		
		if($saveFile){
			$content | ConvertTo-Json -Depth 5 | Out-File $path -Force
			SetCurrentlyActiveFile $null			
		}
	}
	catch {
		Write-Host $global:TextPrefix "Unable to stop file." -ForegroundColor Red
		Write-Host $_.Exception  -ForegroundColor Red
		PromptAnyKey
	}		
	return	

}

Function ShowHelp {
	Write-Host $global:SingleLine -ForegroundColor DarkGreen
	Write-Host $global:TextPrefix "'a' or 'add'" -ForegroundColor Green
	Write-Host $global:TextPrefix "Adds a new $global:MaxDigits digit id to be timed. "
	Write-Host $global:TextPrefix "'d', 'del' or 'delete'" -ForegroundColor Green
	Write-Host $global:TextPrefix "Load the screen to delete a thing you used to touch. "
	Write-Host $global:TextPrefix "'h' or 'help'" -ForegroundColor Green
	Write-Host $global:TextPrefix "Will load the screen you are currently on ... there is no more help for you."
	Write-Host $global:SingleLine -ForegroundColor DarkGreen
	PromptAnyKey
	return
}

Function Rest ($n) {
	Start-Sleep -Seconds $n
}

Function Quit {
	Write-Host ("Good bye")
	Rest 2
	[Environment]::Exit(0)
}

Function Abort {
	[Environment]::Exit(1)
}

Init 

MainMenu


