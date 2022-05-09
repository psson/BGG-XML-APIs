function Get-BGGCategoriesForGames {
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]$gameIDs
    )

    begin {
        $categories = @{}
    }

    process {
        $thingUri = "https://boardgamegeek.com/xmlapi2/thing?id=$gameID"
        [xml]$xmlThing = Invoke-WebRequest -Uri $thingUri

        $categoryLinks = $xmlThing | Select-Xml -XPath "//*[@type='boardgamecategory']"

        

        foreach ( $category in $categoryLinks.Node.value ) {
            try {
                #Write-host $category
                $categories.Add($category,'category')
            } catch [ArgumentException] {
                # Dublett
            } catch {
                Write-Error "Unexpected Error"
            }
        }
    }

    end {
        return $categories
    }
}





#$challengeGameIDs = @('36218','164812','244522','2448','161417','50','113294','1927','2243','13223')
$challengeGameIDs = @('36218','164812','244522','2448','161417','50','113294','1927','2243','13223')


$myCats = $challengeGameIDs | Get-BGGCategoriesForGame
$myCats.Keys | Measure-Object | Select-Object -ExpandProperty count

146021 | Get-BGGCategoriesForGame

$gameID = '146021'
$thingUri = "https://boardgamegeek.com/xmlapi2/thing?id=$gameID"
[xml]$xmlThing = Invoke-WebRequest -Uri $thingUri


$categoryLinks = $xmlThing | Select-Xml -XPath "//*[@type='boardgamecategory']"
#$categoryLinks.Node

foreach ( $category in $categoryLinks.Node.value ) {
    $category
}