function Get-PackageExist {
    param ($PkgName, $PkgVersion)
    $output = ./nuget.exe list $PkgName -ConfigFile nuget_filter.config
    $ret = $output -match "No packages found"
    return (-Not $ret)
}

$nugetDownloadLink = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$output = "nuget.exe"
$credentialProviderNugetId = "Microsoft.VisualStudio.Services.NuGet.CredentialProvider"

$wc = New-Object System.Net.WebClient
$wc.DownloadFile($nugetDownloadLink, $output)

./nuget.exe install $credentialProviderNugetId -ConfigFile nuget.config
Remove-Item CredentialProvider.VSS.exe
$credentialProviderLoc = Get-ChildItem -Include CredentialProvider.VSS.exe -Recurse |Sort-Object LastWriteTime -Descending | Select-Object -ExpandProperty FullName -First 1
Write-Host $credentialProviderLoc
Copy-Item "$credentialProviderLoc" -Destination "."

$sources = (./nuget.exe sources -Format Short -ConfigFile .\nuget_target.config) -split '\n' | Where-Object {$_ -match "^E http.+$"} | ForEach-Object {
    ($_ -split ' ')[1]
}

Write-Host "Target feeds:"
Write-Host $sources

$path = Read-Host "Please input the path of the txt containing the nuget package to be upload. Or the folder containing the nuget packages: "
if (Test-Path -Path $path -PathType Container){
    Get-ChildItem -Include *.nupkg -Recurse | Sort-Object LastWriteTime -Descending| Select-Object -ExpandProperty FullName > nugetList.txt
    $path = Get-ChildItem -Include nugetList.txt | Select-Object -ExpandProperty FullName -First 1
}

$path = $path.Trim()

if (-Not (Test-Path $path)){
    Write-Host "File not exist."
}
else{
    Write-Host ("Process the items in file" + $path)
    foreach($line in Get-Content $path){
        $match = $line | Select-String -Pattern '^.+\\(?<pkgId>.+?)(?<pkgVersion>(\.[0-9]+)+)\.nupkg$'
        if(-Not $match.Matches.Success -or -Not(Test-Path $line)) {
            continue
        }
        $pkgName = $match.Matches.Groups | Where-Object {$_.Name -eq 'pkgId'} | Select-Object -ExpandProperty Value
        $pkgVersion = ($match.Matches.Groups | Where-Object {$_.Name -eq 'pkgVersion'} | Select-Object -ExpandProperty Value).Trim('.')
        Write-Host ("Process the nuget package with id: " + $pkgName)
        if (-Not (Get-PackageExist -PkgName $pkgName -PkgVersion $pkgVersion)){
            Write-Host "Processing"
            foreach($source in $sources){
                # push nuget
                Write-Host ("Push the package [" + $pkgName +"] to feed [" + $source +"].")
                ./nuget.exe push $line -Source $source -ApiKey AzureDevOps -ConfigFile nuget_target.config
            }
        }else{
            Write-Host ("Package [" + $pkgName +"] found in filter feeds. Skipped")
        }
    }
}


