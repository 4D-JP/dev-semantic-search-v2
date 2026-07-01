//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $client : cs:C1710.AIKit.OpenAI
$client:=cs:C1710.AIKit.OpenAI.new({baseURL: "http://127.0.0.1:"+String:C10(Storage:C1525.port.embeddings)+"/v1"})
var $params : cs:C1710.AIKit.OpenAIEmbeddingsParameters
$params:=cs:C1710.AIKit.OpenAIEmbeddingsParameters.new({dimensions: 1024})

var $provider; $model; $oldModel : Text
$provider:="llama.cpp"
$model:="bge-m3-r2"
$oldModel:="bge-m3-r1"

var $passages : cs:C1710.PassageSelection
$passages:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"; $provider; $oldModel)
//58563

var $batch : Object

var $i; $length : Integer
$i:=0
$length:=16
$_passages:=$passages.slice($i; $i+$length)
While ($_passages.length#0)
	$batch:=$client.embeddings.create($_passages.text; $model; $params)
	If ($batch.success)
		$embeddings:=$batch.embeddings
		For each ($passage; $_passages)
			$passage.meta.model:=$model
			$passage.embeddings:=$embeddings.shift().embedding
			$passage.save()
			For each ($vector; $passage.vectors)
				$vector.meta.model:=$model
				$vector.similarity:=$vector.embeddings.cosineSimilarity($passage.embeddings)
				$vector.save()
			End for each 
		End for each 
	End if 
	$i+=$length
	$_passages:=$passages.slice($i; $i+$length)
End while 