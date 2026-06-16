var $event : Object
$event:=FORM Event:C1606

Case of 
	: ($event.code=On Load:K2:1)
		
		var $file : 4D:C1709.File
		$file:=File:C1566("/RESOURCES/streaming-markdown.html")
		WA OPEN URL:C1020(*; $event.objectName; $file.platformPath)
		
	: ($event.code=On End URL Loading:K2:47)
		
		OBJECT SET VISIBLE:C603(*; $event.objectName; True:C214)
		
End case 