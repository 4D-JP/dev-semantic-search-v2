property model : Text
property passage : Integer

Class extends _Agent

Class constructor()
	
	Super:C1705()
	
Function continueConversation($messages : Collection) : cs:C1710.AIKit.OpenAIChatCompletionsResult
	
	This:C1470.reasoning_content:=""
	
	If (This:C1470.ChatResult#"")
		This:C1470.ChatResult+="\r\r"
	End if 
	
	var $ChatCompletionsParameters : cs:C1710.AIKit.OpenAIChatCompletionsParameters
	$ChatCompletionsParameters:=cs:C1710.AIKit.OpenAIChatCompletionsParameters.new(This:C1470)
	$ChatCompletionsParameters.model:=This:C1470.model
	$ChatCompletionsParameters.stream:=This:C1470.stream
	$ChatCompletionsParameters.formula:=This:C1470.onEventStream
	
	var $response_format:={type: "json_schema"; json_schema: {}}
	$response_format.json_schema:={}
	$response_format.json_schema.name:="Pairs"
	$response_format.json_schema.strict:=True:C214
	$response_format.json_schema.schema:={}
	$response_format.json_schema.schema.type:="array"
	
	$response_format.json_schema.schema.items:={}
	$response_format.json_schema.schema.items.type:="object"
	$response_format.json_schema.schema.items.required:=["pair_id"; "passage_language"; "query_language"; "positive_query"; "hard_negative"]
	$response_format.json_schema.schema.items.additionalProperties:=False:C215
	$response_format.json_schema.schema.items.properties:={}
	
	$response_format.json_schema.schema.items.properties.pair_id:={}
	$response_format.json_schema.schema.items.properties.pair_id.type:="integer"
	
	$response_format.json_schema.schema.items.properties.passage_language:={}
	$response_format.json_schema.schema.items.properties.passage_language.type:="string"
	$response_format.json_schema.schema.items.properties.passage_language.enum:=["en"; "fr"; "de"]
	
	$response_format.json_schema.schema.items.properties.query_language:={}
	$response_format.json_schema.schema.items.properties.query_language.type:="string"
	$response_format.json_schema.schema.items.properties.query_language.enum:=["en"; "fr"; "de"]
	
	$response_format.json_schema.schema.items.properties.positive_query:={}
	$response_format.json_schema.schema.items.properties.positive_query.type:="string"
	
	$response_format.json_schema.schema.items.properties.hard_negative:={}
	$response_format.json_schema.schema.items.properties.hard_negative.type:="string"
	
	//$ChatCompletionsParameters.response_format:=$response_format
	
	var $ChatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult
	$ChatCompletionsResult:=This:C1470.OpenAI.chat.completions.create($messages; $ChatCompletionsParameters)
	
	return $ChatCompletionsResult
	
Function startConversation($messages : Collection; $onResponse : 4D:C1709.Function) : cs:C1710.AIKit.OpenAIChatCompletionsResult
	
	If (OB Instance of:C1731($onResponse; 4D:C1709.Function))
		This:C1470._onResponse:=$onResponse
	Else 
		This:C1470._onResponse:=Null:C1517
	End if 
	
	return This:C1470.clearConversation().continueConversation($messages)
	
Function onCompletion($chatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult)
	
	If (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
		This:C1470._onResponse.call(This:C1470; $chatCompletionsResult)
	End if 
	
Function onEventStream($chatCompletionsResult : cs:C1710.AIKit.OpenAIChatCompletionsResult)
	
	If ($chatCompletionsResult.success)
		If ($chatCompletionsResult.terminated)
			//complete result
			If ($chatCompletionsResult.choice#Null:C1517)
				If ($chatCompletionsResult.choice.message=Null:C1517)  //streaming
					$chatCompletionsResult:=JSON Parse:C1218(JSON Stringify:C1217($chatCompletionsResult))
					$chatCompletionsResult.choice.message:={role: "assistant"; content: This:C1470.ChatResult}
				Else   //not streaming
					If ($chatCompletionsResult.choice.message.content#Null:C1517)
						This:C1470.ChatResult+=$chatCompletionsResult.choice.message.content
					End if 
				End if 
			Else 
				
			End if 
			This:C1470.onCompletion($chatCompletionsResult)
		Else 
			//partial result
			If ($chatCompletionsResult.choice#Null:C1517)
				If ($chatCompletionsResult.choice.delta.text#"")
					
					If (This:C1470.reasoning_content#"")
						This:C1470.reasoning_content:=""
						This:C1470.ChatResult:=This:C1470.reasoning_content
					End if 
					This:C1470.ChatResult+=$chatCompletionsResult.choice.delta.text
				Else 
					If ($chatCompletionsResult.choice.delta["reasoning_content"]#Null:C1517)
						This:C1470.reasoning_content+=$chatCompletionsResult.choice.delta["reasoning_content"]
						This:C1470.ChatResult:=This:C1470.reasoning_content
					End if 
				End if 
			Else 
			End if 
		End if 
	Else 
		If ($chatCompletionsResult.terminated)
			This:C1470.ChatResult:=$chatCompletionsResult.errors.extract("message").join("\r")
			If (OB Instance of:C1731(This:C1470._onResponse; 4D:C1709.Function))
				This:C1470._onResponse.call(This:C1470; $chatCompletionsResult)
			End if 
		End if 
	End if 