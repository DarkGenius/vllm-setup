# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a vLLM setup project for running large language models locally with OpenAI-compatible API endpoints. The codebase is designed to work in WSL2 (Windows Subsystem for Linux) environments with GPU support.

## Environment Setup

This project uses `uv` for Python package management (Python 3.11+ required).

**Initial setup:**
```bash
# Install system dependencies (Ubuntu/WSL2)
./install-systems-deps.sh

# Create and activate virtual environment, install dependencies
./reset_env.sh
source .venv/bin/activate
```

**Check installation:**
```bash
python check_vllm.py
```

## Running the Server

The primary way to run the vLLM server is through `start_server.sh`:

```bash
# Run with default model (qwen-7b)
./start_server.sh

# Run specific model
./start_server.sh --model qwen-math-72b

# Custom port
./start_server.sh --model qwen-14b --port 8001

# See all available models and options
./start_server.sh --help
```

**Alternative Python server:**
```bash
python vllm_server.py --model Qwen/Qwen2.5-7B-Instruct --port 8000
```

## Available Models

Models are pre-configured in `start_server.sh` with optimized settings (GPU memory utilization, max context length, quantization):

- **7B models** (~14GB VRAM): `qwen-7b`, `qwen-math-7b`, `mistral-7b`, `deepseek-math`
- **14B models** (~28GB VRAM): `qwen-14b`
- **24-32B models** (~30GB VRAM): `mistral-small`, `qwen-32b`
- **72B models** (AWQ 4-bit, ~31GB VRAM): `qwen-72b`, `qwen-math-72b`

Each model shorthand maps to: `model_id|gpu_mem_utilization|max_context_length|quantization_method`

## Testing

**Basic vLLM functionality test:**
```bash
python test_vllm.py
```
This performs direct inference using the vLLM LLM class (not via API server).

**API server test:**
```bash
# First, start the server in another terminal
./start_server.sh

# Then run the test
python test_math.py
```
This tests the running API server at `http://localhost:8000/v1` with mathematical problems.

## Architecture

**Entry points:**
- `vllm_server.py`: Python wrapper for vLLM's OpenAI API server with custom argument handling
- `start_server.sh`: Bash launcher with pre-configured model presets and user-friendly interface

**Server architecture:**
- The server uses vLLM's built-in OpenAI-compatible API server (`vllm.entrypoints.openai.api_server`)
- `vllm_server.py` constructs arguments and delegates to vLLM's main server entry point
- Models are served with the name "vllm-model" regardless of actual model used

**API endpoints (when server is running):**
- `http://localhost:8000/v1/models` - List available models
- `http://localhost:8000/v1/completions` - Text completions
- `http://localhost:8000/v1/chat/completions` - Chat completions
- `http://localhost:8000/docs` - Swagger UI documentation

## Key Configuration Parameters

When launching models, important parameters include:

- `--gpu-memory-utilization`: Fraction of GPU memory to use (0.0-1.0), typically 0.85-0.95
- `--max-model-len`: Maximum context length (auto-detected if not specified)
- `--tensor-parallel-size`: Number of GPUs for tensor parallelism (default: 1)
- `--quantization`: Quantization method (e.g., "awq" for 72B models)
- `--trust-remote-code`: Required for some models with custom code
- `--served-model-name`: Name used in API responses (set to "vllm-model")

## Development Notes

- This project is primarily for running inference, not training
- The codebase contains Russian language comments and messages (designed for Russian-speaking users)
- WSL2-specific: Server binds to `0.0.0.0` to allow access from Windows host
- The project structure is simple and script-based rather than application-based
