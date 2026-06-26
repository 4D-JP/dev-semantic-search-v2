//%attributes = {}
var $provider; $model : Text
$provider:="llama.cpp"
$model:="bge-m3-r7"

var $all : cs:C1710.PassageSelection
$all:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"; $provider; $model)

var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})

For each ($passage; $all)
	var $batch : Object
	$batch:=$client.embeddings.create($passage.text; $model; $params)
	If ($batch.success)
		$passage.embeddings:=$batch.embedding.embedding
		$passage.meta.model:=$model
		//$passage.save()
	End if 
End for each 