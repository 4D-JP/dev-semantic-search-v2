//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $provider; $model : Text
//$provider:="OpenAI"
//$model:="text-embedding-3-small"
//$provider:="llama.cpp"
//$model:="bge-m3"
$provider:="llama.cpp"
$model:="bge-m3-r6"

var $stats : Collection
$stats:=["|BM@10|NDCG@10"]
$stats.push("|-:|-:")

var $BM; $NDCG : Real
var $BMs; $NDCGs : Collection
$BM:=0
$BMs:=[]
$NDCG:=0
$NDCGs:=[]

var $log2 : Collection
$log2:=[1; 0.631; 0.5; 0.431; 0.387; 0.356; 0.333; 0.315; 0.302; 0.289]

var $searches : cs:C1710.SearchSelection
$searches:=ds:C1482.Search.query("positive ==:1"+\
" and vectors.meta.provider == :2"+\
" and vectors.meta.model == :3"; True:C214; $provider; $model)

/*
OpenAI
11346
BGE M3
15950
*/

var $sampleSize : Integer
$sampleSize:=$searches.length\10
$searches:=$searches.slice(0; $sampleSize)

var $all : cs:C1710.PassageSelection
$all:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"+\
" and meta.type == :3"; $provider; $model; "train")

/*
OpenAI
{
  train: 44310
  test : 14328 
  null : 17335
}

BGE M3
{
  train: 66122
  test : 17072 
  null : 24996 (neither train nor test)
} 108190 

BGE M3 r1
{
  train: 66122
  test : 17072 
  null : 24996 (neither train nor test)
} 108190

BGE M3 r6
{
  train: 66122 (53790)
  test : 17072
  null : 24993
} 108190

*/

var $search : cs:C1710.SearchEntity
For each ($search; $searches)
	var $vectors : cs:C1710.VectorSelection
	$vectors:=$search.vectors.query("meta.provider == :1 and meta.model == :2"; $provider; $model)
	ASSERT:C1129($vectors.length=1)
	//the embeddings for query
	var $embeddings : 4D:C1709.Vector
	$embeddings:=$vectors.first().embeddings
	//the passage that matches the query
	var $passages : cs:C1710.PassageSelection
	$passages:=$search.vectors.query("meta.provider == :1 and meta.model == :2"; $provider; $model).passage
	ASSERT:C1129($passages.length=1)
	var $match : cs:C1710.PassageEntity
	$match:=$passages.first()
	var $matchPassages; $filteredPassages : cs:C1710.PassageSelection
	var $f : 4D:C1709.Function
	$f:=Formula:C1597(This:C1470.embeddings.cosineSimilarity($embeddings))
	$filteredPassages:=$all.orderByFormula($f; dk descending:K85:32).slice(0; 10)
	var $rank : Integer
	$rank:=$filteredPassages.ID.indexOf($match.ID)
	If ($rank=-1)
		$BMs.push(0)
		$NDCGs.push(0)
	Else 
		$BMs.push(1)
		$NDCGs.push($log2[$rank])
	End if 
End for each 

$BM:=$BMs.average()
$NDCG:=$NDCGs.average()

$stats.push("|"+String:C10($BM; "0.000000")+"|"+String:C10($NDCG; "0.000000")+"|")

SET TEXT TO PASTEBOARD:C523($stats.join("\n"))

/*

@test

OpenAI|0.722222|0.586204|
M3    |0.781818|0.586923|
r6    |0.837617|0.628939|

|BM@10|NDCG@10
|-:|-:
|0.000000|0.000000|

------|--------|--------|
r1    |0.881504|0.663531|  symmetric rank loss
r5    |0.862068|0.628188| asymmetric rank loss
r2    |0.903448|0.728600| overfitting, see @full
r3    |0.776175|0.557011| overfitting, see @full

multiple negative symmetric rank loss 
risks hurting the model by producing noise in the reverse direction
the model may seem to perform on limit tasks
but its general ability to match sentence to sentence might be damaged.

@full (test+train)

OpenAI|0.665784|0.538284|
M3    |0.715987|0.534895|
r6    |0.770532|0.573282|
------|--------|--------|
r1    |0.811912|0.601433| representation collapse?
r5    |0.785579|0.563636|
r2    |0.728526|0.523571|  
r3    |0.678369|0.475100| 

sometimes there are no genuine signals
that makes a passage relevant to the query.

encoder-only embedding models (be-encoder)
can't be trained on semantic similarities that don't exist.

the remaining uncaught passages likely belong to that category.
i.e. embedding model alone will not reach 100% retrieval.

*/