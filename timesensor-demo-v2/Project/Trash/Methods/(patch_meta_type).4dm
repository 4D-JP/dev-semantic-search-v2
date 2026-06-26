//%attributes = {}
var $file : 4D:C1709.File
//$file:=Folder("/DATA/synthetic queries/BGE").file("OpenAI-gpt-5.4-batch-response.jsonl")
$file:=Folder:C1567("/DATA/training queries").file("OpenAI-gpt-5.4-batch-response.jsonl")

var $jsonl : Collection
$jsonl:=Split string:C1554($file.getText("utf-8"; Document with LF:K24:22); "\n")
var $line : Text
For each ($line; $jsonl)
	var $json : Object
	$json:=Try(JSON Parse:C1218($line; Is object:K8:27))
	If ($json=Null:C1517)
		continue
	End if 
	var $id : Text
	$id:=Delete string:C232($json.custom_id; 1; Position:C15("-"; $json.custom_id))
	var $passage : cs:C1710.PassageEntity
	$passage:=ds:C1482.Passage.get(Num:C11($id))
	If ($passage=Null:C1517)
		continue
	End if 
	$hash:=$passage.hash
	$passages:=ds:C1482.Passage.query("hash == :1 and meta.model == :2"; $hash; "bge-m3-r3")
	For each ($_passage; $passages)
		//$_passage.meta.type:="test"
		$_passage.meta.type:="train"
		$_passage.save()
	End for each 
End for each 
