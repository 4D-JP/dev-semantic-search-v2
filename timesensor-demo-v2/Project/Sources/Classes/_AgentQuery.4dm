property model : Text
property passage : Integer
property provider : Text
property tools : cs:C1710.Tools
property tool_calls : Collection
property content : Text
property messages : Collection
property conversation : Text
property queries : Collection
property shouldAbort : Boolean

Class extends _Agent

Class constructor($provider : Text; $model : Text)
	
	Super:C1705()
	
	This:C1470.stream:=True:C214
	
	If ($provider="")
		This:C1470.OpenAI:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.chatCompletion)})
		This:C1470.model:="default"
		This:C1470.provider:="llama.cpp"
	Else 
		var $OpenAI : cs:C1710.RemoteLLM
		$OpenAI:=cs:C1710.RemoteLLM.new($provider)
		var $baseURL; $apiKey : Text
		$baseURL:=$OpenAI.endpoint
		$apiKey:=$OpenAI.getAccessToken($provider)
		This:C1470.model:=$model
		This:C1470.provider:=$provider
		This:C1470.OpenAI:=cs:C1710.AIKit.OpenAI.new({baseURL: $baseURL; apiKey: $apiKey})
	End if 
	
	This:C1470.tools:=cs:C1710.Tools.new()
	
Function continueConversation($messages : Collection) : cs:C1710.AIKit.OpenAIChatCompletionsResult
	
	This:C1470.messages:=$messages
	This:C1470.content:=""
	This:C1470.reasoning_content:=""
	This:C1470.tool_calls:=[]
	This:C1470.shouldAbort:=False:C215
	
	If (This:C1470.conversation#"")
		This:C1470.conversation+="\r"
	End if 
	
	var $ChatCompletionsParameters : cs:C1710.AIKit.OpenAIChatCompletionsParameters
	$ChatCompletionsParameters:=cs:C1710.AIKit.OpenAIChatCompletionsParameters.new(This:C1470)
	$ChatCompletionsParameters.tool_choice:="auto"
	$ChatCompletionsParameters.model:=This:C1470.model
	$ChatCompletionsParameters.stream:=This:C1470.stream
	$ChatCompletionsParameters.formula:=This:C1470.onEventStream
	$ChatCompletionsParameters.tools:=This:C1470.tools.tools
	
	var $ChatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult
	$ChatCompletionsResult:=This:C1470.OpenAI.chat.completions.create($messages; $ChatCompletionsParameters)
	
	return $ChatCompletionsResult
	
Function startConversation($messages : Collection; $onResponse : 4D:C1709.Function) : cs:C1710.AIKit.OpenAIChatCompletionsResult
	
	If (OB Instance of:C1731($onResponse; 4D:C1709.Function))
		This:C1470._onResponse:=$onResponse
	Else 
		This:C1470._onResponse:=Null:C1517
	End if 
	
	This:C1470.conversation:=""
	This:C1470.queries:=[]
	
	OBJECT SET VALUE:C1742("tools"; "")
	OBJECT SET VALUE:C1742("text"; This:C1470.conversation)
	WA EXECUTE JAVASCRIPT FUNCTION:C1043(*; "html"; "renderMarkdown"; *; This:C1470.conversation)
	
	return This:C1470.clearConversation().continueConversation($messages)
	
Function onCompletion($chatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult)
	
	var $tools : cs:C1710.Tools
	$tools:=This:C1470.tools
	
	Case of 
		: ($ChatCompletionsResult.choice=Null:C1517)
			//"text" already contains error message
			OBJECT SET TITLE:C194(*; "search"; "Search")
		: ($ChatCompletionsResult.choice.finish_reason="length")
			var $stopMessage : Text
			$stopMessage:="too many tokens!"
			OBJECT SET VALUE:C1742("text"; $stopMessage)
			OBJECT SET TITLE:C194(*; "search"; "Search")
		: ($ChatCompletionsResult.choice.finish_reason="stop")
			If (This:C1470.content="")
				$stopMessage:="server stopped generating!"
				OBJECT SET VALUE:C1742("text"; $stopMessage)
			Else 
				This:C1470.messages.push({role: "assistant"; content: This:C1470.content})
				OBJECT SET VALUE:C1742("text"; This:C1470.conversation)
				WA EXECUTE JAVASCRIPT FUNCTION:C1043(*; "html"; "renderMarkdown"; *; This:C1470.conversation)
			End if 
			OBJECT SET TITLE:C194(*; "search"; "Search")
		: ($ChatCompletionsResult.choice.finish_reason="tool_calls")
			var $messages : Collection
			$messages:=This:C1470.messages
			//tool_call, without content
			$messages.push({role: "assistant"; content: Null:C1517; tool_calls: This:C1470.tool_calls})
			var $tool_call : Object
			For each ($tool_call; This:C1470.tool_calls)
				If (Not:C34(OB Instance of:C1731(This:C1470.tools[$tool_call.function.name]; 4D:C1709.Function)))
					continue
				End if 
				var $tool : Object
				$tool:=OB Copy:C1225($tool_call)  //tool_call, with content
				var $arguments : Object
				$arguments:=Try(JSON Parse:C1218($tool_call.function.arguments; Is object:K8:27))
				If ($arguments=Null:C1517)
					continue
				End if 
				$tool.content:=This:C1470.tools[$tool_call.function.name].call(This:C1470; $arguments)
				$messages.push({\
					role: "tool"; \
					tool_call_id: $tool.id; \
					name: $tool.function.name; \
					content: JSON Stringify:C1217($tool.content)})
				This:C1470.queries.push($arguments.query)
			End for each 
			This:C1470.continueConversation($messages)
			OBJECT SET VALUE:C1742("tools"; This:C1470.queries.join(","))
	End case 
	
	If (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
		This:C1470._onResponse.call(This:C1470; $chatCompletionsResult)
	End if 
	
Function stopConversation()
	
	This:C1470.shouldAbort:=True:C214
	
Function onEventStream($chatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult)
	
	If (This:C1470.shouldAbort) && (Not:C34($chatCompletionsResult.terminated))
		$chatCompletionsResult.request.terminate()
		return 
	End if 
	
	If ($chatCompletionsResult.success)
		If ($chatCompletionsResult.terminated)
			//complete result
			If ($chatCompletionsResult.choice#Null:C1517)
				If ($chatCompletionsResult.choice.message=Null:C1517)
					//streaming, content already captured 
				Else 
					//not streaming, get content here
					If ($chatCompletionsResult.choice.message.content#Null:C1517)
						This:C1470.conversation+=$chatCompletionsResult.choice.message.content
					End if 
				End if 
			Else 
				
			End if 
			This:C1470.onCompletion($chatCompletionsResult)
		Else 
			//partial result
			var $end : Integer
			If ($ChatCompletionsResult.choice.delta.text#Null:C1517)
				This:C1470.content+=$ChatCompletionsResult.choice.delta.text
				This:C1470.conversation+=$ChatCompletionsResult.choice.delta.text
				var $md : Text
				$md:=Replace string:C233(This:C1470.conversation; "\r"; "\r\n"; *)
				WA EXECUTE JAVASCRIPT FUNCTION:C1043(*; "html"; "renderMarkdown"; *; $md)
			End if 
			If ($ChatCompletionsResult.choice.delta["reasoning_content"]#Null:C1517)
				This:C1470.reasoning_content+=$ChatCompletionsResult.choice.delta["reasoning_content"]
				$end:=Length:C16(This:C1470.reasoning_content)+1
				OBJECT SET VALUE:C1742("text"; This:C1470.reasoning_content)
			End if 
			If ($ChatCompletionsResult.choice.delta.tool_calls#Null:C1517)
				var $tool_call : Object
				For each ($tool_call; $ChatCompletionsResult.choice.delta.tool_calls)
					var $tool : Object
					$tool:=This:C1470.tool_calls.query("index == :1"; $tool_call.index).first()
					If ($tool=Null:C1517)
						$tool:=OB Copy:C1225($tool_call)
						This:C1470.tool_calls.push($tool)
					Else 
						$tool.function.arguments+=$tool_call.function.arguments
					End if 
				End for each 
			End if 
		End if 
	Else 
		If ($chatCompletionsResult.terminated)
			var $errorMessage : Text
			$errorMessage:=$chatCompletionsResult.errors.extract("message").join("\r")
			OBJECT SET VALUE:C1742("text"; $errorMessage)
			This:C1470.onCompletion($chatCompletionsResult)
		End if 
	End if 
	