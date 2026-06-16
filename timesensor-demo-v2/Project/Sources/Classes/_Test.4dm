property document : cs:C1710.FullEntity
property documents : cs:C1710.FullSelection
property threshold : Real
property positive : Boolean
property query : Text
property vector : 4D:C1709.Vector
property duration : Real
property _query : cs:C1710.SearchEntity
property _defaultThreshold : Real

Class constructor
	
	This:C1470._defaultThreshold:=0.6
	This:C1470.threshold:=This:C1470._defaultThreshold
	This:C1470.positive:=False:C215
	
Function onLoad($event : Object) : cs:C1710._Test
	
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
	$searches:=ds:C1482.Search.query("positive == :1"; This:C1470.positive)
	This:C1470._query:=$searches.at(Random:C100%$searches.length)
	Form:C1466.query:=This:C1470._query.text
	If (This:C1470.positive)
		This:C1470.document:=This:C1470._query.passage.document  //the document to match
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
	
	Form:C1466.vector:=This:C1470._query.embeddings
	Form:C1466.duration:=Null:C1517
	Form:C1466.documents:=Null:C1517
	
	CALL WORKER:C1389(1; This:C1470._search; {\
		window: Current form window:C827; \
		formula: This:C1470.onSearch; \
		vector: This:C1470.vector; \
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
		" and passages.embeddings > :3"; "OpenAI"; "en"; $comparison; $queryParams)
	var $duration : Real
	$duration:=Abs:C99(Milliseconds:C459-$start)/1000
	CALL FORM:C1391($params.window; $params.formula; {documents: $documents; duration: $duration})
	