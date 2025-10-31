#!/usr/bin/env python3
"""
CLI для работы с изображениями в vLLM
"""

import argparse
import base64
import requests
from pathlib import Path
from typing import List

def encode_image(image_path: str) -> tuple[str, str]:
    """Кодировать изображение и определить MIME type"""
    ext = Path(image_path).suffix.lower()
    mime_types = {
        '.jpg': 'image/jpeg',
        '.jpeg': 'image/jpeg',
        '.png': 'image/png',
        '.gif': 'image/gif',
        '.webp': 'image/webp',
        '.bmp': 'image/bmp',
    }
    mime_type = mime_types.get(ext, 'image/jpeg')
    
    with open(image_path, "rb") as f:
        base64_data = base64.b64encode(f.read()).decode("utf-8")
    
    return base64_data, mime_type

def ask_vllm(
    question: str,
    image_paths: List[str],
    api_url: str = "http://localhost:8000",
    max_tokens: int = 500,
    temperature: float = 0.7,
):
    """Отправить запрос с изображениями в vLLM"""
    
    # Формируем content
    content = [{"type": "text", "text": question}]
    
    # Добавляем изображения
    for image_path in image_paths:
        print(f"📸 Загрузка: {image_path}")
        base64_image, mime_type = encode_image(image_path)
        
        content.append({
            "type": "image_url",
            "image_url": {
                "url": f"data:{mime_type};base64,{base64_image}"
            }
        })
    
    print(f"🚀 Отправка запроса...")
    
    # Запрос
    response = requests.post(
        f"{api_url}/v1/chat/completions",
        json={
            "model": "vllm-model",
            "messages": [{"role": "user", "content": content}],
            "max_tokens": max_tokens,
            "temperature": temperature,
        },
        timeout=120
    )
    
    if response.status_code == 200:
        result = response.json()
        return result["choices"][0]["message"]["content"]
    else:
        raise Exception(f"API Error: {response.status_code} - {response.text}")

def main():
    parser = argparse.ArgumentParser(
        description="Отправка изображений в vLLM Vision модель"
    )
    
    parser.add_argument(
        "images",
        nargs="+",
        help="Путь к изображению(ям)"
    )
    
    parser.add_argument(
        "-q", "--question",
        required=True,
        help="Вопрос об изображении"
    )
    
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000",
        help="URL vLLM API (по умолчанию: http://localhost:8000)"
    )
    
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=500,
        help="Максимум токенов в ответе"
    )
    
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Temperature для генерации"
    )
    
    args = parser.parse_args()
    
    # Проверка существования файлов
    for image_path in args.images:
        if not Path(image_path).exists():
            print(f"❌ Файл не найден: {image_path}")
            return 1
    
    print("=" * 80)
    print("🖼️  vLLM Vision CLI")
    print("=" * 80)
    print()
    print(f"Изображений: {len(args.images)}")
    print(f"Вопрос: {args.question}")
    print(f"API: {args.api_url}")
    print()
    
    try:
        result = ask_vllm(
            question=args.question,
            image_paths=args.images,
            api_url=args.api_url,
            max_tokens=args.max_tokens,
            temperature=args.temperature,
        )
        
        print()
        print("=" * 80)
        print("💬 ОТВЕТ")
        print("=" * 80)
        print()
        print(result)
        print()
        
    except Exception as e:
        print(f"\n❌ Ошибка: {e}\n")
        return 1
    
    return 0

if __name__ == "__main__":
    exit(main())