function Get-BGGCollection {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory)][string]$Uri,
        [Parameter()][Int32]$maxTries=3,
        [Parameter()][Int32]$retryTimeout=5
    )

    # Status codes for 
    $statusSuccess = '200'
    $statusQueued = '202'

    $queued = $true
    $failed = $null
    $tryNum = 1

    while ( $queued ) {

        
        # Attempt to get data and cast as XML
        [xml]$response = Invoke-RestMethod -Uri $Uri -StatusCodeVariable 'scv'
        Write-Debug "Status code of request to BGG XML API 2 is $scv"
        # Check status code of the attempt
        if ( $scv -match $statusSuccess ) {
            # Got the data we're looking for
            $queued = $false
        } elseif ( $scv -match $statusQueued ) {
            # Call queued, increment number of tries and check if max tries reached
            $tryNum++
            # If max tries is reached, break off attempt
            # Otherwise, wait for a new try
            if ( $tryNum -gt $maxTries ) {
                $queued = $false
                $failed = "Maximum number of tries exceeded"
            } else {
                Write-Debug "Attempt $tryNum of $maxTries queued, waiting $retryTimeout seconds before next call..."
                Start-Sleep -Seconds $retryTimeout
            }
            
        } else {
            # Something bad happened
            $queued = $false
            Write-Debug "Unknown error. Status code $scv"
        }


    }

    if ( $failed -notmatch $null ) {
        return $null
    } else {
        return $response
    }

}

function Get-BGGThing {
    param (
        [string]$thingID,
        [string]$thingTypes
    )

    $thingUri = "https://boardgamegeek.com/xmlapi2/thing?id=$gameID&type=$thingTypes"
    [xml]$xmlThing = Invoke-WebRequest -Uri $thingUri

    return $xmlThing

}

function Get-BGGGameName {
    [cmdletbinding()]
    param (
        [string][Parameter(Mandatory,ValueFromPipeline)]$gameID
    )

    begin {}

    process {
        $thingType='boardgame'

        $gameName = Get-BGGThing -thingID $gameID -thingTypes $thingType | Select-Xml -XPath "/items/item/name[@type='primary']" | Select-Object -ExpandProperty "node" | Select-Object -Property value -ExpandProperty value

        return $gameName
    }

    end {}

    
}

function Get-BGGChallengePlaysForEntry {
    [cmdletbinding()]
    param (
        [string]$BGGUser,
        [string[]]$GameIDs,
        [string]$Year,
        [string]$ReqPlayer,
        [switch]$ListGames
    )

    # TODO: BGGConfig Examine provided username and set default username if missing

    $entry = ""
    $curGameNumber = 1

    foreach ( $gameID in $gameIDs ) {
            if ( $ListGames ) {
                $curName = Get-BGGGameName -gameID $gameID
                Write-Host "Fetching plays for $curName"
            }
	        if ( $curGameNumber -eq 11 ) {
		        $entry = $entry + "`nAlternate game:`n"
	        }
	        $newRow = Get-BGGChallengePlaysForGame -bggUser $bggUser -gameID $gameID -year $year -gameNumber $curGameNumber -reqPlayer $reqPlayer -Verbose:$VerbosePreference
	        $entry = $entry + $newRow
	        $curGameNumber = $curGameNumber + 1
    }

    return $entry
}

function Get-BGGChallengePlaysForGame {
    [cmdletbinding()]
    param ( [string]$bggUser,
            [string]$gameID,
            [string]$year,
            [int]$gameNumber,
            [string]$reqPlayer
    )

    # TODO: BGGConfig Examine provided username and set default username if missing

    $playsUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bggUser&id=$gameID&mindate=$year-01-01&maxdate=$year-12-31"
    [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUri
    $numPlays = 0
    $paddedGameNumber = $([string]$gameNumber).PadLeft(2,'0')
    $row = "[c]$paddedGameNumber. [/c]"
    if ( $reqPlayer -eq '' ) {
        # No required player
        Write-Verbose "No required player"
        $xmlPlays | Select-Xml -XPath "//*[*/@objecttype='thing']" | Sort-Object -Property date,id | Select-Object -First 10 -ExpandProperty "node" | Select-Object -ExpandProperty id |  ForEach-Object { $playStar = "[geekurl=/play/details/$_][microbadge=54118][/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    } else {
        # Required player present
        Write-Verbose "Required player $reqPlayer"
        $xmlPlays | Select-Xml -XPath "//*[*/*/@name='$reqPlayer']" | Sort-Object -Property date,id | Select-Object -First 10 -ExpandProperty "node" | Select-Object -ExpandProperty id |  ForEach-Object { $playStar = "[geekurl=/play/details/$_][microbadge=54118][/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    }
    $fillerStars = for( $i = $numPlays+1 ; $i -le 10; $i = $i + 1 ) { $row = $row + '[microbadge=54116]' }
    $gameLink = "[thing=$gameID][/thing]"
    $row = $row + $fillerStars + " $gameLink`n"
    
    return $row

}

function Get-BGGDiversityChallengeList {
    [cmdletbinding()]
    param (
        [Parameter()][string]$BGGUser,
        [Parameter()][string]$Goal = 100,
        [Parameter()][string]$StartDate,
        [Parameter()][string]$EndDate
    )

    # TODO: BGGConfig Examine provided username and set to default username if missing
    # TODO: Examine provided start and end dates and set to year start and year end if missing

    # Construct API URL for games played by user in given year
    $url = "https://www.boardgamegeek.com/xmlapi2/plays?username=$BGGUser&mindate=$StartDate&maxdate=$EndDate"

    # Query the API and parse the XML response
    $response = Invoke-RestMethod $url

    # Calculate number of pages from total plays and 100 plays per page
    $totalPlays = $response.plays.total
    $playsPerPage = 100
    # Find the number of pages by integer division
    $numPages = [math]::Floor($totalPlays/$playsPerPage)
    # Check if there's a remainder (usually) and add a page for that
    if ( ( $totalPlays%$playsPerPage ) -gt 0) { $numPages += 1 }
    Write-Debug "Total plays, expansions included: $totalPlays"
    Write-Debug "Pages: $numPages"

    # Create dictionary for object ids with dates
    $firstPlays = @{}

    # Set counter for current page of results
    # Used for fetching 
    $curPage=1

    # For each page
    while ( $true ) { 

        # Get page plays to a "nice" variable
        $plays = $response.plays.play #| Select-Object -First $maxPlaysPerPage

        # For each play

        foreach ( $play in $plays ) {
            
            $bgPlay = $true     # Play is a play of a boardgame
            $playID = $play.id
            Write-debug "Play ID: $playID"

            # Get subtypes to a "nice" variable
            $subtypes = $play.item.subtypes.subtype
            
            # Is expansion, do nothing
            foreach ( $subtype in $subtypes ) {
                $subVal = $subtype.value
                if ( $subVal -eq 'boardgameexpansion') {
                    Write-Debug "Play is an expansion, don't process"
                    $bgPlay = $false
                }
            }
            

            #<#
            if ( $bgPlay ) {
                $itemID = $play.item.objectid
                $curPlayId = $play.id
                $curDate = $play.date
                # ID not in dictionary, add with date
                if ( -not $firstPlays.Contains($itemID) ) {
                    Write-Debug "Item $itemID not in dictionary. Adding it..."
                    $firstPlays[$itemID]=@{playid=$curPlayId;playdate=$curDate}
                } else {
                    # ID in dictionary

                    Write-Debug "Current date: $curDate"
                    Write-Debug "Existing date: $firstPlays[$itemid].playdate"
                    
                    if ( $curDate -lt $firstPlays[$itemid].playdate ) {
                        # If current date newer than date in dictionary, replace date
                        Write-Debug "Current date, $curDate is less the registered date for $itemID. Replacing..."
                        $firstPlays[$itemID]=@{playid=$curPlayId;playdate=$curDate}
                    }
                }
                    
            }

            #>

            
        
        }

        # If last page, quit
        if ( $curPage -ge $numPages ) {
            # On last page, break out of loop
            Write-Debug "Last page processed, exiting..."
            BREAK
        } else {
            # Increment current page
            Write-Debug "Page $curPage of $numPages processed, continuing..."
            $curPage++
            
            # Construct API URL for games played by user in given year
            $url = "https://www.boardgamegeek.com/xmlapi2/plays?username=$BGGUser&mindate=$StartDate&maxdate=$EndDate&page=$curPage"

            # Query the API and parse the XML response
            $response = Invoke-RestMethod $url
            
        }

        

    }

    # Create BGG code
    
    $sortedItems = $firstPlays.GetEnumerator() | Sort-Object { $_.Value.playdate }

    <#
    $output = "In for $Goal different games`n`nCurrently at $($firstPlays.Count)`n`n"
    #>

    $output = "In for $Goal different games"
    if ( $firstPlays.Count -ge $Goal ) {
        $output += "`n`n[b]CHALLENGE COMPLETED[/b]`n`nCurrently at $($firstPlays.Count)`n`n"
    } else {
        $output += "`n`nCurrently at $($firstPlays.Count)`n`n"
    }
    
    

    foreach ( $item in $sortedItems ) {
        $curLine = "[thing=$($item.key)][/thing] - [geekurl=/play/details/$($item.Value.playid)]$($item.Value.playdate)[/geekurl]`n"
        $output += $curLine
    }

    Write-Verbose $output

    return $output
    
}

function Get-BGGHIndexList {
    [cmdletbinding()]
    param (
        [string]$BGGUser,
        [int32]$Target,
        [int32]$Cutoff
    )
    $collectionUri = "https://boardgamegeek.com/xmlapi2/collection?username=$bggUser&subtype=boardgame&excludesubtype=boardgameexpansion&excludesubtype=boardgameaccessory&played=1"
    $xmlCollection = Get-BGGCollection -Uri $collectionUri

    if ( $null -eq $xmlCollection ) {
        # Failed to get collection
        return 'Failed to get collection from boardgamegeek.com'
    } else {

        # Slår upp spel med numplays större än cutoff
        $boardgameItems = $xmlCollection | Select-Xml -XPath "//item[numplays>=$cutoff]"

        $playsList = @{}

        foreach ( $item in $boardgameItems ) {
            $curID = $item.Node.objectid
            $numPlays = $item.Node.numplays
            try {
                $playsList.Add($curID,[int32]$numPlays)
            } catch [ArgumentException] {
                # Dublett
            } catch {
                Write-Host "Unexpected Error"
            }
        }

        $curRow = 1
        $HIndexList = "[BGCOLOR=#66FF00]"
        $aboveTarget = $true
        $notStartedBelowTarget = $true

        foreach ( $item in $playsList.GetEnumerator() | Sort-Object { $_.Value } -Descending ) {
            $curID = $item.Key
            $curPlays = $item.Value

            if ( ( $curPlays -lt $target ) -and ( $aboveTarget ) ) {
                $HIndexList = $HIndexList + "[/BGCOLOR][BGCOLOR=#FFCC00]"
                $aboveTarget = $false
            } elseif ( $curRow -eq $target ) {
                $HIndexList = $HIndexList + "[/BGCOLOR]"
            } elseif ( ( $curRow -gt $target ) -and ( $notStartedBelowTarget ) ) {
                $HIndexList = $HIndexList + "[BGCOLOR=#FFCC00]"
                $notStartedBelowTarget = $false
            }

            if ( $curRow -eq $target ) { $HIndexList = $HIndexList + '[BGCOLOR=#33FFFF][b][i]' }
            $HIndexList = $HIndexList + "$curRow. [thing=$curID][/thing] $curPlays"
            if ( $curRow -eq $target ) { $HIndexList = $HIndexList + ' Primary goal[/b][/i][/BGCOLOR]' }
            $HIndexList = $HIndexList + "`n"


            $curRow++
            if ( $curPlays -le $cutoff ) {
                $HIndexList = $HIndexList + "[/BGCOLOR]"
                BREAK 
            }
        }

        return $HIndexList
    }

}

function Get-BGGCategoriesForGamesToFile {
    [cmdletbinding()]
    param(
        [string][Parameter(Mandatory)]$BGGuser,
        [string]$StartDate,
        [string]$EndDate
    )

    # Get play data from BGG. Note that the dictionary returns both boardgames and expansions with
    # the value 'bg' and 'bgexp' respectively.
    Write-verbose "About to look up plays to dictionary"
    [hashtable]$idDict = Get-BGGUniqueIDsFromPlays -BGGuser $BGGUser -StartDate $StartDate -EndDate $EndDate
    $numEntries = $idDict.Keys | Measure-Object | Select-Object -ExpandProperty Count
    Write-verbose $numEntries
    
    Write-Verbose "Setting up file"

    if ($psISE) {
        # Objektet finns, skriptet körs från ISE.
        # Hämta sökvägen från $psISE
        $basePath = Split-Path -Path $psISE.CurrentFile.FullPath
    } else {
        # Alla andra fall, använd $PSScriptRoot
        $basePath = $PSScriptRoot
    }

    $now = Get-Date -Format 'yyyyMMdd_HHmm'
    $defaultFilename = "$BGGuser_Categories_$now.txt"
    $filename = Get-SaveFileName -InitialDirectory $basePath -DefaultFileName $defaultFilename

    "Game categories for $BGGUser`nStart date`: $StartDate`nEnd date`: $EndDate`n`n" | Out-File -FilePath $filename -Encoding utf8

    Write-verbose "About to loop through IDs"
    foreach ( $gameID in $idDict.Keys ) {
        
        # Use dictionary to create a string of game IDs
        #<#
        if ( $idDict[$gameID] -eq 'bg' ) {
            # Boardgame ID, add to string
            $thingIDs = $thingIDs + ",$gameID"
        } else {
            # Board game expansion, ignore
        }
        #>
    }

    # Remove last comma from string of game IDs
    $thingIDs = $thingIDs -replace ".$"

    # Get XML data for all played games
    $thingsURI="https://boardgamegeek.com/xmlapi2/thing?id=$thingIDs"
    Write-Verbose $thingsURI
    #[xml]$things = Invoke-WebRequest -Uri $thingsUri

    # Get name and categories for each game, output to file

}

function Get-BGGCategoriesForGame {
    [cmdletbinding()]
    param (
        [string][parameter(Mandatory)]$GameID
    )

    $categories = @{}
    
    $thingUri = "https://boardgamegeek.com/xmlapi2/thing?id=$GameID"
    [xml]$xmlThing = Invoke-WebRequest -Uri $thingUri

    $categoryLinks = $xmlThing | Select-Xml -XPath "//*[@type='boardgamecategory']"

    foreach ( $category in $categoryLinks.Node.value ) {
        try {
            Write-Verbose $category
            $categories.Add($category,'category')
        } catch [ArgumentException] {
            # Dublett
        } catch {
            Write-Error "Unexpected Error"
        }
    }

    return $categories

}

function Get-BGGNumCategoriesForGames {
    [cmdletbinding()]
    param(
        [string][Parameter(Mandatory,ValueFromPipeline)]$GameID
    )

    begin {
        $catDict = @{}
    }

    process {
        Write-Verbose "Processing ID $GameID"
        $gameCats = Get-BGGCategoriesForGame -GameID $GameID
        foreach ( $key in $gameCats.Keys ) {
            if ( $catDict.ContainsKey($key) ) {
                $catDict[$key] = $catDict[$key] + 1
            } else {
                $catDict.Add($key,1)
            }
        }
    }

    end {
        return $catDict
    }

}

function Get-BGGUniqueIDsFromPlays {
    [cmdletbinding()]
    param (
        [string][Parameter(Mandatory)]$BGGuser,
        [string]$StartDate,
        [string]$EndDate
    )

    # Check date format, should be yyyy-mm-dd
    $datePattern = '^[\d]{4}-[\d]{2}-[\d]{2}$'
    if ( $startDate -notmatch $datePattern ) { throw 'Bad start date format' }
    if ( $endDate -notmatch $datePattern ) { throw 'Bad end date format' }

    $playsUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bgguser&subtype=boardgame&mindate=$startDate&maxdate=$endDate"
    [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUri

    # Calculate number of pages from total plays and 100 plays per page
    $totalPlays = $xmlPlays.plays.total
    $playsPerPage = 100
    $numPages = [math]::Floor($totalPlays/$playsPerPage)
    if ( ( $totalPlays%$playsPerPage ) -gt 0) { $numPages += 1 }

    # Create dictionaries to store ids for games and expansions
    $expDict = @{}
    $idDict = @{}

    # Get all pages of the result and store ids in

    $curPage = 1

    while ( $true ) {

        # Store all expansion ids in a dictionary
        Get-UniqueExpansionIDs -xmlPlays $xmlPlays -bgexpDict $expDict
        # Store all gameids in a dictionary
        Get-UniqueIDs -xmlPlays $xmlPlays -bgexpDict $expDict -bgDict $idDict
    
        # Increment $curPage and break out of the loop if number of pages are exceeded
        $curPage++
        if ( $curPage -gt $numPages ) {
            BREAK
        }

        # Fetch next page of results
        $playsUriPage = $playsUri + "&page=$curPage"
        [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUriPage

    }

    # Add expansion-IDs to dictionary that already contains the boardgame IDs
    foreach ( $key in $expDict.Keys ) {
        $curKey = $key
        $idDict.Add($curKey,'bgexp')
    }
    

    return $idDict

}

function Get-UniqueExpansionIDs {
    [cmdletbinding()]
    param(
        [xml]$xmlPlays,
        [hashtable]$bgexpDict
    )

    $expansionItems = $xmlPlays | Select-Xml -XPath "//*[*/*/@value='boardgameexpansion']"

    foreach ( $item in $expansionItems ) {
        $curID = $item.Node.objectid
        
        if ( $bgexpDict.ContainsKey( $curID ) ) {
            # Do nothing, already has key
        } else {
            # Add key to dictionary
            $bgexpDict.Add( $curID,'bgexp' )
        }
    }

}

function Get-UniqueIDs {
    [cmdletbinding()]
    param(
        [xml]$xmlPlays,
        [hashtable]$bgexpDict,
        [hashtable]$bgDict
    )

    # Select all plays of boardgames from xml data
    $boardgameItems = $xmlPlays | Select-Xml -XPath "//*[*/*/@value='boardgame']"

    # Add ids that are board games to the dictionary as boardgames with value bg
    foreach ( $item in $boardgameItems ) {
        $curID = $item.Node.objectid
        
        if ( $bgDict.ContainsKey( $curID ) ) {
            # Do nothing, ID is already present in dictionary
        } elseif ( $bgexpDict.ContainsKey( $curID ) ) {
            # Do nothing, ID is an expansion
        } else {
            # Add a board game id to the dictionary
            $bgDict.Add( $curID,'bg' )
        }
    }

}

function Get-BGGUniqueGamesAndExpansionsText {
    [cmdletbinding()]
    param (
        [string][Parameter(Mandatory)]$BGGuser,
        [string]$StartDate,
        [string]$EndDate
    )
    <#
    param (
        [hashtable]$idDict
    )
    #>

    # Get a dictionary containing all ids of boardgames and expanions played in the time interval
    $idDict = Get-BGGUniqueIDsFromPlays -BGGuser $BGGUser -StartDate $StartDate -EndDate $EndDate

    # Create BGG-code for boardgames based on the dictionary
    
    $bgText = ''
    $curItem=1
    foreach ( $key in $idDict.Keys ) {
        Write-Verbose $key
        if ( $idDict[$key] -eq 'bg' ) {
            $curID = $key
            $bgText = $bgText + "$curItem. [thing=$curID][/thing]`n"
            $curItem++
        }
    }
    $curItem--
    $bgHeader = "[b]Unique Games: $curItem[/b]`n"

    # Create BGG-code for expansions based on dictionary
    $expText = ''
    $curItem=1
    foreach ( $key in $idDict.Keys ) {
        Write-Verbose $key
        if ( $idDict[$key] -eq 'bgexp' ) {
            $curID = $key
            $expText = $expText + "$curItem. [thing=$curID][/thing]`n"
            $curItem++
        }
    }
    $curItem--
    $expHeader = "`n[b]Unique Expansions: $curItem[/b]`n"

    $retText = $bgHeader + $bgText + $expHeader + $expText

    return $retText

}

function Get-BGGUnplayedGameIDs {
    [cmdletbinding()]
    param(
        [string][Parameter(Mandatory)]$BGGUser,
        [switch][Parameter()]$Owned,
        [string][Parameter()]$StartDate,
        [string][Parameter()]$EndDate,
        [switch][Parameter()]$ExcludeExpansions
    )

    <#
    Fetch IDs for unplayed games for user collection
    Either no dates or both dates should be supplied
    If no date is supplied, the entire collection is downloaded 
    #>

    if ( $Owned ) {
        $own = 1
    } else {
        $own = 0
    }

    if ( $ExcludeExpansions ) {
        $ExclExp='&excludesubtype=boardgameexpansion'
    } else {
        $ExclExp=''
    }

    $unplayedIDs = @{}

    if ( ( $StartDate -eq '' ) -or ( $EndDate -eq '' ) ) {

        Write-Verbose "No dates provided"

        # At least one of the dates are empty, get all owned, unplayed games in collection excluding wishlist items
        $unplayedUri = "https://boardgamegeek.com/xmlapi2/collection?username=$BGGUser&own=$own&played=0&wishlist=0$ExclExp"
        $unplayedGames = Get-BGGCollection -Uri $unplayedUri

        # Get all gameIDs to a dictionary

        $unplayedGames.items.item.objectid | ForEach-Object { $unplayedIDs.Add($_,'unplayed') }

    } else {

        Write-Verbose "Dates provided"

        # Get unique IDs of games and expansions played in the specified period
        [hashtable]$playedIDs = Get-BGGUniqueIDsFromPlays -BGGuser $BGGUser -StartDate $StartDate -EndDate $EndDate

        # Get games from user collection
        $gamesUri = "https://boardgamegeek.com/xmlapi2/collection?username=$BGGUser&own=$own$ExclExp"
        
        $games = Get-BGGCollection -Uri $gamesUri

        if ( $null -eq $games ) {
            Write-Error "Failed to get all data from BGG"
            $unplayedIDs = $null
        } else {
        
            # Get all gameIDs to a dictionary
            $allIDs = $games.items.item.objectid

            foreach ( $id in $allIDs ) {
                if ( $playedIDs.ContainsKey( $id ) ) {
                    #ID is played, ignore
                } else {
                    
                    try {
                        $unplayedIDs.Add( $id, 'unplayed' )
                    }
                    catch [System.Management.Automation.MethodInvocationException] {
                        # Exception adding duplicate, ignore
                    }
                    
                }
            }

            Write-Verbose "Found $($unplayedIDs.Count)"

        }
        
    }

    return $unplayedIDs
}

Function Get-SaveFileName {  
    param (
        [string]$InitialDirectory,
        [string]$DefaultFileName
    )
    [System.Reflection.Assembly]::LoadWithPartialName(“System.Windows.Forms”) | Out-Null

    $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
    $OpenFileDialog.initialDirectory = $InitialDirectory
    $OpenFileDialog.filter = “Textfiler (*.txt)| *.txt”
    $OpenFileDialog.Title = "Välj fil"
    $OpenFileDialog.filename = $DefaultFileName
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.filename
}

<#
Export module functions
#>

Export-ModuleMember Get-BGGChallengePlaysForEntry
Export-ModuleMember Get-BGGThing
Export-ModuleMember Get-BGGGameName
Export-ModuleMember Get-BGGDiversityChallengeList
Export-ModuleMember Get-BGGHIndexList
Export-ModuleMember Get-BGGCategoriesForGamesToFile
Export-ModuleMember Get-BGGCategoriesForGame
Export-ModuleMember Get-BGGNumCategoriesForGames
Export-ModuleMember Get-BGGChallengePlaysForGame
Export-ModuleMember Get-BGGUniqueIDsFromPlays
Export-ModuleMember Get-BGGUniqueGamesAndExpansionsText
Export-ModuleMember Get-BGGUnplayedGameIDs