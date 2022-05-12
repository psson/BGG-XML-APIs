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
    param (
        [string]$bggUser,
        [string[]]$gameIDs,
        [string]$year,
        [string]$reqPlayer
    )

    $entry = ""
    $curGameNumber = 1

    foreach ( $gameID in $gameIDs ) {
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
    param ( [string]$bggUser,
            [string]$gameID,
            [string]$year,
            [int]$gameNumber,
            [string]$reqPlayer
    )

    #$gameName = Get-BGGGameName -gameID $gameID

    $playsUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bggUser&id=$gameID&mindate=$year-01-01&maxdate=$year-12-31"
    [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUri
    $numPlays = 0
    $paddedGameNumber = $([string]$gameNumber).PadLeft(2,'0')
    $row = "$paddedGameNumber. "
    $xmlPlays | Select-Xml -XPath "//*[*/*/@name='$reqPlayer']" | Sort-Object -Property date,id | Select-Object -First 10 -ExpandProperty "node" | Select-Object -ExpandProperty id |  ForEach-Object { $playStar = "[geekurl=/play/details/$_]:star:[/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    $fillerStars = for( $i = $numPlays+1 ; $i -le 10; $i = $i + 1 ) { $row = $row + ':nostar:' }
    #$gameLink = "[thing=$gameID]" + $gameName + '[/thing]'
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

    # Slår upp sortindex bara för att få en uppsättning poster att arbeta med. 
    # Borde vara en slagning på spel med <numplays> större än eller lika med $cutoff
    #$boardgameItems = $xmlCollection | Select-Xml -XPath "//*[*/@sortindex='1']"
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

function Get-BGGCategoriesForGames {
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

Export-ModuleMember Get-BGGChallengePlaysForEntry
Export-ModuleMember Get-BGGGameName
Export-ModuleMember Get-BGGHIndexList
Export-ModuleMember Get-BGGCategoriesForGame
Export-ModuleMember Get-BGGCategoriesForGames