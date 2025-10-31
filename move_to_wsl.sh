#!/bin/bash

# Скрипт для копирования проекта в WSL native FS

set -e

# Целевая директория
TARGET_DIR=~/projects/vllm-setup

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🚀 Копирование проекта в WSL native FS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Текущая директория
CURRENT_DIR=$(pwd)
echo -e "${YELLOW}Источник:${NC} $CURRENT_DIR"
echo -e "${YELLOW}Цель:${NC}     $TARGET_DIR"
echo ""

# Проверка что не копируем сами в себя
if [ "$CURRENT_DIR" = "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Ошибка: Источник и цель совпадают!${NC}"
    exit 1
fi

# Проверка что целевая директория существует
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}⚠️  Целевая директория уже существует${NC}"
    
    # Показать содержимое
    echo ""
    echo "Содержимое $TARGET_DIR:"
    ls -lah "$TARGET_DIR" | head -10
    echo ""
    
    read -p "Удалить существующую директорию и продолжить? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}❌ Отменено${NC}"
        exit 1
    fi
    
    echo -e "${YELLOW}🗑️  Удаление старой директории...${NC}"
    rm -rf "$TARGET_DIR"
fi

# Создание родительской директории
echo -e "${GREEN}📁 Создание директории...${NC}"
mkdir -p "$(dirname "$TARGET_DIR")"

# Копирование с исключением .venv
echo -e "${GREEN}📦 Копирование файлов (исключая .venv)...${NC}"
echo ""

# Используем rsync для красивого прогресса и исключений
if command -v rsync &> /dev/null; then
    rsync -av --progress \
        --exclude='.venv' \
        --exclude='.venv/' \
        --exclude='__pycache__' \
        --exclude='*.pyc' \
        --exclude='.git/objects' \
        "$CURRENT_DIR/" "$TARGET_DIR/"
else
    # Fallback: используем cp с find
    echo -e "${YELLOW}ℹ️  rsync не найден, используем cp...${NC}"
    
    # Создаем целевую директорию
    mkdir -p "$TARGET_DIR"
    
    # Копируем все файлы кроме .venv
    find "$CURRENT_DIR" -mindepth 1 -maxdepth 1 ! -name '.venv' -exec cp -r {} "$TARGET_DIR/" \;
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Копирование завершено!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Статистика
echo "📊 Статистика:"
echo -e "   Исходная директория: ${BLUE}$(du -sh "$CURRENT_DIR" | cut -f1)${NC}"
echo -e "   Новая директория:    ${BLUE}$(du -sh "$TARGET_DIR" | cut -f1)${NC}"
echo ""

# Список скопированных файлов
echo "📋 Скопированные файлы и директории:"
ls -lah "$TARGET_DIR" | tail -n +4 | head -15
FILE_COUNT=$(find "$TARGET_DIR" -type f | wc -l)
DIR_COUNT=$(find "$TARGET_DIR" -type d | wc -l)
echo ""
echo -e "   Всего файлов: ${GREEN}$FILE_COUNT${NC}"
echo -e "   Всего директорий: ${GREEN}$DIR_COUNT${NC}"
echo ""

# Проверка файловой системы
echo "🔍 Проверка файловой системы:"
OLD_FS=$(df -T "$CURRENT_DIR" | tail -1 | awk '{print $2}')
NEW_FS=$(df -T "$TARGET_DIR" | tail -1 | awk '{print $2}')
echo -e "   Старая FS: ${YELLOW}$OLD_FS${NC}"
echo -e "   Новая FS:  ${GREEN}$NEW_FS${NC}"

if [[ "$OLD_FS" == "9p" ]] || [[ "$OLD_FS" == "drvfs" ]]; then
    echo -e "   ${GREEN}✅ Перемещено с Windows FS на Linux FS!${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}📝 Следующие шаги:${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Перейдите в новую директорию:"
echo -e "   ${GREEN}cd $TARGET_DIR${NC}"
echo ""
echo "2. Создайте виртуальное окружение:"
echo -e "   ${GREEN}uv venv${NC}"
echo ""
echo "3. Активируйте окружение:"
echo -e "   ${GREEN}source .venv/bin/activate${NC}"
echo ""
echo "4. Установите зависимости:"
echo -e "   ${GREEN}uv sync${NC}"
echo ""
echo "5. Запустите сервер:"
echo -e "   ${GREEN}./start_server.sh${NC}"
echo ""
echo -e "${YELLOW}💡 Совет: После проверки что всё работает, можете удалить старую директорию:${NC}"
echo -e "   ${YELLOW}rm -rf $CURRENT_DIR${NC}"
echo ""
