//%attributes = {}
var $train : cs:C1710.PassageSelection
$train:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"+\
" and meta.type in :3"; "llama.cpp"; "bge-m3"; ["test"; "train"])

//["bge-m3","bge-m3-r6","text-embedding-3-small"]
$v_r6:=ds:C1482.Vector.all().distinct("meta.model")
//vectors are all updated

//["bge-m3","bge-m3-r5","bge-m3-r6","text-embedding-3-small"]
$p_r6:=ds:C1482.Passage.all().distinct("meta.model")





("meta.provider == :1"+\
" and meta.model == :2"+\
" and meta.type in :3"; "llama.cpp"; "bge-m3-r6"; ["test"; "train"])



$v_r6:=ds:C1482.Vector.query("meta.provider == :1"+\
" and meta.model == :2"+\
" and meta.type in :3"; "llama.cpp"; "bge-m3-r6"; ["test"; "train"])
//only 5320


For each ($passage; $train)
	$passages:=ds:C1482.Passage.query("hash == :1"+\
		" and meta.model == :2"+\
		" and document.ID == :3"; $passage.hash; "bge-m3-r6"; $passage.DocumentID)
	//ASSERT($passages.length=1)
	For each ($_passage; $passages)
		$_passage.meta.type:=$passage.meta.type
		$_passage.save()
	End for each 
End for each 
