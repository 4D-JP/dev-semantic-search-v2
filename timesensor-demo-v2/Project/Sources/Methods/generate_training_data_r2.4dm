//%attributes = {"invisible":true}
//sequential vector query may display progress window
MESSAGES OFF:C175

ARRAY LONGINT:C221($pos; 0)
ARRAY LONGINT:C221($len; 0)

var $provider; $model : Text
$provider:="llama.cpp"
$model:="bge-m3-r1"

var $Rn : Text
$Rn:="r2"

var $folder : 4D:C1709.Folder
$folder:=Folder:C1567([""; "DATA"; "dataset"; $Rn].join("/"))
$folder.create()

var $rerankerFolder : 4D:C1709.Folder
$rerankerFolder:=$folder.folder("reranker")
$rerankerFolder.create()

var $reranker : Object
$reranker:=cs:C1710.Reranker.new()

//use the number folders to track progress and resume
var $batch; $count : Integer
$batch:=100
$count:=$rerankerFolder.folders().length

var $top_k : Integer
var $negativeThreshold; $positiveThreshold; $hardNegativeThreshold : Real

Case of 
	: ($Rn="r2")
		$hardNegativeThreshold:=0.45
		$top_k:=7
		$negativeThreshold:=0.5
		$positiveThreshold:=0.85
End case 

$passages:=ds:C1482.Passage.query("meta.provider == :1 and meta.model == :2"; $provider; $model)

//some queries are identical
var $hashes : Collection
$hashes:=ds:C1482.TrainingSearch.query("meta.provider == :1 and meta.newModel == :2"; $provider; $model).distinct("hash")
//58563,60684

While ($count*$batch<$hashes.length)
	var $subFolder : 4D:C1709.Folder
	$subFolder:=$rerankerFolder.folder(String:C10($count+1; "00000"))
	$subFolder.create()
	var $queryHashes : Collection
	$queryHashes:=$hashes.slice($count*$batch; ($count*$batch)+$batch)
	var $hash : Text
	For each ($hash; $queryHashes)
/*
find queries with a positive match
*/
		var $searches : cs:C1710.TrainingSearchSelection
		$searches:=ds:C1482.TrainingSearch.query("hash == :1 and positive == :1"; $hash; True:C214)
		If ($searches.length=0)
			continue
		End if 
		
		var $embeddings : Collection
		$embeddings:=$searches.embeddings
		var $positivePassages : cs:C1710.TrainingPassageSelection
		$positivePassages:=$searches.passage
		//document(s) to which the passage(s) belong
		var $documentIds; $positives; $negatives : Collection
		$documentIds:=$positivePassages.document.ID
		$positives:=[]
		$negatives:=[]
		//for debug purposes; not needed for training
		var $negative_relevance_scores : Collection
		$negative_relevance_scores:=[]
		If ($positivePassages.length=0)
			continue
		End if 
		var $positiveHashes; $negativeHashes : Collection
		$positiveHashes:=[]
		$negativeHashes:=[]
		var $positivePassage : cs:C1710.TrainingPassageEntity
		For each ($positivePassage; $positivePassages)
			If ($positiveHashes.indexOf($positivePassage.hash)=-1)
				$positiveHashes.push($positivePassage.hash)
				$positives.push($positivePassage.text)
			End if 
		End for each 
		var $search : cs:C1710.TrainingSearchEntity
		For each ($search; $searches)
			var $comparisonA:={vector: $search.passage.embeddings; metric: mk cosine:K95:1; threshold: $hardNegativeThreshold}
			var $comparisonB:={vector: $search.embeddings; metric: mk cosine:K95:1; threshold: $hardNegativeThreshold}
			var $negativePassages : cs:C1710.PassageSelection
/*
find negatives from passages
same provider, same model
exclude sibling passage from same document
exclude positive dup
exclude negative dup
*/
			$negativePassages:=$passages.query("embeddings > :1"+\
				"    and not(DocumentID in :2)"+\
				"    and not(hash in :3)"+\
				"    and not(hash in :4)"; \
				$comparisonA; \
				$documentIds; \
				$positiveHashes; \
				$negativeHashes)
			
			$negativePassages:=$negativePassages.or($passages.query("embeddings > :1"+\
				"    and not(DocumentID in :2)"+\
				"    and not(hash in :3)"+\
				"    and not(hash in :4)"; \
				$comparisonB; \
				$documentIds; \
				$positiveHashes; \
				$negativeHashes))
			
			If ($negativePassages.length=0)
				//no hard negatives
				continue
			End if 
			$f:=Formula:C1597(This:C1470.embeddings.cosineSimilarity($search.embeddings))
			$negativePassages:=$negativePassages.orderByFormula($f; dk descending:K85:32).slice(0; $top_k)
			var $text; $negativeHash : Collection
			$text:=$negativePassages.text
			$negativeHash:=$negativePassages.hash
			var $negativeEmbeddings : Collection
			$negativeEmbeddings:=$negativePassages.embeddings
			var $status : Object
			$status:=$reranker.rerank($search.text; $text)
			If ($status.success)
				var $result : Object
				For each ($result; $status.results)
					Case of 
						: ($result.relevance_score>$negativeThreshold)
							//prune false negatives
						Else 
							var $tooSimilar : Boolean
							$tooSimilar:=False:C215
							For each ($passage; $positivePassages)
								//deduplication against positives
								If ($passage.embeddings.cosineSimilarity($negativeEmbeddings[$result.index])>$positiveThreshold)
									$tooSimilar:=True:C214
									break
								End if 
							End for each 
							If (Not:C34($tooSimilar))
								
								If ($negativeHashes.indexOf($negativeHash[$result.index])=-1)
									$negativeHashes.push($negativeHash[$result.index])
									$negatives.push($text[$result.index])
									$negative_relevance_scores.push($result.relevance_score)
								End if 
								
							End if 
					End case 
				End for each 
			Else 
				continue
			End if 
		End for each 
		
		If ($negatives.length=0)
			//no hard negatives
			continue
		End if 
		
		var $jsonl : Object
		$jsonl:={}
		$jsonl.query:=$searches.first().text
		$jsonl.pos:=$positives
		$jsonl.neg:=$negatives
		$jsonl.relevance_score:=$negative_relevance_scores
		$jsonl.pos_hash:=$positiveHashes
		$jsonl.neg_hash:=$negativeHashes
		
		$subFolder.file($hash+".json").setText(JSON Stringify:C1217($jsonl))
	End for each 
	$count:=$rerankerFolder.folders().length
End while 