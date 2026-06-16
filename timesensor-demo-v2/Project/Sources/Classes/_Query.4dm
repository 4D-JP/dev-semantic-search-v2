property query : Text
property messages : Collection
property systemPrompt : Text
property userPromptTemplate : Text
property agent : cs:C1710._AgentQuery
property tools : Text

Class constructor
	
	//This.agent:=cs._AgentQuery.new("OpenAI"; "gpt-5.4")
	This:C1470.agent:=cs:C1710._AgentQuery.new()
	This:C1470.messages:=[]
	
Function stopSearch() : cs:C1710._Query
	
	This:C1470.agent.stopConversation()
	
	return This:C1470
	
Function search($query : Text; $clear : Boolean) : cs:C1710._Query
	
	var $userPrompt : Text
	PROCESS 4D TAGS:C816(This:C1470.userPromptTemplate; $userPrompt; {query: $query; language: "en"; version: "21-R2"})
	
	$clear:=(This:C1470.messages.length=0) || $clear
	
	If ($clear)
		This:C1470.messages:=[]
		This:C1470.messages.push({role: "system"; content: This:C1470.systemPrompt})
	End if 
	
	This:C1470.messages.push({role: "user"; content: $userPrompt})
	
	//no need to call worker, chat completion is asynchronous
	If ($clear)
		This:C1470.agent.startConversation(This:C1470.messages)
	Else 
		This:C1470.agent.continueConversation(This:C1470.messages)
	End if 
	
	return This:C1470
	
Function onLoad($event : Object) : cs:C1710._Query
	
	var $folder : 4D:C1709.Folder
	$folder:=Folder:C1567("/DATA/prompts/search")
	var $systemPrompt; $userPrompt : Text
	This:C1470.systemPrompt:=$folder.file("system.txt").getText()
	This:C1470.userPromptTemplate:=$folder.file("user.txt").getText()
	This:C1470.messages:=[]
	This:C1470.query:="what is the difference between HTTPRequest (class) and HTTP Request command?"
	
	return This:C1470
	
Function onClicked($event : Object) : cs:C1710._Query
	
	Case of 
		: ($event.objectName="search")
			
			If (OBJECT Get title:C1068(*; $event.objectName)="Search")
				OBJECT SET TITLE:C194(*; $event.objectName; "Stop")
				This:C1470.search(This:C1470.query; Macintosh option down:C545 || Macintosh command down:C546)
			Else 
				This:C1470.stopSearch()
			End if 
			
	End case 
	
	return This:C1470