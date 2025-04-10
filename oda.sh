#!/bin/bash

# Enable strict mode for better error handling
set -euo pipefail
trap 'error "Failed at line $LINENO. Exit code: $?"' ERR

# Source configuration and function files
source oda.conf
source setup_functions.sh
source install_functions.sh

# ODA Installer version
ODA_INSTALLER_VERSION="0.1.0"

# Initialize global variables
DISTRO=""
PACKAGE_MANAGER=""
INSTALL_CMD=""
UPDATE_CMD=""
HAS_GPU=false
VERBOSE=false

# Main function - Script entry point
main() {
    # Print banner
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════╗"
    echo "║               ODA Installer               ║"
    echo "║     On Device AI Development Setup        ║"
    echo "╚═══════════════════════════════════════════╝"
    echo -e "${NC}"
    
    # Display installer version
    echo "ODA Installer version: $ODA_INSTALLER_VERSION"
    echo ""

    # Check if the script is run with any arguments
    if [ $# -eq 0 ]; then
        error "No arguments provided. Use -h or --help for usage information."
    fi

    # Parse command-line arguments
    while getopts ":h-:" opt; do
        case "$opt" in
            h)
                usage
                exit 0
                ;;
            -)
                case "${OPTARG}" in
                    help)
                        usage
                        exit 0
                        ;;
                    no-gpu)
                        HAS_GPU=false
                        ;;
                    verbose)
                        VERBOSE=true
                        ;;
                    *)
                        echo "Invalid option: --${OPTARG}" >&2
                        usage
                        exit 1
                        ;;
                esac
                ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                usage
                exit 1
                ;;
        esac
    done
    shift $((OPTIND -1))

    log "Starting ODA installation..."
    
    # Validate system requirements
    validate_system_requirements
    
    # Detect user type

    # Detect distribution
    detect_distribution
    
    # Setup package manager
    setup_package_manager
    
    # Interactive prompts for component selection
    read -r -p "Install PyTorch? (y/N) " INSTALL_PYTORCH_PROMPT
    if [[ "$INSTALL_PYTORCH_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_PYTORCH=true
    else
        INSTALL_PYTORCH=false
    fi

    read -r -p "Install TensorFlow? (y/N) " INSTALL_TENSORFLOW_PROMPT
    if [[ "$INSTALL_TENSORFLOW_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_TENSORFLOW=true
    else
        INSTALL_TENSORFLOW=false
    fi

    read -r -p "Install TVM? (y/N) " INSTALL_TVM_PROMPT
    if [[ "$INSTALL_TVM_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_TVM=true
    else
        INSTALL_TVM=false
    fi

    read -r -p "Install OpenVINO? (y/N) " INSTALL_OPEN_VINO_PROMPT
    if [[ "$INSTALL_OPEN_VINO_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_OPEN_VINO=true
    else
        INSTALL_OPEN_VINO=false
    fi

    read -r -p "Install NCNN? (y/N) " INSTALL_NCNN_PROMPT
    if [[ "$INSTALL_NCNN_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_NCNN=true
    else
        INSTALL_NCNN=false
    fi

    read -r -p "Install ArmNN? (y/N) " INSTALL_ARMNN_PROMPT
    if [[ "$INSTALL_ARMNN_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_ARMNN=true
    else
        INSTALL_ARMNN=false
    fi

    read -r -p "Install llama.cpp? (y/N) " INSTALL_LLAMA_CPP_PROMPT
    if [[ "$INSTALL_LLAMA_CPP_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_LLAMA_CPP=true
    else
        INSTALL_LLAMA_CPP=false
    fi

    read -r -p "Install VS Code? (y/N) " INSTALL_VSCODE_PROMPT
    if [[ "$INSTALL_VSCODE_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_VSCODE=true
    else
        INSTALL_VSCODE=false
    fi

    read -r -p "Install ZSH? (y/N) " INSTALL_ZSH_PROMPT
    if [[ "$INSTALL_ZSH_PROMPT" =~ ^[Yy]$ ]]; then
        INSTALL_ZSH=true
    else
        INSTALL_ZSH=false
    fi

    # Call setup and installation functions
    run_step "base" install_base_packages || return 1
    run_step "python" install_python || return 1
    run_step "python-env" setup_python_environment || return 1
    if [ "$HAS_GPU" = true ]; then
        run_step "nvidia" install_nvidia || return 1
    fi
    run_step "docker" setup_docker || return 1
    run_step "dev-tools" setup_development_tools || return 1
    run_step "ai-tools" setup_ai_tools || return 1

    # Installation completed successfully
    log "ODA installation completed successfully!"
    echo -e "\nTo activate the Python environment, run: ${GREEN}source $VENV_DIR/bin/activate${NC}"
    echo -e "To start using ZSH, run: ${GREEN}zsh${NC}"
    echo -e "Installation log: $LOG_FILE"
}

# Execute the main function with command-line arguments
main "$@"