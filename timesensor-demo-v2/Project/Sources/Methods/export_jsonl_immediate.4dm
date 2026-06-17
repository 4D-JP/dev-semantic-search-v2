//%attributes = {"invisible":true}
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
			
			var $model; $provider : Text
			$model:=This:C1470.model
			$provider:=This:C1470.provider
			
			//TODO: import GPT, import GME 
			//in practice, use Batch API
			
		End if 
	End if 
End if 