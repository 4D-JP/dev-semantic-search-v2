//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $provider : Text
$provider:="llama.cpp"

var $searches : cs:C1710.SearchSelection
$searches:=ds:C1482.Search.query("vectors.meta.provider == :1"; $provider)

$searches:=$searches.slice(0; 100)
var $threshold : Real
$threshold:=0.6

var $stats : Collection
$stats:=[]

var $search : cs:C1710.SearchEntity
For each ($search; $searches)
	var $queryParams : Object
	$queryParams:={queryPath: True:C214; queryPlan: True:C214}
	var $documents : cs:C1710.FullSelection
	var $comparison : Object
	var $passages : cs:C1710.PassageSelection
	$passages:=$search.vectors.query("meta.provider == :1"; $provider).passage
	ASSERT:C1129($passages.length=1)
	var $passage : cs:C1710.PassageEntity
	$passage:=$passages.first()
	var $embeddings : 4D:C1709.Vector
	$embeddings:=$search.vectors.query("meta.provider == :1"; $provider).first().embeddings
	$comparison:={vector: $embeddings; metric: mk cosine:K95:1; threshold: $threshold}
	$documents:=ds:C1482.Full.query("passages.meta.provider == :1 "+\
		" and meta.primary_language == :2 "+\
		" and passages.embeddings > :3"; $provider; $search.language; $comparison; $queryParams)
	var $matchPassages; $filteredPassages : cs:C1710.PassageSelection
	$matchPassages:=$documents.passages.and($passage)
	var $stat : Object
	$stat:={found: False:C215}
	If ($matchPassages.length#0)
		var $top_k : Integer
		$top_k:=10
		var $f : 4D:C1709.Function
		$f:=Formula:C1597(This:C1470.embeddings.cosineSimilarity($embeddings))
		$filteredPassages:=$documents.passages.orderByFormula($f; dk descending:K85:32).slice(0; $top_k)
		var $rank : Integer
		$rank:=$passage.indexOf($filteredPassages)
		If ($rank#-1)
			$stat.rank:=$rank+1
			$stat.found:=True:C214
		End if 
	End if 
	$stats.push($stat)
End for each 

var $rate; $avg : Real
$rate:=$stats.countValues(True:C214; "found")/$stats.length
$avg:=$stats.average("rank")

/*

sample 1000 queries

41.0% in top 10
avg. ranking 2.3829

sample 100 queries

36.0% in top 10
avg. ranking 2.750

*/