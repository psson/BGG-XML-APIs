function Get-BGGChallengePlaysForEntry {
    param (
        [string]$bggUser,
        [string[]]$gameIDs,
        [string]$year
    )

    $entry = ""
    $curGameNumber = 1

    foreach ( $gameID in $gameIDs ) {
           $newRow = Get-BGGChallengePlaysForGame -bggUser $bggUser -gameID $gameID -year $year -gameNumber $curGameNumber
           $entry = $entry + $newRow
           $curGameNumber = $curGameNumber + 1
    }

    return $entry
}

function Get-BGGChallengePlaysForGame {
    param ( [string]$bggUser,
            [string]$gameID,
            [string]$year,
            [int]$gameNumber
    )

    $playsUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bggUser&id=$gameID&mindate=$year-01-01&maxdate=$year-12-31"
    [xml]$xmlPlays = Invoke-WebRequest -Uri $playsUri
    $numPlays = 0
    $paddedGameNumber = $([string]$gameNumber).PadLeft(2,'0')
    $row = "$paddedGameNumber. "
    $xmlPlays.plays.play | Sort-Object -Property date,id | Select-Object -First 10 | ForEach-Object { $playStar = "[geekurl=/play/details/$($_.id)]:star:[/geekurl]" ; $row = $row + $playStar ; $numPlays = $numPlays + 1 }
    $fillerStars = for( $i = $numPlays+1 ; $i -le 10; $i = $i + 1 ) { $row = $row + ':nostar:' }
    $gameLink = "[thing=$gameID]" + $xmlPlays.plays.play.Item(0).item.name + '[/thing]'
    $row = $row + $fillerStars + " $gameLink`n"
    
    return $row

}

# IDs för spelen som ska hämtas
$challengeGameIDs = @('146021','167791','118048','822','28143','154203','312484','244522','36218','224037')

# Hämta rad-datat till clipboard
Get-BGGChallengePlaysForEntry -bggUser 'psson73' -gameIDs $challengeGameIDs -year '2021' | clip

