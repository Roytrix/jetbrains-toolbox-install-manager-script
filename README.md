# JetBrains Toolbox Install Manager Script

This Bash script provides a simple way to install, uninstall, and manage JetBrains Toolbox on Linux systems.

## Features

- **Installation**: Downloads and installs the latest version of JetBrains Toolbox
- **Uninstallation**: Completely removes JetBrains Toolbox from your system
- **Status Check**: Shows which JetBrains tools are currently running
- **Interactive Mode**: Simple menu-driven interface
- **Command-Line Interface**: For direct operations or scripting

## Requirements

The script requires the following tools to be installed:

- `curl` - For API requests and downloads
- `wget` - For downloading the installer
- `tar` - For extracting the archive
- `grep`, `find` - For text processing and file searching
- `sudo` - For operations that may require elevated permissions

## Installation Paths

- Download directory: `$HOME/Downloads`
- Install directory: `$HOME/.local/share/jetbrains-toolbox`
- Desktop entry: `$HOME/.local/share/applications/jetbrains-toolbox.desktop`
- Log file: `/tmp/jetbrains-toolbox-install.log`

## Usage

### Interactive Mode

Run the script without arguments to use the interactive menu:

```bash
./install_jetbrains_toolbox.sh
```

### Command-Line Options

```bash
./install_jetbrains_toolbox.sh [options]

Options:
  --install       Install JetBrains Toolbox (default)
  --uninstall     Uninstall JetBrains Toolbox
  --status        Show currently running JetBrains tools
  --help          Display help and exit
```

## Examples

Install JetBrains Toolbox:

```bash
./install_jetbrains_toolbox.sh --install
```

Uninstall JetBrains Toolbox:

```bash
./install_jetbrains_toolbox.sh --uninstall
```

Check which JetBrains tools are running:

```bash
./install_jetbrains_toolbox.sh --status
```

## Compatibility

This script has been tested on Red Hat Enterprise Linux 9 and may require modifications for other Linux distributions.

## Features in Detail

1. **Automatic Detection**: Automatically finds and downloads the latest version of JetBrains Toolbox
2. **Clean Uninstallation**: Properly removes all associated files and directories
3. **Process Management**: Detects and optionally closes running JetBrains tools
4. **Desktop Integration**: Creates a desktop entry for easy access
5. **Error Handling**: Automatically cleans up in case of installation failures
6. **Logging**: Maintains detailed logs of all operations

## License

This script is provided as-is with no warranties. Use at your own risk.
