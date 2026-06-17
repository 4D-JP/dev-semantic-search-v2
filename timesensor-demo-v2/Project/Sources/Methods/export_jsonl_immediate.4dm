//%attributes = {}
#DECLARE($chatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult)

/*

request LLM to generate query examples for training purposes 
v1/chat/completions

*/

If (Count parameters:C259=0)
	
	CALL WORKER:C1389(Current method name:C684; Current method name:C684; {})
	
Else 
	
	If (This:C1470=Null:C1517)
		
		var $agent : cs:C1710._AgentRemote
		$agent:=cs:C1710._AgentRemote.new("Claude"; "claude-sonnet-4-6")
		$agent:=cs:C1710._AgentRemote.new("OpenAI"; "gpt-5.4")
		
		var $folder : 4D:C1709.Folder
		$folder:=Folder:C1567("/PACKAGE/prompts/queries")
		ASSERT:C1129($folder.exists)
		
		var $systemPrompt; $userPrompt; $userPromptTemplate : Text
		$systemPrompt:=$folder.file("system.txt").getText()
		$userPromptTemplate:=$folder.file("user.txt").getText()
		
		var $passage : cs:C1710.PassageEntity
		$passage:=ds:C1482.Passage.all().first()
		
		If ($passage=Null:C1517)
			TRACE:C157
			return 
		End if 
		
		var $language; $text : Text
		$language:=$passage.document.meta.language
		$text:=$passage.text
		PROCESS 4D TAGS:C816($userPromptTemplate; $userPrompt; {text: $text; language: $language; n: 3})
		
		var $messages:=[]
		
		$messages.push({role: "system"; content: $systemPrompt})
		$messages.push({role: "user"; content: $userPrompt})
		
		$agent.passage:=$passage.getKey()
		$agent.startConversation($messages; Formula from string:C1601(Current method name:C684))
		
	Else 
		
		var $results : Collection
		$results:=Try(JSON Parse:C1218(This:C1470.ChatResult; Is collection:K8:32))
		
		If ($results#Null:C1517)
			$passage:=ds:C1482.Passage.get(This:C1470.passage)
			
			var $client : cs:C1710.AIKit.OpenAI
			$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
			var $model : Text
			$model:="bge-m3"
			var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
			$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
			var $batch : Object
			var $search : cs:C1710.SearchEntity
			var $result : Object
			For each ($result; $results)
				$batch:=$client.embeddings.create([$result.positive_query; $result.hard_negative]; $model; $params)
				If ($batch.success)
					
					$text:=$result.positive_query
					$search:=ds:C1482.Search.new()
					$search.language:=$result.query_language
					$search.positive:=True:C214
					$search.text:=$text
					$search.hash:=Generate digest:C1147($text; SHA1 digest:K66:2)
					//$search.passage:=$passage
					//$search.embeddings:=$batch.embeddings[0].embedding
					
					$text:=$result.hard_negative
					$search:=ds:C1482.Search.new()
					$search.language:=$result.query_language
					$search.positive:=False:C215
					$search.text:=$text
					$search.hash:=Generate digest:C1147($text; SHA1 digest:K66:2)
					//$search.passage:=$passage
					//$search.embeddings:=$batch.embeddings[1].embedding
					
				End if 
				
			End for each 
		End if 
	End if 
End if 