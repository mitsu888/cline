#!/usr/bin/env python3
"""
Auto Translate App - 画面自動翻訳アプリ

DeepLブラウザ翻訳のように、アプリ内の英語・中国語等のテキストを
自動的にOCRで読み取り、日本語に翻訳して表示します。

モード:
  1. 画面キャプチャモード - 指定した画面領域を常時OCR→翻訳
  2. クリップボードモード - コピーしたテキストを自動翻訳

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

try:
    import mss
    import mss.tools
    HAS_MSS = True
except ImportError:
    HAS_MSS = False

try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False

try:
    import pytesseract
    HAS_TESSERACT = True
except ImportError:
    HAS_TESSERACT = False

HAS_OCR = HAS_MSS and HAS_PIL and HAS_TESSERACT


class ScreenOCR:
    """画面領域をキャプチャしてOCRでテキストを抽出するクラス"""

    def __init__(self):
        self.sct = mss.mss() if HAS_MSS else None

    def capture_region(self, x, y, width, height):
        """指定領域をキャプチャしてPIL Imageを返す"""
        if not self.sct:
            return None
        monitor = {"top": y, "left": x, "width": width, "height": height}
        screenshot = self.sct.grab(monitor)
        return Image.frombytes("RGB", screenshot.size, screenshot.bgra, "raw", "BGRX")

    def extract_text(self, image, lang="eng+jpn+chi_sim"):
        """画像からテキストを抽出する"""
        if not HAS_TESSERACT or image is None:
            return ""
        try:
            text = pytesseract.image_to_string(image, lang=lang)
            return text.strip()
        except Exception:
            # 指定言語パックがない場合はengのみで再試行
            try:
                text = pytesseract.image_to_string(image, lang="eng")
                return text.strip()
            except Exception:
                return ""

    def capture_and_extract(self, x, y, width, height):
        """キャプチャ→OCR→テキスト返却"""
        image = self.capture_region(x, y, width, height)
        if image is None:
            return ""
        return self.extract_text(image)


class RegionSelector:
    """画面上の領域をマウスで選択するためのオーバーレイ"""

    def __init__(self, callback):
        self.callback = callback
        self.start_x = 0
        self.start_y = 0
        self.rect_id = None

    def select(self):
        """半透明オーバーレイを表示して領域選択を開始"""
        self.overlay = tk.Toplevel()
        self.overlay.attributes("-fullscreen", True)
        self.overlay.attributes("-topmost", True)
        self.overlay.attributes("-alpha", 0.3)
        self.overlay.configure(bg="black")
        self.overlay.config(cursor="crosshair")

        self.canvas = tk.Canvas(self.overlay, highlightthickness=0, bg="black")
        self.canvas.pack(fill=tk.BOTH, expand=True)

        # 説明テキスト
        self.canvas.create_text(
            self.overlay.winfo_screenwidth() // 2,
            50,
            text="翻訳したい領域をドラッグで選択してください（Escでキャンセル）",
            fill="white", font=("Helvetica", 18, "bold")
        )

        self.canvas.bind("<ButtonPress-1>", self._on_press)
        self.canvas.bind("<B1-Motion>", self._on_drag)
        self.canvas.bind("<ButtonRelease-1>", self._on_release)
        self.overlay.bind("<Escape>", self._on_cancel)

    def _on_press(self, event):
        self.start_x = event.x_root
        self.start_y = event.y_root
        if self.rect_id:
            self.canvas.delete(self.rect_id)

    def _on_drag(self, event):
        if self.rect_id:
            self.canvas.delete(self.rect_id)
        x0 = min(self.start_x, event.x_root)
        y0 = min(self.start_y, event.y_root)
        x1 = max(self.start_x, event.x_root)
        y1 = max(self.start_y, event.y_root)
        self.rect_id = self.canvas.create_rectangle(
            x0, y0, x1, y1, outline="red", width=2, fill="blue", stipple="gray25"
        )

    def _on_release(self, event):
        x = min(self.start_x, event.x_root)
        y = min(self.start_y, event.y_root)
        w = abs(event.x_root - self.start_x)
        h = abs(event.y_root - self.start_y)
        self.overlay.destroy()
        if w > 10 and h > 10:
            self.callback(x, y, w, h)

    def _on_cancel(self, event):
        self.overlay.destroy()


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
            pass
        self.root.after(self.interval_ms, self._poll)


class ScreenMonitor:
    """画面領域を定期的にOCRで監視するクラス"""

    def __init__(self, callback, interval_ms=2000):
        self.callback = callback
        self.interval_ms = interval_ms
        self.running = False
        self.root = None
        self.region = None  # (x, y, width, height)
        self.ocr = ScreenOCR() if HAS_OCR else None
        self.last_text = ""

    def set_region(self, x, y, width, height):
        self.region = (x, y, width, height)

    def start(self, root):
        self.root = root
        self.running = True
        self.last_text = ""
        self._poll()

    def stop(self):
        self.running = False

    def _poll(self):
        if not self.running or not self.root or not self.region or not self.ocr:
            return

        def do_ocr():
            x, y, w, h = self.region
            text = self.ocr.capture_and_extract(x, y, w, h)
            if text and text != self.last_text and len(text) > 2:
                self.last_text = text
                self.root.after(0, self.callback, text)

        thread = threading.Thread(target=do_ocr, daemon=True)
        thread.start()

        self.root.after(self.interval_ms, self._poll)


class Translator:
    """翻訳を実行するクラス"""

    JAPANESE_PATTERN = re.compile(r'[\u3040-\u309F\u30A0-\u30FF\u4E00-\u9FFF]')

    def __init__(self, target_lang="ja"):
        self.target_lang = target_lang
        self.translator = GoogleTranslator(source="auto", target=target_lang)

    def is_mostly_japanese(self, text):
        if not text:
            return False
        jp_chars = len(self.JAPANESE_PATTERN.findall(text))
        return jp_chars / max(len(text), 1) > 0.3

    def translate(self, text):
        if not text or len(text.strip()) == 0:
            return None, None

        if self.is_mostly_japanese(text):
            translator = GoogleTranslator(source="ja", target="en")
            translated = translator.translate(text)
            return translated, "ja → en"
        else:
            translated = self.translator.translate(text)
            return translated, f"auto → {self.target_lang}"


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
    """メインアプリケーション

    2つのモード:
      - 画面OCRモード: 選択した画面領域を定期キャプチャ→OCR→翻訳
      - クリップボードモード: コピーしたテキストを自動翻訳
    """

    MODE_CLIPBOARD = "clipboard"
    MODE_SCREEN = "screen"

    def __init__(self):
        self.root = tk.Tk()
        self.root.title("Auto Translate - 画面自動翻訳")
        self.root.geometry("560x680")
        self.root.minsize(440, 500)
        self.root.attributes("-topmost", True)

        # テーマカラー
        self.bg = "#1e1e2e"
        self.fg = "#cdd6f4"
        self.accent = "#89b4fa"
        self.surface = "#313244"
        self.green = "#a6e3a1"
        self.red = "#f38ba8"
        self.yellow = "#f9e2af"
        self.text_bg = "#181825"
        self.root.configure(bg=self.bg)

        # コンポーネント
        self.translator = Translator()
        self.history = TranslationHistory()
        self.clipboard_monitor = ClipboardMonitor(self._on_new_text)
        self.screen_monitor = ScreenMonitor(self._on_new_text, interval_ms=2000)
        self.current_mode = self.MODE_CLIPBOARD
        self.is_monitoring = False
        self.selected_region = None  # (x, y, w, h)
        self.region_indicator = None  # 領域表示ウィンドウ

        self._build_ui()
        self._start_monitoring()

        self.root.protocol("WM_DELETE_WINDOW", self._on_close)

    # ── UI構築 ──────────────────────────────────────────

    def _build_ui(self):
        style = ttk.Style()
        style.theme_use("clam")
        style.configure("TFrame", background=self.bg)
        style.configure("TLabel", background=self.bg, foreground=self.fg)
        style.configure("Title.TLabel", background=self.bg, foreground=self.accent,
                         font=("Helvetica", 14, "bold"))
        style.configure("Status.TLabel", background=self.bg, foreground=self.green,
                         font=("Helvetica", 10))

        # ── ヘッダー ──
        header = ttk.Frame(self.root)
        header.pack(fill=tk.X, padx=15, pady=(12, 4))
        ttk.Label(header, text="Auto Translate", style="Title.TLabel").pack(side=tk.LEFT)
        self.status_label = ttk.Label(header, text="", style="Status.TLabel")
        self.status_label.pack(side=tk.RIGHT)

        # ── モード切替 ──
        mode_frame = ttk.Frame(self.root)
        mode_frame.pack(fill=tk.X, padx=15, pady=4)

        self.mode_var = tk.StringVar(value=self.MODE_CLIPBOARD)

        cb_radio = tk.Radiobutton(
            mode_frame, text="クリップボード監視", variable=self.mode_var,
            value=self.MODE_CLIPBOARD, command=self._on_mode_change,
            bg=self.bg, fg=self.fg, selectcolor=self.surface,
            activebackground=self.bg, activeforeground=self.fg,
            font=("Helvetica", 10)
        )
        cb_radio.pack(side=tk.LEFT)

        ocr_state = tk.NORMAL if HAS_OCR else tk.DISABLED
        self.screen_radio = tk.Radiobutton(
            mode_frame, text="画面OCR翻訳", variable=self.mode_var,
            value=self.MODE_SCREEN, command=self._on_mode_change,
            bg=self.bg, fg=self.fg if HAS_OCR else "#585b70",
            selectcolor=self.surface, activebackground=self.bg,
            activeforeground=self.fg, font=("Helvetica", 10),
            state=ocr_state
        )
        self.screen_radio.pack(side=tk.LEFT, padx=(15, 0))

        if not HAS_OCR:
            ttk.Label(mode_frame, text="(OCR未インストール)", style="TLabel",
                      font=("Helvetica", 8)).pack(side=tk.LEFT, padx=(5, 0))

        # ── コントロールバー ──
        ctrl_frame = ttk.Frame(self.root)
        ctrl_frame.pack(fill=tk.X, padx=15, pady=4)

        self.toggle_btn = self._btn(ctrl_frame, "⏸ 停止", self._toggle_monitoring)
        self.toggle_btn.pack(side=tk.LEFT)

        self.select_region_btn = self._btn(ctrl_frame, "領域選択", self._select_region)
        self.select_region_btn.pack(side=tk.LEFT, padx=(8, 0))
        self.select_region_btn.config(state=tk.DISABLED)

        self.topmost_var = tk.BooleanVar(value=True)
        tk.Checkbutton(
            ctrl_frame, text="最前面", variable=self.topmost_var,
            command=self._toggle_topmost, bg=self.bg, fg=self.fg,
            selectcolor=self.surface, activebackground=self.bg,
            activeforeground=self.fg, font=("Helvetica", 10)
        ).pack(side=tk.LEFT, padx=(12, 0))

        self._btn(ctrl_frame, "履歴クリア", self._clear_history).pack(side=tk.RIGHT)

        # ── OCR間隔スライダー ──
        self.interval_frame = ttk.Frame(self.root)
        self.interval_frame.pack(fill=tk.X, padx=15, pady=2)
        ttk.Label(self.interval_frame, text="OCR間隔:", font=("Helvetica", 9)).pack(side=tk.LEFT)
        self.interval_var = tk.IntVar(value=2)
        self.interval_scale = tk.Scale(
            self.interval_frame, from_=1, to=10, orient=tk.HORIZONTAL,
            variable=self.interval_var, command=self._on_interval_change,
            bg=self.bg, fg=self.fg, troughcolor=self.surface,
            highlightbackground=self.bg, font=("Helvetica", 9), length=200
        )
        self.interval_scale.pack(side=tk.LEFT, padx=(5, 0))
        ttk.Label(self.interval_frame, text="秒", font=("Helvetica", 9)).pack(side=tk.LEFT)
        self.interval_frame.pack_forget()  # クリップボードモードでは非表示

        # ── 領域情報 ──
        self.region_label = ttk.Label(self.root, text="", style="TLabel",
                                       font=("Helvetica", 9))
        self.region_label.pack(fill=tk.X, padx=15)

        # ── 区切り線 ──
        tk.Frame(self.root, height=1, bg=self.surface).pack(fill=tk.X, padx=15, pady=6)

        # ── 原文 ──
        ttk.Label(self.root, text="原文:", font=("Helvetica", 9, "bold")).pack(
            anchor=tk.W, padx=15, pady=(2, 0))
        self.original_text = scrolledtext.ScrolledText(
            self.root, height=3, wrap=tk.WORD, font=("Helvetica", 11),
            bg=self.text_bg, fg=self.fg, insertbackground=self.fg,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.original_text.pack(fill=tk.X, padx=15, pady=(2, 6))

        # ── 翻訳結果 ──
        ttk.Label(self.root, text="翻訳:", font=("Helvetica", 9, "bold")).pack(
            anchor=tk.W, padx=15, pady=(0, 0))
        self.translated_text = scrolledtext.ScrolledText(
            self.root, height=4, wrap=tk.WORD, font=("Helvetica", 12, "bold"),
            bg=self.text_bg, fg=self.accent, insertbackground=self.fg,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.translated_text.pack(fill=tk.X, padx=15, pady=(2, 8))

        # ── 区切り線 ──
        tk.Frame(self.root, height=1, bg=self.surface).pack(fill=tk.X, padx=15, pady=4)

        # ── 履歴 ──
        ttk.Label(self.root, text="翻訳履歴:", font=("Helvetica", 10, "bold")).pack(
            anchor=tk.W, padx=15, pady=(2, 2))
        self.history_text = scrolledtext.ScrolledText(
            self.root, wrap=tk.WORD, font=("Helvetica", 10),
            bg=self.text_bg, fg=self.fg, insertbackground=self.fg,
            relief=tk.FLAT, padx=8, pady=6, state=tk.DISABLED
        )
        self.history_text.pack(fill=tk.BOTH, expand=True, padx=15, pady=(0, 10))

        # ── ステータスバー ──
        self.statusbar = ttk.Label(self.root, text="", font=("Helvetica", 9))
        self.statusbar.pack(fill=tk.X, padx=15, pady=(0, 8))
        self._update_statusbar_hint()

    def _btn(self, parent, text, command):
        return tk.Button(
            parent, text=text, command=command,
            bg=self.surface, fg=self.fg, relief=tk.FLAT,
            font=("Helvetica", 10), padx=10, pady=3, cursor="hand2"
        )

    # ── モード切替 ──────────────────────────────────────

    def _on_mode_change(self):
        new_mode = self.mode_var.get()
        if new_mode == self.current_mode:
            return

        # 現在の監視を停止
        self._stop_monitoring()
        self.current_mode = new_mode

        if new_mode == self.MODE_SCREEN:
            self.select_region_btn.config(state=tk.NORMAL)
            self.interval_frame.pack(fill=tk.X, padx=15, pady=2,
                                      after=self.select_region_btn.master)
            self._update_statusbar_hint()
            if self.selected_region:
                self._start_monitoring()
        else:
            self.select_region_btn.config(state=tk.DISABLED)
            self.interval_frame.pack_forget()
            self._hide_region_indicator()
            self.region_label.config(text="")
            self._start_monitoring()
            self._update_statusbar_hint()

    def _on_interval_change(self, val):
        interval_ms = int(val) * 1000
        self.screen_monitor.interval_ms = interval_ms

    # ── 領域選択 ──────────────────────────────────────

    def _select_region(self):
        self._stop_monitoring()
        self._hide_region_indicator()
        # メインウィンドウを一時的に隠す
        self.root.withdraw()
        self.root.after(300, self._do_region_select)

    def _do_region_select(self):
        selector = RegionSelector(self._on_region_selected)
        selector.select()

    def _on_region_selected(self, x, y, w, h):
        self.root.deiconify()
        self.selected_region = (x, y, w, h)
        self.screen_monitor.set_region(x, y, w, h)
        self.region_label.config(
            text=f"選択領域: ({x}, {y}) - {w}x{h}px"
        )
        self._show_region_indicator(x, y, w, h)
        self._start_monitoring()

    def _show_region_indicator(self, x, y, w, h):
        """選択領域を赤枠で表示"""
        self._hide_region_indicator()
        border = tk.Toplevel(self.root)
        border.overrideredirect(True)
        border.attributes("-topmost", True)
        border.geometry(f"{w+4}x{h+4}+{x-2}+{y-2}")
        # 透明な中央部分を持つ赤枠のみ表示
        border.attributes("-alpha", 0.6)
        canvas = tk.Canvas(border, highlightthickness=0, bg="black")
        canvas.pack(fill=tk.BOTH, expand=True)
        canvas.create_rectangle(2, 2, w+2, h+2, outline="red", width=2, fill="")
        # クリック透過（X11環境のみ）
        try:
            border.wm_attributes("-transparentcolor", "black")
        except tk.TclError:
            pass
        self.region_indicator = border

    def _hide_region_indicator(self):
        if self.region_indicator:
            self.region_indicator.destroy()
            self.region_indicator = None

    # ── 監視制御 ──────────────────────────────────────

    def _on_new_text(self, text):
        """新しいテキストが検出されたときのコールバック"""
        if not text or len(text) > 5000:
            return

        def do_translate():
            try:
                translated, direction = self.translator.translate(text)
                if translated and translated != text:
                    self.history.add(text, translated, direction)
                    self.root.after(0, self._update_result, text, translated, direction)
            except Exception as e:
                self.root.after(0, self._show_error, str(e))

        threading.Thread(target=do_translate, daemon=True).start()

    def _update_result(self, original, translated, direction):
        self._set_text(self.original_text, original)
        self._set_text(self.translated_text, translated)
        self._refresh_history()
        self.statusbar.config(
            text=f"[{direction}] {time.strftime('%H:%M:%S')} に翻訳完了"
        )

    def _show_error(self, msg):
        self.statusbar.config(text=f"エラー: {msg}")

    def _set_text(self, widget, text):
        widget.config(state=tk.NORMAL)
        widget.delete("1.0", tk.END)
        widget.insert("1.0", text)
        widget.config(state=tk.DISABLED)

    def _refresh_history(self):
        items = self.history.get_all()
        lines = []
        for item in items[1:]:
            preview = item["original"][:60]
            if len(item["original"]) > 60:
                preview += "..."
            lines.append(f"[{item['time']}] {item['direction']}")
            lines.append(f"  {preview}")
            lines.append(f"  -> {item['translated'][:80]}")
            lines.append("")
        self._set_text(self.history_text, "\n".join(lines))

    def _toggle_monitoring(self):
        if self.is_monitoring:
            self._stop_monitoring()
        else:
            self._start_monitoring()

    def _start_monitoring(self):
        self.is_monitoring = True
        if self.current_mode == self.MODE_CLIPBOARD:
            self.clipboard_monitor.start(self.root)
        elif self.current_mode == self.MODE_SCREEN and self.selected_region:
            self.screen_monitor.start(self.root)
        self.toggle_btn.config(text="⏸ 停止")
        self.status_label.config(text="● 監視中", foreground=self.green)

    def _stop_monitoring(self):
        self.is_monitoring = False
        self.clipboard_monitor.stop()
        self.screen_monitor.stop()
        self.toggle_btn.config(text="▶ 開始")
        self.status_label.config(text="● 停止中", foreground=self.red)

    def _toggle_topmost(self):
        self.root.attributes("-topmost", self.topmost_var.get())

    def _clear_history(self):
        self.history.clear()
        self._set_text(self.history_text, "")
        self._set_text(self.original_text, "")
        self._set_text(self.translated_text, "")
        self.statusbar.config(text="履歴をクリアしました")

    def _update_statusbar_hint(self):
        if self.current_mode == self.MODE_CLIPBOARD:
            self.statusbar.config(text="テキストをコピー(Ctrl+C)すると自動翻訳されます")
        else:
            if self.selected_region:
                self.statusbar.config(text="選択領域を定期的にOCR翻訳中...")
            else:
                self.statusbar.config(text="「領域選択」で翻訳する画面領域を指定してください")

    def _on_close(self):
        self.clipboard_monitor.stop()
        self.screen_monitor.stop()
        self._hide_region_indicator()
        self.root.destroy()

    def run(self):
        self.root.mainloop()


if __name__ == "__main__":
    app = AutoTranslateApp()
    app.run()
