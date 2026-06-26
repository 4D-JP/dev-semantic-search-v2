//%attributes = {}
ARRAY LONGINT:C221($pos; 0)
ARRAY LONGINT:C221($len; 0)

var $f : 4D:C1709.Function
$f:=Formula:C1597(Match regex:C1019("(?:[^|]+\\|){20,}"; This:C1470.text; 1; $pos; $len))
$all:=ds:C1482.Passage.all()

For each ($passage; $all)
	If ($f.call($passage))
		$passage.vectors.search.drop()
		$passage.vectors.drop()
		$passage.drop()
	End if 
End for each 
//277740
//var $passages : cs.PassageSelection
//$passages:=$all.query(":1"; $f)
//$passages:=ds.Passage.all()

//$passages.vectors.search.drop()
//$passages.vectors.drop()
//$passages.drop()