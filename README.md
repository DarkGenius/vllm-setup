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
# Vision-Language модель для работы с изображениями
./start_server.sh --model qwen3-vl-2b

# Математическая модель 7B (быстрая)
./start_server.sh --model qwen-math-7b

# Универсальная модель 14B (баланс)
./start_server.sh --model qwen-14b

# Самая мощная модель 72B (требует больше VRAM)
./start_server.sh --model qwen-math-72b

# Запуск на другом порту
./start_server.sh --model qwen-7b --port 8001

# С CPU offloading (для больших моделей)
./start_server.sh --model llama-3.3-70b --cpu-offload-gb 64
```

### Список всех доступных моделей

```bash
./start_server.sh --help
```

## Доступные модели

### 2-3B модели (очень быстрые, ~4-6GB VRAM)

| Название | Model ID | Описание |
|----------|----------|----------|
| `qwen3-vl-2b` | unsloth/Qwen3-VL-2B-Instruct | Vision-Language модель, работает с изображениями + текстом. Контекст: 8K, поддержка до 10 изображений. Оптимизированные параметры: top_p=0.8, top_k=20, temperature=0.7, presence_penalty=1.5 |

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

### Vision-Language модель с изображениями

#### CLI инструменты (рекомендуется)

**query_qwen3vl.py** - клиент с оптимизированными параметрами:

```bash
# Сначала запустите VLM сервер:
./start_server.sh --model qwen3-vl-2b

# Запрос с изображением
python query_qwen3vl.py \
  -q "Что изображено на картинке?" \
  -i imgs/photo.jpg

# Несколько изображений
python query_qwen3vl.py \
  -q "Сравни эти изображения" \
  -i imgs/photo1.jpg imgs/photo2.jpg

# Настройка параметров
python query_qwen3vl.py \
  -q "Опиши детально" \
  -i imgs/photo.jpg \
  --temperature 0.5 \
  --top-p 0.9 \
  --max-tokens 1000
```

Оптимизированные параметры по умолчанию:
- `top_p: 0.8` - ядерная выборка
- `top_k: 20` - топ-20 токенов
- `temperature: 0.7` - креативность
- `presence_penalty: 1.5` - разнообразие ответов

**vllm_image_cli.py** - упрощенный CLI:

```bash
# Простой запрос
python vllm_image_cli.py imgs/photo.jpg \
  -q "Что на картинке?"

# С настройками
python vllm_image_cli.py imgs/photo.jpg \
  -q "Опиши подробно" \
  --temperature 0.8 \
  --max-tokens 500
```

#### Python OpenAI SDK

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://localhost:8000/v1",
    api_key="dummy"
)

# Запрос с оптимизированными параметрами
response = client.chat.completions.create(
    model="vllm-model",
    messages=[{
        "role": "user",
        "content": [
            {"type": "text", "text": "Что изображено на картинке?"},
            {"type": "image_url", "image_url": {"url": "https://example.com/image.jpg"}}
        ]
    }],
    top_p=0.8,
    top_k=20,
    temperature=0.7,
    presence_penalty=1.5,
    max_tokens=500
)

print(response.choices[0].message.content)
```

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

- **Для работы с изображениями**: `qwen3-vl-2b` (Vision-Language модель)
- **Для экспериментов и тестирования**: `qwen-7b` (быстро, мало памяти)
- **Для математических задач**: `qwen-math-72b` (лучшее качество)
- **Для production**: `qwen-72b` (универсальная мощь)
- **При ограниченной VRAM**: `qwen3-vl-2b` или `qwen-7b` или `qwen-math-7b`

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
├── start_server.sh                  # Главный скрипт запуска (с пресетами моделей)
├── vllm_server.py                   # Python wrapper для vLLM API сервера
│
├── Vision-Language CLI:
│   ├── query_qwen3vl.py                 # Клиент для VLM с оптимизированными параметрами
│   └── vllm_image_cli.py                # Упрощенный CLI для работы с изображениями
│
├── Тесты:
│   ├── test_vllm.py                     # Тест прямого использования vLLM
│   ├── test_math.py                     # Тест API сервера с математическими задачами
│   └── check_vllm.py                    # Проверка установки vLLM и CUDA
│
├── Установка:
│   ├── reset_env.sh                     # Пересоздание виртуального окружения
│   └── install-systems-deps.sh          # Установка системных зависимостей
│
├── CUDA Toolkit и FlashInfer:
│   ├── install_cuda128_flashinfer.sh   # Установка CUDA 12.8 + FlashInfer (интерактивный)
│   ├── install_cuda_auto.sh            # Автоматическая установка CUDA + FlashInfer
│   ├── uninstall_cuda_toolkit.sh       # Полная деинсталляция CUDA Toolkit
│   ├── check_flashinfer_availability.sh # Проверка доступности FlashInfer wheels
│   └── check_pytorch_availability.sh    # Проверка доступности PyTorch для CUDA
│
├── Диагностика и проверка:
│   └── check_uva_detailed.py            # Детальная проверка UVA/CUDA capabilities
│
├── Утилиты WSL:
│   ├── move_to_wsl.sh                   # Копирование проекта в WSL native FS
│   └── sync.sh                          # Синхронизация проекта в WSL native FS
│
├── pyproject.toml                    # Конфигурация проекта и зависимости
└── uv.lock                           # Lock-файл зависимостей
```

## Расширенные возможности

### Оптимизация Vision-Language моделей

Для модели `qwen3-vl-2b` используются оптимизированные параметры генерации:

- **top_p: 0.8** - Nucleus sampling, баланс разнообразия и качества
- **top_k: 20** - Ограничение выбора топ-20 токенами
- **temperature: 0.7** - Креативность (0.0 = детерминированный, 1.0 = случайный)
- **presence_penalty: 1.5** - Штраф за повторения, увеличивает разнообразие
- **max_num_seqs: 256** - Параллельная обработка до 256 запросов
- **Flash Attention** - Включен автоматически для ускорения

Эти параметры подобраны на основе рекомендаций из llama.cpp и обеспечивают:
- Качественное описание изображений
- Разнообразие в ответах
- Минимум повторений
- Хорошую скорость генерации

CLI инструменты (`query_qwen3vl.py` и `vllm_image_cli.py`) автоматически используют эти параметры.

### CUDA Toolkit и FlashInfer

FlashInfer - это библиотека для оптимизации attention kernels, которая может ускорить vLLM на 10-20%. Для работы FlashInfer требуется CUDA Toolkit.

#### Автоматическая установка (рекомендуется)

```bash
./install_cuda_auto.sh
```

Скрипт автоматически:
- Определит версию CUDA драйвера
- Установит подходящую версию CUDA Toolkit
- Переустановит PyTorch для правильной версии CUDA
- Установит FlashInfer

#### Ручная установка CUDA 12.8

```bash
./install_cuda128_flashinfer.sh
```

Интерактивный скрипт проведет через все шаги установки.

#### Проверка доступности компонентов

```bash
# Проверить доступность FlashInfer wheels
./check_flashinfer_availability.sh

# Проверить доступность PyTorch для разных CUDA
./check_pytorch_availability.sh

# Детальная проверка CUDA capabilities
python check_uva_detailed.py
```

#### Удаление CUDA Toolkit

Если FlashInfer не нужен или вызывает проблемы:

```bash
./uninstall_cuda_toolkit.sh
```

vLLM продолжит работать без FlashInfer, используя базовые PyTorch kernels.

### Миграция на WSL Native FS

Для лучшей производительности в WSL2 рекомендуется держать проект в Linux файловой системе, а не на Windows диске (e.g., `/mnt/e/`).

#### Копирование проекта

```bash
# Полное копирование (создает новую директорию)
./move_to_wsl.sh

# Целевая директория: ~/projects/vllm-setup
```

#### Синхронизация изменений

```bash
# Синхронизировать изменения (не удаляет файлы в цели)
./sync.sh
```

Преимущества native FS:
- Быстрее файловые операции (особенно при компиляции)
- Лучше работают git операции
- Нет проблем с permissions и line endings

### CPU Offloading

vLLM V1 поддерживает CPU offloading для запуска моделей, которые не помещаются в GPU память. Однако в WSL2 есть ограничения из-за отсутствия Unified Memory.

```bash
# Проверить поддержку UVA/Unified Memory
python check_uva_detailed.py
```

**Важно:** CPU offloading может не работать в WSL2. Альтернативы:
- Используйте квантизованные модели (AWQ)
- Уменьшите `--gpu-memory-utilization`
- Используйте меньшую модель
- Используйте `--disable-v1` для legacy engine

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
