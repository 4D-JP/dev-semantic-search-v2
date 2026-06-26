//%attributes = {}
/*

add missing non-train passages for the new model
run once for each new model
run import_queries_bge_test first

*/

If (True:C214)
	var $fulls : cs:C1710.FullSelection
	var $full : cs:C1710.FullEntity
	var $languages : Collection
	$languages:=["de"; "fr"; "en"]
	$fulls:=ds:C1482.Full.query("meta.primary_language in :1"; $languages)
	var $provider; $model : Text
	$provider:="llama.cpp"
	$model:="bge-m3-r3"
/*
run this after switching to new LoRA merged model
find any documents that do not have passages in this new model
(train dataset are created during import) 
*/
	var $fullWithPassages; $fullWithoutPassages : cs:C1710.FullSelection
	$fullWithPassages:=$fulls.query("passages.meta.provider == :1 and passages.meta.model == :2"; $provider; $model)
	$fullWithoutPassages:=$fulls.minus($fullWithPassages)
/*
make sure 
Passage[test] are not duplicated 
note:
[train] passages are untagged in Passage
we have a copy in TrainingPassage
*/
	var $client : cs:C1710.AIKit.OpenAI
	$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
	var $document : cs:C1710.FullEntity
	For each ($document; $fullWithoutPassages)
		var $passages : cs:C1710.PassageSelection
		$passages:=$document.passages.query("meta.provider == :1 and meta.model == :2"; $provider; "bge-m3")
/*
create copy of corresponding passage here
*/
		var $passage : cs:C1710.PassageEntity
		For each ($passage; $passages)
			var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
			$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})
			var $batch : Object
			$batch:=$client.embeddings.create($passage.text; $model; $params)
			If ($batch.success)
				var $_passage : cs:C1710.PassageEntity
				$_passage:=ds:C1482.Passage.new()
				$_passage.document:=$passage.document
				$_passage.embeddings:=$batch.embedding.embedding
				$_passage.hash:=$passage.hash
				$_passage.text:=$passage.text
				$_passage.meta:={provider: $provider; model: $model}
				$_passage.save()
			End if 
		End for each 
	End for each 
End if 
