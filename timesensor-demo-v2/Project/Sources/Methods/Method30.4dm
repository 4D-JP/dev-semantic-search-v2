//%attributes = {}
$t100:=ds:C1482.TrainingSearch.all().slice(0; 100)
$pdrift:=$t100.query("positive == true").average("drift")
$ndrift:=$t100.query("positive == false").average("drift")
