#!/bin/bash

# vLLM сервер с поддержкой различных моделей

set -e

# Значения по умолчанию
DEFAULT_MODEL="Qwen/Qwen2.5-7B-Instruct"
PORT=8000
HOST="0.0.0.0"
CPU_OFFLOAD_GB=""

# Конфигурация моделей: название => "model_id|gpu_mem|max_len|quant|special_flags|sampling_params"
declare -A MODELS=(
    # Qwen модели
    ["qwen-7b"]="Qwen/Qwen2.5-7B-Instruct|0.85|8192||||"
    ["qwen-14b"]="Qwen/Qwen2.5-14B-Instruct|0.90|8192||||"
    ["qwen-32b"]="Qwen/Qwen2.5-32B-Instruct|0.95|4096||||"
    ["qwen-72b"]="Qwen/Qwen2.5-72B-Instruct-AWQ|0.95|4096|awq|||"
    ["qwen-math-7b"]="Qwen/Qwen2.5-Math-7B-Instruct|0.85|4096||||"
    ["qwen-math-72b"]="Qwen/Qwen2.5-Math-72B-Instruct-AWQ|0.95|4096|awq|||"
    
    # Qwen Vision-Language модели (оптимизированные параметры)
    ["qwen3-vl-2b"]="unsloth/Qwen3-VL-2B-Instruct|0.85|8192||vlm|top_p=0.8,top_k=20,temperature=0.7,presence_penalty=1.5"
    
    # Llama модели (требуют gated access!)
    ["llama-3.2-3b"]="meta-llama/Llama-3.2-3B-Instruct|0.80|8192||||"
    ["llama-3.1-8b"]="meta-llama/Llama-3.1-8B-Instruct|0.85|8192||||"
    ["llama-3.3-70b"]="casperhansen/llama-3.3-70b-instruct-awq|0.85|8192|awq|||"
    ["llama-3.1-70b"]="hugging-quants/Meta-Llama-3.1-70B-Instruct-AWQ-INT4|0.95|8192|awq|||"
    
    # Другие модели
    ["mistral-7b"]="mistralai/Mistral-7B-Instruct-v0.3|0.85|8192||||"
    ["mistral-small"]="mistralai/Mistral-Small-Instruct-2409|0.95|8192||||"
    ["deepseek-math"]="deepseek-ai/deepseek-math-7b-instruct|0.85|8192||||"
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
                      Контекст: 8K, поддержка до 10 изображений в промпте
                      Оптимизированные параметры генерации:
                        - top_p: 0.8, top_k: 20, temperature: 0.7
                        - presence_penalty: 1.5 (для разнообразия)
                        - Flash Attention включен автоматически

📊 7B модели (быстрые, ~14GB VRAM):
    qwen-7b           Qwen/Qwen2.5-7B-Instruct
    qwen-math-7b      Qwen/Qwen2.5-Math-7B-Instruct
    mistral-7b        mistralai/Mistral-7B-Instruct-v0.3
    deepseek-math     deepseek-ai/deepseek-math-7b-instruct

📊 14B модели (баланс, ~28GB VRAM):
    qwen-14b          Qwen/Qwen2.5-14B-Instruct

📊 24-32B модели (мощные, ~30GB VRAM):
    mistral-small     mistralai/Mistral-Small-Instruct-2409 (24B)
    qwen-32b          Qwen/Qwen2.5-32B-Instruct

📊 72B модели (максимум, AWQ 4-bit, ~31GB VRAM):
    qwen-72b          Qwen/Qwen2.5-72B-Instruct-AWQ
    qwen-math-72b     Qwen/Qwen2.5-Math-72B-Instruct-AWQ

Примеры:
    ./start_server.sh
    ./start_server.sh --model qwen3-vl-2b
    ./start_server.sh --model qwen-math-72b
    ./start_server.sh --model qwen-14b --port 8001

После запуска сервер будет доступен по адресу:
    http://localhost:$PORT/v1

EOF
}

# Парсинг аргументов
MODEL_NAME="qwen-7b"

while [[ $# -gt 0 ]]; do
    case $1 in
        --model) MODEL_NAME="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --cpu-offload-gb) CPU_OFFLOAD_GB="$2"; shift 2 ;;
        --help|-h) show_help; exit 0 ;;
        *) echo "❌ Неизвестный аргумент: $1"; echo "Используйте --help для справки"; exit 1 ;;
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
IFS='|' read -r MODEL_ID GPU_MEM MAX_LEN QUANT SPECIAL SAMPLING <<< "${MODELS[$MODEL_NAME]}"

# Формирование команды через массив
CMD_ARGS=(
    python -m vllm.entrypoints.openai.api_server
    --model "$MODEL_ID"
    --host "$HOST"
    --port "$PORT"
    --trust-remote-code
    --gpu-memory-utilization "$GPU_MEM"
    --max-model-len "$MAX_LEN"
    --served-model-name vllm-model
)

# Квантизация
[[ -n "$QUANT" ]] && CMD_ARGS+=(--quantization "$QUANT")

# CPU offload
[[ -n "$CPU_OFFLOAD_GB" ]] && CMD_ARGS+=(--cpu-offload-gb "$CPU_OFFLOAD_GB")

# VLM флаги
if [[ "$SPECIAL" == "vlm" ]]; then
    CMD_ARGS+=(
        --limit-mm-per-prompt '{"image": 10}'
        --enable-prefix-caching
        --enable-chunked-prefill
        --max-num-batched-tokens 8192
        --max-num-seqs 256
    )
    IS_VLM=true
else
    IS_VLM=false
fi

# Параметры сэмплирования по умолчанию
if [[ -n "$SAMPLING" ]]; then
    # Преобразуем "key=value,key=value" в JSON
    SAMPLING_JSON="{"
    IFS=',' read -ra PARAMS <<< "$SAMPLING"
    for i in "${!PARAMS[@]}"; do
        IFS='=' read -r key value <<< "${PARAMS[$i]}"
        [[ $i -gt 0 ]] && SAMPLING_JSON+=","
        SAMPLING_JSON+="\"$key\": $value"
    done
    SAMPLING_JSON+="}"
    
    # Добавляем в аргументы (если vLLM поддерживает)
    # В текущей версии vLLM это настраивается через запросы
    HAS_SAMPLING=true
else
    HAS_SAMPLING=false
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
    echo "🔥 Flash Attn:    Enabled (автоматически)"
fi

if [[ -n "$QUANT" ]]; then
    echo "🔢 Quantization:  $QUANT"
fi

if [[ -n "$CPU_OFFLOAD_GB" ]]; then
    echo "💿 CPU Offload:   ${CPU_OFFLOAD_GB} GB"
fi

if [[ "$HAS_SAMPLING" == true ]]; then
    echo ""
    echo "⚙️  Параметры сэмплирования по умолчанию:"
    echo "   $SAMPLING_JSON"
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
echo "⏳ Загрузка модели (30-90 секунд)..."
echo ""

if [[ "$IS_VLM" == true ]]; then
    echo "💡 Пример запроса с изображением:"
    echo ""
    echo "curl http://localhost:$PORT/v1/chat/completions \\"
    echo "  -H 'Content-Type: application/json' \\"
    echo "  -d '{"
    echo "    \"model\": \"vllm-model\","
    echo "    \"messages\": [{"
    echo "      \"role\": \"user\","
    echo "      \"content\": ["
    echo "        {\"type\": \"text\", \"text\": \"Что на картинке?\"},"
    echo "        {\"type\": \"image_url\", \"image_url\": {\"url\": \"https://...\"}}"
    echo "      ]"
    echo "    }],"
    
    if [[ "$HAS_SAMPLING" == true ]]; then
        echo "    \"top_p\": 0.8,"
        echo "    \"top_k\": 20,"
        echo "    \"temperature\": 0.7,"
        echo "    \"presence_penalty\": 1.5,"
    fi
    
    echo "    \"max_tokens\": 500"
    echo "  }'"
    echo ""
fi

echo "Для остановки нажмите Ctrl+C"
echo ""

# Запуск сервера
"${CMD_ARGS[@]}"