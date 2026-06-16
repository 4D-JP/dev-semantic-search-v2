property _baseURLs : Object
property baseURL : Text
property apiKey : Text

Class constructor($provider : Text)
	
	This:C1470._baseURLs:={\
		Claude: "https://api.anthropic.com/v1"; \
		OpenAI: ""}
	
	This:C1470.baseURL:=This:C1470._baseURLs[$provider]
	
	var $file : 4D:C1709.File
	$file:=This:C1470._resolvePath(Folder:C1567("/PROJECT/")).parent.folder("Secrets").file($provider+".token")
	
	If ($file.exists)
		This:C1470.apiKey:=$file.getText()
	End if 
	
Function _resolvePath($item : Object) : Object
	
	return OB Class:C1730($item).new($item.platformPath; fk platform path:K87:2)