//%attributes = {}
$Rn:="r7"
var $folder : 4D:C1709.Folder
$folder:=Folder:C1567([""; "DATA"; "dataset"; $Rn].join("/"))
//$folder.create()

var $rerankerFolder : 4D:C1709.Folder
$rerankerFolder:=$folder.folder("reranker")
//$rerankerFolder.create()
$targetFolder:=$rerankerFolder.parent.folder("exclude")
$targetFolder.create()

$files:=$rerankerFolder.files(fk recursive:K87:7).query("extension == :1"; ".json")
ARRAY LONGINT:C221($pos; 0)
ARRAY LONGINT:C221($len; 0)
For each ($file; $files)
	$text:=$file.getText()
	If (Match regex:C1019("(?:[^|]+\\|){20,}"; $text; 1; $pos; $len))
		$file.moveTo($targetFolder)
	End if 
End for each 