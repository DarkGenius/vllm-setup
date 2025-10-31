#!/bin/bash

echo "🔍 Проверка доступности FlashInfer wheels"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

check_flashinfer_cuda() {
    local cuda_version=$1
    local url="https://flashinfer.ai/whl/${cuda_version}/torch2.4/"
    
    echo -n "CUDA ${cuda_version}: "
    
    if curl -s -f -I "${url}" > /dev/null 2>&1; then
        local packages=$(curl -s "${url}" | grep -c "flashinfer")
        if [ "$packages" -gt 0 ]; then
            echo "✅ Доступен ($packages версий)"
            
            # Показываем последние версии
            curl -s "${url}" | \
                grep -o 'flashinfer[^"]*\.whl' | \
                head -3 | \
                sed 's/^/     /'
        else
            echo "❌ Индекс пуст"
        fi
    else
        echo "❌ Не доступен"
    fi
    echo ""
}

echo "📦 FlashInfer wheels:"
check_flashinfer_cuda "cu118"
check_flashinfer_cuda "cu121"
check_flashinfer_cuda "cu124"
check_flashinfer_cuda "cu128"
check_flashinfer_cuda "cu130"

echo ""
echo "📦 GitHub Releases (универсальные):"
echo ""

# Проверка GitHub releases
curl -s https://api.github.com/repos/flashinfer-ai/flashinfer/releases/latest | \
    jq -r '.assets[] | select(.name | endswith(".whl")) | "  ✅ \(.name)"'

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
