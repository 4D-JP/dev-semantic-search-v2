/*

settings

*/

var $settings : Object
$settings:={}
$settings.chatCompletion:=False:C215
$settings.reranker:=True:C214
$settings.embeddings:=True:C214

var $homeFolder; $folder : 4D:C1709.Folder
var $path : Text
var $URL : Text

$homeFolder:=Folder:C1567(fk home folder:K87:24).folder(".GGUF")

//$folder:=$homeFolder.folder("bge-m3")
//$path:="bge-m3-Q8_0.gguf"
//$URL:="keisuke-miyako/bge-m3-gguf-q8_0"

$folder:=$homeFolder.folder("timesensor-ai")
$path:="bge-m3-lemur-r1-q8_0.gguf"
$URL:="keisuke-miyako/bge-m3-lemur-r1-gguf"

$folder:=$homeFolder.folder("timesensor-ai")
$path:="bge-m3-lemur-r2-q8_0.gguf"
$URL:="keisuke-miyako/bge-m3-lemur-r2-gguf"

//$folder:=$homeFolder.folder("GPT")
//$path:="cl100k_tokenizer.gguf"
//$URL:="keisuke-miyako/cl100k_tokenizer-gguf"

var $modelFile : 4D:C1709.File
$modelFile:=$folder.file($path)
ASSERT:C1129($modelFile.exists)
Extract SET OPTION(Extract Option Tokenizer File; $modelFile)

Use (Storage:C1525)
	Storage:C1525.port:=New shared object:C1526("embeddings"; 7001; "reranker"; 7002; "chatCompletion"; 7003)
End use 

var $llama : cs:C1710.llama.llama
var $huggingfaces : cs:C1710.event.huggingfaces
var $embeddings; $rerank; $chat : cs:C1710.event.huggingface

var $file : 4D:C1709.File
var $port : Integer

var $event : cs:C1710.event.event
$event:=cs:C1710.event.event.new()

var $max_position_embeddings; $batch_size; $parallel; $threads; $batches : Integer

var $pooling; $cache_type_k; $cache_type_v : Text
var $ubatch_size; $n_gpu_layers : Integer
var $threads_batch : Integer
var $options : Object
var $logFile : 4D:C1709.File
var $ctx_size : Integer
var $temp; $min_p; $top_k; $top_p; $repeat_penalty; $presence_penalty : Real

//MARK: Embeddings

$pooling:="cls"
$ubatch_size:=512  //max_position_embeddings=8194, but for better granularity
$n_gpu_layers:=-1
$batches:=16  //may increase with P cores
$threads:=$batches  //input; tokenisers
$threads_batch:=1  //output; GPU does the heavy lifting

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not:C34($logFile.exists))
	$logFile.setContent(4D:C1709.Blob.new())
End if 

$port:=Storage:C1525.port.embeddings
$options:={\
embeddings: True:C214; \
pooling: $pooling; \
ctx_size: $ubatch_size*$batches; \
batch_size: $ubatch_size*$batches; \
ubatch_size: $ubatch_size; \
parallel: $batches; \
threads: $threads; \
threads_batch: $threads_batch; \
threads_http: $batches+1; \
log_file: $logFile; \
log_disable: False:C215; \
n_gpu_layers: $n_gpu_layers}

$embeddings:=cs:C1710.event.huggingface.new($folder; $URL; $path)
$huggingfaces:=cs:C1710.event.huggingfaces.new([$embeddings])
If ($settings.embeddings)
	$llama:=cs:C1710.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
End if 

//MARK: Reranker

$folder:=$homeFolder.folder("ettin-reranker")
$path:="ettin-reranker-1b-v1-Q8_0.gguf"
$URL:="keisuke-miyako/ettin-reranker-v1-gguf"

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not:C34($logFile.exists))
	$logFile.setContent(4D:C1709.Blob.new())
End if 

$pooling:="rank"
$ubatch_size:=1024  //ettin uses more tokens than BGE M3
$n_gpu_layers:=-1
$batches:=10  //may increase with P cores
$threads:=$batches  //input; tokenisers
$threads_batch:=1  //output; GPU does the heavy lifting

$port:=Storage:C1525.port.reranker
$options:={\
reranking: True:C214; \
pooling: $pooling; \
ctx_size: $ubatch_size*$batches; \
batch_size: $ubatch_size*$batches; \
ubatch_size: $ubatch_size; \
parallel: $batches; \
threads: $threads; \
threads_batch: $threads_batch; \
threads_http: $batches+1; \
log_file: $logFile; \
log_disable: False:C215; \
n_gpu_layers: $n_gpu_layers}

$rerank:=cs:C1710.event.huggingface.new($folder; $URL; $path)
$huggingfaces:=cs:C1710.event.huggingfaces.new([$rerank])

If ($settings.reranker)
	$llama:=cs:C1710.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
End if 

//MARK: Chat Completion

$folder:=$homeFolder.folder("qwen-3.5")
$path:="Qwen3.5-2B-Q8_0.gguf"
$URL:="unsloth/Qwen3.5-2B-GGUF"

$logFile:=$folder.file("llama.log")
$folder.create()
If (Not:C34($logFile.exists))
	$logFile.setContent(4D:C1709.Blob.new())
End if 

$temp:=0.2
$min_p:=0.02
//let min_p do the work
//$top_k:=20
$top_p:=0.85
$repeat_penalty:=1.15  //penalise re-issuing the exact same tool call
$presence_penalty:=0.15  //discourages repeating tokens that already appeared in the context, which helps break the loop at the token level.
$ctx_size:=100000  //262144
$batches:=1
$ubatch_size:=128
$threads:=4
$batch_size:=$ubatch_size*4
$cache_type_k:="f16"
$cache_type_v:="f16"

$port:=Storage:C1525.port.chatCompletion
$options:={\
ctx_size: $ctx_size; \
batch_size: $batch_size; \
ubatch_size: $ubatch_size; \
parallel: $batches; \
threads: $threads; \
threads_batch: $threads_batch; \
threads_http: $batches+1; \
temp: $temp; \
min_p: $min_p; \
top_p: $top_p; \
repeat_penalty: $repeat_penalty; \
presence_penalty: $presence_penalty; \
log_file: $logFile; \
log_disable: False:C215; \
n_gpu_layers: $n_gpu_layers; \
jinja: True:C214; \
reasoning_format: "deepseek"; \
cache_type_k: $cache_type_k; \
cache_type_v: $cache_type_v}

$chat:=cs:C1710.event.huggingface.new($folder; $URL; $path)
$huggingfaces:=cs:C1710.event.huggingfaces.new([$chat])
If ($settings.chatCompletion)
	$llama:=cs:C1710.llama.llama.new($port; $huggingfaces; $homeFolder; $options; $event)
End if 