# Set console encoding to support Unicode characters
# 設置控制台編碼以支援 Unicode 字符
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# Ollm Bridge v 0.6
# Ollm Bridge aims to create a structure of directories and symlinks to make Ollama models more easily accessible to LMStudio users.
# 旨在創建目錄結構和符號鏈接，使 Ollama 模型更容易被 LMStudio 用戶訪問
# 主要功能：將 Ollama 存儲的模型轉換為 LMStudio 可識別的目錄結構，通過符號鏈接實現模型共享，避免重複存儲

# Define the directory variables
# 定義目錄變數：設置腳本運行所需的所有路徑變數
$manifest_dirs = @(
    # Ollama 官方倉庫的 manifest 文件目錄
    "$env:USERPROFILE\.ollama\models\manifests\registry.ollama.ai"

    # Add additional manifest directory paths here if needed
    # Example: "D:\AlternativeOllama\models\manifests\registry.ollama.ai"

    # Hugging Face 模型的 manifest 文件目錄
    "$env:USERPROFILE\.ollama\models\manifests\hf.co"
)
# Ollama 實際存儲模型文件的目錄（blob 存儲）
$blob_dir = "$env:USERPROFILE\.ollama\models\blobs"
# 公共模型目錄，用於存儲橋接後的模型
$publicModels_dir = "$env:USERPROFILE\publicmodels"

# This path stores symbolic links to model files organized in LMStudio-compatible structure
# LMStudio 目標目錄：存儲按 LMStudio 兼容結構組織的符號鏈接
$lmstudio_target_dir = "$publicModels_dir\lmstudio"

# Check administrative privileges for symbolic link creation
# 檢查創建符號鏈接所需的系統權限
Write-Host ""
Write-Host "Checking Privileges:" -ForegroundColor Cyan
Write-Host ""

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "[!] Warning: Not running as Administrator" -ForegroundColor Yellow
    Write-Host "  Symbolic link creation may fail without elevated privileges." -ForegroundColor Yellow
    Write-Host "  Consider running this script as Administrator." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "[+] Running with Administrator privileges" -ForegroundColor Green
    Write-Host ""
}

# Test symbolic link creation capability
# 測試符號鏈接創建能力
try {
    # Clean up any existing test link first
    $testLinkPath = "$env:TEMP\ollm_bridge_test_link"
    $testTargetPath = "$env:TEMP\test_target"
    
    # Ensure target directory exists
    if (-not (Test-Path $testTargetPath)) {
        New-Item -ItemType Directory -Path $testTargetPath -Force | Out-Null
    }
    
    # Remove existing test link if it exists
    if (Test-Path $testLinkPath) {
        Remove-Item -Path $testLinkPath -Force -ErrorAction SilentlyContinue
    }
    
    # Create symbolic link test
    New-Item -ItemType SymbolicLink -Path $testLinkPath -Value $testTargetPath -ErrorAction Stop | Out-Null
    
    # Verify the link was created successfully
    if ((Get-Item $testLinkPath).LinkType -eq "SymbolicLink") {
        Write-Host "[+] Symbolic link creation test passed" -ForegroundColor Green
        # Clean up test files
        Remove-Item -Path $testLinkPath -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path $testTargetPath -Force -ErrorAction SilentlyContinue | Out-Null
    } else {
        throw "Created link is not a symbolic link"
    }
} catch {
    Write-Host "[-] Symbolic link creation test failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "  Enable Developer Mode or run as Administrator to create symbolic links." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Continue anyway? (Press Enter to continue, Ctrl+C to exit)" -ForegroundColor Cyan
    Read-Host
}
Write-Host ""

# Print the base directories to confirm the variables
# 輸出基礎目錄信息：顯示所有配置的目錄路徑，用於確認設置正確
Write-Host ""
Write-Host "Confirming Directories:" -ForegroundColor Cyan
Write-Host ""
Write-Host "Manifest Directories:" -ForegroundColor Yellow
$manifest_dirs | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
Write-Host "Blob Directory: $blob_dir" -ForegroundColor White
Write-Host "Public Models Directory: $publicModels_dir" -ForegroundColor White
Write-Host "LMStudio Model Structure Directory: $lmstudio_target_dir" -ForegroundColor White


# Check if the LMStudio target directory already exists, and delete it if so
# 檢查並重置 LMStudio 目標目錄：確保每次運行都創建乾淨的符號鏈接結構
if (Test-Path $lmstudio_target_dir) {
    Write-Host ""
    Remove-Item -Path $lmstudio_target_dir -Recurse -Force
    Write-Host "Ollm Bridge Directory Reset." -ForegroundColor Magenta
}

# Ensure public models directory exists
# 確保公共模型目錄存在：檢查或創建存儲橋接模型的基礎目錄
if (Test-Path $publicModels_dir) {
    Write-Host ""
    Write-Host "Public Models Directory Confirmed." -ForegroundColor Green
} else {
    New-Item -Type Directory -Path $publicModels_dir | Out-Null
    Write-Host ""
    Write-Host "Public Models Directory Created." -ForegroundColor Green
}


# Explore all manifest directories and record the manifest file locations
# 掃描所有 manifest 目錄並記錄有效的 manifest 文件位置
Write-Host ""
Write-Host "Exploring Manifest Directories:" -ForegroundColor Cyan
Write-Host ""
$manifestLocations = @()  # 存儲找到的有效 manifest 文件路徑

# 遍歷每個配置的 manifest 目錄
foreach ($manifest_dir in $manifest_dirs) {
    if (Test-Path $manifest_dir) {
        Write-Host "Processing directory: $manifest_dir" -ForegroundColor Yellow
        # 遞歸獲取目錄中的所有文件（排除子目錄）
        $files = Get-ChildItem -Path $manifest_dir -Recurse -Force | Where-Object {$_.PSIsContainer -eq $false}
        
        # 檢查每個文件是否為有效的 manifest 文件
        foreach ($file in $files) {
            $path = "$($file.DirectoryName)\$($file.Name)"
            
            # Pre-filter JSON files by validating their structure
            # 通過驗證 JSON 結構來預過濾文件，確保只處理有效的 manifest
            try {
                $json = Get-Content -Path $path
                $obj = ConvertFrom-Json -InputObject $json
                
                # Validate that the JSON has the expected structure for a manifest
                # 驗證 JSON 是否具有 manifest 的預期結構（必須包含 config 和 layers 字段）
                if ($obj.config -and $obj.layers) {
                    $manifestLocations += $path  # 添加到有效 manifest 列表
                    Write-Host "  [+] Valid manifest: $($file.Name)" -ForegroundColor Green
                } else {
                    Write-Host "  [-] Invalid manifest structure: $($file.Name)" -ForegroundColor Red
                }
            } catch {
                Write-Host "  [-] Invalid JSON or unreadable file: $($file.Name) - $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    } else {
        Write-Host "Warning: Directory not found - $manifest_dir" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "File Locations:" -ForegroundColor Cyan
Write-Host ""
$manifestLocations | ForEach-Object { Write-Host $_ -ForegroundColor Gray }

# Check if the directory exists and create it if necessary
# 檢查 LMStudio 主目錄是否存在，必要時創建
if (-not (Test-Path -Path $lmstudio_target_dir)) {
    Write-Host ""
    Write-Host "Creating LMStudio model structure directory..." -ForegroundColor Magenta
    New-Item -Type Directory -Path $lmstudio_target_dir | Out-Null
}

# Parse through validated manifest files to get model info
# 解析已驗證的 manifest 文件以提取模型信息
Write-Host ""
Write-Host "Processing $($manifestLocations.Count) valid manifest files..." -ForegroundColor Cyan
Write-Host ""

# 遍歷每個有效的 manifest 文件
$totalManifests = $manifestLocations.Count
$currentCount = 0

# 根據總數量決定補0位數
if ($totalManifests -lt 100) {
    # 2位數: 01, 02, 03...
    $paddingFormat = "{0:D2}"
} elseif ($totalManifests -lt 1000) {
      # 3位數: 001, 002, 003...
    $paddingFormat = "{0:D3}"
} else {
    $paddingFormat = "{0:D4}"
}

foreach ($manifest in $manifestLocations) {
    $currentCount++
    # 動態補0對齊
    $paddedCount = $paddingFormat -f $currentCount
    Write-Host "[$paddedCount/$totalManifests] Processing manifest: $($manifest)" -ForegroundColor Gray
    
    # JSON is already validated, just parse it
    # JSON 已驗證，直接解析即可
    $json = Get-Content -Path $manifest
    $obj = ConvertFrom-Json -InputObject $json

    # Check if the digest is a child of "config"
    # 檢查 digest 是否為 config 的子屬性，並提取模型配置文件路徑
    if ($obj.config.digest) {
        # Replace "sha256:" with "sha256-" in the config digest
        # 將配置摘要中的 "sha256:" 替換為 "sha256-" 以構建實際文件路徑
        $modelConfig = "$blob_dir\$('sha256-' + $($obj.config.digest.Replace('sha256:', '')))"
    }

    # 遍歷所有層（layers），根據 mediaType 提取不同類型文件的路徑
    foreach ($layer in $obj.layers) {
        # If mediaType ends in "model", build $modelfile
        # 如果 mediaType 以 "model" 結尾，構建模型文件路徑
        if ($layer.mediaType -like "*model") {
            # Replace "sha256:" with "sha256-" in the model digest
            # 將模型摘要中的 "sha256:" 替換為 "sha256-" 來構建實際文件路徑
            $modelFile = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
           
        # If mediaType ends in "template", build $modelTemplate
        # 如果 mediaType 以 "template" 結尾，構建模板文件路徑
        if ($layer.mediaType -like "*template") {
            # Replace "sha256:" with "sha256-" in the template digest
            # 將模板摘要中的 "sha256:" 替換為 "sha256-" 來構建實際文件路徑
            $modelTemplate = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
           
        # If mediaType ends in "params", build $modelParams
        # 如果 mediaType 以 "params" 結尾，構建參數文件路徑
        if ($layer.mediaType -like "*params") {
            # Replace "sha256:" with "sha256-" in the parameter digest
            # 將參數摘要中的 "sha256:" 替換為 "sha256-" 來構建實際文件路徑
            $modelParams = "$blob_dir\$('sha256-' + $($layer.digest.Replace('sha256:', '')))"
        }
    }

    # Extract variables from $modelConfig
    # 從模型配置文件中提取關鍵變數：量化級別、文件格式和模型類型
    $modelConfigObj = ConvertFrom-Json (Get-Content -Path $modelConfig)

    # 量化級別（如 Q4_K_M、Q8_0 等）
    $modelQuant = $modelConfigObj.'file_type'
    # 模型文件格式（如 gguf、safetensors 等）
    $modelExt = $modelConfigObj.'model_format'
    # 模型參數規模（如 7B、13B、70B 等）
    $modelTrainedOn = $modelConfigObj.'model_type'

    # Get the parent directory of $manifest
    # 獲取 manifest 文件的父目錄，用於提取模型名稱
    $parentDir = Split-Path -Path $manifest -Parent

    # Set the $modelName variable to the name of the directory
    # 將模型名稱設置為父目錄的名稱（如 llama3、codellama 等）
    $modelName = (Get-Item -Path $parentDir).Name

    Write-Host ""
    Write-Host "Model Name: " -NoNewline; Write-Host $modelName -ForegroundColor Green
    Write-Host "Model Info: Quant = " -NoNewline; Write-Host $modelQuant -ForegroundColor Cyan -NoNewline; 
    Write-Host ", Format = " -NoNewline; Write-Host $modelExt -ForegroundColor Cyan -NoNewline; 
    Write-Host ", Parameters Trained = " -NoNewline; Write-Host $modelTrainedOn -ForegroundColor Cyan

    # Check if the subdirectory exists and create it if necessary
    # 檢查模型子目錄是否存在，必要時創建
    if (-not (Test-Path -Path $lmstudio_target_dir\$modelName)) {
        # Write-Host ""
        # Write-Host "Creating $modelName directory..." -ForegroundColor Magenta
        New-Item -Type Directory -Path $lmstudio_target_dir\$modelName | Out-Null
    }

    # Create the symbolic link
    # 創建符號鏈接：將 Ollama 的實際模型文件鏈接到 LMStudio 兼容的結構中
    # 文件命名格式：模型名稱-參數數量-量化級別.擴展名
    $name = "$($modelName)-$($modelTrainedOn)-$($modelQuant).$($modelExt)"

    Write-Host ""
    Write-Host "Creating symbolic link for $name"
    Write-Host "$modelFile" -ForegroundColor Gray
    New-Item -ItemType SymbolicLink -Path "$lmstudio_target_dir\$modelName\$($name)" -Value $modelFile | Out-Null
    Write-Host ""
}

Write-Host ""
Write-Host ""
Write-Host "*********************" -ForegroundColor Gray
Write-Host "Ollm Bridge complete." -ForegroundColor Green
Write-Host "Set the Models Directory in LMStudio to: $lmstudio_target_dir" -ForegroundColor Yellow 
