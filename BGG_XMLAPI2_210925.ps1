# Diverse utforskning av BGG XMLAPI2 via Powershell

# Hämta XML för collections, gör om så att den hanterar väntan
$collectionUri = 'https://boardgamegeek.com/xmlapi2/collection?username=psson73&subtype=boardgame&excludesubtype=boardgameexpansion&excludesubtype=boardgameaccessory&own=1'

[xml]$xmlCollection = Invoke-WebRequest -Uri $collectionUri

# Första spelet i min collection
$xmlCollection.items.item | Select-Object -First 1

# De första fem spelen och hur många gånger jag spelat dem
$xmlCollection.items.item | Select-Object -First 5 | ForEach-Object { $message = "Spel: $($_.name.InnerXML). Spelat $($_.numplays) gånger." ; Write-Host $message }

# De spel som är aktuella i H-index challenge
# Observera användningen av calculated properties bl a för att casta [string]numplays till [int]numplays för korrekt sortering
$xmlCollection.items.item | Select-Object -Property @{ Name = 'gamename' ; Expression = { $_.name.InnerXML } },@{ Name = 'numplays' ; Expression = {  [int]$_.numplays } } | Where-Object { ([int]$_.numplays -lt 38) -and ( [int]$_.numplays -gt 20 ) } | Sort-Object -Property numplays -Descending | ForEach-Object { $message = "$($_.gamename): $($_.numplays)" ; Write-Host $message }

# Want to play
# Mer calculated properties
$xmlCollection.items.item | Select-Object @{ Name = 'gamename' ; Expression = { $_.name.InnerXML } },@{ Name = 'wanttoplay' ; Expression = {  $_.status.wanttoplay } } | Where-Object { $_.wanttoplay -eq '1' } | Sort-Object -Property gamename | Select-Object -ExpandProperty gamename

# Hämta spel genom BGG XML API
$gameID = '146021'
$gameUri = "https://boardgamegeek.com/xmlapi/boardgame/$gameID"
[xml]$xmlGame = Invoke-WebRequest -Uri $gameUri

$xmlGame.boardgames.boardgame.description
$xmlGame.boardgames.boardgame.name
$xmlGame.boardgames.boardgame.name | Where-Object -Property { $_.primary -eq 'true' }
$xmlGame.boardgames.boardgame.boardgamemechanic
$xmlGame.boardgames.boardgame.boardgamecategory

# Hämta spel genom BGG XML API2
$wishlistUri = "https://boardgamegeek.com/xmlapi2/collection?username=psson73&wishlist=1"
[xml]$xmlWishlist = Invoke-WebRequest -Uri $wishlistUri

$xmlWishlist.items.item | ForEach-Object { $_.status.wishlistpriority }

# Wishlist, status 3 och högre
# Observera användningen av calculated properties
$highlist = $xmlWishlist.items.item | Select-Object -Property @{ Name = 'gamename' ; Expression = { $_.name.InnerXML } },objectid,@{ Name = 'wprio' ; Expression = { $_.status.wishlistpriority } } | Where-Object { $_.wprio -le '3' } | Sort-Object -Property wprio,gamename
$highlist

