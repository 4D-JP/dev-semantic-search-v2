//%attributes = {}
//sequential vector query may display progress window
MESSAGES OFF:C175

var $Rn : Text
$Rn:="r7"

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

var $hardNegativeThreshold; \
$semanticAmbiguityCeiling; \
$semanticAmbiguityFloor; \
$positiveDriftCap : Real

Case of 
	: ($Rn="r7")
		//newEmbeddings
		$hardNegativeThreshold:=0.55  //Hard enough
		$semanticAmbiguityCeiling:=0.7  //Not a false negative
		//new vs old
		$positiveDriftCap:=0.19  //Not an Rn artifact
End case 

//some queries are identical
var $hashes : Collection
$hashes:=ds:C1482.TrainingSearch.query("meta.provider == :1"; "llama.cpp").distinct("hash")
//122020,122016 (4 are identical)

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
		
		//var $documentIds
		//document(s) to which the passage(s) belong
		$documentIds:=$positivePassages.document.ID
		
		//dedup
		var $positives; $negatives : Collection
		$positives:=[]
		$negatives:=[]
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
		
		var $negative_drifts:=[]
		var $old_similarities:=[]
		var $new_similarities:=[]
		
		var $search : cs:C1710.TrainingSearchEntity
		For each ($search; $searches)
			
			If ($search.passage.newEmbeddings=Null:C1517)
				continue
			End if 
			
			var $newComparison:={vector: $search.newEmbeddings; metric: mk cosine:K95:1; threshold: $hardNegativeThreshold}
			var $newComparisonCeiling:={vector: $search.newEmbeddings; metric: mk cosine:K95:1; threshold: $semanticAmbiguityCeiling}
			
			//TODO: we should import full-train to TrainingPassage
			
			var $negativePassages : cs:C1710.TrainingPassageSelection
			$negativePassages:=ds:C1482.TrainingPassage.query("newEmbeddings > :1"+\
				"    and newEmbeddings   < :2"+\
				"    and not(DocumentID in :3)"+\
				"    and not(hash in :4)"+\
				"    and not(hash in :5)"; \
				$newComparison; \
				$newComparisonCeiling; \
				$documentIds; \
				$positiveHashes; \
				$negativeHashes)
			
			If ($negativePassages.length=0)
				//no hard negatives
				continue
			End if 
			
			var $top_k : Integer
			$top_k:=5
			var $f : 4D:C1709.Function
			$f:=Formula:C1597(This:C1470.newEmbeddings.cosineSimilarity($search.newEmbeddings))
			$negativePassages:=$negativePassages.orderByFormula($f; dk descending:K85:32).slice(0; $top_k)
			
			var $negativePassage : cs:C1710.TrainingPassageEntity
			For each ($negativePassage; $negativePassages)
				
				$oldCos:=$negativePassage.embeddings.cosineSimilarity($search.embeddings)
				$newCos:=$negativePassage.newEmbeddings.cosineSimilarity($search.newEmbeddings)
				
				$drift:=$newCos-$oldCos
				
				Case of 
					: ($drift>0) && ($drift<$positiveDriftCap)
						//drift is small positive
					: ($drift<0)
						//drift is negative (R1 pushed it away — clean)
					Else 
						continue
				End case 
				
				$negativeHash:=$negativePassage.hash
				If ($negativeHashes.indexOf($negativeHash)=-1)
					$negativeHashes.push($negativeHash)
					$negatives.push($negativePassage.text)
					$negative_drifts.push($drift)
					$old_similarities.push($oldCos)
					$new_similarities.push($newCos)
				End if 
			End for each 
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
		$jsonl.drift:=$negative_drifts
		$jsonl.new_similarity:=$new_similarities
		$jsonl.old_similarity:=$old_similarities
		$jsonl.pos_hash:=$positiveHashes
		$jsonl.neg_hash:=$negativeHashes
		
		$subFolder.file($hash+".json").setText(JSON Stringify:C1217($jsonl))
	End for each 
	$count:=$rerankerFolder.folders().length
End while 