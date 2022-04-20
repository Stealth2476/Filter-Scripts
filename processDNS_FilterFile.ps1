# MIT License

# Copyright (c) 2022 Unisys, inc.

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

#==============================================================================
# 
#               comand line parameter -filterfile <path to input csv file>
#               format of input CSV file:
#   Object,Function,Name,Description,Type,IP,Protocol,LocalPort,RemotePort,ExLocal,ExRemote,Exclude,Qualifier,COIFilter
#               
#               Example input file:
#   Object,Function,Name,Description,Type,IP,Protocol,LocalPort,RemotePort,ExLocal,ExRemote,Exclude,Qualifier,COIFilter
    # FilterList,Use,FL AD Server IP,List of AD Server IPs,,,,,,,,,,
    # FilterList,Attach_Qual,,www.cnn.com,,151.101.1.67,,,,,,,,,
    # FilterList,Attach_Qual,,www.cnn.com,,151.101.129.67,,,,,,,,,
    # FilterList,Attach_Qual,,www.cnn.com,,151.101.193.67,,,,,,,,,
    # FilterList,Attach_Qual,,www.cnn.com,,151.101.65.67,,,,,,,,,
    # FilterList,Attach_Qual,,www.cnbc.com,,96.6.22.232,,,,,,,,,

# after the running of the script two files will be created 
#           1)  <input file name>-newConfig.csv is the new configuration file
#                that needs to be run through the Stealth ecoAPI generator 
#           2)  <input file name>-previous.csv This file is the configuration 
#               that was generated from the previous run and is compared to the current run
#==============================================================================
#       Change History
#       2022/04/19 : 
#       1) Added feature to allow headers in any order; however, "Function","Description", 
#       and "IP"  are required headers. The header names are case insensitive.
#       2) fixed bug in compare-object added -SyncWindow 0 to keep records in order
#       3) Fixed bug in Deatch_Qual
# -----------------------------------------------------------------------------
#       2022/04/20:
#       1) add version to output 
#
param ($filterfile)

$configuration = @{}
$version ="Version=202204201107EDST"
function read-FilterFile{
    param ($filterFileName)
    get-content $filterFileName
}

function readPreviousConfig{
    param ($filename)
    get-content $filename
}

function buildNewFilterList
{
    param ($filterFile,$configuration)
    $newFilterList =@()
    $function=(($filterFile[0].split(",")).ToUpper()).indexof("FUNCTION")
    $description=(($filterFile[0].split(",")).ToUpper()).indexof("DESCRIPTION")
    $ip=(($filterFile[0].split(",")).ToUpper()).indexof("IP")
    foreach ($rec in $filterFile)
        {
            $cells = $rec.split(",")
            switch ($cells[$function])
                {
                    "Attach_Qual"{
                        $url=$cells[$description].Trim()
                        try {
                            $dns= [System.Net.Dns]::GetHostEntry($url).AddressList.IPAddressToString
                            $IPAs = $dns | Sort-Object
                            foreach ($Arec in $IPAs)
                            {
                                $cells[$ip]=$Arec
                                $newRec=""
                                foreach ($c in $cells)
                                    {
                                        $newRec=$newRec+$c+","
                                    }
                                $newFilterList += $newRec
                            }
                        } catch {
                            $newFilterList += $rec
                        }
                    }
                    Default {
                        $newFilterList += $rec
                    }
                }
        }
    $newFilterList

}

#==============================================================================
Write-Host $version
if ($null -eq $filterfile)
{
    Write-Host "No filter file supplied"
    $filterfile =".\DNS_Filter_test.csv"
}

if (-not(Test-Path $filterfile)){
    Write-Host "config file not found, exiting..."
    exit 
}

$previousConfigFileName = $filterfile.substring(0,$filterfile.indexof(".csv"))+"-previous.csv"

$configFile=read-FilterFile $filterfile

if (Test-Path $previousConfigFileName){
    $previousConfig =  readPreviousConfig $previousConfigFileName
} else {
    Write-Host "Previous configuration not found"
}
        
$fl1 = buildNewFilterList -filterFile $configFile -configuration $configuration
$fl1 | Out-File -FilePath $previousConfigFileName -Encoding ASCII 
$tmpConfig=Compare-Object  -ReferenceObject $previousConfig  -DifferenceObject $fl1 -IncludeEqual -SyncWindow 0
$tmpConfig | Out-File -FilePath ($filterfile.substring(0,$filterfile.indexof(".csv"))+"-compare.csv") -Encoding ASCII

if (Test-Path $filterFile"-newConfig.csv" ){
    Remove-Item $filterFile"-newConfig.csv"
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
$newconfig | Out-File -FilePath $filterFile"-newConfig.csv" -Encoding ASCII
