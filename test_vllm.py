from vllm import LLM, SamplingParams

sampling_params = SamplingParams(
    temperature=0.7,
    top_p=0.95,
    max_tokens=256
)

llm = LLM(
    model="Qwen/Qwen2.5-7B-Instruct",
    tensor_parallel_size=1,
    gpu_memory_utilization=0.9
)

prompts = [
    "Объясни, что такое машинное обучение простыми словами:",
    "Напиши короткое стихотворение про Python:"
]

outputs = llm.generate(prompts, sampling_params)

for output in outputs:
    print(f"Промпт: {output.prompt}")
    print(f"Ответ: {output.outputs[0].text}\n")

