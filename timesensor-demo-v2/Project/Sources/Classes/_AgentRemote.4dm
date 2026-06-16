property provider : Text

Class extends _AgentQueries

Class constructor($provider : Text; $model : Text)
	
	Super:C1705()
	
	var $LLM : cs:C1710.RemoteLLM
	$LLM:=cs:C1710.RemoteLLM.new($provider)
	
	This:C1470.stream:=False:C215
	This:C1470.model:=$model
	This:C1470.provider:=$provider
	This:C1470.OpenAI:=cs:C1710.AIKit.OpenAI.new({baseURL: $LLM.baseURL; apiKey: $LLM.apiKey})