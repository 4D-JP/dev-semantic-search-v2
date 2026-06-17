//%attributes = {}
/*

export v1/batch endpoint batch request
used to generate training dataset

*/

var $provider : Text
$provider:="llama.cpp"

var $passages; $_passages : cs:C1710.PassageSelection
var $passage : cs:C1710.PassageEntity

var $langs : Collection
var $lang : Text

$langs:=["de"; "fr"; "en"]

For each ($lang; $langs)
	var $languagesFolder; $rootFolder; $langFolder : 4D:C1709.Folder
	$languagesFolder:=Folder:C1567("/DATA/LEMUR/languages/")
	$langFolder:=$languagesFolder.folder($lang)
	$rootFolder:=$langFolder.parent.parent
	
	var $train : 4D:C1709.File
	$train:=$langFolder.file("train.jsonl")
	ASSERT:C1129($train.exists)
	var $row : Text
	var $rows : Collection
	$rows:=Split string:C1554($train.getText("utf-8"; Document with LF:K24:22); "\n")
	var $json : Object
	$passages:=ds:C1482.Passage.newSelection()
	For each ($row; $rows)
		If ($row="")
			continue
		End if 
		$json:=JSON Parse:C1218($row; Is object:K8:27)
		var $fulls : cs:C1710.FullSelection
		$fulls:=ds:C1482.Full.query("meta.pdf_path == :1"; $json.pdf_path)
		ASSERT:C1129($fulls.length=1)
		For each ($passage; $fulls.passages.query("meta.provider == :1"; $provider))
			$passages.add($passage)
		End for each 
	End for each 
End for each 
//20389

For each ($passage; $passages)
	
	var $searches : cs:C1710.SearchSelection
	$searches:=$passage.vectors.query("meta.provider == :1"; $provider).search
	ASSERT:C1129($searches.length=1)
	
	var $search : cs:C1710.SearchEntity
	$search:=$searches.first()
	
	
	
	var $language; $text : Text
	$language:=$passage.document.meta.language
	$text:=$passage.text
	PROCESS 4D TAGS:C816($userPromptTemplate; $userPrompt; {text: $text; language: $language; n: 3})
	Case of 
		: ($provider="Anthropic")
			$json:={params: {}}
			$json.custom_id:="passage-"+String:C10($passage.getKey())
			$json.params.model:=$model
			$json.params.max_tokens:=1500
			$json.params.system:=$systemPrompt
			$json.params.messages:=[{role: "user"; content: $userPrompt}]
			$jsonl.requests.push($json)
		: ($provider="OpenAI")
			$json:={body: {}}
			$json.custom_id:="passage-"+String:C10($passage.getKey())
			$json.method:="POST"
			$json.url:="/v1/chat/completions"
			$json.body.model:=$model
			$json.body.max_completion_tokens:=1500
			$json.body.messages:=[\
				{role: "system"; content: $systemPrompt}; \
				{role: "user"; content: $userPrompt}]
			$jsonl.requests.push(JSON Stringify:C1217($json))
	End case 
End for each 

Case of 
	: ($provider="Anthropic")
		Folder:C1567(fk desktop folder:K87:19).file($provider+"-"+$model+"-batch-request.jsonl").setText(JSON Stringify:C1217($jsonl))
	: ($provider="OpenAI")
		Folder:C1567(fk desktop folder:K87:19).file($provider+"-"+$model+"-batch-request.jsonl").setText($jsonl.requests.join("\n"))
End case 