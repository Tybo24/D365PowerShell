# Initialise collection
$collection = @{
    info = @{
        _postman_id = [guid]::NewGuid().ToString()
        name = Split-Path (Get-Location).Path -NoQualifier | Split-Path -Leaf
        schema = "https://schema.getpostman.com/json/collection/v2.1.0/collection.json"
        _exporter_id = "GeneratedByPowerShell"
    }
    item = @()
}

# Function to extract method request contract class
function Get-ContractClassName($sourceCode) {
    if ($sourceCode -match '\((\w+)\s+\w+\)') {
        return $matches[1]
    }
    return $null
}

# Function to extract JSON body from a contract class XML
function Generate-RequestBody($contractXmlPath) {
    Write-Host "  [INFO] Parsing contract XML: $contractXmlPath"
    $xml = [xml](Get-Content $contractXmlPath)
    $params = @{}
    foreach ($method in $xml.AxClass.SourceCode.Methods.Method) {
        $name = $method.Name
        $sourceText = $method.Source.InnerText
        Write-Host "    [DEBUG] Method source for '$name':"
        Write-Host $sourceText

        if ($sourceText -match '\[DataMember') {
            Write-Host "    [FOUND] DataMember parameter: $name"
            $params[$name] = ""
        } else {
            Write-Host "    [SKIPPED] Not a DataMember: $name"
        }
    }
    return @{
        _request = $params
    } | ConvertTo-Json -Depth 10
}

# Create shared structure once
$serviceGroupFolder = @{
    name = "Service group"
    item = @()
}

$jsonFolder = @{
    name = "JSON"
    item = @($serviceGroupFolder)
}

$webservicesFolder = @{
    name = "Webservices"
    item = @($jsonFolder)
}

# Add to collection once
$collection.item += $webservicesFolder

# Load AxServiceGroup XML files
$axServiceGroupFiles = Get-ChildItem -Recurse -Filter "*.xml" -Path ".\AxServiceGroup"
foreach ($file in $axServiceGroupFiles) {
    $xml = [xml](Get-Content $file.FullName)
    $groupName = $xml.AxServiceGroup.Name

    Write-Host "`n[GROUP] Processing Service Group: $groupName"

    $groupItem = @{
        name = $groupName
        item = @(@{ name = "Service"; item = @() })
    }

    foreach ($service in $xml.AxServiceGroup.Services.AxServiceGroupService) {
        Write-Host "  [SERVICE] $($service.Name)"
        $serviceFolder = @{
            name = $service.Name
            item = @()
        }

        # Load service class XML
        $className = $service.Service
        $classFile = Get-ChildItem -Recurse -Path ".\AxClass" -Filter "$className.xml" | Select-Object -First 1
        if (-not $classFile) {
            Write-Host "    [WARNING] Service class XML not found: $className.xml"
            continue
        }

        $classXml = [xml](Get-Content $classFile.FullName)
        $methods = $classXml.AxClass.SourceCode.Methods.Method

        for ($i = 0; $i -lt $methods.Count; $i++) {
            $method = $methods[$i]
            $methodName = $method.Name
			$sourceText = $method.Source.InnerText
			
            $contractClass = Get-ContractClassName($sourceText)
            if ($contractClass) {
                Write-Host "      [CONTRACT] Detected: $contractClass"
            } else {
                Write-Host "      [CONTRACT] Not detected: $contractClass"
            }

            $body = "{}"
            if ($contractClass) {
                $contractFile = Get-ChildItem -Recurse -Path ".\AxClass" -Filter "$contractClass.xml" | Select-Object -First 1
                if ($contractFile) {
                    $body = Generate-RequestBody $contractFile.FullName
                } else {
                    Write-Host "      [WARNING] Contract class XML not found: $contractClass.xml"
                }
            }

            $request = @{
                name = $methodName
                request = @{
                    method = "POST"
                    header = @(
                        @{
                            key = "Authorization"
                            value = "Bearer {{bearerToken}}"
                            type = "text"
                        }
                    )
                    body = @{
                        mode = "raw"
                        raw = $body
                        options = @{
                            raw = @{
                                language = "json"
                            }
                        }
                    }
                    url = @{
                        raw = "{{resource}}/api/services/$groupName/$($service.Name)/$methodName"
                        host = @("{{resource}}")
                        path = @("api", "services", $groupName, $service.Name, $methodName)
                    }
                }
                response = @()
            }

            $serviceFolder.item += $request
        }

        $groupItem.item[0].item += $serviceFolder
    }

    # Add group to the shared Service group folder
    $serviceGroupFolder.item += $groupItem
}

# Output to file
Write-Host "`n[INFO] Saving Postman collection to postman_collection.json"
$collection | ConvertTo-Json -Depth 20 | Set-Content -Path "postman_collection.json" -Encoding UTF8
Write-Host "[DONE] Collection created."
pause