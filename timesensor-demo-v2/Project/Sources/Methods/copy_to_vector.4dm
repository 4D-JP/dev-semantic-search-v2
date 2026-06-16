//%attributes = {}
//TRUNCATE TABLE([Vector])
//SET DATABASE PARAMETER([Vector]; Table sequence number; 0)

For each ($search; ds:C1482.Search.all())
	
	$v:=ds:C1482.Vector.new()
	$v.embeddings:=$search.embeddings
	$v.meta:=$search.meta
	$v.similarity:=$search.similarity
	$v.search:=$search
	$v.save()
	
End for each 