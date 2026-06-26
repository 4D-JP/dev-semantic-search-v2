//%attributes = {}
ARRAY LONGINT:C221($pos; 0)
ARRAY LONGINT:C221($len; 0)

var $f : 4D:C1709.Function
$f:=Formula:C1597(Match regex:C1019("(?:[^|]+\\|){20,}"; This:C1470.text; 1; $pos; $len))

var $passages : cs:C1710.TrainingPassageSelection
$passages:=ds:C1482.TrainingPassage.query(":1"; $f)
//$passages:=ds.TrainingPassage.all()

$passages.searches.drop()
$passages.drop()
