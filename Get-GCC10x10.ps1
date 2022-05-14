[cmdletbinding()]
param (
    [string][ValidateSet('Normal','Hardcore')]$ChallengeMode
)

#Import-Module psson-BGGAPI -Force

#Användare
$bggUser='psson73'

# År
$year='2022'

# Medspelare
$reqPlayer='Patricia'

if ( $ChallengeMode -eq 'Normal') {
    # IDs för spelen som ska hämtas för Normal challenge
    $challengeGameIDs = @('36218','164812','244522','2448','161417','50','113294','1927','2243','13223')
} elseif ( $ChallengeMode -eq 'Hardcore') {
    # IDs för spelen som ska hämtas för Hardcore challenge
    $challengeGameIDs = @('146021','70919','244521','163412','199561','110327','68448','221107','148949','28143','185196')
}

# Hämta rad-datat till clipboard
Get-BGGChallengePlaysForEntry -bggUser $bggUser -gameIDs $challengeGameIDs -year $year -reqPlayer $reqPlayer -ListGames | clip  