//%attributes = {"invisible":true}
If (False:C215)
	
	var $langs : Collection
	var $lang : Text
	
	$langs:=["de"; "fr"; "en"]
	
/*
full
de: 1128
fr: 1125
en: 1128
	
train
de: 677
fr: 677
en: 677
	
test:
de: 227
fr: 225
en: 228
*/
	
	For each ($lang; $langs)
		var $languagesFolder; $rootFolder; $langFolder : 4D:C1709.Folder
		$languagesFolder:=Folder:C1567("/DATA/LEMUR/languages/")
		$langFolder:=$languagesFolder.folder($lang)
		$rootFolder:=$langFolder.parent.parent
		
		var $full : 4D:C1709.File
		$full:=$langFolder.file("full.jsonl")
		ASSERT:C1129($full.exists)
		
		var $row : Text
		var $rows : Collection
		$rows:=Split string:C1554($full.getText("utf-8"; Document with LF:K24:22); "\n")
		var $json : Object
		For each ($row; $rows)
			If ($row="")
				continue
			End if 
			$json:=JSON Parse:C1218($row; Is object:K8:27)
/*
[
"law_id",
"category",
"year",
"primary_language",
"metadata",
"text",
"is_table",
"is_diagram",
"rotation_correction",
"is_rotation_valid",
"pdf_path",
"pdf_total_pages"
]
*/
			var $pdfFile : 4D:C1709.File
			$pdfFile:=$rootFolder.file($json.pdf_path)
			ASSERT:C1129($pdfFile.exists)
			
			var $eFull : cs:C1710.FullEntity
			$eFull:=ds:C1482.Full.new()
			$eFull.file:=$pdfFile
			$eFull.meta:=$json  //includes text
			$eFull.save()
		End for each 
	End for each 
End if 



