//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})

var $provider; $model; $oldModel : Text
$provider:="llama.cpp"
$model:="bge-m3-r6"
$oldModel:="bge-m3-r6"

$models:=ds:C1482.Vector.all().distinct("meta.model")
//["bge-m3","bge-m3-r5","text-embedding-3-small"]

var $searches : cs:C1710.SearchSelection
$searches:=ds:C1482.Search.query("vectors.meta.provider == :1"+\
" and vectors.meta.model == :2"; $provider; $oldModel)
//31900

var $batch : Object

var $i; $length : Integer
$i:=0
$length:=8

$_searches:=$searches.slice($i; $i+$length)
While ($_searches.length#0)
	$passages:=$_searches.vectors.passage
	$batch:=$client.embeddings.create($passages.text; $model; $params)
	If ($batch.success)
		$embeddings:=$batch.embeddings
		For each ($passage; $passages)
			$passage.meta.model:=$model
			$passage.embeddings:=$embeddings.shift().embedding
			//$passage.save()
		End for each 
	End if 
	$batch:=$client.embeddings.create($_searches.text; $model; $params)
	If ($batch.success)
		$embeddings:=$batch.embeddings
		For each ($vector; $_searches.vectors)
			$vector.meta.model:=$model
			$vector.embeddings:=$embeddings.shift().embedding
			$vector.similarity:=$vector.embeddings.cosineSimilarity($vector.passage.embeddings)
			//$vector.save()
		End for each 
	End if 
	$i+=$length
	$_searches:=$searches.slice($i; $i+$length)
End while 