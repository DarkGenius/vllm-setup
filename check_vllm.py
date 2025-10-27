import vllm; 
import torch;

print(f'vllm version: {vllm.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'CUDA version: {torch.version.cuda}')

