import requests

BASE_URL = "http://localhost:8000/v1"

math_problems = [
    "Реши уравнение: 3x + 7 = 22",
    "Найди производную функции f(x) = x³ + 2x² - 5x + 1",
    "Вычисли интеграл: ∫(2x + 3)dx",
    "Реши систему уравнений:\n2x + y = 5\nx - y = 1",
    "Найди корни квадратного уравнения: x² - 5x + 6 = 0",
]

def test_math(problem):
    response = requests.post(
        f"{BASE_URL}/chat/completions",
        json={
            "model": "vllm-model",
            "messages": [
                {"role": "system", "content": "Ты математический ассистент. Решай задачи пошагово."},
                {"role": "user", "content": problem}
            ],
            "temperature": 0.1,  # низкая для точности
            "max_tokens": 500
        }
    )
    return response.json()['choices'][0]['message']['content']

print("🧮 Тестирование математических способностей модели\n")
print("=" * 70)

for i, problem in enumerate(math_problems, 1):
    print(f"\n📝 Задача {i}: {problem}")
    print("-" * 70)
    answer = test_math(problem)
    print(f"💡 Ответ:\n{answer}")
    print("=" * 70)
