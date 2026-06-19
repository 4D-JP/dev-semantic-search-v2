//%attributes = {}
/*

add missing test passages and the rest of documents

*/

var $fulls : cs:C1710.FullSelection
var $full : cs:C1710.FullEntity
var $languages : Collection
$languages:=["de"; "fr"; "en"]
$fulls:=ds:C1482.Full.query("meta.primary_language in :1"; $languages)
//3380

var $provider : Text
$provider:="llama.cpp"

var $model : Text
$model:="bge-m3-r1"

//227
var $fullWithPassages; $fullWithoutPassages : cs:C1710.FullSelection
$fullWithPassages:=$fulls.query("passages.meta.provider == :1 and passages.meta.model == :2"; $provider; $model)
//3153
$fullWithoutPassages:=$fulls.minus($fullWithPassages)

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

