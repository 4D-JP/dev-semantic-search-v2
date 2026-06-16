property client : cs:C1710.AIKit.Reranker
property VARFolder : 4D:C1709.Folder

Class constructor
	
	This:C1470.client:=cs:C1710.AIKit.Reranker.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.reranker)+"/v1"})
	
Function rerank($query; $documents : Collection) : Object
	
	var $parameters : cs:C1710.AIKit.RerankerParameters
	$parameters:=cs:C1710.AIKit.RerankerParameters.new({\
		model: "default"; \
		top_n: \
		$documents.length})
	
	var $q:=cs:C1710.AIKit.RerankerQuery.new({query: $query; documents: $documents})
	var $status:=This:C1470.client.rerank.create($q; $parameters)
	
	return $status