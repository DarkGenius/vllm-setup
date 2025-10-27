#!/bin/bash

set -e

echo "🗑️  Удаление старого окружения..."
rm -rf .venv

echo "📦 Создание нового окружения..."
uv venv

echo "✅ Активация окружения..."
source .venv/bin/activate

echo "⬇️  Установка зависимостей..."
uv sync

echo ""
echo "🎉 Готово! Проверка установки..."
echo ""

python -c "
import vllm
import torch
import huggingface_hub
print(f'✅ vLLM: {vllm.__version__}')
print(f'✅ PyTorch: {torch.__version__}')
print(f'✅ CUDA: {torch.version.cuda}')
print(f'✅ HuggingFace Hub: {huggingface_hub.__version__}')
print(f'✅ CUDA available: {torch.cuda.is_available()}')
"

echo ""
echo "Для декактивации окружения выполните:"
echo "deactivate"
echo ""
echo "Для активации окружения выполните:"
echo "source .venv/bin/activate"
echo ""

