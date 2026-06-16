var $event : Object
$event:=FORM Event:C1606

Case of 
	: ($event.code=On Load:K2:1)
		
		Form:C1466.onLoad($event)
		
	: ($event.code=On Double Clicked:K2:5)
		
		Form:C1466.onDoubleClicked($event)
		
	: ($event.code=On Data Change:K2:15)
		
		Form:C1466.onDataChange($event)
		
	: ($event.code=On Clicked:K2:4)
		
		Form:C1466.onClicked($event)
		
End case 