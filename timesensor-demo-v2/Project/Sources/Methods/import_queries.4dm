//%attributes = {}
var $LLM : cs:C1710.RemoteLLM
$LLM:=cs:C1710.RemoteLLM.new("OpenAI")

var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: $LLM.baseURL; apiKey: $LLM.apiKey})

var $model : Text
$model:="text-embedding-3-small"

var $file : 4D:C1709.File
$file:=Folder:C1567("/DATA/synthetic queries/").file("OpenAI-gpt-5.4-batch-response.jsonl")

var $jsonl : Collection
$jsonl:=Split string:C1554($file.getText("utf-8"; Document with LF:K24:22); "\n")
var $line : Text
For each ($line; $jsonl)
	var $json : Object
	$json:=Try(JSON Parse:C1218($line; Is object:K8:27))
	If ($json=Null:C1517)
		continue
	End if 
	var $id : Text
	$id:=Delete string:C232($json.custom_id; 1; Position:C15("-"; $json.custom_id))
	var $passage : cs:C1710.PassageEntity
	$passage:=ds:C1482.Passage.get(Num:C11($id))
	If ($passage=Null:C1517)
		continue
	End if 
	ARRAY LONGINT:C221($pos; 0)
	ARRAY LONGINT:C221($len; 0)
	var $type; $content : Text
	Case of 
		: ($json.response#Null:C1517)
			$type:="OpenAI"
			$content:=$json.response.body.choices.first().message.content
		: ($json.result#Null:C1517)
			If ($json.result.type="errored")
				continue
			End if 
			$type:="Anthropic"
			$content:=$json.result.message.content.first().text
		Else 
			$content:=""
	End case 
	If ($content="")
		continue
	End if 
	If (Match regex:C1019("```json(?msi)(.+)```$"; $content; 1; $pos; $len))
		$content:=Substring:C12($content; $pos{1}; $len{1})
	End if 
	var $results : Collection
	$results:=Try(JSON Parse:C1218($content; Is collection:K8:32))
	If ($results=Null:C1517)
		continue
	End if 
	
	var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
	$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})
	
	var $batch : Object
	var $search : cs:C1710.SearchEntity
	var $result : Object
	For each ($result; $results)
		$batch:=$client.embeddings.create([$result.positive_query; $result.hard_negative]; $model; $params)
		If ($batch.success)
			var $text : Text
			$text:=$result.positive_query
			$search:=ds:C1482.Search.new()
			$search.language:=$result.query_language
			$search.positive:=True:C214
			$search.text:=$text
			$search.hash:=Generate digest:C1147($text; SHA1 digest:K66:2)
			$search.passage:=$passage
			$search.embeddings:=$batch.embeddings[0].embedding
			$search.similarity:=$search.embeddings.cosineSimilarity($search.passage.embeddings)
			$search.meta:={model: "gpt-5.4"; provider: "OpenAI"}
			$search.save()
			
			$text:=$result.hard_negative
			$search:=ds:C1482.Search.new()
			$search.language:=$result.query_language
			$search.positive:=False:C215
			$search.text:=$text
			$search.hash:=Generate digest:C1147($text; SHA1 digest:K66:2)
			$search.passage:=$passage
			$search.embeddings:=$batch.embeddings[1].embedding
			$search.similarity:=$search.embeddings.cosineSimilarity($search.passage.embeddings)
			$search.meta:={model: "gpt-5.4"; provider: "OpenAI"}
			$search.save()
		End if 
	End for each 
End for each 
