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
    param (
        [string]$gameID
    )

    $thingType='boardgame'

    $gameName = Get-BGGThing -thingID $gameID -thingTypes $thingType | Select-Xml -XPath "/items/item/name[@type='primary']" | Select-Object -ExpandProperty "node" | Select-Object -Property value -ExpandProperty value

    return $gameName
}

function Get-BGGChallengePlaysForEntry {
    [cmdletbinding()]
    param (
        [string]$bggUser,
        [string[]]$gameIDs,
        [string]$year,
        [string]$reqPlayer,
        [switch]$ListGames
    )

    $entry = ""
    $curGameNumber = 1

    foreach ( $gameID in $gameIDs ) {
            if ( $listGames ) {
                $curName = Get-BGGGameName -gameID $gameID
                Write-Host "Fetching plays for $curName"
            }
	        if ( $curGameNumber -eq 11 ) {
		        $entry = $entry + "`nAlternate game:`n"
	        }
	        $newRow = Get-BGGChallengePlaysForGame -bggUser $bggUser -gameID $gameID -year $year -gameNumber $curGameNumber -reqPlayer $reqPlayer
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

    $playsUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bggUser&id=$gameID&mindate=$year-01-01&maxdate=$year-12-31"
    [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUri
    $numPlays = 0
    $paddedGameNumber = $([string]$gameNumber).PadLeft(2,'0')
    $row = "$paddedGameNumber. "
    if ( $reqPlayer -eq '' ) {
        # No required player
        Write-Verbose "No required player"
        $xmlPlays | Select-Xml -XPath "//*[*/@objecttype='thing']" | Sort-Object -Property date,id | Select-Object -First 10 -ExpandProperty "node" | Select-Object -ExpandProperty id |  ForEach-Object { $playStar = "[geekurl=/play/details/$_]:star:[/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    } else {
        # Required player present
        Write-Verbose "Required player $reqPlayer"
        $xmlPlays | Select-Xml -XPath "//*[*/*/@name='$reqPlayer']" | Sort-Object -Property date,id | Select-Object -First 10 -ExpandProperty "node" | Select-Object -ExpandProperty id |  ForEach-Object { $playStar = "[geekurl=/play/details/$_]:star:[/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    }
    $fillerStars = for( $i = $numPlays+1 ; $i -le 10; $i = $i + 1 ) { $row = $row + ':nostar:' }
    $gameLink = "[thing=$gameID][/thing]"
    $row = $row + $fillerStars + " $gameLink`n"
    
    return $row

}

function Get-BGGHIndexList {
    param (
        [string]$bggUser,
        [int32]$target,
        [int32]$cutoff
    )
    $collectionUri = "https://boardgamegeek.com/xmlapi2/collection?username=$bggUser&subtype=boardgame&excludesubtype=boardgameexpansion&excludesubtype=boardgameaccessory&played=1"
    [xml]$xmlCollection = Invoke-WebRequest -Uri $collectionUri

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
    $HIndexList = "[BGCOLOR=#CCFF00]"
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

    # Get a dictionary containing all ids of boardgames and expaniosn played in the time interval
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
    $numExpansions = $bgexpDict.Count
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

<#
$myIDs = Get-BGGUniqueIDsFromPlays -bgguser 'psson73' -startDate '2022-01-01' -endDate '2022-04-03'
$myIDs

$numIDs = 0
$numBGs = 0
$numBGExp = 0

foreach ( $key in $myIDs.Keys ) {
    $numIDs +=1
    if ( $myIDs[$key] -eq 'bg' ) {
        $numBGs +=1
    } elseif ( $myIDs[$key] -eq 'bgexp' ) {
        $numBGExp +=1acc
    }
}

$numIDs
$numBGs
$numBGExp

# Skapa BGG-kod och skicka till clipboard
Get-BGGUniqueGamesAndExpansionsText -idDict $myIDs | clip
#>




Export-ModuleMember Get-BGGChallengePlaysForEntry
Export-ModuleMember Get-BGGGameName
Export-ModuleMember Get-BGGHIndexList
Export-ModuleMember Get-BGGCategoriesForGame
Export-ModuleMember Get-BGGNumCategoriesForGames
Export-ModuleMember Get-BGGChallengePlaysForGame
Export-ModuleMember Get-BGGUniqueIDsFromPlays
Export-ModuleMember Get-BGGUniqueGamesAndExpansionsText