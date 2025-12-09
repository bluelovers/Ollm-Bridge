# Ollm Bridge v0.6 - Easy Access to Ollama Models for LMStudio Users

## What is this?
Ollm Bridge is a simple tool designed to streamline the process of accessing Ollama models within LMStudio. It automatically creates directories, symlinks, and organizes files based on the manifest information from the Ollama registry.
 * **Available in two versions:**
   - PowerShell Script (`Ollm_Bridge_v0.6.ps1`)
   - Executable File (`Ollm_Bridge_v0.6.exe`), built with MScholtes' PS2EXE module)

## How do I use it?
1. Download the desired version of Ollm Bridge from our repository or release page.
2. Run the executable as an administrator (right-click > Run as administrator) or execute the PowerShell script in PowerShell as an administrator.

### Command Line Options (PowerShell Script Only)
- `.Ollm_Bridge_v0.6.ps1 -SafeMode true` - Skip directory deletion (auto-skip)
- `.Ollm_Bridge_v0.6.ps1 -SafeMode false` - Auto-execute without confirmation
- `.Ollm_Bridge_v0.6.ps1 -SafeMode null` - Manual confirmation required
- `.Ollm_Bridge_v0.6.ps1` - Default: Manual confirmation

### New Features
- **Safety Controls**: Protects against accidental directory deletion
- **Duplicate Detection**: Logs conflicting models with different sources to `log.md`
- **Parameter Support**: Control behavior via command line arguments
- **Error Handling**: Improved error messages and recovery

3. After completion, set your LMStudio Models Directory to `%userprofile%\publicmodels`.

## Credits
* Thanks to [Matt Williams](https://github.com/technovangelist) for [inspiration](https://youtu.be/UfhXbwA5thQ?si=ML8x01C26kNStTJw)
* Thanks to [MScholtes](https://github.com/MScholtes) for the [PS2EXE](https://github.com/MScholtes/PS2EXE) module
* Code written primarly by Beyonder 24B 5_K_M (LMStudio, Ryzen 5 3600x, GTX 960)


#####             README written by Aidain, an AI Assistant
