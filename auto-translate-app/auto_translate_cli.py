#!/usr/bin/env python3
"""
Auto Translate CLI - コマンドライン版自動翻訳

GUI環境がない場合でも使えるCLI版です。
クリップボードを監視し、変更があれば翻訳結果をターミナルに表示します。

使い方:
  python3 auto_translate_cli.py              # クリップボード監視モード
  python3 auto_translate_cli.py -t "Hello"   # 直接翻訳モード
  echo "Hello world" | python3 auto_translate_cli.py --stdin  # パイプ入力
"""

import argparse
import re
import signal
import sys
import time

from deep_translator import GoogleTranslator

# 日本語文字パターン
JAPANESE_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

# ANSIカラーコード
BLUE = "\033[94m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
DIM = "\033[2m"
BOLD = "\033[1m"
RESET = "\033[0m"


def is_mostly_japanese(text):
    if not text:
        return False
    jp_chars = len(JAPANESE_PATTERN.findall(text))
    return jp_chars / max(len(text), 1) > 0.3


def translate_text(text):
    """テキストを翻訳する"""
    if not text or not text.strip():
        return None, None

    if is_mostly_japanese(text):
        translator = GoogleTranslator(source="ja", target="en")
        translated = translator.translate(text)
        return translated, "ja → en"
    else:
        translator = GoogleTranslator(source="auto", target="ja")
        translated = translator.translate(text)
        return translated, "auto → ja"


def print_translation(original, translated, direction):
    """翻訳結果を表示"""
    timestamp = time.strftime("%H:%M:%S")
    print(f"\n{DIM}[{timestamp}] {direction}{RESET}")
    print(f"{DIM}原文:{RESET} {original[:200]}")
    print(f"{BOLD}{BLUE}翻訳:{RESET} {BOLD}{GREEN}{translated}{RESET}")
    print(f"{DIM}{'─' * 50}{RESET}")


def monitor_clipboard(interval=0.5):
    """クリップボード監視モード"""
    try:
        import pyperclip
    except ImportError:
        print("エラー: pyperclip が必要です。pip install pyperclip を実行してください。")
        sys.exit(1)

    print(f"{BOLD}{BLUE}Auto Translate CLI{RESET}")
    print(f"{DIM}クリップボードを監視中... (Ctrl+C で終了){RESET}")
    print(f"{DIM}{'─' * 50}{RESET}")

    last_content = ""
    try:
        last_content = pyperclip.paste()
    except Exception:
        pass

    def signal_handler(sig, frame):
        print(f"\n{DIM}監視を終了しました。{RESET}")
        sys.exit(0)

    signal.signal(signal.SIGINT, signal_handler)

    while True:
        try:
            current = pyperclip.paste()
            if current != last_content and current.strip() and len(current) <= 5000:
                last_content = current
                text = current.strip()
                translated, direction = translate_text(text)
                if translated and translated != text:
                    print_translation(text, translated, direction)
        except Exception as e:
            pass
        time.sleep(interval)


def translate_direct(text):
    """直接翻訳モード"""
    translated, direction = translate_text(text)
    if translated:
        print_translation(text, translated, direction)
    else:
        print("翻訳できませんでした。")


def translate_stdin():
    """標準入力から翻訳"""
    text = sys.stdin.read().strip()
    if text:
        translate_direct(text)
    else:
        print("入力テキストがありません。")


def main():
    parser = argparse.ArgumentParser(
        description="Auto Translate CLI - 自動翻訳ツール"
    )
    parser.add_argument(
        "-t", "--text",
        help="翻訳するテキストを直接指定"
    )
    parser.add_argument(
        "--stdin",
        action="store_true",
        help="標準入力からテキストを読み取って翻訳"
    )
    parser.add_argument(
        "--interval",
        type=float,
        default=0.5,
        help="クリップボード監視間隔（秒）。デフォルト: 0.5"
    )

    args = parser.parse_args()

    if args.text:
        translate_direct(args.text)
    elif args.stdin:
        translate_stdin()
    else:
        monitor_clipboard(args.interval)


if __name__ == "__main__":
    main()
