Class extends _AgentQueries

Class constructor($baseURL : Text)
	
	Super:C1705()
	
	This:C1470.OpenAI:=cs:C1710.AIKit.OpenAI.new({baseURL: $baseURL})
	This:C1470.stream:=True:C214
	This:C1470.model:="default"