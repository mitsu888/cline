#!/usr/bin/env python3
"""
Auto Translate App - クリップボード自動翻訳アプリ

テキストをコピー(Ctrl+C)するだけで、自動的に日本語に翻訳して表示します。
ブラウザだけでなく、あらゆるアプリケーション内の英語テキストを翻訳できます。

使い方:
  python3 auto_translate.py
"""

import re
import threading
import time
import tkinter as tk
from tkinter import ttk, scrolledtext
from collections import deque

from deep_translator import GoogleTranslator


class ClipboardMonitor:
    """クリップボードの変更を監視するクラス"""

    def __init__(self, callback, interval_ms=500):
        self.callback = callback
        self.interval_ms = interval_ms
        self.last_content = ""
        self.running = False
        self.root = None

    def start(self, root):
        self.root = root
        self.running = True
        # 初期値を取得
        try:
            self.last_content = root.clipboard_get()
        except tk.TclError:
            self.last_content = ""
        self._poll()

    def stop(self):
        self.running = False

    def _poll(self):
        if not self.running or not self.root:
            return
        try:
            current = self.root.clipboard_get()
            if current != self.last_content and current.strip():
                self.last_content = current
                self.callback(current.strip())
        except tk.TclError:
            pass  # クリップボードが空またはアクセス不可
        self.root.after(self.interval_ms, self._poll)


class Translator:
    """翻訳を実行するクラス"""

    # 日本語文字のパターン（ひらがな、カタカナ、漢字）
    JAPANESE_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

    def __init__(self, target_lang="ja"):
        self.target_lang = target_lang
        self.translator = GoogleTranslator(source="auto", target=target_lang)

    def is_mostly_japanese(self, text):
        """テキストが主に日本語かどうか判定"""
        if not text:
            return False
        jp_chars = len(self.JAPANESE_PATTERN.findall(text))
        # 日本語文字が全体の30%以上なら日本語とみなす
        return jp_chars / max(len(text), 1) > 0.3

    def translate(self, text):
        """テキストを翻訳する。日本語テキストの場合は英語に翻訳。"""
        if not text or len(text.strip()) == 0:
            return None, None

        if self.is_mostly_japanese(text):
            # 日本語 → 英語
            translator = GoogleTranslator(source="ja", target="en")
            translated = translator.translate(text)
            return translated, "ja → en"
        else:
            # その他 → 日本語
            translated = self.translator.translate(text)
            return translated, f"auto → {self.target_lang}"
        return None, None


class TranslationHistory:
    """翻訳履歴を管理するクラス"""

    def __init__(self, max_size=50):
        self.history = deque(maxlen=max_size)

    def add(self, original, translated, direction):
        self.history.appendleft({
            "original": original,
            "translated": translated,
            "direction": direction,
            "time": time.strftime("%H:%M:%S"),
        })

    def get_all(self):
        return list(self.history)

    def clear(self):
        self.history.clear()


class AutoTranslateApp:
    """メインアプリケーションクラス"""

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Auto Translate - 自動翻訳アプリ")
        self.root.geometry("520x600")
        self.root.minsize(400, 400)

        # 常に最前面に表示
        self.root.attributes("-topmost", True)

        # ダークテーマカラー
        self.bg_color = "#1e1e2e"
        self.fg_color = "#cdd6f4"
        self.accent_color = "#89b4fa"
        self.surface_color = "#313244"
        self.green_color = "#a6e3a1"
        self.red_color = "#f38ba8"
        self.yellow_color = "#f9e2af"
        self.text_bg = "#181825"

        self.root.configure(bg=self.bg_color)

        # コンポーネント初期化
        self.translator = Translator()
        self.history = TranslationHistory()
        self.clipboard_monitor = ClipboardMonitor(self._on_clipboard_change)
        self.is_monitoring = False

        self._build_ui()
        self._start_monitoring()

        # ウィンドウ閉じる時のクリーンアップ
        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        """UIを構築"""
        style = ttk.Style()
        style.theme_use("clam")

        # スタイル設定
        style.configure("TFrame", background=self.bg_color)
        style.configure("TLabel", background=self.bg_color, foreground=self.fg_color)
        style.configure("Title.TLabel", background=self.bg_color, foreground=self.accent_color,
                         font=("Helvetica", 14, "bold"))
        style.configure("Status.TLabel", background=self.bg_color, foreground=self.green_color,
                         font=("Helvetica", 10))
        style.configure("Direction.TLabel", background=self.surface_color, foreground=self.yellow_color,
                         font=("Helvetica", 9))
        style.configure("Accent.TButton", background=self.accent_color, foreground="#1e1e2e",
                         font=("Helvetica", 10, "bold"))
        style.configure("TCheckbutton", background=self.bg_color, foreground=self.fg_color)

        # ヘッダー
        header_frame = ttk.Frame(self.root, style="TFrame")
        header_frame.pack(fill=tk.X, padx=15, pady=(15, 5))

        ttk.Label(header_frame, text="Auto Translate", style="Title.TLabel").pack(side=tk.LEFT)

        self.status_label = ttk.Label(header_frame, text="● 監視中", style="Status.TLabel")
        self.status_label.pack(side=tk.RIGHT)

        # コントロールバー
        control_frame = ttk.Frame(self.root, style="TFrame")
        control_frame.pack(fill=tk.X, padx=15, pady=5)

        self.toggle_btn = tk.Button(
            control_frame, text="⏸ 停止", command=self._toggle_monitoring,
            bg=self.surface_color, fg=self.fg_color, relief=tk.FLAT,
            font=("Helvetica", 10), padx=12, pady=4, cursor="hand2"
        )
        self.toggle_btn.pack(side=tk.LEFT)

        self.topmost_var = tk.BooleanVar(value=True)
        topmost_cb = tk.Checkbutton(
            control_frame, text="常に最前面", variable=self.topmost_var,
            command=self._toggle_topmost, bg=self.bg_color, fg=self.fg_color,
            selectcolor=self.surface_color, activebackground=self.bg_color,
            activeforeground=self.fg_color, font=("Helvetica", 10)
        )
        topmost_cb.pack(side=tk.LEFT, padx=(15, 0))

        clear_btn = tk.Button(
            control_frame, text="履歴クリア", command=self._clear_history,
            bg=self.surface_color, fg=self.fg_color, relief=tk.FLAT,
            font=("Helvetica", 10), padx=12, pady=4, cursor="hand2"
        )
        clear_btn.pack(side=tk.RIGHT)

        # 区切り線
        separator = tk.Frame(self.root, height=1, bg=self.surface_color)
        separator.pack(fill=tk.X, padx=15, pady=8)

        # 最新の翻訳結果表示エリア
        latest_frame = ttk.Frame(self.root, style="TFrame")
        latest_frame.pack(fill=tk.X, padx=15, pady=(0, 5))

        ttk.Label(latest_frame, text="最新の翻訳:", style="TLabel",
                  font=("Helvetica", 10, "bold")).pack(anchor=tk.W)

        self.direction_label = ttk.Label(latest_frame, text="", style="Direction.TLabel")
        self.direction_label.pack(anchor=tk.W, pady=(2, 0))

        # 原文
        orig_label_frame = ttk.Frame(self.root, style="TFrame")
        orig_label_frame.pack(fill=tk.X, padx=15, pady=(5, 2))
        ttk.Label(orig_label_frame, text="原文:", style="TLabel",
                  font=("Helvetica", 9)).pack(anchor=tk.W)

        self.original_text = scrolledtext.ScrolledText(
            self.root, height=3, wrap=tk.WORD, font=("Helvetica", 11),
            bg=self.text_bg, fg=self.fg_color, insertbackground=self.fg_color,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.original_text.pack(fill=tk.X, padx=15, pady=(0, 5))

        # 翻訳結果
        trans_label_frame = ttk.Frame(self.root, style="TFrame")
        trans_label_frame.pack(fill=tk.X, padx=15, pady=(0, 2))
        ttk.Label(trans_label_frame, text="翻訳:", style="TLabel",
                  font=("Helvetica", 9)).pack(anchor=tk.W)

        self.translated_text = scrolledtext.ScrolledText(
            self.root, height=4, wrap=tk.WORD, font=("Helvetica", 12, "bold"),
            bg=self.text_bg, fg=self.accent_color, insertbackground=self.fg_color,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.translated_text.pack(fill=tk.X, padx=15, pady=(0, 10))

        # 区切り線
        separator2 = tk.Frame(self.root, height=1, bg=self.surface_color)
        separator2.pack(fill=tk.X, padx=15, pady=5)

        # 履歴エリア
        history_header = ttk.Frame(self.root, style="TFrame")
        history_header.pack(fill=tk.X, padx=15, pady=(0, 5))
        ttk.Label(history_header, text="翻訳履歴:", style="TLabel",
                  font=("Helvetica", 10, "bold")).pack(anchor=tk.W)

        self.history_text = scrolledtext.ScrolledText(
            self.root, wrap=tk.WORD, font=("Helvetica", 10),
            bg=self.text_bg, fg=self.fg_color, insertbackground=self.fg_color,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.history_text.pack(fill=tk.BOTH, expand=True, padx=15, pady=(0, 15))

        # ステータスバー
        self.statusbar = ttk.Label(
            self.root, text="テキストをコピー(Ctrl+C)すると自動で翻訳されます",
            style="TLabel", font=("Helvetica", 9)
        )
        self.statusbar.pack(fill=tk.X, padx=15, pady=(0, 10))

    def _set_text(self, widget, text):
        """読み取り専用テキストウィジェットにテキストを設定"""
        widget.config(state=tk.NORMAL)
        widget.delete("1.0", tk.END)
        widget.insert("1.0", text)
        widget.config(state=tk.DISABLED)

    def _on_clipboard_change(self, text):
        """クリップボードの内容が変わったときのコールバック"""
        if not text or len(text) > 5000:
            return

        # 翻訳をバックグラウンドスレッドで実行
        def do_translate():
            try:
                translated, direction = self.translator.translate(text)
                if translated and translated != text:
                    self.history.add(text, translated, direction)
                    # UIスレッドで更新
                    self.root.after(0, self._update_ui, text, translated, direction)
            except Exception as e:
                self.root.after(0, self._show_error, str(e))

        thread = threading.Thread(target=do_translate, daemon=True)
        thread.start()

    def _update_ui(self, original, translated, direction):
        """翻訳結果でUIを更新"""
        self._set_text(self.original_text, original)
        self._set_text(self.translated_text, translated)
        self.direction_label.config(text=f"  {direction}  ")
        self._refresh_history()
        self.statusbar.config(text=f"最終翻訳: {time.strftime('%H:%M:%S')}")

    def _show_error(self, error_msg):
        """エラーメッセージを表示"""
        self.statusbar.config(text=f"エラー: {error_msg}")

    def _refresh_history(self):
        """履歴表示を更新"""
        items = self.history.get_all()
        lines = []
        for item in items[1:]:  # 最新は上部に表示済みなのでスキップ
            orig_preview = item["original"][:60]
            if len(item["original"]) > 60:
                orig_preview += "..."
            lines.append(f"[{item['time']}] {item['direction']}")
            lines.append(f"  {orig_preview}")
            lines.append(f"  → {item['translated'][:80]}")
            lines.append("")
        self._set_text(self.history_text, "\n".join(lines))

    def _toggle_monitoring(self):
        """クリップボード監視のオン/オフ切替"""
        if self.is_monitoring:
            self._stop_monitoring()
        else:
            self._start_monitoring()

    def _start_monitoring(self):
        """監視開始"""
        self.is_monitoring = True
        self.clipboard_monitor.start(self.root)
        self.toggle_btn.config(text="⏸ 停止", bg=self.surface_color)
        self.status_label.config(text="● 監視中", foreground=self.green_color)

    def _stop_monitoring(self):
        """監視停止"""
        self.is_monitoring = False
        self.clipboard_monitor.stop()
        self.toggle_btn.config(text="▶ 開始", bg=self.surface_color)
        self.status_label.config(text="● 停止中", foreground=self.red_color)

    def _toggle_topmost(self):
        """常に最前面のオン/オフ"""
        self.root.attributes("-topmost", self.topmost_var.get())

    def _clear_history(self):
        """履歴をクリア"""
        self.history.clear()
        self._set_text(self.history_text, "")
        self._set_text(self.original_text, "")
        self._set_text(self.translated_text, "")
        self.direction_label.config(text="")
        self.statusbar.config(text="履歴をクリアしました")

    def _on_close(self):
        """アプリ終了時のクリーンアップ"""
        self.clipboard_monitor.stop()
        self.root.destroy()

    def run(self):
        """アプリケーション起動"""
        self.root.mainloop()


if __name__ == "__main__":
    app = AutoTranslateApp()
    app.run()
