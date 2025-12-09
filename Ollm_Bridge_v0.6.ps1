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

# Support custom OLLAMA_MODELS environment variable
# 支援 OLLAMA_MODELS 環境變數來自定義 Ollama 目錄
$ollama_base_dir = if ($env:OLLAMA_MODELS) { 
    # 如果 OLLAMA_MODELS 已經包含 \models，則直接使用；否則添加 \models
    if ($env:OLLAMA_MODELS -like "*\models*") {
        $env:OLLAMA_MODELS
    } else {
        "$env:OLLAMA_MODELS\models"
    }
} else { 
    "$env:USERPROFILE\.ollama\models" 
}

$manifest_dirs = @(
    # Ollama 官方倉庫的 manifest 文件目錄
    "$ollama_base_dir\manifests\registry.ollama.ai"

    # Add additional manifest directory paths here if needed
    # Example: "D:\AlternativeOllama\models\manifests\registry.ollama.ai"

    # Hugging Face 模型的 manifest 文件目錄
    "$ollama_base_dir\manifests\hf.co"
)
# Ollama 實際存儲模型文件的目錄（blob 存儲）
$blob_dir = "$ollama_base_dir\blobs"

# This path stores symbolic links to model files organized in LMStudio-compatible structure
# 輸出目標目錄：存儲按 LMStudio 兼容結構組織的符號鏈接
$output_target_dir = "$env:USERPROFILE\publicmodels\lmstudio"

# Helper function to convert sha256 digest to blob path
# 輔助函數：將 sha256 摘要轉換為 blob 路徑
function Convert-DigestToBlobPath {
    param([string]$digest)
    return "$blob_dir\$('sha256-' + $($digest.Replace('sha256:', '')))"
}

# Helper function to display colored model info
# 輔助函數：顯示彩色模型信息
function Show-ModelInfo {
    param([string]$modelName, [string]$modelQuant, [string]$modelExt, [string]$modelTrainedOn)
    Write-Host "Model Name: " -NoNewline; Write-Host $modelName -ForegroundColor Green
    Write-Host "Model Info: Quant = " -NoNewline; Write-Host $modelQuant -ForegroundColor Cyan -NoNewline; 
    Write-Host ", Format = " -NoNewline; Write-Host $modelExt -ForegroundColor Cyan -NoNewline; 
    Write-Host ", Parameters Trained = " -NoNewline; Write-Host $modelTrainedOn -ForegroundColor Cyan
}

# Helper function to display directory configuration
# 輔助函數：顯示目錄配置信息
function Show-DirectoryConfig {
    Write-Host "Ollama Base Directory: $ollama_base_dir" -ForegroundColor White
    if ($env:OLLAMA_MODELS) {
        Write-Host "  (Using custom OLLAMA_MODELS environment variable)" -ForegroundColor Yellow
        Write-Host "    Path: $env:OLLAMA_MODELS" -ForegroundColor Gray
    } else {
        Write-Host "  (Using default user profile directory)" -ForegroundColor Gray
    }
    Write-Host "Manifest Directories:" -ForegroundColor Yellow
    $manifest_dirs | ForEach-Object { Write-Host "  - $_" -ForegroundColor White }
    Write-Host "Blob Directory: $blob_dir" -ForegroundColor White
    Write-Host "Output Target LMStudio Model Structure Directory: $output_target_dir" -ForegroundColor White
}

# Helper function to extract model configuration
# 輔助函數：提取模型配置信息
function Get-ModelConfig {
    param([string]$modelConfigPath)
    
    try {
        # Extract variables from $modelConfig
        # 從模型配置文件中提取關鍵變數：量化級別、文件格式和模型類型
        $config = Get-Content -Path $modelConfigPath | ConvertFrom-Json
        return [PSCustomObject]@{
            # 量化級別（如 Q4_K_M、Q8_0 等）
            Quant = $config.'file_type'
            # 模型文件格式（如 gguf、safetensors 等）
            Ext = $config.'model_format'
            # 模型參數規模（如 7B、13B、70B 等）
            TrainedOn = $config.'model_type'
        }
    } catch {
        Write-Host "[-] Failed to parse model config: $($_.Exception.Message)" -ForegroundColor Red
        return $null
    }
}

# Helper function to display status messages with consistent formatting
# 輔助函數：顯示統一格式的狀態訊息
function Write-StatusMessage {
    param(
        [ValidateSet("Success", "Warning", "Error", "Info", "Processing")]
        [string]$Type,
        [string]$Message
    )
    
    switch ($Type) {
        "Success" { Write-Host "[+] $Message" -ForegroundColor Green }
        "Warning" { Write-Host "[!] $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "[-] $Message" -ForegroundColor Red }
        "Info" { Write-Host "[*] $Message" -ForegroundColor White }
        "Processing" { Write-Host "[~] $Message" -ForegroundColor Cyan }
    }
}

# Check administrative privileges for symbolic link creation
# 檢查創建符號鏈接所需的系統權限
Write-Host ""
Write-Host "Checking Privileges:" -ForegroundColor Cyan
Write-Host ""

$currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($currentUser)

if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-StatusMessage "Warning" "Not running as Administrator"
    Write-Host "  Symbolic link creation may fail without elevated privileges." -ForegroundColor Yellow
    Write-Host "  Consider running this script as Administrator." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-StatusMessage "Success" "Running with Administrator privileges"
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
        Write-StatusMessage "Success" "Symbolic link creation test passed"
        # Clean up test files
        Remove-Item -Path $testLinkPath -Force -ErrorAction SilentlyContinue | Out-Null
        Remove-Item -Path $testTargetPath -Force -ErrorAction SilentlyContinue | Out-Null
    } else {
        throw "Created link is not a symbolic link"
    }
} catch {
    Write-StatusMessage "Error" "Symbolic link creation test failed: $($_.Exception.Message)"
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
Show-DirectoryConfig

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

# Ensure output target directory is clean and ready
# 確保輸出目標目錄乾淨且準備就緒
if (Test-Path $output_target_dir) {
    Write-Host ""
    Remove-Item -Path $output_target_dir -Recurse -Force
    Write-Host "Ollm Bridge Directory Reset." -ForegroundColor Magenta
}

Write-Host ""
Write-Host "Creating LMStudio model structure directory..." -ForegroundColor Magenta
New-Item -Type Directory -Path $output_target_dir -Force | Out-Null

# Parse through validated manifest files to get model info
# 解析已驗證的 manifest 文件以提取模型信息
Write-Host ""
Write-Host "Processing $($manifestLocations.Count) valid manifest files..." -ForegroundColor Cyan
Write-Host ""

# Initialize log file for duplicate models
# 初始化重複模型日誌檔案
$logFile = "$output_target_dir\log.md"
$duplicateModels = @()  # 存儲重複模型資訊

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

    # Extract file paths from digests
    # 從摘要中提取文件路徑
    $modelConfig = Convert-DigestToBlobPath $obj.config.digest
    
    # Extract layer file paths
    # 提取層文件路徑
    foreach ($layer in $obj.layers) {
        if ($layer.mediaType -like "*model") {
            $modelFile = Convert-DigestToBlobPath $layer.digest
        } elseif ($layer.mediaType -like "*template") {
            $modelTemplate = Convert-DigestToBlobPath $layer.digest
        } elseif ($layer.mediaType -like "*params") {
            $modelParams = Convert-DigestToBlobPath $layer.digest
        }
    }

    # Extract model configuration
    # 提取模型配置信息
    $modelConfigObj = Get-ModelConfig $modelConfig
    if (-not $modelConfigObj) {
        Write-Host "[-] Skipping manifest due to config parsing failure: $manifest" -ForegroundColor Red
        continue
    }
    
    $modelQuant = $modelConfigObj.Quant
    $modelExt = $modelConfigObj.Ext
    $modelTrainedOn = $modelConfigObj.TrainedOn

    # Get the parent directory of $manifest
    # 獲取 manifest 文件的父目錄，用於提取模型名稱
    $parentDir = Split-Path -Path $manifest -Parent

    # Set the $modelName variable to the name of the directory
    # 將模型名稱設置為父目錄的名稱（如 llama3、codellama 等）
    $modelName = (Get-Item -Path $parentDir).Name

    Write-Host ""
    Show-ModelInfo $modelName $modelQuant $modelExt $modelTrainedOn

    # Check if the subdirectory exists and create it if necessary
    # 檢查模型子目錄是否存在，必要時創建
    if (-not (Test-Path -Path $output_target_dir\$modelName)) {
        # Write-Host ""
        # Write-Host "Creating $modelName directory..." -ForegroundColor Magenta
        New-Item -Type Directory -Path $output_target_dir\$modelName | Out-Null
    }

    # Create the symbolic link
    # 創建符號鏈接：將 Ollama 的實際模型文件鏈接到 LMStudio 兼容的結構中
    # 文件命名格式：模型名稱-參數數量-量化級別.擴展名
    $name = "$($modelName)-$($modelTrainedOn)-$($modelQuant).$($modelExt)"
    $symlinkPath = "$output_target_dir\$modelName\$($name)"

    Write-Host ""
    Write-Host "Creating symbolic link for $name"
    Write-Host "$modelFile" -ForegroundColor Gray
    
    # Check if symbolic link already exists
    # 檢查符號鏈接是否已經存在
    if (Test-Path $symlinkPath) {
        Write-StatusMessage "Warning" "Model already exists, skipping creation - $name"
        
        # Get existing symlink target for comparison
        # 獲取現有符號鏈接的目標進行比較
        $existingTarget = (Get-Item $symlinkPath).Target
        
        if ($existingTarget -ne $modelFile) {
            Write-StatusMessage "Error" "Different source detected - Existing: $existingTarget"
            Write-StatusMessage "Error" "New source: $modelFile"
            
            # Add to duplicate models log
            # 添加到重複模型日誌
            $duplicateInfo = [PSCustomObject]@{
                ModelName = $name
                ExistingSource = $existingTarget
                NewSource = $modelFile
                ModelDir = $modelName
                CreatedTime = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
            $duplicateModels += $duplicateInfo
        }
    } else {
        try {
            New-Item -ItemType SymbolicLink -Path $symlinkPath -Value $modelFile -ErrorAction Stop | Out-Null
        } catch {
            Write-StatusMessage "Error" "Failed to create symbolic link: $($_.Exception.Message)"
        }
    }
    Write-Host ""
}

Write-Host ""

# Generate duplicate models log if any duplicates found
# 如果發現重複模型，生成日誌檔案
if ($duplicateModels.Count -gt 0) {
    Write-Host "Writing duplicate models log to: $logFile" -ForegroundColor Yellow
    
    $logContent = @"
# Ollm Bridge Duplicate Models Log
# Ollm Bridge 重複模型日誌

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Total duplicate models found: $($duplicateModels.Count)

## Duplicate Model Details
## 重複模型詳細資訊

"@

    foreach ($duplicate in $duplicateModels) {
        $logContent += @"

### $($duplicate.ModelName)
- **Model Directory:** $($duplicate.ModelDir)
- **Existing Source:** $($duplicate.ExistingSource)
- **New Source:** $($duplicate.NewSource)
- **Detected Time:** $($duplicate.CreatedTime)

---
"@
    }

    $logContent += @"

## Resolution Notes
## 解決方案備註

- Models with the same name but different sources may indicate:
  - Different quantization levels with the same model name
  - Different versions of the same model
  - Corrupted or incomplete downloads
- Review the above entries to determine which version to keep
- Consider renaming models to avoid conflicts

"@

    # Write log to file
    # 將日誌寫入檔案
    $logContent | Out-File -FilePath $logFile -Encoding UTF8 -Force
    
    Write-Host "[!] $($duplicateModels.Count) duplicate model(s) detected and logged" -ForegroundColor Red
    Write-Host "[!] Check $logFile for details" -ForegroundColor Yellow
} else {
    Write-Host "[+] No duplicate models found" -ForegroundColor Green
}

Write-Host ""
Write-Host ""
Write-Host "*********************" -ForegroundColor Gray
Write-Host "Ollm Bridge complete." -ForegroundColor Green
Write-Host "Set the Models Directory in LMStudio to: $output_target_dir" -ForegroundColor Yellow 
