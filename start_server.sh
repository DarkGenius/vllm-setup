#!/bin/bash

# vLLM сервер с поддержкой различных моделей

set -e

# Значения по умолчанию
DEFAULT_MODEL="Qwen/Qwen2.5-7B-Instruct"
PORT=8000
HOST="0.0.0.0"
CPU_OFFLOAD_GB=""

# Конфигурация моделей: название => "model_id|gpu_mem|max_len|quant|special_flags"
declare -A MODELS=(
    # Qwen модели
    ["qwen-7b"]="Qwen/Qwen2.5-7B-Instruct|0.85|8192||"
    ["qwen-14b"]="Qwen/Qwen2.5-14B-Instruct|0.90|8192||"
    ["qwen-32b"]="Qwen/Qwen2.5-32B-Instruct|0.95|4096||"
    ["qwen-72b"]="Qwen/Qwen2.5-72B-Instruct-AWQ|0.95|4096|awq|"
    ["qwen-math-7b"]="Qwen/Qwen2.5-Math-7B-Instruct|0.85|4096||"
    ["qwen-math-72b"]="Qwen/Qwen2.5-Math-72B-Instruct-AWQ|0.95|4096|awq|"
    
    # Qwen Vision-Language модели (NEW!)
    ["qwen3-vl-2b"]="unsloth/Qwen3-VL-2B-Instruct|0.85|8192||vlm"
    
    # Llama модели (требуют gated access!)
    ["llama-3.2-3b"]="meta-llama/Llama-3.2-3B-Instruct|0.80|8192||"
    ["llama-3.1-8b"]="meta-llama/Llama-3.1-8B-Instruct|0.85|8192||"
    ["llama-3.3-70b"]="casperhansen/llama-3.3-70b-instruct-awq|0.85|8192|awq|"
    ["llama-3.1-70b"]="hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4|0.95|8192|awq|"
    
    # Другие модели
    ["mistral-7b"]="mistralai/Mistral-7B-Instruct-v0.3|0.85|8192||"
    ["mistral-small"]="mistralai/Mistral-Small-Instruct-2409|0.95|8192||"
    ["deepseek-math"]="deepseek-ai/deepseek-math-7b-instruct|0.85|8192||"
)

# Функция помощи
show_help() {
    cat << EOF
🚀 vLLM Server Launcher

Использование: 
    ./start_server.sh [OPTIONS]

Опции:
    --model <name>           Название модели для запуска (по умолчанию: qwen-7b)
    --port <port>            Порт сервера (по умолчанию: 8000)
    --host <host>            Host адрес (по умолчанию: 0.0.0.0)
    --cpu-offload-gb <gb>    Количество GB RAM для CPU оффлоада (опционально)
    --help                   Показать эту справку

Доступные модели (по возрастанию мощности):

📊 2-3B модели (очень быстрые, ~4-6GB VRAM):
    qwen3-vl-2b       unsloth/Qwen3-VL-2B-Instruct [VLM]
                      Vision-Language модель, работает с изображениями + текстом
                      Контекст: 32K, поддержка до 10 изображений в промпте

📊 7B модели (быстрые, ~14GB VRAM):
    qwen-7b           Qwen/Qwen2.5-7B-Instruct
                      Универсальная модель, отлично работает с русским
                      
    qwen-math-7b      Qwen/Qwen2.5-Math-7B-Instruct
                      Специализация на математике
                      
    mistral-7b        mistralai/Mistral-7B-Instruct-v0.3
                      Быстрая западная модель
                      
    deepseek-math     deepseek-ai/deepseek-math-7b-instruct
                      Математическая специализация

📊 14B модели (баланс, ~28GB VRAM):
    qwen-14b          Qwen/Qwen2.5-14B-Instruct
                      Улучшенное рассуждение

📊 24-32B модели (мощные, ~30GB VRAM):
    mistral-small     mistralai/Mistral-Small-Instruct-2409 (24B)
                      Баланс скорости и качества
                      
    qwen-32b          Qwen/Qwen2.5-32B-Instruct
                      Максимум без квантизации

📊 72B модели (максимум, AWQ 4-bit, ~31GB VRAM):
    qwen-72b          Qwen/Qwen2.5-72B-Instruct-AWQ
                      Самая мощная универсальная модель
                      
    qwen-math-72b     Qwen/Qwen2.5-Math-72B-Instruct-AWQ
                      Лучшая для сложной математики

Примеры:
    ./start_server.sh
    ./start_server.sh --model qwen3-vl-2b
    ./start_server.sh --model qwen-math-72b
    ./start_server.sh --model qwen-14b --port 8001
    ./start_server.sh --model llama-3.3-70b --cpu-offload-gb 64
    
Рекомендации:
    - Для тестирования: qwen-7b (быстро)
    - Для работы с изображениями: qwen3-vl-2b (VLM)
    - Для математики: qwen-math-72b (лучшее качество)
    - Для production: qwen-72b (универсальная мощь)

После запуска сервер будет доступен по адресу:
    http://localhost:$PORT/v1

Документация API:
    http://localhost:$PORT/docs

Для Vision моделей используйте формат с изображениями:
    {
      "model": "vllm-model",
      "messages": [{
        "role": "user",
        "content": [
          {"type": "text", "text": "Что на картинке?"},
          {"type": "image_url", "image_url": {"url": "https://..."}}
        ]
      }]
    }

EOF
}

# Парсинг аргументов
MODEL_NAME="qwen-7b"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model)
            MODEL_NAME="$2"
            shift 2
            ;;
        --port)
            PORT="$2"
            shift 2
            ;;
        --host)
            HOST="$2"
            shift 2
            ;;
        --cpu-offload-gb)
            CPU_OFFLOAD_GB="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "❌ Неизвестный аргумент: $1"
            echo "Используйте --help для справки"
            exit 1
            ;;
    esac
done

# Проверка что модель существует
if [[ ! -v MODELS[$MODEL_NAME] ]]; then
    echo "❌ Ошибка: Модель '$MODEL_NAME' не найдена"
    echo ""
    echo "Доступные модели:"
    for key in "${!MODELS[@]}"; do
        echo "  - $key"
    done | sort
    echo ""
    echo "Используйте --help для подробной информации"
    exit 1
fi

# Разбор конфигурации модели
IFS='|' read -r MODEL_ID GPU_MEM MAX_LEN QUANT SPECIAL <<< "${MODELS[$MODEL_NAME]}"

# Формирование базовой команды запуска
CMD="python -m vllm.entrypoints.openai.api_server \
    --model $MODEL_ID \
    --host $HOST \
    --port $PORT \
    --trust-remote-code \
    --gpu-memory-utilization $GPU_MEM \
    --max-model-len $MAX_LEN \
    --served-model-name vllm-model"

# Добавление квантизации если нужно
if [[ -n "$QUANT" ]]; then
    CMD="$CMD --quantization $QUANT"
fi

# Добавление CPU offload если указан
if [[ -n "$CPU_OFFLOAD_GB" ]]; then
    CMD="$CMD --cpu-offload-gb $CPU_OFFLOAD_GB"
fi

# Специальные флаги для Vision-Language моделей
if [[ "$SPECIAL" == "vlm" ]]; then
    # ИСПРАВЛЕНО: JSON формат для --limit-mm-per-prompt
    CMD="$CMD --limit-mm-per-prompt '{\"image\": 10}'"
    CMD="$CMD --enable-prefix-caching"
    CMD="$CMD --enable-chunked-prefill"
    CMD="$CMD --max-num-batched-tokens 8192"
    IS_VLM=true
else
    IS_VLM=false
fi

# Вывод информации
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🚀 Запуск vLLM сервера"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Модель:        $MODEL_NAME"
echo "🔖 Model ID:      $MODEL_ID"
echo "🌐 Адрес:         http://$HOST:$PORT"
echo "💾 GPU Memory:    ${GPU_MEM}0%"
echo "📏 Max Length:    $MAX_LEN"

if [[ "$IS_VLM" == true ]]; then
    echo "🖼️  Type:          Vision-Language Model (VLM)"
    echo "📸 Images:        До 10 изображений в промпте"
fi

if [[ -n "$QUANT" ]]; then
    echo "🔢 Quantization:  $QUANT"
fi

if [[ -n "$CPU_OFFLOAD_GB" ]]; then
    echo "💿 CPU Offload:   ${CPU_OFFLOAD_GB} GB"
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Проверка GPU
if command -v nvidia-smi &> /dev/null; then
    GPU_NAME=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)
    GPU_MEM_TOTAL=$(nvidia-smi --query-gpu=memory.total --format=csv,noheader,nounits | head -1)
    echo "🎮 GPU:           $GPU_NAME ($GPU_MEM_TOTAL MB)"
else
    echo "⚠️  nvidia-smi не найден"
fi

echo ""
echo "⏳ Загрузка модели (30-60 секунд)..."
echo ""

if [[ "$IS_VLM" == true ]]; then
    echo "💡 Для работы с изображениями используйте:"
    echo "   curl http://localhost:$PORT/v1/chat/completions \\"
    echo "     -H 'Content-Type: application/json' \\"
    echo "     -d '{"
    echo "       \"model\": \"vllm-model\","
    echo "       \"messages\": [{"
    echo "         \"role\": \"user\","
    echo "         \"content\": ["
    echo "           {\"type\": \"text\", \"text\": \"Что на картинке?\"},"
    echo "           {\"type\": \"image_url\", \"image_url\": {\"url\": \"https://...\"}}"
    echo "         ]"
    echo "       }]"
    echo "     }'"
    echo ""
fi

echo "Для остановки нажмите Ctrl+C"
echo ""

# Запуск сервера
eval $CMD