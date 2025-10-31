#!/bin/bash

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 Автоматическая настройка CUDA + FlashInfer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Определение версии CUDA из драйвера
# ============================================================================

echo -e "${CYAN}🔍 Определение версии CUDA драйвера...${NC}"

if ! command -v nvidia-smi &>/dev/null; then
    echo -e "${RED}❌ nvidia-smi не найден${NC}"
    exit 1
fi

DRIVER_CUDA_FULL=$(nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+' | head -1)
DRIVER_CUDA_MAJOR=$(echo "$DRIVER_CUDA_FULL" | cut -d'.' -f1)
DRIVER_CUDA_MINOR=$(echo "$DRIVER_CUDA_FULL" | cut -d'.' -f2)

echo -e "   Драйвер CUDA: ${GREEN}${DRIVER_CUDA_FULL}${NC}"
echo ""

# Определяем нужную версию Toolkit
if [ "$DRIVER_CUDA_MAJOR" -eq 13 ]; then
    TOOLKIT_VERSION="13.0"
    TOOLKIT_PACKAGE="cuda-toolkit-13-0"
    CUDA_PATH="/usr/local/cuda-13.0"
    PYTORCH_CUDA="cu130"  # Если доступен
    PYTORCH_URL="https://download.pytorch.org/whl/nightly/cu130"
    FLASHINFER_CUDA="cu130"
elif [ "$DRIVER_CUDA_MAJOR" -eq 12 ]; then
    if [ "$DRIVER_CUDA_MINOR" -ge 8 ]; then
        TOOLKIT_VERSION="12.8"
        TOOLKIT_PACKAGE="cuda-toolkit-12-8"
        CUDA_PATH="/usr/local/cuda-12.8"
        PYTORCH_CUDA="cu128"
        PYTORCH_URL="https://download.pytorch.org/whl/cu128"
        FLASHINFER_CUDA="cu124"  # Используем 12.4 (совместимо)
    else
        TOOLKIT_VERSION="12.1"
        TOOLKIT_PACKAGE="cuda-toolkit-12-1"
        CUDA_PATH="/usr/local/cuda-12.1"
        PYTORCH_CUDA="cu121"
        PYTORCH_URL="https://download.pytorch.org/whl/cu121"
        FLASHINFER_CUDA="cu121"
    fi
else
    echo -e "${RED}❌ Неподдерживаемая версия CUDA: ${DRIVER_CUDA_FULL}${NC}"
    exit 1
fi

echo -e "${CYAN}📋 План установки:${NC}"
echo -e "   CUDA Toolkit: ${GREEN}${TOOLKIT_VERSION}${NC}"
echo -e "   PyTorch: ${GREEN}${PYTORCH_CUDA}${NC}"
echo -e "   FlashInfer: ${GREEN}${FLASHINFER_CUDA}${NC}"
echo ""

read -p "Продолжить? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

echo ""

# ============================================================================
# Проверка установленного Toolkit
# ============================================================================

check_toolkit() {
    if ! command -v nvcc &>/dev/null; then
        return 1
    fi
    
    NVCC_VERSION=$(nvcc --version | grep -oP 'release \K[0-9.]+')
    if [ "$NVCC_VERSION" = "$TOOLKIT_VERSION" ]; then
        echo -e "${GREEN}✅ CUDA Toolkit ${TOOLKIT_VERSION} уже установлен${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  Установлен Toolkit ${NVCC_VERSION}, требуется ${TOOLKIT_VERSION}${NC}"
        return 1
    fi
}

# ============================================================================
# Установка CUDA Toolkit
# ============================================================================

install_toolkit() {
    echo -e "${BLUE}📦 Установка CUDA Toolkit ${TOOLKIT_VERSION}...${NC}"
    echo ""
    
    # Установка ключа репозитория (если нужно)
    if [ ! -f cuda-keyring_1.1-1_all.deb ]; then
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
    fi
    
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update -qq
    
    # Установка пакетов
    echo "Установка ${TOOLKIT_PACKAGE} (это может занять 5-10 минут)..."
    sudo apt-get install -y -qq ${TOOLKIT_PACKAGE} ninja-build build-essential
    
    echo -e "${GREEN}✅ CUDA Toolkit ${TOOLKIT_VERSION} установлен${NC}"
    echo ""
    
    # Настройка переменных
    export CUDA_HOME=${CUDA_PATH}
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    # Проверка
    if nvcc --version &>/dev/null; then
        NVCC_VERSION=$(nvcc --version | grep -oP 'release \K[0-9.]+')
        echo -e "${GREEN}✅ nvcc ${NVCC_VERSION} работает${NC}"
    fi
    
    echo ""
}

# ============================================================================
# Настройка переменных окружения
# ============================================================================

setup_env() {
    echo -e "${CYAN}📝 Настройка переменных окружения...${NC}"
    
    if grep -q "CUDA_HOME=${CUDA_PATH}" ~/.bashrc 2>/dev/null; then
        echo -e "   ${GREEN}✅ Переменные уже настроены${NC}"
    else
        cat >> ~/.bashrc << EOF

# CUDA ${TOOLKIT_VERSION} для FlashInfer
export CUDA_HOME=${CUDA_PATH}
export PATH=\$CUDA_HOME/bin:\$PATH
export LD_LIBRARY_PATH=\$CUDA_HOME/lib64:\$LD_LIBRARY_PATH
EOF
        echo -e "   ${GREEN}✅ Переменные добавлены в ~/.bashrc${NC}"
    fi
    
    # Установка для текущей сессии
    export CUDA_HOME=${CUDA_PATH}
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    echo ""
}

# ============================================================================
# Проверка и установка Python пакетов
# ============================================================================

setup_python() {
    echo -e "${CYAN}📦 Настройка Python окружения...${NC}"
    echo ""
    
    if [ ! -d ".venv" ]; then
        echo -e "${RED}❌ .venv не найден${NC}"
        exit 1
    fi
    
    source .venv/bin/activate
    
    # Проверка PyTorch
    NEEDS_PYTORCH=false
    if ! python -c "import torch" 2>/dev/null; then
        echo "PyTorch не установлен"
        NEEDS_PYTORCH=true
    else
        TORCH_CUDA=$(python -c "import torch; print(torch.version.cuda)" 2>/dev/null)
        if [ "$TORCH_CUDA" != "${DRIVER_CUDA_MAJOR}.${DRIVER_CUDA_MINOR}" ]; then
            echo "PyTorch CUDA ${TORCH_CUDA} != Driver CUDA ${DRIVER_CUDA_FULL}"
            NEEDS_PYTORCH=true
        fi
    fi
    
    # Установка PyTorch если нужно
    if [ "$NEEDS_PYTORCH" = true ]; then
        echo "Установка PyTorch для CUDA ${PYTORCH_CUDA}..."
        
        # Для CUDA 13.0 может не быть stable релиза
        if [ "$DRIVER_CUDA_MAJOR" -eq 13 ]; then
            echo -e "${YELLOW}⚠️  CUDA 13.0 может требовать nightly PyTorch${NC}"
            
            # Попытка 1: Nightly
            if uv pip install --pre torch torchvision torchaudio --index-url ${PYTORCH_URL} 2>/dev/null; then
                echo -e "${GREEN}✅ PyTorch nightly установлен${NC}"
            else
                # Fallback на CUDA 12.8
                echo -e "${YELLOW}⚠️  Используем PyTorch для CUDA 12.8 (совместимо)${NC}"
                uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
            fi
        else
            uv pip install torch torchvision torchaudio --index-url ${PYTORCH_URL}
        fi
        
        echo -e "${GREEN}✅ PyTorch установлен${NC}"
    else
        echo -e "${GREEN}✅ PyTorch уже настроен корректно${NC}"
    fi
    
    echo ""
    
    # Проверка vLLM
    if ! python -c "import vllm" 2>/dev/null; then
        echo "Установка vLLM..."
        uv pip install vllm
        echo -e "${GREEN}✅ vLLM установлен${NC}"
    else
        VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)")
        echo -e "${GREEN}✅ vLLM ${VLLM_VERSION} установлен${NC}"
    fi
    
    echo ""
    
    # FlashInfer
    echo "Установка FlashInfer..."
    uv pip uninstall flashinfer flashinfer-python -y 2>/dev/null || true
    
    # Попытка установки
    if uv pip install https://github.com/flashinfer-ai/flashinfer/releases/download/v0.4.1/flashinfer_python-0.4.1-py3-none-any.whl 2>/dev/null; then
        echo -e "${GREEN}✅ FlashInfer 0.4.1 установлен${NC}"
    elif uv pip install flashinfer-python --extra-index-url https://flashinfer.ai/whl/${FLASHINFER_CUDA}/torch2.4/ 2>/dev/null; then
        echo -e "${GREEN}✅ FlashInfer установлен${NC}"
    else
        echo -e "${YELLOW}⚠️  FlashInfer не удалось установить, vLLM будет работать без него${NC}"
    fi
    
    echo ""
}

# ============================================================================
# Основная логика
# ============================================================================

main() {
    # Проверка и установка Toolkit
    if ! check_toolkit; then
        install_toolkit
        setup_env
    else
        # Убедимся что переменные установлены
        if [ -z "$CUDA_HOME" ]; then
            export CUDA_HOME=${CUDA_PATH}
            export PATH=$CUDA_HOME/bin:$PATH
            export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
        fi
    fi
    
    # Настройка Python
    setup_python
    
    # Итоговый отчет
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}🎉 Установка завершена!${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    echo "📊 Конфигурация:"
    echo -e "   Driver CUDA: ${GREEN}${DRIVER_CUDA_FULL}${NC}"
    echo -e "   Toolkit: ${GREEN}${TOOLKIT_VERSION}${NC}"
    
    if [ -d ".venv" ]; then
        source .venv/bin/activate
        TORCH_VER=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
        TORCH_CUDA=$(python -c "import torch; print(torch.version.cuda)" 2>/dev/null)
        echo -e "   PyTorch: ${GREEN}${TORCH_VER}${NC} (CUDA ${TORCH_CUDA})"
        
        if python -c "import flashinfer" 2>/dev/null; then
            FI_VER=$(python -c "import flashinfer; print(flashinfer.__version__)" 2>/dev/null)
            echo -e "   FlashInfer: ${GREEN}${FI_VER}${NC}"
        fi
    fi
    
    echo ""
    echo "📋 Следующие шаги:"
    echo "   source ~/.bashrc"
    echo "   source .venv/bin/activate"
    echo "   ./start_server.sh --model qwen-7b"
    echo ""
}

main

