//%attributes = {}
/*
where we find hard negatives
*/
$samples:=ds:C1482.TrainingSearch.query("newSimilarity > :1 and similarity < :2 and similarity > :3"; 0.6; 0.5; 0.1)
/*
where we want the data to be
*/
//$samples:=ds.TrainingSearch.query("newSimilarity > :1 and similarity > :2"; 0.6; 0.5)

$drifts:=$samples.drift.orderBy(ck descending:K85:8)

SET TEXT TO PASTEBOARD:C523(JSON Stringify:C1217($drifts; *))