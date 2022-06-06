# MIT License

# Copyright (c) 2022 Stealth2476

# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
#   https://docs.microsoft.com/en-us/microsoft-365/enterprise/microsoft-365-ip-web-service?view=o365-worldwide#endpoints-web-method
# 
# 
#------------------------------------------------------------------------------
param($serviceAreaFile)
$hashT = @{}
$action = $null
function getJsonAsSysObj{
    param($jsonURL)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $json =Invoke-WebRequest $jsonURL 
    $json.content | ConvertFrom-Json
}
#------------------------------------------------------------------------------
function getJson{
    param($jsonURL)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest $jsonURL 
}
#------------------------------------------------------------------------------
function convert2Hash {
    param($jsonFrame)

    ConvertFrom-Json -InputObject $jsonFrame -AsHashtable

}
#------------------------------------------------------------------------------
function getServiceAreas{
    param($fileName)

    if (-not(Test-Path $fileName)) {
        write-host "Service Areas file not found"
        exit
    } else
    {
        Get-Content $fileName
    }
}
#------------------------------------------------------------------------------
function getPreviousConfig($fileName){
    if (-not(Test-Path $fileName)) {
        write-host "No previous config file not found"
        $global:action="create"
    } else
    {
        $global:action="use"
        $previousConfig= Get-Content $fileName
    }
    $previousConfig
}
#------------------------------------------------------------------------------
if ($null -eq $serviceAreaFile){
    $serviceAreaFile=".\serviceAreas.txt"
}
$previousConfigFileName=$serviceAreaFile.substring(0,$serviceAreaFile.indexof(".txt"))+"-previous.csv"
$serviceAreas=getServiceAreas -fileName ($serviceAreaFile)
if (test-path $previousConfigFileName) {
    $previousConfig=getPreviousConfig -fileName $previousConfigFileName
    Remove-Item $previousConfigFileName
}else {
    write-host " pervious config not found"
}


$azure= getJson -jsonURL 'https://endpoints.office.com/endpoints/worldwide?clientrequestid=b10c5ed1-bad1-445f-b386-b919946339a7'
$azure2= $azure.Content.Split('{')
$i=1
$filterListCSV=@()
$filterListCSV +='Object,Function,Name,Description,Type,IP,Protocol,LocalPort,RemotePort'
for (;$i -lt $azure2.count;$i++){
    $azure2[$i]='{'+$azure2[$i].Replace("},","}").Replace("`r`n]","")
    $serviceArea=convert2Hash -jsonFrame $azure2[$i]
    foreach($sa in $serviceAreas){
        if (($serviceArea.serviceArea.contains($sa)) -and ($null -ne $serviceArea.ips)) {
            $filterListCSV +='FilterList,'+$action+','+$serviceArea.urls+','+$serviceArea.serviceAreaDisplayName
            foreach ($ip in $serviceArea.ips){
                foreach ($port in $serviceArea.tcpPorts.split(",")){
                    $filterListCSV +='FilterList,Attach_Qual,,'+$serviceArea.urls+',,'+$ip+',6,*,'+$port
                }
            }
        }
    
    }

}
$filterListCSV | Out-File -FilePath $previousConfigFileName -Encoding ASCII
$newConfigFileName=$serviceAreaFile.substring(0,$serviceAreaFile.indexof(".txt"))+"-newConfig.csv"
if ($null -ne $previousConfig){
    $tmpConfig=Compare-Object  -ReferenceObject $previousConfig  -DifferenceObject $filterListCSV -IncludeEqual -SyncWindow 0
    $tmpConfig | Out-File -FilePath ($serviceAreaFile.substring(0,$serviceAreaFile.indexof(".txt"))+"-compare.csv") -Encoding ASCII

    if (Test-Path $newConfigFileName){
        Remove-Item $newConfigFileName
    }

    $recNo=0
    $newconfig=@()
    foreach ($Iobj in $tmpConfig.GetEnumerator())
    {
        $rec=$Iobj.InputObject
        $diff=$Iobj.SideIndicator
        $recNo +=1
        if ($diff.contains("<=")) {
            $newconfig += $rec.replace("Attach_Qual","Detach_Qual")
        } else {
            $newconfig += $rec
        }
    }
    $newconfig | Out-File -FilePath $newConfigFileName  -Encoding ASCII
} else {
    $filterListCSV | Out-File -FilePath $newConfigFileName -Encoding ASCII

}

