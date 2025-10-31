#!/bin/bash

# Скрипт для полной деинсталляции CUDA Toolkit из WSL2

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}🗑️  Деинсталляция CUDA Toolkit${NC}"
echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Предупреждение
echo -e "${YELLOW}⚠️  ВНИМАНИЕ:${NC}"
echo "Этот скрипт удалит:"
echo "  - CUDA Toolkit (все версии)"
echo "  - nvcc компилятор"
echo "  - CUDA библиотеки из /usr/local/cuda*"
echo "  - Переменные окружения из ~/.bashrc"
echo "  - Кеш FlashInfer"
echo ""
echo -e "${YELLOW}НЕ будет удалено:${NC}"
echo "  - NVIDIA драйвер (он нужен для работы GPU)"
echo "  - PyTorch и vLLM (останутся в .venv)"
echo ""

read -p "Продолжить деинсталляцию? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${GREEN}Отменено${NC}"
    exit 0
fi

echo ""

# Проверка установленных пакетов CUDA
echo -e "${BLUE}🔍 Шаг 1/7: Поиск установленных CUDA пакетов...${NC}"
CUDA_PACKAGES=$(dpkg -l | grep -i cuda | awk '{print $2}' | grep -v "cuda-keyring" || true)

if [ -z "$CUDA_PACKAGES" ]; then
    echo "ℹ️  CUDA пакеты не найдены через apt"
else
    echo "Найдены пакеты:"
    echo "$CUDA_PACKAGES" | sed 's/^/  - /'
fi

echo ""

# Остановка процессов использующих CUDA
echo -e "${BLUE}🛑 Шаг 2/7: Остановка процессов использующих CUDA...${NC}"

# Остановка vLLM если запущен
if pgrep -f "vllm.entrypoints" > /dev/null; then
    echo "Остановка vLLM..."
    pkill -f "vllm.entrypoints" || true
    sleep 2
fi

# Проверка других процессов
if command -v nvidia-smi &> /dev/null; then
    CUDA_PROCS=$(nvidia-smi --query-compute-apps=pid --format=csv,noheader 2>/dev/null || true)
    if [ -n "$CUDA_PROCS" ]; then
        echo -e "${YELLOW}⚠️  Обнаружены процессы использующие GPU:${NC}"
        nvidia-smi --query-compute-apps=pid,name --format=csv
        echo ""
        read -p "Остановить эти процессы? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "$CUDA_PROCS" | xargs -r kill 2>/dev/null || true
            sleep 2
        fi
    fi
fi

echo "✅ Процессы проверены"
echo ""

# Удаление CUDA пакетов через apt
echo -e "${BLUE}📦 Шаг 3/7: Удаление CUDA пакетов через apt...${NC}"

if [ -n "$CUDA_PACKAGES" ]; then
    echo "Удаление пакетов..."
    echo "$CUDA_PACKAGES" | xargs sudo apt-get --purge remove -y
    
    # Autoremove зависимостей
    sudo apt-get autoremove -y
    
    echo "✅ Пакеты удалены"
else
    echo "ℹ️  Пакеты не требуют удаления"
fi

echo ""

# Удаление директорий CUDA
echo -e "${BLUE}🗑️  Шаг 4/7: Удаление директорий CUDA...${NC}"

CUDA_DIRS=(
    "/usr/local/cuda"
    "/usr/local/cuda-12.8"
    "/usr/local/cuda-12.1"
    "/usr/local/cuda-*"
)

for dir_pattern in "${CUDA_DIRS[@]}"; do
    for dir in $dir_pattern; do
        if [ -d "$dir" ] || [ -L "$dir" ]; then
            echo "Удаление: $dir"
            sudo rm -rf "$dir"
        fi
    done
done

# Дополнительные директории
if [ -d "/usr/lib/cuda" ]; then
    echo "Удаление: /usr/lib/cuda"
    sudo rm -rf /usr/lib/cuda
fi

if [ -d "/usr/include/cuda" ]; then
    echo "Удаление: /usr/include/cuda"
    sudo rm -rf /usr/include/cuda
fi

echo "✅ Директории удалены"
echo ""

# Очистка переменных окружения из ~/.bashrc
echo -e "${BLUE}📝 Шаг 5/7: Очистка переменных окружения...${NC}"

if [ -f ~/.bashrc ]; then
    # Создаем backup
    cp ~/.bashrc ~/.bashrc.backup_$(date +%Y%m%d_%H%M%S)
    
    # Удаляем CUDA-related строки
    sed -i '/# CUDA.*for FlashInfer/d' ~/.bashrc
    sed -i '/export CUDA_HOME=/d' ~/.bashrc
    sed -i '/export PATH=.*cuda/d' ~/.bashrc
    sed -i '/export LD_LIBRARY_PATH=.*cuda/d' ~/.bashrc
    
    # Удаляем пустые строки (если остались)
    sed -i '/^$/N;/^\n$/D' ~/.bashrc
    
    echo "✅ ~/.bashrc очищен (backup создан)"
else
    echo "ℹ️  ~/.bashrc не найден"
fi

# Проверка других конфигов
for config in ~/.zshrc ~/.profile ~/.bash_profile; do
    if [ -f "$config" ] && grep -q "CUDA_HOME" "$config"; then
        echo "⚠️  Найдены CUDA переменные в $config"
        read -p "Очистить $config? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cp "$config" "${config}.backup_$(date +%Y%m%d_%H%M%S)"
            sed -i '/CUDA_HOME/d' "$config"
            sed -i '/cuda/d' "$config"
            echo "✅ $config очищен"
        fi
    fi
done

echo ""

# Удаление кеша FlashInfer
echo -e "${BLUE}🗑️  Шаг 6/7: Удаление кеша FlashInfer...${NC}"

if [ -d ~/.cache/flashinfer ]; then
    SIZE=$(du -sh ~/.cache/flashinfer 2>/dev/null | cut -f1)
    echo "Найден кеш FlashInfer: $SIZE"
    rm -rf ~/.cache/flashinfer
    echo "✅ Кеш FlashInfer удален"
else
    echo "ℹ️  Кеш FlashInfer не найден"
fi

# Удаление других CUDA кешей
for cache_dir in ~/.cache/cuda ~/.cache/nvidia ~/.nv; do
    if [ -d "$cache_dir" ]; then
        SIZE=$(du -sh "$cache_dir" 2>/dev/null | cut -f1)
        echo "Удаление $cache_dir ($SIZE)"
        rm -rf "$cache_dir"
    fi
done

echo "✅ Кеши очищены"
echo ""

# Удаление ключа репозитория CUDA
echo -e "${BLUE}🔑 Шаг 7/7: Удаление ключа репозитория CUDA...${NC}"

if [ -f /usr/share/keyrings/cuda-archive-keyring.gpg ]; then
    sudo rm -f /usr/share/keyrings/cuda-archive-keyring.gpg
    echo "✅ Ключ удален"
fi

# Удаление списков репозиториев
sudo rm -f /etc/apt/sources.list.d/cuda*.list

# Обновление списков пакетов
sudo apt-get update > /dev/null 2>&1

echo "✅ Репозиторий очищен"
echo ""

# Проверка что всё удалено
echo -e "${BLUE}🔍 Финальная проверка...${NC}"
echo ""

# Проверка nvcc
if command -v nvcc &> /dev/null; then
    echo -e "${YELLOW}⚠️  nvcc всё еще доступен: $(which nvcc)${NC}"
else
    echo -e "${GREEN}✅ nvcc удален${NC}"
fi

# Проверка директорий
if [ -d /usr/local/cuda ]; then
    echo -e "${YELLOW}⚠️  /usr/local/cuda всё еще существует${NC}"
else
    echo -e "${GREEN}✅ /usr/local/cuda* удалены${NC}"
fi

# Проверка пакетов
REMAINING=$(dpkg -l | grep -i cuda | grep -v "cuda-keyring" | wc -l)
if [ "$REMAINING" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  Остались CUDA пакеты: $REMAINING${NC}"
    dpkg -l | grep -i cuda | grep -v "cuda-keyring"
else
    echo -e "${GREEN}✅ Все CUDA пакеты удалены${NC}"
fi

# Проверка переменных
if grep -q "CUDA_HOME" ~/.bashrc 2>/dev/null; then
    echo -e "${YELLOW}⚠️  CUDA_HOME всё еще в ~/.bashrc${NC}"
else
    echo -e "${GREEN}✅ Переменные окружения очищены${NC}"
fi

echo ""

# Статистика освобожденного места
echo -e "${BLUE}💾 Освобождено места на диске${NC}"
echo "(приблизительно)"
echo ""

# Итоговое сообщение
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Деинсталляция CUDA Toolkit завершена!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo "📋 Что было удалено:"
echo "  ✅ CUDA Toolkit (все версии)"
echo "  ✅ nvcc компилятор"
echo "  ✅ CUDA библиотеки"
echo "  ✅ Переменные окружения"
echo "  ✅ Кеш FlashInfer"
echo "  ✅ Ключи репозиториев"
echo ""

echo "📋 Что осталось:"
echo "  ✅ NVIDIA драйвер (нужен для GPU)"
echo "  ✅ PyTorch в .venv (будет работать через драйвер)"
echo "  ✅ vLLM в .venv"
echo ""

echo "📝 Следующие шаги:"
echo ""
echo "1. Перезапустите терминал для применения изменений:"
echo "   exit  # затем откройте новый терминал"
echo ""
echo "2. vLLM будет работать БЕЗ FlashInfer:"
echo "   source .venv/bin/activate"
echo "   ./start_server.sh --model qwen-7b"
echo ""
echo "3. Если хотите переустановить Python пакеты без FlashInfer:"
echo "   source .venv/bin/activate"
echo "   uv pip uninstall flashinfer flashinfer-python -y"
echo "   # vLLM продолжит работать"
echo ""
echo "4. Если нужен FlashInfer снова - запустите:"
echo "   ./install_cuda128_flashinfer.sh"
echo ""

echo -e "${YELLOW}💡 Совет:${NC} Для большинства случаев FlashInfer не обязателен."
echo "   vLLM отлично работает с базовым PyTorch sampling."
echo ""

# Опциональная очистка Python пакетов
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
read -p "Удалить FlashInfer из Python окружения? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if [ -d ".venv" ]; then
        source .venv/bin/activate
        uv pip uninstall flashinfer flashinfer-python -y 2>/dev/null || true
        echo "✅ FlashInfer удален из .venv"
    else
        echo "ℹ️  .venv не найден в текущей директории"
    fi
fi

echo ""
echo "🎉 Готово!"
