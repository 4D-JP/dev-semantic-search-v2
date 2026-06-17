property document : cs:C1710.FullEntity
property documents : cs:C1710.FullSelection
property threshold : Real
property positive : Boolean
property query : Text
property vector : 4D:C1709.Vector
property duration : Real
property _query : cs:C1710.SearchEntity
property _defaultThreshold : Real
property _provider : Text
property _searches : cs:C1710.SearchSelection
property openai : Boolean
property bgem3 : Boolean
property bgem3r1 : Boolean

Class constructor
	
	This:C1470._defaultThreshold:=0.6
	This:C1470.threshold:=This:C1470._defaultThreshold
	This:C1470.positive:=False:C215
	
	This:C1470.setModel("OpenAI")
	
Function setModel($model : Text) : cs:C1710._Test
	
	Case of 
		: ($model="OpenAI")
			This:C1470.openai:=True:C214
			This:C1470.bgem3:=False:C215
			This:C1470.bgem3r1:=False:C215
			This:C1470._provider:="OpenAI"
			This:C1470._searches:=ds:C1482.Search.query("vectors.meta.provider == :1"; This:C1470._provider)
			
		: ($model="bge-m3")
			This:C1470.openai:=False:C215
			This:C1470.bgem3:=True:C214
			This:C1470.bgem3r1:=False:C215
			This:C1470._provider:="llama.cpp"
			This:C1470._searches:=ds:C1482.Search.query("vectors.meta.provider == :1"; This:C1470._provider)
			
		: ($model="bge-m3-r1")
			//This.openai:=False
			//This.bgem3:=False
			//This.bgem3r1:=True
			//This._provider:="llama.cpp"
			//This._searches:=ds.Search.query("vectors.meta.provider == :1"; This._provider)
	End case 
	
	This:C1470.documents:={col: Null:C1517; sel: Null:C1517; item: Null:C1517; pos: Null:C1517}
	This:C1470.document:=Null:C1517
	This:C1470.query:=""
	
	return This:C1470
	
Function onLoad($event : Object) : cs:C1710._Test
	
	OBJECT SET ENABLED:C1123(*; "rb.bgem3r1"; False:C215)
	
	return This:C1470
	
Function onDoubleClicked($event : Object) : cs:C1710._Test
	
	Case of 
		: ($event.objectName="documents")
			If (Form:C1466.documents.item#Null:C1517)
				OPEN URL:C673(This:C1470.documents.item.file.platformPath)
			End if 
		: ($event.objectName="threshold")
			If (This:C1470._defaultThreshold#This:C1470.threshold)
				This:C1470.threshold:=This:C1470._defaultThreshold
				This:C1470.search()
			End if 
	End case 
	
	return This:C1470
	
Function onClicked($event : Object) : cs:C1710._Test
	
	Case of 
		: ($event.objectName="rb.openai")
			This:C1470.setModel("OpenAI")
		: ($event.objectName="rb.bgem3")
			This:C1470.setModel("bge-m3")
		: ($event.objectName="rb.bgem3r1")
			This:C1470.setModel("bge-m3-r1")
		: ($event.objectName="btn.negative")
			This:C1470.positive:=False:C215
			This:C1470.changeDocument().search()
		: ($event.objectName="btn.positive")
			This:C1470.positive:=True:C214
			This:C1470.changeDocument().search()
	End case 
	
	return This:C1470
	
Function changeDocument() : cs:C1710._Test
	
	var $searches : cs:C1710.SearchSelection
	$searches:=This:C1470._searches.query("positive == :1"; This:C1470.positive)
	This:C1470._query:=$searches.at(Random:C100%$searches.length)
	Form:C1466.query:=This:C1470._query.text
	If (This:C1470.positive)
		var $vectors : cs:C1710.VectorSelection
		$vectors:=This:C1470._query.vectors.query("meta.provider == :1"; This:C1470._provider)
		ASSERT:C1129($vectors.length=1)
		var $documents : cs:C1710.FullSelection
		$documents:=$vectors.passage.document
		ASSERT:C1129($documents.length=1)
		This:C1470.document:=$documents.first()  //the document to match
	Else 
		This:C1470.document:=Null:C1517
	End if 
	
	return This:C1470
	
Function onDataChange($event : Object) : cs:C1710._Test
	
	Case of 
		: ($event.objectName="query")
			var $client : cs:C1710.AIKit.OpenAI
			$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
			var $model : Text
			$model:="bge-m3"
			var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
			$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new()
			var $batch : Object
			$batch:=$client.embeddings.create(Form:C1466.query; $model; $params)
			If ($batch.success)
				This:C1470.vector:=$batch.embedding.embedding
				This:C1470.search()
				GOTO OBJECT:C206(*; $event.objectName)
			End if 
		: ($event.objectName="rul.threshold")
			This:C1470.search()
	End case 
	
	return This:C1470
	
Function search() : cs:C1710._Test
	
	If (This:C1470._query=Null:C1517)
		return 
	End if 
	
	var $vectors : cs:C1710.VectorSelection
	$vectors:=This:C1470._query.vectors.query("meta.provider == :1"; This:C1470._provider)
	ASSERT:C1129($vectors.length=1)
	
	Form:C1466.vector:=$vectors.first().embeddings
	Form:C1466.duration:=Null:C1517
	Form:C1466.documents:=Null:C1517
	
	CALL WORKER:C1389(1; This:C1470._search; {\
		window: Current form window:C827; \
		formula: This:C1470.onSearch; \
		vector: This:C1470.vector; \
		provider: This:C1470._provider; \
		threshold: This:C1470.threshold})
	
	return This:C1470
	
Function onSearch($event : Object)
	
	Form:C1466.documents:={col: Null:C1517; sel: Null:C1517; item: Null:C1517; pos: Null:C1517}
	Form:C1466.documents.col:=$event.documents
	Form:C1466.duration:=$event.duration
	
Function _search($params : Object)
	
	var $start : Integer
	$start:=Milliseconds:C459
	var $queryParams : Object
	$queryParams:={queryPath: True:C214; queryPlan: True:C214}
	var $documents : cs:C1710.FullSelection
	var $comparison : Object
	$comparison:={vector: $params.vector; metric: mk cosine:K95:1; threshold: $params.threshold}
	$documents:=ds:C1482.Full.query("passages.meta.provider == :1 "+\
		" and meta.primary_language == :2 "+\
		" and passages.embeddings > :3"; $params.provider; "en"; $comparison; $queryParams)
	var $duration : Real
	$duration:=Abs:C99(Milliseconds:C459-$start)/1000
	CALL FORM:C1391($params.window; $params.formula; {documents: $documents; duration: $duration})
	