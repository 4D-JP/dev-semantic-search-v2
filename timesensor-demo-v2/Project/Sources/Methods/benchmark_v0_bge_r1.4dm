//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $provider; $model : Text
$provider:="OpenAI"
$model:="text-embedding-3-small"
//$provider:="llama.cpp"
//$model:="bge-m3"
$provider:="llama.cpp"
$model:="bge-m3-r2"

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
 7770
BGE M3
10353
*/

var $sampleSize : Integer
//$sampleSize:=$searches.length\10
//$searches:=$searches.slice(0; $sampleSize)

var $all : cs:C1710.PassageSelection
$all:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"+\
" and meta.type == :3"; $provider; $model; "@")

/*

OpenAI
{
  train: 30310
  test : 10665 
  null : 17335
} 40975

BGE M3
{
  train: 34894
  test : 11521 
  null : 24996
} 46415 

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

@full (test+train,10%)

      |BM@10   |NDCG@10 |
------|--------|--------|
OpenAI|0.727155|0.593400|
BGE M3|0.778743|0.590327|
r1    |0.845410|0.643336|
r2    |0.904347|0.716485|

@full (test+train,100%)
      |BM@10   |NDCG@10 |
------|--------|--------|
OpenAI|0.670527|0.528276|
BGE M3|0.746933|0.556364|
r1    |0.818603|0.620830|
r2    |0.870375|0.689861|

*/