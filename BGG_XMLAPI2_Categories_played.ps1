$bgguser = 'psson73'
$year = '2021'
$bgguserPlaysUri = "https://boardgamegeek.com/xmlapi2/plays?username=$bgguser&mindate=$year-01-01&maxdate=$year-12-31"
[xml]$xmlBGGUserPlays = Invoke-WebRequest -Uri $bgguserPlaysUri

$uniqueLocations = $xmlBGGUserPlays.plays.play.location | Sort-Object | Get-Unique
#$uniqueLocations | measure

#$xmlBGGUserPlays.plays.play.item(0).item.name


$uniqueGamesPlayed = $xmlBGGUserPlays.plays.play | Select-Object -ExpandProperty item | Select-Object -ExpandProperty objectid | Sort-Object | Get-Unique
$uniqueGamesPlayed | measure

$gameIDs = ''
foreach ( $gamePlayed in $uniqueGamesPlayed ) {
    $gameIDs = $gameIDs + $gamePlayed + ","
}

#write-host $gameIDs
$bggGameDataUri = "https://boardgamegeek.com/xmlapi/boardgame/$gameIDs"
[xml]$gameData = Invoke-WebRequest -Uri $bggGameDataUri

$gameData.boardgames.boardgame | Select-Object -ExpandProperty name | Where-Object { $_.primary -eq 'true' } | Select-Object -ExpandProperty InnerXML | Sort-Object