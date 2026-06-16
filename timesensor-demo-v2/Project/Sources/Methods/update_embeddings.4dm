//%attributes = {}
/*

update ds.Document.all().embeddings
run this after switching models

*/
var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $model : Text
$model:="bge-m3"
var $document : cs:C1710.FullEntity
For each ($document; ds:C1482.Full.all())
	var $passages : cs:C1710.PassageSelection
	$passages:=$document.passages
	var $embeddings : Collection
	var $cosineSimilarity : Real
	var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
	$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
	var $batch : Object
	$batch:=$client.embeddings.create($passages.text; $model; $params)
	If ($batch.success)
		$embeddings:=$batch.embeddings
		var $passage : cs:C1710.PassageEntity
		var $text : Text
		For each ($passage; $passages)
			$passage.embeddings:=$embeddings.shift().embedding
			$passage.save()
		End for each 
	End if 
End for each 
