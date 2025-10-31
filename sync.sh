#!/bin/bash

# Скрипт для синхронизации проекта в WSL native FS

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
echo -e "${BLUE}🔄 Синхронизация проекта в WSL native FS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Текущая директория
CURRENT_DIR=$(pwd)
echo -e "${YELLOW}Источник:${NC} $CURRENT_DIR"
echo -e "${YELLOW}Цель:${NC}     $TARGET_DIR"
echo ""

# Проверка что не синхронизируем сами в себя
if [ "$CURRENT_DIR" = "$TARGET_DIR" ]; then
    echo -e "${RED}❌ Ошибка: Источник и цель совпадают!${NC}"
    exit 1
fi

# Проверка наличия rsync
if ! command -v rsync &> /dev/null; then
    echo -e "${RED}❌ Ошибка: rsync не найден. Установите rsync для использования этого скрипта.${NC}"
    exit 1
fi

# Создание родительской директории
if [ ! -d "$TARGET_DIR" ]; then
    echo -e "${GREEN}📁 Создание целевой директории...${NC}"
    mkdir -p "$(dirname "$TARGET_DIR")"
else
    echo -e "${GREEN}📁 Целевая директория уже существует${NC}"
    echo -e "${YELLOW}ℹ️  Файлы, которые есть только в целевом каталоге, будут сохранены${NC}"
fi

# Синхронизация с исключением .venv
echo ""
echo -e "${GREEN}🔄 Синхронизация файлов (исключая .venv)...${NC}"
echo ""

# Используем rsync БЕЗ --delete, чтобы не удалять файлы в destination
rsync -av --progress \
    --exclude='.venv' \
    --exclude='.venv/' \
    --exclude='__pycache__' \
    --exclude='__pycache__/' \
    --exclude='*.pyc' \
    --exclude='.git/objects' \
    "$CURRENT_DIR/" "$TARGET_DIR/"

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ Синхронизация завершена!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Статистика
echo "📊 Статистика:"
echo -e "   Исходная директория: ${BLUE}$(du -sh "$CURRENT_DIR" | cut -f1)${NC}"
echo -e "   Целевая директория:  ${BLUE}$(du -sh "$TARGET_DIR" | cut -f1)${NC}"
echo ""

# Список файлов в целевой директории
echo "📋 Содержимое целевой директории:"
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
echo -e "   Источник FS: ${YELLOW}$OLD_FS${NC}"
echo -e "   Цель FS:     ${GREEN}$NEW_FS${NC}"

if [[ "$OLD_FS" == "9p" ]] || [[ "$OLD_FS" == "drvfs" ]]; then
    echo -e "   ${GREEN}✅ Синхронизировано с Windows FS на Linux FS!${NC}"
fi

echo ""

