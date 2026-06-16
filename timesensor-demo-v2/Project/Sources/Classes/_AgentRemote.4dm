property provider : Text

Class extends _AgentQueries

Class constructor($provider : Text; $model : Text)
	
	Super:C1705()
	
	var $OpenAI : cs:C1710.RemoteLLM
	$OpenAI:=cs:C1710.RemoteLLM.new($provider)
	var $baseURL; $apiKey : Text
	$baseURL:=$OpenAI.endpoint
	$apiKey:=$OpenAI.getAccessToken($provider)
	This:C1470.stream:=False:C215
	This:C1470.model:=$model
	This:C1470.provider:=$provider
	This:C1470.OpenAI:=cs:C1710.AIKit.OpenAI.new({baseURL: $baseURL; apiKey: $apiKey})