//%attributes = {}

$ww:=ds:C1482.Passage.all().distinct("meta.model")

var $provider; $model : Text
$provider:="llama.cpp"
$model:="bge-m3-r2"

var $searches : cs:C1710.SearchSelection
$searches:=ds:C1482.Search.query(""+\
" vectors.meta.provider == :2"+\
" and vectors.meta.model == :3"; True:C214; $provider; $model)

//31900
$searches.drop()

var $passages : cs:C1710.PassageSelection
$passages:=ds:C1482.Passage.query("meta.provider == :1"+\
" and meta.model == :2"+\
""; $provider; $model)

//108190
$passages.drop()