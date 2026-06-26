//%attributes = {}
//$models:=ds.Vector.all().distinct("meta.model")
//["bge-m3","bge-m3-r1","text-embedding-3-small"]

$searches:=ds:C1482.Vector.query("meta.model == :1"; "bge-m3-r1").search
/*
20706
20706
15540
*/