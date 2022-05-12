<#
Exploring getting categories for games
#>

Import-Module -Name psson-BGGAPI -Force


<#
$gameID = '146021'  # Eldritch Horror
#$gameID = '70919'   # Takenoko

[hashtable]$myCategories = Get-BGGCategoriesForGame -GameID $gameID
$myCategories.Keys
#>


$challengeGameIDs = @('36218','164812','244522','2448','161417','50','113294','1927','2243','13223')
$challengeGameIDs


[hashtable]$myCats = $challengeGameIDs | Get-BGGNumCategoriesForGames -Verbose
$myCats.Keys | Measure-Object | Select-Object -ExpandProperty count
$myCats