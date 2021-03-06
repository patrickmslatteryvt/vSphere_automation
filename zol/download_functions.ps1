# Powershell script to download a public PowerShell functions file from GitHub and save it in the correct location on the users disk

# Read in the users homepath environment variable
$homepath = $env:homepath
# The PowerShell modules directory
$modulesdir = "\Documents\WindowsPowerShell\Modules\vsphere_functions"
# Full path of where we want to save our file at
$outputdir = "$homepath$modulesdir"
# Create the directory if it does not exist
New-Item -ItemType Directory -Force -Path $outputdir
# Create a new webclient object
$webclient = New-Object System.Net.WebClient
# Public OAuth key
$webclient.Headers.Add('Authorization','token f296c0f531640d3ddbbf273c1b169b599fea097d')
# URL to the file we want to download
$url = "https://raw.github.com/patrickmslatteryvt/vSphere_automation/master/vsphere_functions/vsphere_functions.psm1"
# URI to where we want to save the file
$file = "$outputdir\vsphere_functions.psm1"
# Download the file
$webclient.DownloadFile($url,$file)
