//%attributes = {}
var $Rn : Text
$Rn:="r1"

var $folder : 4D:C1709.Folder
$folder:=Folder:C1567([""; "DATA"; "dataset"; $Rn].join("/"))
ASSERT:C1129($folder.exists)

var $exportFolder : 4D:C1709.Folder
$exportFolder:=$folder.folder("export")
$exportFolder.create()

var $rowsPerFile : Integer
$rowsPerFile:=100

var $fileIndex; $negIndex : Integer
$fileIndex:=1

var $files; $lines; $posRow; $negRow : Collection
$files:=$folder.files(fk recursive:K87:7).query("extension == :1"; ".json")

$lines:=[]
$posRow:=[]
$negRow:=[]

// First pass: build index of which queries each passage appears in as a positive

var $allRecords : Collection
$allRecords:=[]
var $passageToQueries : Object  // passage_hash -> collection of query hashes
$passageToQueries:={}

var $file : 4D:C1709.File
var $jsonl : Object
For each ($file; $files)
	$jsonl:=JSON Parse:C1218($file.getText())
	$allRecords.push($jsonl)
	var $posHash : Text
	For each ($posHash; $jsonl.pos_hash)
		If ($passageToQueries[$posHash]=Null:C1517)
			$passageToQueries[$posHash]:=[]
		End if 
		If ($passageToQueries[$posHash].indexOf($jsonl.query)=-1)
			$passageToQueries[$posHash].push($jsonl.query)
		End if 
	End for each 
End for each 

// Second pass: prune negatives that appear as positives
For each ($jsonl; $allRecords)
	var $cleanNeg : Collection
	$cleanNeg:=[]
	$negIndex:=0
	var $negHash : Text
	For each ($negHash; $jsonl.neg_hash)
		var $isPositiveForThisQuery : Boolean
		$isPositiveForThisQuery:=False:C215
		If ($passageToQueries[$negHash]#Null:C1517)
			If ($passageToQueries[$negHash].indexOf($jsonl.query)#-1)
				$isPositiveForThisQuery:=True:C214
			End if 
		End if 
		If (Not:C34($isPositiveForThisQuery))
			$cleanNeg.push($jsonl.neg.at($negIndex))
		End if 
		$negIndex+=1
	End for each 
	If ($cleanNeg.length=0)
		continue
	End if 
	$jsonl.neg:=$cleanNeg
	//OB REMOVE($jsonl; "relevance_score")
	OB REMOVE:C1226($jsonl; "pos_hash")
	OB REMOVE:C1226($jsonl; "neg_hash")
	$posRow.push($jsonl.pos.length)
	$negRow.push($jsonl.neg.length)
	$lines.push(JSON Stringify:C1217($jsonl))
	If ($lines.length=$rowsPerFile)
		$exportFolder.file(String:C10($fileIndex; "00000")+".jsonl").setText($lines.join("\n"))
		$fileIndex+=1
		$lines:=[]
	End if 
End for each 

If ($lines.length#0)
	$exportFolder.file(String:C10($fileIndex; "00000")+".jsonl").setText($lines.join("\n"))
End if 

var $posAvg; $negAvg : Real
$posAvg:=$posRow.average()
$negAvg:=$negRow.average()

var $totalRows; $prunedRows : Integer
$totalRows:=$posRow.length
$prunedRows:=$allRecords.length-$totalRows