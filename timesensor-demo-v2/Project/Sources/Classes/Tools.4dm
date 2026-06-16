property tools : Collection

shared singleton Class constructor
	
	var $tools : Collection
	$tools:=[]
	
	var $OpenAITool : cs:C1710.AIKit.OpenAITool
	
	$OpenAITool:=cs:C1710.AIKit.OpenAITool.new({\
		type: "function"; \
		function: {\
		name: "KnowledgeBase"; \
		description: "The KnowledgeBase tool returns information about the 4D language, IDE, design mode, and more."; \
		required: ["query"]; \
		parameters: {\
		type: "object"; \
		properties: {\
		version: {\
		type: "string"; \
		description: "The 4D version code to specify product version. Default: \"21-R2\"."; \
		enum: ["21"; "21-R2"; "latest"; "any"]}; \
		language: {\
		type: "string"; \
		description: "The 639-1 country code to specify documentation language. Default: \"en\"."; \
		enum: ["en"; "fr"; "es"; "pt"; "ja"]}; \
		query: {\
		type: "string"; \
		description: "The freestyle query text. Must not be empty."}\
		}}}})
	
	$tools.push($OpenAITool)
	
	This:C1470.tools:=$tools.copy(ck shared:K85:29)
	
Function KnowledgeBase($arguments : Object) : Object
	
	var $query : Text
	var $version : Text
	var $language : Text
	
	$query:=$arguments.query
	$version:=$arguments.version
	$language:=$arguments.language
	
	var $client : cs:C1710.AIKit.OpenAI
	$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
	var $model : Text
	$model:="bge-m3"
	var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
	$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
	var $batch : Object
	$batch:=$client.embeddings.create($query; $model; $params)
	If ($batch.success)
		var $vector : 4D:C1709.Vector
		$vector:=$batch.embedding.embedding
		var $queryParams : Object
		$queryParams:={queryPath: True:C214; queryPlan: True:C214}
		var $documents : cs:C1710.DocumentSelection
		$documents:=ds:C1482.Document.query("meta.version == :1"+\
			" and meta.language == :2"; $version; $language; $queryParams)
		var $comparison : Object
		var $threshold : Real
		For each ($threshold; [0.6; 0.58; 0.56; 0.54])
			$comparison:={vector: $vector; metric: mk cosine:K95:1; threshold: $threshold}
			$documents:=$documents.query("passages.embeddings > :1"; $comparison; $queryParams)
			If ($documents.length#0)
				break
			End if 
		End for each 
		return {text: $documents.passages.text}
	End if 
	
	return {text: "No matching results found."; \
		hint: "Do not retry this query. Summarise what you know or ask the user for clarification."}