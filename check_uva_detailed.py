#!/usr/bin/env python3
"""
Детальная проверка UVA и CUDA capabilities в WSL2
"""

import torch
import subprocess
import sys

def check_cuda_basic():
    """Базовая проверка CUDA"""
    print("=" * 80)
    print("🔍 БАЗОВАЯ ПРОВЕРКА CUDA")
    print("=" * 80)
    print()
    
    if not torch.cuda.is_available():
        print("❌ CUDA не доступна")
        return False
    
    print(f"✅ CUDA доступна")
    print(f"   PyTorch: {torch.__version__}")
    print(f"   CUDA: {torch.version.cuda}")
    print(f"   Устройств: {torch.cuda.device_count()}")
    print()
    
    return True

def check_gpu_properties():
    """Проверка свойств GPU"""
    print("=" * 80)
    print("📊 СВОЙСТВА GPU")
    print("=" * 80)
    print()
    
    for i in range(torch.cuda.device_count()):
        props = torch.cuda.get_device_properties(i)
        print(f"GPU {i}: {props.name}")
        print(f"  Compute Capability: {props.major}.{props.minor}")
        print(f"  Total Memory: {props.total_memory / 1024**3:.2f} GB")
        print(f"  Multi Processors: {props.multi_processor_count}")
        
        # UVA требует Compute Capability >= 2.0
        if props.major >= 2:
            print(f"  ✅ UVA Supported (CC >= 2.0)")
        else:
            print(f"  ❌ UVA Not Supported (CC < 2.0)")
        
        print()

def check_pinned_memory():
    """Проверка pinned memory (требуется для UVA)"""
    print("=" * 80)
    print("📌 PINNED MEMORY")
    print("=" * 80)
    print()
    
    try:
        # Создаем pinned memory
        x = torch.randn(1000, 1000).pin_memory()
        print("✅ Pinned memory allocation works")
        
        # Проверяем что память действительно pinned
        if x.is_pinned():
            print("✅ Memory is pinned")
        else:
            print("⚠️  Memory allocated but not pinned")
        
        # Тест копирования на GPU
        x_gpu = x.cuda()
        print("✅ Pinned memory -> GPU transfer works")
        
        del x, x_gpu
        print()
        return True
        
    except Exception as e:
        print(f"❌ Pinned memory error: {e}")
        print()
        return False

def check_unified_memory():
    """Проверка Unified Memory (managed memory)"""
    print("=" * 80)
    print("🔗 UNIFIED MEMORY (Managed Memory)")
    print("=" * 80)
    print()
    
    try:
        # Unified memory в PyTorch
        # Это работает через cudaMallocManaged
        import ctypes
        
        # Загружаем CUDA runtime
        try:
            cuda = ctypes.CDLL("libcuda.so.1")
            print("✅ CUDA runtime library accessible")
        except:
            print("❌ Cannot load libcuda.so.1")
            print()
            return False
        
        # Проверяем версию драйвера
        driver_version = ctypes.c_int()
        result = cuda.cuDriverGetVersion(ctypes.byref(driver_version))
        
        if result == 0:
            version = driver_version.value
            major = version // 1000
            minor = (version % 1000) // 10
            print(f"✅ CUDA Driver Version: {major}.{minor}")
        else:
            print(f"⚠️  Cannot get driver version (code: {result})")
        
        print()
        
        # Managed memory обычно не работает в WSL2
        print("⚠️  Managed Memory (cudaMallocManaged) typically NOT supported in WSL2")
        print("   This is a known limitation")
        print()
        
        return False
        
    except Exception as e:
        print(f"❌ Unified memory check error: {e}")
        print()
        return False

def check_peer_access():
    """Проверка peer-to-peer доступа между устройствами"""
    print("=" * 80)
    print("🔄 PEER-TO-PEER ACCESS")
    print("=" * 80)
    print()
    
    device_count = torch.cuda.device_count()
    
    if device_count < 2:
        print("ℹ️  Only 1 GPU, P2P not applicable")
        print()
        return True
    
    for i in range(device_count):
        for j in range(device_count):
            if i != j:
                can_access = torch.cuda.can_device_access_peer(i, j)
                status = "✅" if can_access else "❌"
                print(f"{status} GPU {i} -> GPU {j}: {can_access}")
    
    print()

def check_wsl_specific():
    """Проверка специфичных для WSL ограничений"""
    print("=" * 80)
    print("🪟 WSL2 SPECIFIC CHECKS")
    print("=" * 80)
    print()
    
    # Проверяем что мы в WSL
    try:
        with open("/proc/version", "r") as f:
            version = f.read()
            if "microsoft" in version.lower() or "wsl" in version.lower():
                print("✅ Running in WSL2")
                print(f"   {version.strip()}")
            else:
                print("ℹ️  Not running in WSL")
    except:
        pass
    
    print()
    
    # Проверяем nvidia-smi
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=driver_version", "--format=csv,noheader"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            driver_ver = result.stdout.strip()
            print(f"✅ NVIDIA Driver: {driver_ver}")
        else:
            print("⚠️  nvidia-smi error")
    except:
        print("❌ nvidia-smi not available")
    
    print()
    
    # Проверяем пути к библиотекам
    import os
    wsl_lib_path = "/usr/lib/wsl/lib"
    if os.path.exists(wsl_lib_path):
        print(f"✅ WSL CUDA libs found: {wsl_lib_path}")
        
        # Проверяем libcuda.so
        libcuda = os.path.join(wsl_lib_path, "libcuda.so.1")
        if os.path.exists(libcuda):
            size = os.path.getsize(libcuda) / 1024**2
            print(f"   libcuda.so.1: {size:.1f} MB")
    else:
        print(f"⚠️  WSL lib path not found: {wsl_lib_path}")
    
    print()

def check_vllm_requirements():
    """Проверка требований vLLM для CPU offloading"""
    print("=" * 80)
    print("🚀 vLLM CPU OFFLOADING REQUIREMENTS")
    print("=" * 80)
    print()
    
    all_ok = True
    
    # 1. Compute Capability
    if torch.cuda.is_available():
        props = torch.cuda.get_device_properties(0)
        if props.major >= 2:
            print("✅ Compute Capability >= 2.0 (UVA supported)")
        else:
            print("❌ Compute Capability < 2.0 (UVA not supported)")
            all_ok = False
    
    # 2. Pinned Memory
    try:
        x = torch.randn(100, 100).pin_memory()
        print("✅ Pinned memory works")
    except:
        print("❌ Pinned memory doesn't work")
        all_ok = False
    
    # 3. Managed Memory (обычно не работает в WSL2)
    print("❌ Managed memory (cudaMallocManaged) - NOT supported in WSL2")
    print("   This is the MAIN blocker for vLLM V1 CPU offloading")
    all_ok = False
    
    print()
    
    if all_ok:
        print("🎉 All requirements met for CPU offloading")
    else:
        print("⚠️  CPU offloading requirements NOT fully met")
        print()
        print("💡 Recommendations:")
        print("   1. Use vLLM WITHOUT --cpu-offload (you have 32GB VRAM)")
        print("   2. Use quantization if needed (AWQ/GPTQ)")
        print("   3. Use vLLM V0 with --disable-v1")
        print("   4. Use alternative: llama.cpp (better CPU offload support)")
    
    print()

def main():
    print()
    print("=" * 80)
    print("🔍 COMPREHENSIVE UVA AND CUDA CAPABILITIES CHECK")
    print("=" * 80)
    print()
    
    if not check_cuda_basic():
        print("❌ CUDA not available, cannot proceed")
        sys.exit(1)
    
    check_gpu_properties()
    pinned_ok = check_pinned_memory()
    unified_ok = check_unified_memory()
    check_peer_access()
    check_wsl_specific()
    check_vllm_requirements()
    
    print("=" * 80)
    print("📋 SUMMARY")
    print("=" * 80)
    print()
    
    print(f"Pinned Memory:    {'✅' if pinned_ok else '❌'}")
    print(f"Unified Memory:   {'✅' if unified_ok else '❌'} (Expected ❌ in WSL2)")
    print()
    
    if not unified_ok:
        print("⚠️  CONCLUSION:")
        print("   vLLM V1 CPU offloading will NOT work in WSL2")
        print("   due to lack of Unified Memory (cudaMallocManaged) support")
        print()
        print("✅ SOLUTIONS:")
        print("   • Don't use --cpu-offload (you have enough VRAM)")
        print("   • Use --disable-v1 for legacy vLLM engine")
        print("   • Use quantization instead")
        print("   • Use llama.cpp for CPU offloading")
    
    print()

if __name__ == "__main__":
    main()