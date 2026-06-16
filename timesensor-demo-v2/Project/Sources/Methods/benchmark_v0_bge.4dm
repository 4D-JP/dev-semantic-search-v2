//%attributes = {"invisible":true}
$provider:="llama.cpp"

$s:=ds:C1482.Search.query("vectors.meta.provider == :1"; $provider)

$searches:=$s.slice(0; 100)
$threshold:=0.6

$stats:=[]

For each ($search; $searches)
	var $queryParams : Object
	$queryParams:={queryPath: True:C214; queryPlan: True:C214}
	var $documents : cs:C1710.FullSelection
	var $comparison : Object
	$passages:=$search.vectors.query("meta.provider == :1"; $provider).passage
	ASSERT:C1129($passages.length=1)
	$passage:=$passages.first()
	$embeddings:=$search.vectors.query("meta.provider == :1"; $provider).first().embeddings
	$comparison:={vector: $embeddings; metric: mk cosine:K95:1; threshold: $threshold}
	$documents:=ds:C1482.Full.query("passages.meta.provider == :1 "+\
		" and meta.primary_language == :2 "+\
		" and passages.embeddings > :3"; $provider; $search.language; $comparison; $queryParams)
	$r:=$documents.passages.and($passage)
	$stat:={found: False:C215}
	If ($r.length#0)
		$top_k:=10
		var $f : 4D:C1709.Function
		$f:=Formula:C1597(This:C1470.embeddings.cosineSimilarity($embeddings))
		$oo:=$documents.passages.orderByFormula($f; dk descending:K85:32).slice(0; $top_k)
		$rank:=$passage.indexOf($oo)
		If ($rank#-1)
			$stat.rank:=$rank+1
			$stat.found:=True:C214
		End if 
	End if 
	$stats.push($stat)
End for each 

$rate:=$stats.countValues(True:C214; "found")/$stats.length
$avg:=$stats.average("rank")

/*

sample 1000 queries

45.5% in top 10
avg. ranking 2.3208
this is the number to beat

*/