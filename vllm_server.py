#!/usr/bin/env python3
"""
vLLM OpenAI-совместимый API сервер
Запуск: python vllm_server.py
"""

import argparse
import os
from vllm.entrypoints.openai.api_server import run_server
from vllm.engine.arg_utils import AsyncEngineArgs
from vllm.entrypoints.openai.cli_args import make_arg_parser


def main():
    parser = argparse.ArgumentParser(description="vLLM OpenAI API Server")
    
    # Основные параметры
    parser.add_argument("--model", type=str, 
                       default="Qwen/Qwen2.5-7B-Instruct",
                       help="Название модели из HuggingFace")
    
    parser.add_argument("--host", type=str, 
                       default="0.0.0.0",
                       help="Host для сервера (0.0.0.0 для доступа из Windows)")
    
    parser.add_argument("--port", type=int, 
                       default=8000,
                       help="Порт сервера")
    
    parser.add_argument("--gpu-memory-utilization", type=float, 
                       default=0.9,
                       help="Доля GPU памяти для использования (0.0-1.0)")
    
    parser.add_argument("--max-model-len", type=int, 
                       default=None,
                       help="Максимальная длина контекста")
    
    parser.add_argument("--tensor-parallel-size", type=int, 
                       default=1,
                       help="Количество GPU для параллелизма")
    
    parser.add_argument("--trust-remote-code", action="store_true",
                       help="Доверять удаленному коду (для некоторых моделей)")
    
    args = parser.parse_args()
    
    print("=" * 70)
    print("🚀 Запуск vLLM API сервера")
    print("=" * 70)
    print(f"📦 Модель: {args.model}")
    print(f"🌐 Host: {args.host}")
    print(f"🔌 Port: {args.port}")
    print(f"💾 GPU Memory: {args.gpu_memory_utilization * 100}%")
    print(f"📏 Max context: {args.max_model_len or 'auto'}")
    print("=" * 70)
    print(f"\n✅ Сервер будет доступен по адресу:")
    print(f"   WSL: http://localhost:{args.port}")
    print(f"   Windows: http://localhost:{args.port}")
    print(f"   Сеть: http://<WSL_IP>:{args.port}")
    print("\n📋 OpenAI API endpoints:")
    print(f"   - http://localhost:{args.port}/v1/models")
    print(f"   - http://localhost:{args.port}/v1/completions")
    print(f"   - http://localhost:{args.port}/v1/chat/completions")
    print(f"   - http://localhost:{args.port}/docs (Swagger UI)")
    print("=" * 70)
    print("\n⏳ Загрузка модели (это может занять 30-60 секунд)...\n")
    
    # Запуск через CLI (самый надежный способ)
    import sys
    sys.argv = [
        "vllm.entrypoints.openai.api_server",
        "--model", args.model,
        "--host", args.host,
        "--port", str(args.port),
        "--gpu-memory-utilization", str(args.gpu_memory_utilization),
        "--tensor-parallel-size", str(args.tensor_parallel_size),
    ]
    
    if args.max_model_len:
        sys.argv.extend(["--max-model-len", str(args.max_model_len)])
    
    if args.trust_remote_code:
        sys.argv.append("--trust-remote-code")
    
    # Импортируем и запускаем сервер
    from vllm.entrypoints.openai.api_server import main as vllm_main
    vllm_main()


if __name__ == "__main__":
    main()
