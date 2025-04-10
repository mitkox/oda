#!/bin/bash

# This file contains the install functions for the ODA installer

# Install base packages
install_base_packages() {
    log "Installing base packages..."
    
    local packages=(
        curl
        wget
        git
        zsh
        build-essential
    )
    
    # Update package lists
    $UPDATE_CMD
    
    # Install packages
    for package in "${packages[@]}"; do
        log "Installing $package..."
        $INSTALL_CMD "$package" || error "Failed to install $package"
    done
}

# Install Python
install_python() {
    log "Installing Python ${PYTHON_VERSION}..."
    
    case "$DISTRO" in
        ubuntu)
            # Add deadsnakes PPA for Python
            sudo add-apt-repository -y ppa:deadsnakes/ppa
            sudo apt-get update
            $INSTALL_CMD "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-venv" "python${PYTHON_VERSION}-dev"
            ;;
        redhat)
            # Enable EPEL repository
            $INSTALL_CMD epel-release
            # Install Python
            $INSTALL_CMD "python${PYTHON_VERSION}" "python${PYTHON_VERSION}-devel"
            ;;
    esac
}

# Setup Python environment
setup_python_environment() {
    log "Setting up Python virtual environment..."
    
    # Create virtual environment
    python${PYTHON_VERSION} -m venv "$VENV_DIR" || error "Failed to create virtual environment"
    
    # Upgrade pip
    source "$VENV_DIR/bin/activate"
    pip install --upgrade pip || error "Failed to upgrade pip"
    pip install -r requirements.txt || error "Failed to install Python AI packages from requirements.txt"
    deactivate
}

# Install NVIDIA components
install_nvidia() {
    if [ "$HAS_GPU" = false ]; then
        return
    fi
    
    log "Installing NVIDIA components..."
    
    case "$DISTRO" in
        ubuntu)
            # Add NVIDIA repository
            curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | 
                sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | 
                sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
            
            $UPDATE_CMD
            
            # Install NVIDIA drivers and CUDA
            $INSTALL_CMD nvidia-driver-$NVIDIA_VERSION cuda-toolkit
            
            # Install TensorRT
            $INSTALL_CMD tensorrt
            
            # Install NVIDIA Container Toolkit
            $INSTALL_CMD nvidia-container-toolkit
            ;;
            
        redhat)
            # Add NVIDIA repository
            sudo dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/rhel8/x86_64/cuda-rhel8.repo
            
            # Install NVIDIA drivers and CUDA
            $INSTALL_CMD nvidia-driver-$NVIDIA_VERSION cuda-toolkit
            
            # Install TensorRT
            $INSTALL_CMD tensorrt
            
            # Install NVIDIA Container Toolkit
            curl -s -L https://nvidia.github.io/libnvidia-container/stable/rpm/nvidia-container-toolkit.repo | 
                sudo tee /etc/yum.repos.d/nvidia-container-toolkit.repo
            $INSTALL_CMD nvidia-container-toolkit
            ;;
    esac
    
    # Install NVIDIA Triton
    sudo docker pull nvcr.io/nvidia/tritonserver:${TRITON_VERSION}-py3
    sudo docker pull nvcr.io/nvidia/tritonserver:${TRITON_VERSION}-py3-sdk
    
    # Install NVIDIA Nsight Systems
    case "$DISTRO" in
        ubuntu)
            $INSTALL_CMD nsight-systems
            ;;
        redhat)
            $INSTALL_CMD nsight-systems
            ;;
    esac
}

# Setup Docker
setup_docker() {
    log "Setting up Docker..."
    
    case "$DISTRO" in
        ubuntu)
            # Install Docker using official repository
            curl -fsSL https://get.docker.com -o get-docker.sh
            sudo sh get-docker.sh
            rm get-docker.sh
            ;;
        redhat)
            # Add Docker repository
            sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
            $INSTALL_CMD docker-ce docker-ce-cli containerd.io
            sudo systemctl start docker
            sudo systemctl enable docker
            ;;
    esac
    
    # Add user to docker group
    sudo usermod -aG docker "$USER"
    
    if [ "$HAS_GPU" = true ]; then
        # Install NVIDIA Container Toolkit
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
        curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
        
        case "$DISTRO" in
            ubuntu)
                sudo apt-get update
                $INSTALL_CMD nvidia-docker2
                ;;
            redhat)
                sudo dnf clean all
                $INSTALL_CMD nvidia-docker2
                ;;
        esac
        
        sudo systemctl restart docker
    fi
}

# Setup development tools
setup_development_tools() {
    log "Setting up development tools..."
    # VS Code installation
    if [ "$INSTALL_VSCODE" = true ]; then
        run_step "vscode" _install_vscode || return 1
    fi
    
    # Oh My Zsh installation
    if [ "$INSTALL_ZSH" = true ]; then
        run_step "oh-my-zsh" _install_oh_my_zsh || return 1
    fi
    
    # llama.cpp installation
    if [ "$INSTALL_LLAMA_CPP" = true ]; then
        run_step "llama-cpp" _install_llama_cpp || return 1
    fi
}

_install_vscode() {
    case "$DISTRO" in
        ubuntu)
            log "Installing VS Code..."
            sudo apt install code
            ;;
        redhat)
            log "Installing VS Code..."
            sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
            sudo sh -c 'echo -e "[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
            $INSTALL_CMD code
            ;;
    esac
    return 0
}

_install_oh_my_zsh() {
    if [ -d "$HOME/.oh-my-zsh" ]; then
        log "Oh My Zsh is already installed. Skipping installation..."
        if [ -d "$HOME/.oh-my-zsh/.git" ]; then
            log "Updating Oh My Zsh via git..."
            (cd "$HOME/.oh-my-zsh" && git pull)
        fi
    else
        log "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    return 0
}

_install_llama_cpp() {
    LLAMA_DIR="$INSTALL_DIR/llama.cpp"
    if [ -d "$LLAMA_DIR" ]; then
        log "llama.cpp directory already exists. Updating..."
        cd "$LLAMA_DIR"
        git pull origin master
    else
        log "Cloning llama.cpp..."
        git clone https://github.com/ggerganov/llama.cpp.git "$LLAMA_DIR"
        cd "$LLAMA_DIR"
    fi
    
    log "Building llama.cpp..."
    if [ "$HAS_GPU" = true ]; then
        make clean && make CUDA=1
    else
        make clean && make
    fi
    return 0
}

# Setup AI tools
setup_ai_tools() {
    log "Setting up AI tools..."
    # Install TVM dependencies
    if [ "$INSTALL_TVM" = true ]; then
        run_step "tvm-deps" _install_tvm_deps || return 1
    fi
    
    # Install and build TVM
    if [ "$INSTALL_TVM" = true ]; then
        run_step "tvm" _install_tvm || return 1
    fi
    
    # Install Python AI packages
    run_step "python-ai-packages" _install_python_ai_packages || return 1
    
    # Install OpenVINO
    if [ "$INSTALL_OPEN_VINO" = true ]; then
        run_step "openvino" _install_openvino || return 1
    fi
    
    # Install NCNN
    if [ "$INSTALL_NCNN" = true ]; then
        run_step "ncnn" _install_ncnn || return 1
    fi
    
    # Install ARM NN (only for aarch64)
    if [ "$(uname -m)" = "aarch64" ] && [ "$INSTALL_ARMNN" = true ]; then
        run_step "armnn" _install_armnn || return 1
    fi
}

_install_tvm_deps() {
    case "$DISTRO" in
        ubuntu)
            $INSTALL_CMD cmake build-essential git python3-dev python3-setuptools gcc libtinfo-dev zlib1g-dev libedit-dev libxml2-dev
            ;;
        redhat)
            $INSTALL_CMD cmake gcc-c++ git python3-devel python3-setuptools ncurses-devel zlib-devel
            ;;
    esac
    return 0
}

_install_tvm() {
    log "Installing TVM..."
    source "$VENV_DIR/bin/activate"
    pip install apache-tvm==${TVM_VERSION}
    deactivate
    return 0
}

_install_python_ai_packages() {
    log "Installing Python AI packages..."
    return 0
}

_install_openvino() {
    case "$DISTRO" in
        ubuntu)
            wget https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
            sudo apt-key add GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB
            echo "deb https://apt.repos.intel.com/openvino/2023 ubuntu22 main" | sudo tee /etc/apt/sources.list.d/intel-openvino-2023.list
            $UPDATE_CMD
            $INSTALL_CMD intel-openvino-dev-ubuntu22
            ;;
        redhat)
            sudo dnf config-manager --add-repo https://yum.repos.intel.com/openvino/2023/setup/intel-openvino-2023.repo
            $INSTALL_CMD intel-openvino-dev
            ;;
    esac
    return 0
}

_install_ncnn() {
    log "Installing NCNN..."
    git clone https://github.com/Tencent/ncnn.git
    cd ncnn
    mkdir -p build
    cd build
    if [ "$HAS_GPU" = true ]; then
        cmake -DNCNN_VULKAN=ON ..
    else
        cmake ..
    fi
    make -j$(nproc)
    sudo make install
    cd ../..
    return 0
}

_install_armnn() {
    log "Installing Arm NN..."
    git clone https://github.com/ARM-software/armnn.git
    cd armnn
    mkdir -p build
    cd build
    cmake .. 
        -DARMCOMPUTE_ROOT=/usr/local/include 
        -DARMCOMPUTE_BUILD_DIR=/usr/local/lib
    make -j$(nproc)
    sudo make install
    cd ../..
    return 0
}