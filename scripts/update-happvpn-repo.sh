#!/bin/bash
# update-happvpn-repo.sh — Обновление репозитория happvpn из GitHub (git pull)
# Usage: ./update-happvpn-repo.sh

set -e

REPO_PATH="${REPO_PATH:-$(pwd)}"

echo "🔍 Обновление репозитория happvpn..."
cd "$REPO_PATH"

# Проверка что это git репозиторий
if [ ! -d ".git" ]; then
    echo "❌ Ошибка: $REPO_PATH не является git репозиторием"
    exit 1
fi

# Показать текущую ветку
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "Ветка: $CURRENT_BRANCH"

echo ""
echo "🔄 git pull origin $CURRENT_BRANCH..."
git pull origin "$CURRENT_BRANCH"

if [ $? -ne 0 ]; then
    echo "❌ Ошибка при обновлении"
    exit 1
fi

echo ""
echo "✅ Обновление завершено!"
git log --oneline -1

echo ""
echo "📊 Статус:"
git status --short
