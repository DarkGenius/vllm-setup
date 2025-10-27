# vLLM Setup - Локальный запуск LLM с OpenAI API

Проект для удобного запуска больших языковых моделей (LLM) локально с использованием vLLM и OpenAI-совместимым API интерфейсом.

## Описание

vLLM Setup позволяет запускать мощные языковые модели на вашем собственном оборудовании с GPU. Сервер предоставляет OpenAI-совместимый API, что позволяет использовать те же библиотеки и инструменты, что и для ChatGPT.

**Ключевые возможности:**
- OpenAI-совместимый API (drop-in replacement для OpenAI API)
- Поддержка множества моделей от 7B до 72B параметров
- Предварительно настроенные конфигурации для популярных моделей
- Оптимизированное использование GPU памяти
- Поддержка квантизации (AWQ) для больших моделей
- Работает в WSL2 с доступом из Windows

## Требования

### Системные требования
- **ОС**: Ubuntu/Debian (или WSL2 на Windows)
- **GPU**: NVIDIA GPU с минимум 14GB VRAM (для 7B моделей)
- **CUDA**: 11.8 или новее
- **Python**: 3.11 или новее
- **Пакетный менеджер**: [uv](https://github.com/astral-sh/uv)

### Рекомендуемое оборудование
| Размер модели | Требуемая VRAM | Рекомендуемый GPU |
|---------------|----------------|-------------------|
| 7B            | ~14GB          | RTX 3090, RTX 4090, L4 |
| 14B           | ~28GB          | RTX 4090, A5000, A100 |
| 32B           | ~30GB          | A5000 (48GB), A100 |
| 72B (AWQ)     | ~31GB          | A5000 (48GB), A100 |

## Установка

### 1. Установка системных зависимостей

```bash
./install-systems-deps.sh
```

Скрипт установит `python3.12-dev` и `build-essential`.

### 2. Установка uv (если еще не установлен)

```bash
curl -LsSf https://astral.sh/uv/install.sh | sh
```

### 3. Создание виртуального окружения и установка зависимостей

```bash
./reset_env.sh
```

Скрипт автоматически:
- Создаст виртуальное окружение `.venv`
- Установит все зависимости через uv
- Проверит установку vLLM, PyTorch и CUDA

### 4. Активация окружения

```bash
source .venv/bin/activate
```

### 5. Проверка установки

```bash
python check_vllm.py
```

Должен вывести версии vLLM, CUDA и подтвердить доступность GPU.

## Использование

### Быстрый старт

Запуск сервера с моделью по умолчанию (Qwen 7B):

```bash
./start_server.sh
```

Сервер будет доступен по адресу `http://localhost:8000`

### Запуск конкретной модели

```bash
# Математическая модель 7B (быстрая)
./start_server.sh --model qwen-math-7b

# Универсальная модель 14B (баланс)
./start_server.sh --model qwen-14b

# Самая мощная модель 72B (требует больше VRAM)
./start_server.sh --model qwen-math-72b

# Запуск на другом порту
./start_server.sh --model qwen-7b --port 8001
```

### Список всех доступных моделей

```bash
./start_server.sh --help
```

## Доступные модели

### 7B модели (быстрые, ~14GB VRAM)

| Название | Model ID | Описание |
|----------|----------|----------|
| `qwen-7b` | Qwen/Qwen2.5-7B-Instruct | Универсальная модель, отлично с русским |
| `qwen-math-7b` | Qwen/Qwen2.5-Math-7B-Instruct | Специализация на математике |
| `mistral-7b` | mistralai/Mistral-7B-Instruct-v0.3 | Быстрая западная модель |
| `deepseek-math` | deepseek-ai/deepseek-math-7b-instruct | Математическая специализация |

### 14B модели (баланс, ~28GB VRAM)

| Название | Model ID | Описание |
|----------|----------|----------|
| `qwen-14b` | Qwen/Qwen2.5-14B-Instruct | Улучшенное рассуждение |

### 24-32B модели (мощные, ~30GB VRAM)

| Название | Model ID | Описание |
|----------|----------|----------|
| `mistral-small` | mistralai/Mistral-Small-Instruct-2409 | 24B, баланс скорости и качества |
| `qwen-32b` | Qwen/Qwen2.5-32B-Instruct | Максимум без квантизации |

### 72B модели (максимум, AWQ 4-bit, ~31GB VRAM)

| Название | Model ID | Описание |
|----------|----------|----------|
| `qwen-72b` | Qwen/Qwen2.5-72B-Instruct-AWQ | Самая мощная универсальная |
| `qwen-math-72b` | Qwen/Qwen2.5-Math-72B-Instruct-AWQ | Лучшая для сложной математики |

## API Endpoints

После запуска сервера доступны следующие endpoints:

- **GET** `http://localhost:8000/v1/models` - Список доступных моделей
- **POST** `http://localhost:8000/v1/completions` - Text completion
- **POST** `http://localhost:8000/v1/chat/completions` - Chat completion
- **GET** `http://localhost:8000/docs` - Swagger UI документация

## Примеры использования

### Python с OpenAI SDK

```python
from openai import OpenAI

# Указываем локальный сервер
client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"  # vLLM не требует настоящий ключ
)

# Chat completion
response = client.chat.completions.create(
    model="vllm-model",
    messages=[
        {"role": "system", "content": "Ты полезный ассистент."},
        {"role": "user", "content": "Объясни квантовую механику простыми словами"}
    ],
    temperature=0.7,
    max_tokens=500
)

print(response.choices[0].message.content)
```

### cURL

```bash
curl http://localhost:8000/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{
    "model": "vllm-model",
    "messages": [
      {"role": "system", "content": "Ты математический ассистент."},
      {"role": "user", "content": "Реши уравнение: 3x + 7 = 22"}
    ],
    "temperature": 0.1,
    "max_tokens": 300
  }'
```

### Прямое использование vLLM (без API сервера)

```python
python test_vllm.py
```

Этот скрипт демонстрирует прямое использование vLLM для inference без запуска API сервера.

## Тестирование

### Проверка установки

```bash
python check_vllm.py
```

### Тест прямого inference

```bash
python test_vllm.py
```

### Тест API сервера

```bash
# В первом терминале запустите сервер
./start_server.sh

# Во втором терминале запустите тест
python test_math.py
```

Скрипт `test_math.py` отправит серию математических задач на сервер и выведет ответы модели.

## Рекомендации

### Выбор модели

- **Для экспериментов и тестирования**: `qwen-7b` (быстро, мало памяти)
- **Для математических задач**: `qwen-math-72b` (лучшее качество)
- **Для production**: `qwen-72b` (универсальная мощь)
- **При ограниченной VRAM**: `qwen-7b` или `qwen-math-7b`

### Оптимизация производительности

1. **GPU Memory Utilization**: Используйте 0.90-0.95 для максимальной производительности
2. **Max Context Length**: Уменьшите если не нужен длинный контекст (освободит память)
3. **Tensor Parallel**: Используйте несколько GPU если доступно
4. **Quantization**: Используйте AWQ модели для экономии памяти

### Доступ из Windows (WSL2)

Сервер автоматически привязывается к `0.0.0.0`, что позволяет:
- Доступ из WSL: `http://localhost:8000`
- Доступ из Windows: `http://localhost:8000`
- Доступ из сети: `http://<WSL_IP>:8000`

## Структура проекта

```
vllm-setup/
├── start_server.sh           # Главный скрипт запуска (с пресетами моделей)
├── vllm_server.py           # Python wrapper для vLLM API сервера
├── test_vllm.py             # Тест прямого использования vLLM
├── test_math.py             # Тест API сервера с математическими задачами
├── check_vllm.py            # Проверка установки
├── reset_env.sh             # Пересоздание виртуального окружения
├── install-systems-deps.sh  # Установка системных зависимостей
├── pyproject.toml           # Конфигурация проекта и зависимости
└── uv.lock                  # Lock-файл зависимостей
```

## Устранение проблем

### CUDA не найдена

```bash
# Проверьте версию CUDA
nvidia-smi

# Убедитесь что PyTorch установлен с CUDA
python -c "import torch; print(torch.cuda.is_available())"
```

### Недостаточно GPU памяти

1. Выберите модель меньшего размера
2. Уменьшите `--gpu-memory-utilization` (например, 0.80 вместо 0.90)
3. Уменьшите `--max-model-len`
4. Используйте квантизованную модель (AWQ)

### Модель загружается слишком долго

Первый запуск модели медленный (скачивание с HuggingFace). Последующие запуски будут быстрее благодаря кешированию.

Кеш моделей находится в `~/.cache/huggingface/hub/`

## Альтернативный запуск через Python

```bash
python vllm_server.py \
  --model Qwen/Qwen2.5-7B-Instruct \
  --port 8000 \
  --gpu-memory-utilization 0.9 \
  --max-model-len 8192
```

## Остановка сервера

Нажмите `Ctrl+C` в терминале где запущен сервер.

## Лицензия

Проект использует vLLM (Apache 2.0 License). Модели имеют свои собственные лицензии.

## Ссылки

- [vLLM GitHub](https://github.com/vllm-project/vllm)
- [vLLM Documentation](https://docs.vllm.ai/)
- [Qwen Models](https://huggingface.co/Qwen)
- [Mistral Models](https://huggingface.co/mistralai)
