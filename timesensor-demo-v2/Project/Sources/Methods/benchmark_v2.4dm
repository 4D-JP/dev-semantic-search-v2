//%attributes = {}
var $thresholds : Collection
$thresholds:=[0.54; 0.55; 0.56; 0.57]
//$thresholds:=[0.58;0.59; 0.6; 0.61]
var $count : Integer
$count:=300

var $stats : Collection
$stats:=["|Threshold|Positive|Negative|Gap|"; "|:-:|:-:|:-:|:-:|"]

var $threshold : Real
For each ($threshold; $thresholds)
	var $positiveMatch; $negativeMatch : Real
	$positiveMatch:=0
	$negativeMatch:=0
	
	var $searches : cs:C1710.SearchSelection
	$searches:=ds:C1482.Search.query("relevance == :1"; 3).slice(0; $count)
	var $search : cs:C1710.SearchEntity
	For each ($search; $searches)
		var $comparison : Object
		$comparison:={vector: $search.embeddings; metric: mk cosine:K95:1; threshold: $threshold}
		var $documents : cs:C1710.FullSelection
		$documents:=ds:C1482.Full.query("passages.embeddings > :1"; $comparison)
		If ($documents.passages.and($search.passage).length#0)
			$positiveMatch+=1
		End if 
	End for each 
	
	$searches:=ds:C1482.Search.query("relevance <= :1"; 1).slice(0; $count)
	For each ($search; $searches)
		$comparison:={vector: $search.embeddings; metric: mk cosine:K95:1; threshold: $threshold}
		$documents:=ds:C1482.Full.query("passages.embeddings > :1"; $comparison)
		If ($documents.passages.and($search.passage).length#0)
			$negativeMatch+=1
		End if 
	End for each 
	
	var $posRate; $negRate; $gap : Real
	$posRate:=$positiveMatch/$count
	$negRate:=$negativeMatch/$count
	$gap:=$posRate-$negRate
	
	$stats.push("|"+String:C10($threshold; "#0.00")+"| `"+String:C10($posRate; "#0.00")+"` | `"+String:C10($negRate; "#0.00")+"` | `"+String:C10($gap; "#0.00")+"`|")
End for each 

SET TEXT TO PASTEBOARD:C523($stats.join("\r"))

/*

original BGE M3

|Threshold|Positive|Negative|Gap|
|:-:|:-:|:-:|:-:|
|0.55| `0.94` | `0.41` | `0.52`|
|0.56| `0.91` | `0.38` | `0.53`|
|0.57| `0.87` | `0.32` | `0.54`|
|0.58| `0.84` | `0.28` | `0.56`|
|0.59| `0.81` | `0.26` | `0.55`|
|0.60| `0.76` | `0.22` | `0.54`|
|0.61| `0.69` | `0.18` | `0.50`|
|0.62| `0.64` | `0.14` | `0.49`|
|0.63| `0.60` | `0.11` | `0.49`|
|0.64| `0.52` | `0.08` | `0.44`|
|0.65| `0.44` | `0.06` | `0.38`|
|0.66| `0.37` | `0.05` | `0.32`|

after LoRA r1

|Threshold|Positive|Negative|Gap|
|:-:|:-:|:-:|:-:|
|0.54| `0.99` | `0.43` | `0.55`|
|0.55| `0.98` | `0.41` | `0.56`|
|0.56| `0.95` | `0.38` | `0.57`|
|0.57| `0.94` | `0.34` | `0.60`|
|0.58| `0.93` | `0.32` | `0.61`|
|0.59| `0.92` | `0.28` | `0.63`|
|0.60| `0.87` | `0.26` | `0.61`|
|0.61| `0.86` | `0.21` | `0.64`|

- no clear peak (positives and negatives decline at same rate)

after LoRA r2

|Threshold|Positive|Negative|Gap|
|:-:|:-:|:-:|:-:|
|0.54| `0.94` | `0.26` | `0.67`|
|0.55| `0.91` | `0.24` | `0.66`|
|0.56| `0.88` | `0.21` | `0.66`|
|0.57| `0.84` | `0.18` | `0.65`|
|0.58| `0.80` | `0.14` | `0.65`|
|0.59| `0.76` | `0.10` | `0.66`|
|0.60| `0.70` | `0.09` | `0.61`|
|0.61| `0.67` | `0.07` | `0.60`|

- no clear peak (positives and negatives decline at same rate)

after LoRA r3

|Threshold|Positive|Negative|Gap|
|:-:|:-:|:-:|:-:|
|0.54| `0.96` | `0.33` | `0.62`|
|0.55| `0.94` | `0.31` | `0.63`|
|0.56| `0.92` | `0.27` | `0.64`|
|0.57| `0.90` | `0.24` | `0.65`|
|0.58| `0.88` | `0.22` | `0.65`|
|0.59| `0.85` | `0.18` | `0.67`|<====gap peak!!
|0.55| `0.94` | `0.31` | `0.63`|
|0.60| `0.80` | `0.15` | `0.65`|
|0.61| `0.73` | `0.12` | `0.60`|

The cliff for positives is at 0.60→0.61 
where they drop from 0.80 to 0.73
that's the sharpest single-step drop in the table. 
Negatives are declining steadily 
throughout with no sharp cliff of their own.

The gap peaks at 0.59 with 0.67 — that's our decision boundary.
For $hardNegativeThreshold (r4) set 0.57
(Two steps below the gap peak)

- Positives still strong at 0.90
- Negatives at 0.24 — healthy pool for the reranker

after LoRA r4

|Threshold|Positive|Negative|Gap|
|:-:|:-:|:-:|:-:|
|0.54| `0.97` | `0.31` | `0.65`|
|0.55| `0.95` | `0.29` | `0.65`|
|0.56| `0.93` | `0.26` | `0.67`|
|0.57| `0.90` | `0.23` | `0.67`|
|0.58| `0.88` | `0.18` | `0.69`|<====gap peak!!
|0.59| `0.83` | `0.15` | `0.67`|
|0.60| `0.78` | `0.12` | `0.65`|
|0.61| `0.74` | `0.09` | `0.64`|

*/