property document : cs:C1710.DocumentEntity
property documents : cs:C1710.DocumentSelection
property threshold : Real
property relevance : Integer
property query : Text
property vector : 4D:C1709.Vector
property duration : Real
property _query : cs:C1710.SearchEntity
property _defaultThreshold : Real

Class constructor
	
	Case of 
		: (File:C1566(Data file:C490; fk platform path:K87:2).name="original-bge-m3-data")
			This:C1470._defaultThreshold:=0.6
		: (File:C1566(Data file:C490; fk platform path:K87:2).name="finetuned-r1-bge-m3-data")
			This:C1470._defaultThreshold:=0.6
		: (File:C1566(Data file:C490; fk platform path:K87:2).name="finetuned-r2-bge-m3-data")
			This:C1470._defaultThreshold:=0.59
		Else 
			This:C1470._defaultThreshold:=0.6
	End case 
	
	This:C1470.threshold:=This:C1470._defaultThreshold
	This:C1470.relevance:=3
	
Function onLoad($event : Object) : cs:C1710._Test
	
	return This:C1470
	
Function onDoubleClicked($event : Object) : cs:C1710._Test
	
	Case of 
		: ($event.objectName="documents")
			If (Form:C1466.documents.item#Null:C1517)
				OPEN URL:C673(This:C1470.documents.item.file.platformPath)
			End if 
		: ($event.objectName="threshold")
			If (0.6#This:C1470.threshold)
				This:C1470.threshold:=0.6
				This:C1470.search()
			End if 
	End case 
	
	return This:C1470
	
Function onClicked($event : Object) : cs:C1710._Test
	
	If ($event.objectName="btn.rel.@")
		var $relevance : Integer
		ARRAY LONGINT:C221($pos; 0)
		ARRAY LONGINT:C221($len; 0)
		If (Match regex:C1019("\\.(\\d)"; $event.objectName; 1; $pos; $len))
			This:C1470.relevance:=Num:C11(Substring:C12($event.objectName; $pos{1}; $len{1}))
		End if 
		This:C1470.changeDocument().search()
	End if 
	
	return This:C1470
	
Function changeDocument() : cs:C1710._Test
	
	var $searches : cs:C1710.SearchSelection
	$searches:=ds:C1482.Search.query("relevance == :1"; This:C1470.relevance)
	This:C1470._query:=$searches.at(Random:C100%$searches.length)
	Form:C1466.query:=This:C1470._query.text
	If (This:C1470.relevance>1)
		This:C1470.document:=This:C1470._query.passage.document
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
	var $documents : cs:C1710.DocumentSelection
	$documents:=ds:C1482.Document.query("meta.version == :1"+\
		" and meta.language in :2"; "21-R2"; ["en"]; $queryParams)
	var $comparison : Object
	$comparison:={vector: $params.vector; metric: mk cosine:K95:1; threshold: $params.threshold}
	$documents:=$documents.query("passages.embeddings > :1"; $comparison; $queryParams)
	var $duration : Real
	$duration:=Abs:C99(Milliseconds:C459-$start)/1000
	CALL FORM:C1391($params.window; $params.formula; {documents: $documents; duration: $duration})
	