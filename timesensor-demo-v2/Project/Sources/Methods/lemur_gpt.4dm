//%attributes = {"invisible":true}
/*
OpenAI, text-embedding-3-small
go over all documents (ds.Full.all)
extract and create passages 
*/
If (False:C215)
	var $LLM : cs:C1710.RemoteLLM
	$LLM:=cs:C1710.RemoteLLM.new("OpenAI")
	
	var $client : cs:C1710.AIKit.OpenAI
	$client:=cs:C1710.AIKit.OpenAI.new({baseURL: $LLM.baseURL; apiKey: $LLM.apiKey})
	
	var $model : Text
	$model:="text-embedding-3-small"
	
	var $fulls : cs:C1710.FullSelection
	var $full : cs:C1710.FullEntity
	var $languages : Collection
	$languages:=["de"; "fr"; "en"]
	$fulls:=ds:C1482.Full.query("meta.primary_language in :1"; $languages)
	
	var $temporaryFolder : 4D:C1709.Folder
	$temporaryFolder:=Folder:C1567(Temporary folder:C486; fk platform path:K87:2)
	var $file : 4D:C1709.File
	
	For each ($full; $fulls)
		
		$file:=$temporaryFolder.file(Generate UUID:C1066)
		$file.setText($full.meta.text)
		
		var $task : Object
		$task:={file: $file; \
			text_as_tokens: False:C215; \
			tokens_length: 509; \
			overlap_ratio: 0.09; \
			unique_values_only: False:C215; \
			pooling_mode: Extract Pooling Mode Mean}
		var $extracted : Object
		$extracted:=Extract(Extract Document TXT; Extract Output Collection; $task)
		If ($extracted.success)
			
			var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
			$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})
			var $batch : Object
			$batch:=$client.embeddings.create($extracted.input; $model; $params)
			If ($batch.success)
				var $embeddings : Object
				$embeddings:=$batch.embeddings
				var $text : Text
				For each ($text; $extracted.input)
					var $passage : cs:C1710.PassageEntity
					$passage:=ds:C1482.Passage.new()
					$passage.document:=$full
					$passage.text:=$text
					$passage.hash:=Generate digest:C1147($text; SHA1 digest:K66:2)
					$passage.meta:={provider: "OpenAI"; model: $model}
					$passage.embeddings:=$embeddings.shift().embedding
					$passage.save()
				End for each 
			End if 
		End if 
	End for each 
End if 