# Ollm Bridge v 0.6
# Ollm Bridge aims to create a structure of directories and symlinks to make Ollama models more easily accessible to LMStudio users.

# Define the directory variables
$manifest_dirs = @(
    "$env:USERPROFILE\.ollama\models\manifests\registry.ollama.ai"
    # Add additional manifest directory paths here if needed
    # Example: "D:\AlternativeOllama\models\manifests\registry.ollama.ai"
    "$env:USERPROFILE\.ollama\models\manifests\hf.co"
)
$blob_dir = "$env:USERPROFILE\.ollama\models\blobs"
$publicModels_dir = "$env:USERPROFILE\publicmodels"

# This path stores symbolic links to model files organized in LMStudio-compatible structure
$lmstudio_target_dir = "$publicModels_dir\lmstudio"

# Print the base directories to confirm the variables
Write-Host ""
Write-Host "Confirming Directories:"
Write-Host ""
Write-Host "Manifest Directories:"
$manifest_dirs | ForEach-Object { Write-Host "  - $_" }
Write-Host "Blob Directory: $blob_dir"
Write-Host "Public Models Directory: $publicModels_dir"
Write-Host "LMStudio Model Structure Directory: $lmstudio_target_dir"


# Check if the LMStudio target directory already exists, and delete it if so
if (Test-Path $lmstudio_target_dir) {
    Write-Host ""
    Remove-Item -Path $lmstudio_target_dir -Recurse -Force
    Write-Host "Ollm Bridge Directory Reset."
}

if (Test-Path $publicModels_dir) {
    Write-Host ""
    Write-Host "Public Models Directory Confirmed."
} else {
    New-Item -Type Directory -Path $publicModels_dir
    Write-Host ""
    Write-Host "Public Models Directory Created."
}


# Explore all manifest directories and record the manifest file locations
Write-Host ""
Write-Host "Exploring Manifest Directories:"
Write-Host ""
$manifestLocations = @()

foreach ($manifest_dir in $manifest_dirs) {
    if (Test-Path $manifest_dir) {
        Write-Host "Processing directory: $manifest_dir"
        $files = Get-ChildItem -Path $manifest_dir -Recurse -Force | Where-Object {$_.PSIsContainer -eq $false}
        
        foreach ($file in $files) {
            $path = "$($file.DirectoryName)\$($file.Name)"
            
            # Pre-filter JSON files by validating their structure
            try {
                $json = Get-Content -Path $path
                $obj = ConvertFrom-Json -InputObject $json
                
                # Validate that the JSON has the expected structure for a manifest
                if ($obj.config -and $obj.layers) {
                    $manifestLocations += $path
                    Write-Host "  ✓ Valid manifest: $($file.Name)"
                } else {
                    Write-Host "  ✗ Invalid manifest structure: $($file.Name)"
                }
            } catch {
                Write-Host "  ✗ Invalid JSON or unreadable file: $($file.Name) - $($_.Exception.Message)"
            }
        }
    } else {
        Write-Host "Warning: Directory not found - $manifest_dir"
    }
}

Write-Host ""
Write-Host "File Locations:"
Write-Host ""
$manifestLocations | ForEach-Object { Write-Host $_ }


# Parse through validated manifest files to get model info
Write-Host ""
Write-Host "Processing $($manifestLocations.Count) valid manifest files..."
Write-Host ""

foreach ($manifest in $manifestLocations) {
    Write-Host "Processing manifest: $(Split-Path $manifest -Leaf)"
    
    # JSON is already validated, just parse it
    $json = Get-Content -Path $manifest
    $obj = ConvertFrom-Json -InputObject $json

    # Check if the digest is a child of "config"
    if ($obj.config.digest) {
        # Replace "sha256:" with "sha256-" in the config digest
        $modelConfig = "$blob_dir\$('sha256-' + $($obj.config.digest.Replace('sha256:', '')))"
    }

    foreach ($layer in $obj.layers) {
        # If mediaType ends in "model", build $modelfile
        if ($layer.mediaType -like "*model") {
            # Replace "sha256:" with "sha256-" in the model digest
            $modelFile = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
           
        # If mediaType ends in "template", build $modelTemplate
        if ($layer.mediaType -like "*template") {
            # Replace "sha256:" with "sha256-" in the template digest
            $modelTemplate = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
           
        # If mediaType ends in "params", build $modelParams
        if ($layer.mediaType -like "*params") {
            # Replace "sha256:" with "sha256-" in the parameter digest
            $modelParams = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
    }

    # Extract variables from $modelConfig
    $modelConfigObj = ConvertFrom-Json (Get-Content -Path $modelConfig)

    $modelQuant = $modelConfigObj.'file_type'
    $modelExt = $modelConfigObj.'model_format'
    $modelTrainedOn = $modelConfigObj.'model_type'

    # Get the parent directory of $manifest
    $parentDir = Split-Path -Path $manifest -Parent

    # Set the $modelName variable to the name of the directory
    $modelName = (Get-Item -Path $parentDir).Name

    Write-Host ""
    Write-Host "Model Name is" $modelName
    Write-Host "Quant is" $modelQuant
    Write-Host "Extension is" $modelExt
    Write-Host "Number of Parameters Trained on is" $modelTrainedOn
    Write-Host ""


    # Check if the directory exists and create it if necessary
    if (-not (Test-Path -Path $lmstudio_target_dir)) {
        Write-Host ""
        Write-Host "Creating LMStudio model structure directory..."
        New-Item -Type Directory -Path $lmstudio_target_dir
    }

    # Check if the subdirectory exists and create it if necessary
    if (-not (Test-Path -Path $lmstudio_target_dir\$modelName)) {
        Write-Host ""
        Write-Host "Creating $modelName directory..."
        New-Item -Type Directory -Path $lmstudio_target_dir\$modelName
    }

    # Create the symbolic link
    Write-Host ""
    Write-Host "Creating symbolic link for $modelFile..."
    New-Item -ItemType SymbolicLink -Path "$lmstudio_target_dir\$modelName\$($modelName)-$($modelTrainedOn)-$($modelQuant).$($modelExt)" -Value $modelFile
}

Write-Host ""
Write-Host ""
Write-Host "*********************"
Write-Host "Ollm Bridge complete."
Write-Host "Set the Models Directory in LMStudio to: $lmstudio_target_dir" 
