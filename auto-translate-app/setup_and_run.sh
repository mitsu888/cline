#!/bin/bash
# Auto Translate セットアップスクリプト（Mac用）
# ダブルクリックまたはターミナルで実行してください

set -e

echo "==============================="
echo " Auto Translate セットアップ"
echo "==============================="
echo ""

# Homebrewの確認
if ! command -v brew &> /dev/null; then
    echo "[エラー] Homebrewがインストールされていません。"
    echo "以下を先にターミナルで実行してください："
    echo ""
    echo '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
    echo ""
    exit 1
fi

echo "[1/5] Python3 を確認中..."
if ! brew list python@3.14 &> /dev/null && ! brew list python@3.13 &> /dev/null && ! brew list python@3.12 &> /dev/null; then
    echo "  -> Homebrew版 Python3 をインストール中..."
    brew install python@3.14
fi

# Homebrew の python3 を優先的に使う
if [ -x "/opt/homebrew/bin/python3" ]; then
    PYTHON="/opt/homebrew/bin/python3"
    PIP="/opt/homebrew/bin/pip3"
elif [ -x "/usr/local/bin/python3" ]; then
    PYTHON="/usr/local/bin/python3"
    PIP="/usr/local/bin/pip3"
else
    PYTHON="python3"
    PIP="pip3"
fi
echo "  -> Python: $($PYTHON --version)"

echo ""
echo "[2/5] Tesseract OCR を確認中..."
if ! command -v tesseract &> /dev/null; then
    echo "  -> Tesseract をインストール中..."
    brew install tesseract tesseract-lang
else
    echo "  -> 既にインストール済み"
fi

echo ""
echo "[3/5] tkinter を確認中..."
if ! $PYTHON -c "import tkinter" 2> /dev/null; then
    echo "  -> python-tk をインストール中..."
    brew install python-tk
else
    echo "  -> 既にインストール済み"
fi

echo ""
echo "[4/5] Python パッケージをインストール中..."
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
$PIP install --user deep-translator pyperclip Pillow mss pytesseract 2>&1 | tail -3

echo ""
echo "[5/5] アプリを起動します..."
echo ""
echo "==============================="
echo " 起動完了！"
echo " 終了するにはウィンドウを閉じてください"
echo "==============================="
echo ""

$PYTHON "$SCRIPT_DIR/auto_translate.py"
