//%attributes = {}
var $Rn : Text
$Rn:="r4"

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
//r1: 30310
//r2: 36784
//r3: 42118
//r4: 43292
//r5: 41102
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
//r1: 5200 unique passsages (out of 124761)
//r2: 5296 unique passsages (out of 124761)
//r3: 5420 unique passsages (out of 124761)
//r4: 5421 unique passsages (out of 124761)
//r5: 5419 unique passsages (out of 124761)

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
	OB REMOVE:C1226($jsonl; "relevance_score")
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
//r1: 1.005
//r2: 1.002
//r3: 1.002
//r4: 1.001
//r5: 1.001
$negAvg:=$negRow.average()
//r1: 3.047
//r2: 2.948
//r3: 2.018
//r4: 1.942
//r5: 1.876
var $totalRows; $prunedRows : Integer
$totalRows:=$posRow.length
$prunedRows:=$allRecords.length-$totalRows