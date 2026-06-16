//%attributes = {}
/*

update ds.Search.all().embeddings
run this after switching models

*/
var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $model : Text
$model:="bge-m3"
var $search : cs:C1710.SearchEntity
For each ($search; ds:C1482.Search.all())
	var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
	$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
	var $batch : Object
	$batch:=$client.embeddings.create($search.text; $model; $params)
	If ($batch.success)
		var $embeddings : Collection
		$search.embeddings:=$batch.embedding.embedding
		$search.save()
	End if 
End for each 
