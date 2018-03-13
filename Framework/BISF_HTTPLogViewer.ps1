Param(
    [string]$logFile
)

Start-Transcript
#requires -Version 2
$header = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Frameset//EN" "http://www.w3.org/TR/html4/frameset.dtd">
<html><head><title>$hostname</title>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <script src="https://ajax.googleapis.com/ajax/libs/jquery/3.2.1/jquery.min.js"></script>
<style type="text/css">

iframe {
    border: 0;
    width: 100%;
    height: 100%;
    
}
body {
font-family: Verdana, Geneva, Arial, Helvetica, sans-serif;
}
 
#report { width: 835px; }
 
table{
border-collapse: collapse;
border: none;
font: 10pt Verdana, Geneva, Arial, Helvetica, sans-serif;
color: black;
margin-bottom: 10px;
border: 1px solid black;
}
 
table td{
font-size: 12px;
padding-left: 3px;
padding-right: 5px;
text-align: left;
border: 1px solid;
border-color: #3C3C3C;
}
 
table th {
font-size: 12px;
font-weight: bold;
padding-left: 0px;
padding-right: 20px;
text-align: left;
border: 1px solid;
border-color: #3C3C3C;
background-color: #6fc9d6;
color: white;
}
 
h2{ clear: both; font-size: 130%;color:#354B5E; }
 
h3{
clear: both;
font-size: 75%;
margin-left: 20px;
margin-top: 30px;
color:#475F77;
}
 
p{ margin-left: 20px; font-size: 12px; }
 
table.list{ float: left; }
 
table.list td:nth-child(1){
font-weight: bold;
border-right: 1px grey solid;
text-align: right;
}
ul.menu {
    list-style-type: none;
    margin: 0;
    padding: 0;
    overflow: hidden;
    background-color: #333;
}
li.menu {
    float: left;
}
li.menu a.menu {
    display: block;
    color: white;
    text-align: center;
    padding: 14px 16px;
    text-decoration: none;
}
li.menu a:hover:not(.active).menu {
    background-color: #111;
}
#active {
    background-color: #6fc9d6;
}
#stop {
    background-color: #f44336;
}



 
table.list td:nth-child(2){ padding-left: 7px; }
table tr:nth-child(even) td:nth-child(even){ background: #BBBBBB; }
table tr:nth-child(odd) td:nth-child(odd){ background: #F2F2F2; }
table tr:nth-child(even) td:nth-child(odd){ background: #DDDDDD; }
table tr:nth-child(odd) td:nth-child(even){ background: #E5E5E5; }
div.column { width: 320px; float: left; }
div.first{ padding-right: 20px; border-right: 1px grey solid; }
div.second{ margin-left: 30px; }
table{ margin-left: 20px; }
->
</style>
</head>
"@


$hostname = [System.Net.Dns]::GetHostByName(($env:computerName)).Hostname


$bodyExplainQuery = @"
<ul class="menu">
  <li class="menu"><a class="menu" id="active">$hostname</a></li>
  <li class="menu"><a class="menu">BISF Event Logs</a></li>
  <ul class="menu" style="float:right;list-style-type:none;">
    <li class="menu" ><a class="menu" id="stop" style="hove: " href="/StopServer">Stop Powershell Web Server</a></li>
  </ul>
</ul>
<div id="tab-content1" class="tab-content">
    <form method="get" target="queryEvent" id="formid">
        <input type="hidden" name="BISFEvents" value=""><br>
    </form>
    <iframe id="form-iframe" name="queryEvent" onload="AdjustIframeHeightOnLoad1()"></iframe>
    <script type="text/javascript">
    var timerId = setInterval(function() {
        `$("#formid").submit();
    }, 15000);
    function AdjustIframeHeightOnLoad1() { document.getElementById("form-iframe").style.height = document.getElementById("form-iframe").contentWindow.document.body.scrollHeight + "px"; }
    //function AdjustIframeHeight1(i) { console.log ("i:", i); document.getElementById("form-iframe").style.height = parseInt(i) + "px"; }
    // 1 second = 1000 milliseconds.
    </script>
    <br>
</div>
"@



function Setup-Toolbar 
{
        $format = $null | ConvertTo-Html -Head $header -Body $bodyExplainQuery

        return $format
}


function Query-BISFLog 
{
        
    if($null -or '')
    {
        $format = $null | ConvertTo-Html -Head $header

        return $format
    }
    else {
            $total = @()
        foreach ($line in (Get-Content $logFile)) {
            $Object = New-Object PSObject
            $Object | add-member Noteproperty Time $line.split("|")[0]
            $Object | add-member Noteproperty User $line.split("|")[1]
            $Object | add-member Noteproperty Event $line.split("|")[2]
            $Object | add-member Noteproperty Message $line.split("|")[3]
            $total += $Object
        }
        [array]::Reverse($total)
        $format = $total | ConvertTo-Html -Head $header
    
        return $format
    }
}


function Stop-Server 
{
    $listener.Stop()
}

$routes = @{
    '/'         = {
        return Setup-Toolbar 
    }
    '/queryRaw' = {
        return Query-BISFLog
    }
    '/StopServer' = {
        Stop-Server 
    }
}

$url = "http://$($hostname):8157/"
$listener = New-Object -TypeName System.Net.HttpListener
$listener.Prefixes.Add($url)
$listener.Start()

Write-Host "Listening at $url..."

try
{
    while ($listener.IsListening)
    {
        $context = $listener.GetContext()
        $requestUrl = $context.Request.Url
        $response = $context.Response

        Write-Host ''
        Write-Host "> $requestUrl"

        $localPath = $requestUrl.LocalPath
        $route = $routes.Get_Item($requestUrl.LocalPath)

            
        if ($route -eq $null)
        {
            $response.StatusCode = 404
        }
        else
        {
            if($requestUrl -match 'BISFEvents')
            {
                $content = Query-BISFLog
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
            else
            {
                $content = & $route
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($content)
                $response.ContentLength64 = $buffer.Length
                $response.OutputStream.Write($buffer, 0, $buffer.Length)
            }
        }
    
        $response.Close()

        $responseStatus = $response.StatusCode
        Write-Host "< $responseStatus"
    } 
}
catch 
{
    $listener.Stop()
}