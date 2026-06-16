//%attributes = {}
/*

update cosine similarity

*/

var $searches : cs:C1710.SearchSelection
$searches:=ds:C1482.Search.all()
var $search : cs:C1710.SearchEntity
For each ($search; $searches)
	$search.similarity:=$search.embeddings.cosineSimilarity($search.passage.embeddings)
	$search.save()
End for each 

var $stats:=["|Relevance|Min|Max|Average|"; "|:-:|-:|-:|-:|"]
var $count; $relevance : Integer
$count:=ds:C1482.Search.getCount()

For each ($relevance; [3; 2; 1; 0])
	$searches:=ds:C1482.Search.query("relevance ==:1"; $relevance)
	$stats.push(\
		"|`"+String:C10($relevance)+\
		"`|`"+String:C10($searches.min("similarity"); "#0.00")+\
		"`|`"+String:C10($searches.max("similarity"); "#0.00")+\
		"`|`"+String:C10($searches.average("similarity"); "#0.00")+"`")
End for each 

SET TEXT TO PASTEBOARD:C523($stats.join("\r"))

/*

original BAAI/BGE-M3

|Relevance|Min|Max|Average|
|:-:|-:|-:|-:|
|`3`|`0.33`|`0.83`|`0.63`
|`2`|`0.28`|`0.81`|`0.60`
|`1`|`0.31`|`0.82`|`0.57`
|`0`|`0.21`|`0.69`|`0.43`

- avg. spread: 0.25
- lv. 3 vs 2 is separated by 0.03
- lv. 3 vs 1 is separated by 0.03
- lv. 0 is separated at 0.43

after LoRA r1

|Relevance|Min|Max|Average|
|:-:|-:|-:|-:|
|`3`|`0.42`|`0.89`|`0.67`
|`2`|`0.23`|`0.85`|`0.63`
|`1`|`0.27`|`0.83`|`0.58`
|`0`|`0.05`|`0.70`|`0.31`

- avg. spread: 0.36 (+0.11) 👍🏻
- lv. 3 vs 2 is separated by 0.04 (+0.01) 👍🏻
- lv. 3 vs 1 is separated by 0.05 (+0.02) 👍🏻
- lv. 0 is separated at 0.31 (-0.09) 👍🏻

after LoRA r2

|Relevance|Min|Max|Average|
|:-:|-:|-:|-:|
|`3`| `0.23`|`0.84`|`0.63`
|`2`| `0.03`|`0.83`|`0.59`
|`1`| `0.02`|`0.78`|`0.52`
|`0`|`-0.12`|`0.60`|`0.18`

- avg. spread: 0.45 (+0.09) 👍🏻
- lv. 3 vs 2 is separated by 0.04
- lv. 3 vs 1 is separated by 0.05
- lv. 0 is separated at 0.31

after LoRA r3

|Relevance|Min|Max|Average|
|:-:|-:|-:|-:|
|`3`| `0.29`|`0.85`|`0.65`
|`2`| `0.03`|`0.83`|`0.61`
|`1`| `0.04`|`0.80`|`0.54`
|`0`|`-0.11`|`0.63`|`0.20`

- avg. spread: 0.45
- lv. 3 vs 2 is separated by 0.04
- lv. 3 vs 1 is separated by 0.11 (+0.06) 👍🏻
- lv. 0 is well separated at 0.20 (-0.11) 👍🏻

after LoRA r4

|Relevance|Min|Max|Average|
|:-:|-:|-:|-:|
|`3`| `0.31`|`0.84`|`0.64`
|`2`| `0.04`benchmark_v1|`0.82`|`0.60`
|`1`| `0.06`|`0.77`|`0.53`
|`0`|`-0.11`|`0.61`|`0.19`

- avg. spread: 0.45
- lv. 3 vs 2 is separated by 0.04
- lv. 3 vs 1 is separated by 0.11
- lv. 0 is well separated at 0.19 (-0.01) 👍🏻

*/