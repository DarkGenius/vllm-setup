#!/bin/bash

echo "🔍 Проверка доступности PyTorch для разных версий CUDA"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Функция проверки stable
check_pytorch_stable() {
    local cuda_version=$1
    local url="https://download.pytorch.org/whl/${cuda_version}/torch_stable.html"
    
    echo -n "CUDA ${cuda_version}: "
    
    if curl -s -f "${url}" > /dev/null 2>&1; then
        local packages=$(curl -s "${url}" | grep -c "torch-")
        if [ "$packages" -gt 0 ]; then
            echo "✅ Доступен ($packages пакетов)"
            return 0
        else
            echo "❌ Индекс есть, но пакеты не найдены"
            return 1
        fi
    else
        echo "❌ Не доступен"
        return 1
    fi
}

# Функция проверки nightly (исправленная)
check_pytorch_nightly() {
    local cuda_version=$1
    # Для nightly используем другую структуру URL
    local url="https://download.pytorch.org/whl/nightly/${cuda_version}/"
    
    echo -n "CUDA ${cuda_version}: "
    
    # Пытаемся получить список файлов
    local response=$(curl -s -f "${url}" 2>&1)
    
    if echo "$response" | grep -q "torch"; then
        local packages=$(echo "$response" | grep -c "torch-")
        echo "✅ Доступен ($packages пакетов)"
        
        # Показываем последнюю версию
        local latest=$(echo "$response" | grep -o 'torch-[0-9.+dev0-9]*' | head -1)
        [ -n "$latest" ] && echo "     Последняя: $latest"
        return 0
    else
        echo "❌ Не доступен"
        return 1
    fi
}

echo "📦 Stable releases:"
check_pytorch_stable "cu118"
check_pytorch_stable "cu121"
check_pytorch_stable "cu124"
check_pytorch_stable "cu128"
check_pytorch_stable "cu130"

echo ""
echo "🌙 Nightly releases:"
check_pytorch_nightly "cu121"
check_pytorch_nightly "cu124"
check_pytorch_nightly "cu126"
check_pytorch_nightly "cu128"
check_pytorch_nightly "cu129"
check_pytorch_nightly "cu130"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Доступные CUDA версии на PyTorch nightly:"
curl -s https://download.pytorch.org/whl/nightly/torch/ | \
    grep -o 'cu[0-9]*' | \
    sort -u | \
    sed 's/^/  - /'
