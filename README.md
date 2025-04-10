# ODA (On Device AI)

Turn your Linux system into a fully-configured, sleek, and modern on-device AI development system by running a single command.

Radicle: `rad://z2ELVemM12PrcCMfi7dQCTHfsWPNh`

### 2025-04 Changelog Summary:

- **Feature Enhancements:**
  - Enhanced GPU support with automatic CUDA version detection and installation.
  - Expanded AI/ML library selection with the inclusion of Transformers and Hugging Face libraries.
  - Added support for PyTorch 2.2.1 and CUDA 12.1.
- **Package Updates:**
  - Updated TensorFlow to version 2.15.0.
  - Updated CUDA Driver to version 535.
- **Distribution Support:**
  - Extended support to include Debian 12 and Fedora 39.

## Overview

ODA is a comprehensive setup script that transforms a fresh Linux installation into a complete AI development environment. It automates the installation and configuration of essential tools, libraries, and environments commonly used in AI development.

## Features

- One-command setup
- Command-line options for flexible installation
- Robust logging system with multiple levels
- Automatic distribution detection and configuration (Ubuntu, Debian, RedHat, Fedora, CentOS)
- Configuration backup and resume capability
- Essential development tools
- Python environment with AI/ML libraries (version-pinned)
- Docker configuration
- GPU drivers and CUDA setup (if available)
- Development environment configurations
- Performance optimizations
- Strict error handling and validation
- Version compatibility checks

## Quick Start

```bash
# Option 1: Direct execution (recommended)
curl -sSL https://raw.githubusercontent.com/mitkox/oda/main/oda.sh | bash

# Option 2: Download and inspect before running
curl -O https://raw.githubusercontent.com/mitkox/oda/main/oda.sh
chmod +x oda.sh
./oda.sh [OPTIONS]
```

### Command-Line Options

```bash
Usage: ./oda.sh [OPTIONS]
Options:
  -y, --yes        Non-interactive mode, assume yes for all prompts
  -d, --dry-run    Show what would be installed without making changes
  -v, --verbose    Enable verbose logging
  -h, --help       Show this help message
  --no-gpu         Skip GPU-related installations
  --resume         Resume from last failed step
```

### Examples

```bash
# Non-interactive installation
./oda.sh -y

# Verbose installation without GPU support
./oda.sh -v --no-gpu

# Resume a failed installation
./oda.sh --resume

# Show what would be installed without making changes
./oda.sh --dry-run
```

After installation, activate the Python virtual environment:
```bash
source ~/.oda-venv/bin/activate
```

## What Gets Installed

- System essentials (git, curl, build tools)
- Python 3.10 with virtual environment
- Version-pinned AI/ML libraries:
  - PyTorch 2.2.1
  - TensorFlow 2.15.0
  - CUDA 12.1
  - NumPy 1.24.3
  - pandas 2.1.1
  - scikit-learn 1.3.1
  - Transformers
  - Hugging Face libraries
- llama.cpp with CUDA support (when GPU available)
- Docker and NVIDIA Container Toolkit
- Development tools (VS Code)
- Shell improvements (zsh, oh-my-zsh)
- NVIDIA driver 535 and CUDA (if GPU available)

## Requirements

### Updated Requirements

#### Supported Distributions
- Ubuntu 20.04 LTS, 22.04 LTS, or newer
- Debian 11, 12, or newer
- Red Hat Enterprise Linux 8, 9, or newer
- Fedora 38, 39, or newer
- CentOS Stream 8, 9, or newer
- Rocky Linux 8, 9, or newer
- AlmaLinux 8, 9, or newer
### Supported Distributions

### System Requirements
- Internet connection
- Sudo privileges
- 20GB free disk space
- NVIDIA GPU (optional, for GPU acceleration)

## Features

### Error Handling
- Strict error checking with detailed error messages
- Disk space validation
- System compatibility checks
- Detailed installation logs at `/tmp/oda-install.log`

### Python Environment
- Isolated virtual environment at `~/.oda-venv`
- Version-pinned dependencies for stability
- Pre-configured for AI/ML development

### GPU Support
- Automatic NVIDIA GPU detection
- CUDA-enabled builds when GPU is available
- Containerized GPU support with NVIDIA Docker
- Fallback to CPU-only versions when no GPU is present

### Distribution Support
- Automatic distribution detection
- Distribution-specific optimizations
- Automatic package manager detection
- Distribution-specific repository management

### Security Features
- HTTPS-only downloads
- GPG key verification for repositories
- Secure temporary file handling
- Principle of least privilege
- Comprehensive error checking

### On-Device AI Development Tools

#### Model Serving and Inference
- NVIDIA Triton Inference Server ${TRITON_VERSION}
- TensorRT ${TENSORRT_VERSION}
- ONNX Runtime with GPU support
- TensorFlow Lite
- OpenVINO
- Apache TVM ${TVM_VERSION}

#### Edge AI and Mobile
- MediaPipe
- Edge Impulse CLI
- NCNN for mobile devices
- ARM NN SDK (on ARM devices)
- PyTorch Mobile
- TensorFlow Lite

#### Model Optimization
- Neural Network Distiller
- TensorFlow Model Optimization
- Intel Neural Compressor
- Torch2TRT
- NVIDIA TensorRT

#### Performance Tools
- MLPerf for benchmarking
- NVIDIA Nsight Systems
- perf for profiling
- CUDA Toolkit

#### Additional Frameworks
- PaddlePaddle Lite
- MXNet
- ARM Compute Library (on ARM)

## Installation Directory Structure

```
$HOME/
├── .oda/                    # Main installation directory
│   └── llama.cpp/          # llama.cpp installation
└── .oda-venv/              # Python virtual environment
```

## Troubleshooting

### Installation Logs
Check the installation log for detailed information:
```bash
cat /tmp/oda-install.log
```

### Common Issues
1. **GPU Not Detected**: Ensure NVIDIA drivers are properly installed
2. **Package Installation Fails**: Check internet connection and try again
3. **Permission Issues**: Ensure you have sudo privileges
4. **Space Issues**: Ensure you have at least 20GB free space

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes:

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details

## Security

For security concerns, please see our [Security Policy](SECURITY.md)
