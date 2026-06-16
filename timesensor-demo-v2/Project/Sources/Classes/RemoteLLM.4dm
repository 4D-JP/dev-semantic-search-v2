property _endpoints : Object
property endpoint : Text

Class constructor($provider : Text)
	
	This:C1470._endpoints:={\
		Claude: "https://api.anthropic.com/v1"; \
		OpenAI: ""}
	
	This:C1470.endpoint:=This:C1470._endpoints[$provider]
	
Function _resolvePath($item : Object) : Object
	
	return OB Class:C1730($item).new($item.platformPath; fk platform path:K87:2)
	
Function getAccessToken($name : Text) : Text
	
	var $file : 4D:C1709.File
	$file:=This:C1470._resolvePath(Folder:C1567("/PROJECT/")).parent.folder("Secrets").file($name+".token")
	
	If ($file.exists)
		return $file.getText()
	End if 