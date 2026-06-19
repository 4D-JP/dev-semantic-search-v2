//%attributes = {"invisible":true}
/*

update ds.Passage.embeddings
update ds.Search.vectors.embeddings
run this after switching models
update passage first!

*/

If (False:C215)
	var $client : cs:C1710.AIKit.OpenAI
	$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
	var $model : Text
	$model:="bge-m3"
	
	var $search : cs:C1710.SearchEntity
	For each ($search; ds:C1482.Search.query("vectors.meta.provider == :1"; "llama.cpp"))
		ASSERT:C1129($search.vectors.length=1)
		var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
		$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
		var $batch : Object
		var $passages : cs:C1710.PassageSelection
		$passages:=$search.vectors.passage
		$batch:=$client.embeddings.create($passages.text; $model; $params)
		If ($batch.success)
			var $embeddings : 4D:C1709.Vector
			$embeddings:=$batch.embeddings
			var $passage : cs:C1710.PassageEntity
			var $text : Text
			For each ($passage; $passages)
				$passage.embeddings:=$embeddings.shift().embedding
				$passage.save()
			End for each 
		End if 
/*
single-batch embeddings can be a little bit different 
from multi-batch embeddings generated originally
*/
		$batch:=$client.embeddings.create($search.text; $model; $params)
		If ($batch.success)
			var $vector : cs:C1710.VectorEntity
			$vector:=$search.vectors.first()
			$vector.embeddings:=$batch.embedding.embedding
			$vector.similarity:=$vector.passage.embeddings.cosineSimilarity($vector.embeddings)
			$vector.save()
		End if 
	End for each 
End if 