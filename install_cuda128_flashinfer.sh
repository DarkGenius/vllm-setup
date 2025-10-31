#!/bin/bash

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Требуемые версии
REQUIRED_CUDA_VERSION="12.8"
REQUIRED_NVCC_VERSION="12.8"
MIN_FLASHINFER_VERSION="0.4.0"
MIN_VLLM_VERSION="0.6.0"

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🔧 Проверка и установка CUDA Toolkit 12.8 + FlashInfer${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# ============================================================================
# Функции для проверки версий
# ============================================================================

version_ge() {
    # Сравнение версий: $1 >= $2
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

check_cuda_driver() {
    echo -e "${CYAN}🔍 Проверка CUDA драйвера...${NC}"
    
    if ! command -v nvidia-smi &>/dev/null; then
        echo -e "${RED}❌ nvidia-smi не найден. Убедитесь что NVIDIA драйвер установлен в Windows${NC}"
        exit 1
    fi
    
    DRIVER_CUDA=$(nvidia-smi | grep -oP 'CUDA Version: \K[0-9.]+' | head -1)
    echo -e "   Драйвер CUDA: ${GREEN}${DRIVER_CUDA}${NC}"
    
    if ! version_ge "$DRIVER_CUDA" "$REQUIRED_CUDA_VERSION"; then
        echo -e "${YELLOW}⚠️  Драйвер поддерживает CUDA ${DRIVER_CUDA}, требуется >= ${REQUIRED_CUDA_VERSION}${NC}"
        echo -e "${YELLOW}   Toolkit может работать нестабильно${NC}"
    else
        echo -e "   ${GREEN}✅ Драйвер совместим${NC}"
    fi
    
    echo ""
}

check_cuda_toolkit() {
    echo -e "${CYAN}🔍 Проверка CUDA Toolkit...${NC}"
    
    if ! command -v nvcc &>/dev/null; then
        echo -e "   ${YELLOW}nvcc не найден${NC}"
        return 1
    fi
    
    NVCC_VERSION=$(nvcc --version | grep -oP 'release \K[0-9.]+')
    echo -e "   Установленная версия nvcc: ${GREEN}${NVCC_VERSION}${NC}"
    
    if [ "$NVCC_VERSION" = "$REQUIRED_NVCC_VERSION" ]; then
        echo -e "   ${GREEN}✅ CUDA Toolkit ${NVCC_VERSION} уже установлен${NC}"
        
        # Проверка переменных окружения
        if [ -z "$CUDA_HOME" ]; then
            echo -e "   ${YELLOW}⚠️  CUDA_HOME не установлен${NC}"
            export CUDA_HOME=/usr/local/cuda-${NVCC_VERSION}
            export PATH=$CUDA_HOME/bin:$PATH
            export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
            echo -e "   Временно установлен: CUDA_HOME=$CUDA_HOME"
        else
            echo -e "   CUDA_HOME: ${GREEN}${CUDA_HOME}${NC}"
        fi
        
        return 0
    else
        echo -e "   ${YELLOW}Требуется версия ${REQUIRED_NVCC_VERSION}${NC}"
        return 1
    fi
}

check_python_env() {
    echo -e "${CYAN}🔍 Проверка Python окружения...${NC}"
    
    if [ ! -d ".venv" ]; then
        echo -e "   ${RED}❌ Виртуальное окружение .venv не найдено${NC}"
        echo -e "   Создайте его: ${YELLOW}uv venv${NC}"
        exit 1
    fi
    
    source .venv/bin/activate
    echo -e "   ${GREEN}✅ Окружение .venv активировано${NC}"
    echo ""
}

check_pytorch() {
    echo -e "${CYAN}🔍 Проверка PyTorch...${NC}"
    
    if ! python -c "import torch" 2>/dev/null; then
        echo -e "   ${YELLOW}PyTorch не установлен${NC}"
        return 1
    fi
    
    TORCH_VERSION=$(python -c "import torch; print(torch.__version__)" 2>/dev/null)
    TORCH_CUDA=$(python -c "import torch; print(torch.version.cuda)" 2>/dev/null)
    TORCH_CUDA_AVAILABLE=$(python -c "import torch; print(torch.cuda.is_available())" 2>/dev/null)
    
    echo -e "   PyTorch: ${GREEN}${TORCH_VERSION}${NC}"
    echo -e "   CUDA version: ${GREEN}${TORCH_CUDA}${NC}"
    echo -e "   CUDA available: ${GREEN}${TORCH_CUDA_AVAILABLE}${NC}"
    
    if [ "$TORCH_CUDA_AVAILABLE" = "True" ] && [ "$TORCH_CUDA" = "12.8" ]; then
        echo -e "   ${GREEN}✅ PyTorch настроен корректно для CUDA 12.8${NC}"
        return 0
    else
        echo -e "   ${YELLOW}⚠️  PyTorch требует переустановки для CUDA 12.8${NC}"
        return 1
    fi
}

check_vllm() {
    echo -e "${CYAN}🔍 Проверка vLLM...${NC}"
    
    if ! python -c "import vllm" 2>/dev/null; then
        echo -e "   ${YELLOW}vLLM не установлен${NC}"
        return 1
    fi
    
    VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)" 2>/dev/null)
    echo -e "   vLLM: ${GREEN}${VLLM_VERSION}${NC}"
    
    if version_ge "$VLLM_VERSION" "$MIN_VLLM_VERSION"; then
        echo -e "   ${GREEN}✅ vLLM версии ${VLLM_VERSION} совместим${NC}"
        return 0
    else
        echo -e "   ${YELLOW}⚠️  Требуется vLLM >= ${MIN_VLLM_VERSION}${NC}"
        return 1
    fi
}

check_flashinfer() {
    echo -e "${CYAN}🔍 Проверка FlashInfer...${NC}"
    
    if ! python -c "import flashinfer" 2>/dev/null; then
        echo -e "   ${YELLOW}FlashInfer не установлен${NC}"
        return 1
    fi
    
    FLASHINFER_VERSION=$(python -c "import flashinfer; print(flashinfer.__version__)" 2>/dev/null)
    echo -e "   FlashInfer: ${GREEN}${FLASHINFER_VERSION}${NC}"
    
    # Проверка что версия >= 0.4.0
    if version_ge "$FLASHINFER_VERSION" "$MIN_FLASHINFER_VERSION"; then
        echo -e "   ${GREEN}✅ FlashInfer ${FLASHINFER_VERSION} совместим${NC}"
        
        # Проверка что может импортироваться
        if python -c "import flashinfer; flashinfer.__version__" &>/dev/null; then
            echo -e "   ${GREEN}✅ FlashInfer работает корректно${NC}"
            return 0
        else
            echo -e "   ${YELLOW}⚠️  FlashInfer установлен но не работает${NC}"
            return 1
        fi
    else
        echo -e "   ${YELLOW}⚠️  Требуется FlashInfer >= ${MIN_FLASHINFER_VERSION}${NC}"
        return 1
    fi
}

# ============================================================================
# Функции установки
# ============================================================================

install_cuda_toolkit() {
    echo -e "${BLUE}📦 Установка CUDA Toolkit ${REQUIRED_CUDA_VERSION}...${NC}"
    echo ""
    
    # Установка ключа репозитория
    if [ ! -f cuda-keyring_1.1-1_all.deb ]; then
        echo "Скачивание ключа репозитория..."
        wget -q https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-keyring_1.1-1_all.deb
    fi
    
    sudo dpkg -i cuda-keyring_1.1-1_all.deb
    sudo apt-get update -qq
    
    # Установка CUDA Toolkit и зависимостей
    echo "Установка пакетов (это может занять 5-10 минут)..."
    sudo apt-get install -y -qq cuda-toolkit-12-8 ninja-build build-essential
    
    echo -e "${GREEN}✅ CUDA Toolkit ${REQUIRED_CUDA_VERSION} установлен${NC}"
    echo ""
    
    # Настройка переменных окружения
    export CUDA_HOME=/usr/local/cuda-12.8
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    # Проверка nvcc
    if nvcc --version &>/dev/null; then
        NVCC_VERSION=$(nvcc --version | grep -oP 'release \K[0-9.]+')
        echo -e "${GREEN}✅ nvcc ${NVCC_VERSION} работает${NC}"
    else
        echo -e "${RED}❌ nvcc не найден после установки${NC}"
        exit 1
    fi
    
    echo ""
}

setup_env_variables() {
    echo -e "${CYAN}📝 Настройка переменных окружения...${NC}"
    
    if grep -q "CUDA_HOME=/usr/local/cuda-12.8" ~/.bashrc 2>/dev/null; then
        echo -e "   ${GREEN}✅ Переменные уже настроены в ~/.bashrc${NC}"
    else
        echo ""
        cat >> ~/.bashrc << 'EOF'

# CUDA 12.8 для FlashInfer
export CUDA_HOME=/usr/local/cuda-12.8
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
EOF
        echo -e "   ${GREEN}✅ Переменные добавлены в ~/.bashrc${NC}"
        echo -e "   ${YELLOW}   Для применения в текущей сессии выполните: source ~/.bashrc${NC}"
    fi
    
    # Установка для текущей сессии
    export CUDA_HOME=/usr/local/cuda-12.8
    export PATH=$CUDA_HOME/bin:$PATH
    export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH
    
    echo ""
}

reinstall_pytorch() {
    echo -e "${BLUE}📦 Переустановка PyTorch для CUDA 12.8...${NC}"
    echo ""
    
    # Удаление старых версий
    echo "Удаление текущего PyTorch..."
    uv pip uninstall torch torchvision torchaudio -y 2>/dev/null || true
    
    # Установка PyTorch для CUDA 12.8
    echo "Установка PyTorch с CUDA 12.8..."
    uv pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128
    
    # Проверка
    if python -c "import torch; assert torch.cuda.is_available(), 'CUDA not available'" 2>/dev/null; then
        TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
        echo -e "${GREEN}✅ PyTorch ${TORCH_VERSION} установлен с CUDA 12.8${NC}"
    else
        echo -e "${RED}❌ Ошибка при установке PyTorch${NC}"
        exit 1
    fi
    
    echo ""
}

reinstall_vllm() {
    echo -e "${BLUE}📦 Переустановка vLLM...${NC}"
    echo ""
    
    echo "Установка vLLM..."
    uv pip install vllm
    
    if python -c "import vllm" 2>/dev/null; then
        VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)")
        echo -e "${GREEN}✅ vLLM ${VLLM_VERSION} установлен${NC}"
    else
        echo -e "${RED}❌ Ошибка при установке vLLM${NC}"
        exit 1
    fi
    
    echo ""
}

install_flashinfer() {
    echo -e "${BLUE}📦 Установка FlashInfer...${NC}"
    echo ""
    
    # Удаление старой версии
    uv pip uninstall flashinfer flashinfer-python -y 2>/dev/null || true
    
    # Попытка 1: Установка из GitHub release (v0.4.1)
    echo "Попытка 1: Установка FlashInfer 0.4.1 из GitHub releases..."
    if uv pip install https://github.com/flashinfer-ai/flashinfer/releases/download/v0.4.1/flashinfer_python-0.4.1-py3-none-any.whl 2>/dev/null; then
        echo -e "${GREEN}✅ FlashInfer 0.4.1 установлен из GitHub${NC}"
    else
        echo -e "${YELLOW}⚠️  Не удалось установить из GitHub releases${NC}"
        
        # Попытка 2: Wheels для CUDA 12.4 (совместимо с 12.8)
        echo "Попытка 2: Установка из flashinfer.ai wheels (CUDA 12.4)..."
        if uv pip install flashinfer-python --extra-index-url https://flashinfer.ai/whl/cu124/torch2.4/ 2>/dev/null; then
            echo -e "${GREEN}✅ FlashInfer установлен из wheels${NC}"
        else
            echo -e "${YELLOW}⚠️  Wheels не найдены${NC}"
            
            # Попытка 3: Сборка из исходников
            echo "Попытка 3: Сборка из исходников..."
            if uv pip install git+https://github.com/flashinfer-ai/flashinfer.git 2>/dev/null; then
                echo -e "${GREEN}✅ FlashInfer собран из исходников${NC}"
            else
                echo -e "${RED}❌ Не удалось установить FlashInfer${NC}"
                echo -e "${YELLOW}   vLLM будет работать без FlashInfer${NC}"
                return 1
            fi
        fi
    fi
    
    # Проверка работы
    echo ""
    echo "Проверка FlashInfer..."
    if python -c "import flashinfer; print(f'FlashInfer {flashinfer.__version__}')" 2>/dev/null; then
        FLASHINFER_VERSION=$(python -c "import flashinfer; print(flashinfer.__version__)")
        echo -e "${GREEN}✅ FlashInfer ${FLASHINFER_VERSION} работает!${NC}"
        return 0
    else
        echo -e "${YELLOW}⚠️  FlashInfer установлен но не импортируется${NC}"
        return 1
    fi
}

# ============================================================================
# Основная логика
# ============================================================================

main() {
    # Шаг 1: Проверка CUDA драйвера
    check_cuda_driver
    
    # Шаг 2: Проверка CUDA Toolkit
    CUDA_TOOLKIT_OK=false
    if check_cuda_toolkit; then
        CUDA_TOOLKIT_OK=true
        echo ""
    else
        echo ""
        read -p "Установить CUDA Toolkit ${REQUIRED_CUDA_VERSION}? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            install_cuda_toolkit
            setup_env_variables
            CUDA_TOOLKIT_OK=true
        else
            echo -e "${RED}❌ CUDA Toolkit необходим для FlashInfer${NC}"
            exit 1
        fi
    fi
    
    # Шаг 3: Проверка Python окружения
    check_python_env
    
    # Шаг 4: Проверка PyTorch
    PYTORCH_OK=false
    if check_pytorch; then
        PYTORCH_OK=true
        echo ""
    else
        echo ""
        read -p "Переустановить PyTorch для CUDA 12.8? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            reinstall_pytorch
            PYTORCH_OK=true
        else
            echo -e "${YELLOW}⚠️  PyTorch может работать некорректно${NC}"
            echo ""
        fi
    fi
    
    # Шаг 5: Проверка vLLM
    VLLM_OK=false
    if check_vllm; then
        VLLM_OK=true
        echo ""
    else
        echo ""
        read -p "Установить vLLM? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            reinstall_vllm
            VLLM_OK=true
        fi
        echo ""
    fi
    
    # Шаг 6: Проверка FlashInfer
    FLASHINFER_OK=false
    if check_flashinfer; then
        FLASHINFER_OK=true
        echo ""
    else
        echo ""
        read -p "Установить/переустановить FlashInfer? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if install_flashinfer; then
                FLASHINFER_OK=true
            fi
        fi
        echo ""
    fi
    
    # ========================================================================
    # Итоговый отчет
    # ========================================================================
    
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}📊 Итоговый статус${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    # Статус компонентов
    [ "$CUDA_TOOLKIT_OK" = true ] && echo -e "  ${GREEN}✅${NC} CUDA Toolkit 12.8" || echo -e "  ${RED}❌${NC} CUDA Toolkit 12.8"
    [ "$PYTORCH_OK" = true ] && echo -e "  ${GREEN}✅${NC} PyTorch с CUDA 12.8" || echo -e "  ${YELLOW}⚠️${NC} PyTorch"
    [ "$VLLM_OK" = true ] && echo -e "  ${GREEN}✅${NC} vLLM" || echo -e "  ${YELLOW}⚠️${NC} vLLM"
    [ "$FLASHINFER_OK" = true ] && echo -e "  ${GREEN}✅${NC} FlashInfer" || echo -e "  ${YELLOW}⚠️${NC} FlashInfer (опционально)"
    
    echo ""
    
    # Детальная информация
    if [ "$CUDA_TOOLKIT_OK" = true ]; then
        NVCC_VERSION=$(nvcc --version | grep -oP 'release \K[0-9.]+')
        echo -e "  nvcc: ${GREEN}${NVCC_VERSION}${NC}"
    fi
    
    if [ "$PYTORCH_OK" = true ]; then
        TORCH_VERSION=$(python -c "import torch; print(torch.__version__)")
        TORCH_CUDA=$(python -c "import torch; print(torch.version.cuda)")
        echo -e "  PyTorch: ${GREEN}${TORCH_VERSION}${NC} (CUDA ${TORCH_CUDA})"
    fi
    
    if [ "$VLLM_OK" = true ]; then
        VLLM_VERSION=$(python -c "import vllm; print(vllm.__version__)")
        echo -e "  vLLM: ${GREEN}${VLLM_VERSION}${NC}"
    fi
    
    if [ "$FLASHINFER_OK" = true ]; then
        FLASHINFER_VERSION=$(python -c "import flashinfer; print(flashinfer.__version__)")
        echo -e "  FlashInfer: ${GREEN}${FLASHINFER_VERSION}${NC}"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    # Следующие шаги
    if [ "$CUDA_TOOLKIT_OK" = true ] && [ "$PYTORCH_OK" = true ] && [ "$VLLM_OK" = true ]; then
        echo -e "${GREEN}🎉 Всё готово к работе!${NC}"
        echo ""
        echo "📋 Следующие шаги:"
        echo ""
        
        if ! grep -q "CUDA_HOME=/usr/local/cuda-12.8" ~/.bashrc 2>/dev/null; then
            echo "1. Примените переменные окружения:"
            echo "   source ~/.bashrc"
            echo ""
            echo "2. Запустите vLLM:"
        else
            echo "1. Запустите vLLM:"
        fi
        
        echo "   source .venv/bin/activate"
        echo "   ./start_server.sh --model qwen-7b"
        echo ""
        
        if [ "$FLASHINFER_OK" = true ]; then
            echo -e "${GREEN}✅ FlashInfer будет использоваться для оптимизации${NC}"
            echo "   При первом запуске может потребоваться 1-2 минуты на компиляцию kernels"
        else
            echo -e "${YELLOW}⚠️  vLLM будет работать без FlashInfer (производительность -10-20%)${NC}"
        fi
    else
        echo -e "${YELLOW}⚠️  Не все компоненты настроены${NC}"
        echo ""
        echo "vLLM может не работать оптимально. Проверьте статус выше."
    fi
    
    echo ""
}

# Запуск основной логики
main

