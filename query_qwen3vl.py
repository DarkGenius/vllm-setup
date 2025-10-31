#!/usr/bin/env python3
"""
Helper для запросов к Qwen3-VL-2B с оптимальными параметрами
"""

import requests
import base64
from pathlib import Path
from typing import List, Optional

class Qwen3VLClient:
    """Клиент для Qwen3-VL-2B с оптимальными параметрами"""
    
    def __init__(self, api_url: str = "http://localhost:8000"):
        self.api_url = api_url
        self.default_params = {
            # Параметры из llama.cpp
            "top_p": 0.8,
            "top_k": 20,
            "temperature": 0.7,
            "presence_penalty": 1.5,
            "max_tokens": 500,
        }
    
    def encode_image(self, image_path: str) -> tuple[str, str]:
        """Кодировать изображение в base64"""
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
    
    def ask(
        self,
        question: str,
        image_paths: Optional[List[str]] = None,
        **kwargs
    ) -> str:
        """
        Отправить запрос с оптимальными параметрами
        
        Args:
            question: Вопрос
            image_paths: Список путей к изображениям (опционально)
            **kwargs: Переопределить параметры генерации
        """
        
        # Объединяем параметры
        params = {**self.default_params, **kwargs}
        
        # Формируем content
        if image_paths:
            content = [{"type": "text", "text": question}]
            
            for image_path in image_paths:
                base64_image, mime_type = self.encode_image(image_path)
                content.append({
                    "type": "image_url",
                    "image_url": {
                        "url": f"data:{mime_type};base64,{base64_image}"
                    }
                })
        else:
            content = question
        
        # Запрос
        response = requests.post(
            f"{self.api_url}/v1/chat/completions",
            json={
                "model": "vllm-model",
                "messages": [{"role": "user", "content": content}],
                **params
            },
            timeout=120
        )
        
        if response.status_code == 200:
            return response.json()["choices"][0]["message"]["content"]
        else:
            raise Exception(f"API Error: {response.status_code} - {response.text}")

# CLI интерфейс
if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(
        description="Клиент для Qwen3-VL-2B с оптимальными параметрами"
    )
    
    parser.add_argument(
        "-q", "--question",
        required=True,
        help="Вопрос"
    )
    
    parser.add_argument(
        "-i", "--images",
        nargs="*",
        help="Путь к изображению(ям)"
    )
    
    parser.add_argument(
        "--api-url",
        default="http://localhost:8000",
        help="URL vLLM API"
    )
    
    parser.add_argument(
        "--temperature",
        type=float,
        default=0.7,
        help="Temperature (по умолчанию: 0.7)"
    )
    
    parser.add_argument(
        "--top-p",
        type=float,
        default=0.8,
        help="Top-p (по умолчанию: 0.8)"
    )
    
    parser.add_argument(
        "--top-k",
        type=int,
        default=20,
        help="Top-k (по умолчанию: 20)"
    )
    
    parser.add_argument(
        "--presence-penalty",
        type=float,
        default=1.5,
        help="Presence penalty (по умолчанию: 1.5)"
    )
    
    parser.add_argument(
        "--max-tokens",
        type=int,
        default=500,
        help="Max tokens (по умолчанию: 500)"
    )
    
    args = parser.parse_args()
    
    # Создаем клиент
    client = Qwen3VLClient(api_url=args.api_url)
    
    # Параметры
    params = {
        "temperature": args.temperature,
        "top_p": args.top_p,
        "top_k": args.top_k,
        "presence_penalty": args.presence_penalty,
        "max_tokens": args.max_tokens,
    }
    
    print("=" * 80)
    print("🖼️  Qwen3-VL-2B Client (оптимизированные параметры)")
    print("=" * 80)
    print()
    print(f"Вопрос: {args.question}")
    if args.images:
        print(f"Изображений: {len(args.images)}")
    print()
    print("Параметры генерации:")
    for key, value in params.items():
        print(f"  {key}: {value}")
    print()
    
    # Отправляем запрос
    try:
        result = client.ask(
            question=args.question,
            image_paths=args.images,
            **params
        )
        
        print("=" * 80)
        print("💬 ОТВЕТ")
        print("=" * 80)
        print()
        print(result)
        print()
        
    except Exception as e:
        print(f"❌ Ошибка: {e}")