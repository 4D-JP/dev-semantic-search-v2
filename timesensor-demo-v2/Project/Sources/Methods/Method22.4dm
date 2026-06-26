//%attributes = {}
var $provider; $model : Text
$provider:="llama.cpp"
$model:="bge-m3-r7"

var $all : cs:C1710.VectorSelection
$all:=ds:C1482.Vector.query("meta.provider == :1"+\
" and meta.model == :2"; $provider; $model)

var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})

For each ($vector; $all)
	var $batch : Object
	$batch:=$client.embeddings.create($vector.search.text; $model; $params)
	If ($batch.success)
		$vector.embeddings:=$batch.embedding.embedding
		$vector.similarity:=$vector.embeddings.cosineSimilarity($vector.passage.embeddings)
		$vector.meta.model:=$model
		//$vector.save()
	End if 
End for each 