# Auto Translate - 画面自動翻訳アプリ

アプリ内の英語・中国語などのテキストを自動的にOCRで読み取り、日本語に翻訳して表示するデスクトップアプリです。

## 機能

### 1. 画面OCR翻訳モード（DeepLブラウザ翻訳ライク）
- 画面上の任意の領域をマウスで選択
- 選択領域を定期的にスクリーンキャプチャ → OCR → 翻訳
- アプリ、ゲーム、PDF等あらゆる画面上のテキストに対応
- 英語・中国語（簡体字/繁体字）の自動検出

### 2. クリップボード監視モード
- テキストをコピー（Ctrl+C）するだけで自動翻訳
- すべてのアプリケーションで動作

### 共通機能
- 日本語テキストは英語に翻訳（双方向翻訳）
- 翻訳履歴の保持
- 常に最前面表示オプション
- ダークテーマUI

## セットアップ

### 必要なもの
- Python 3.8以上
- Tesseract OCR（画面OCRモード利用時）

### インストール

```bash
# 1. Python依存パッケージ
pip install -r requirements.txt

# 2. Tesseract OCR（画面OCRモード利用時）

# Ubuntu/Debian
sudo apt install tesseract-ocr tesseract-ocr-jpn tesseract-ocr-chi-sim tesseract-ocr-chi-tra python3-tk

# macOS
brew install tesseract tesseract-lang

# Windows
# https://github.com/UB-Mannheim/tesseract/wiki からインストーラをダウンロード
```

### 起動

```bash
# GUI版（画面OCR + クリップボード両対応）
python3 auto_translate.py

# CLI版（クリップボード監視 / 直接翻訳）
python3 auto_translate_cli.py              # クリップボード監視
python3 auto_translate_cli.py -t "Hello"   # 直接翻訳
echo "Hello" | python3 auto_translate_cli.py --stdin  # パイプ入力
```

## 使い方

### 画面OCRモードの使い方
1. アプリ起動後、「画面OCR翻訳」ラジオボタンを選択
2. 「領域選択」ボタンをクリック
3. 翻訳したいアプリの画面領域をマウスでドラッグして選択
4. 選択した領域が赤枠で表示され、自動的にOCR→翻訳が開始
5. OCR間隔はスライダーで1〜10秒に調整可能

### クリップボードモードの使い方
1. 「クリップボード監視」ラジオボタンを選択（デフォルト）
2. 翻訳したいテキストをCtrl+Cでコピー
3. 自動的に翻訳結果が表示される

## 既存の類似アプリ

| アプリ名 | OS | 特徴 |
|---|---|---|
| Pot Desktop | Win/Mac/Linux | オープンソース、OCR+翻訳 |
| Translumo | Windows | リアルタイム画面OCR翻訳 |
| Bob | macOS | OCR+クリップボード翻訳 |
| QTranslate | Windows | テキスト選択で翻訳ポップアップ |
