# Zivo AI & Cost Optimizations

This document outlines the engineering optimizations implemented to reduce AI API and infrastructure costs from **₹2–3 per scan** down to **5–10 paise per scan** (a 95%+ savings).

---

## 1. Client-Side Image Pre-Processing & Compression
* **Resolution Limiting**: Images selected for AI analysis (Food Logs, Skincare, and Supplement Vision scans) are capped at a maximum dimension of **1024px** (preserving aspect ratio) instead of uploading raw 12MP–48MP smartphone photos.
* **Format & Quality Compression**: Images are compressed on the client device (using native native compression on iOS/Android, and HTML5 Canvas scaling on Web) to **JPEG at 80% quality**.
* **Result**: Average file upload sizes dropped from **3MB–8MB** down to **80KB–200KB** (a 95%+ file size reduction), saving database bandwidth and storage.

## 2. Token Optimization for Vision Models
* **Reduced Tile Splitting**: Large multimodal models (such as Gemini) split images into 512x512 pixel tiles. 
* By downscaling images to a maximum of 1024px, the image token count was lowered from thousands of tokens to **258–512 tokens** per scan.
* **Result**: Input token costs for the vision models were slashed by **over 90%** per request.

## 3. High-Efficiency Model Selection
* **Gemini 2.5 Flash Lite Integration**: Transitioned Firebase Cloud Functions backend to utilize the `gemini-2.5-flash-lite` model for nutritional and packaging scans.
* **Result**: Flash Lite's highly competitive pricing ($0.075 per 1,000,000 input tokens) combined with client-side image compression keeps the average total API cost under **5–10 paise** per scan.

## 4. Intelligent Barcode Scanning Bypasses
* **Deterministic Local Recognition**: Barcode scans utilize local scanner libraries (Native ML Kit on mobile and Web BarcodeDetector/ZXing) instead of calling AI vision APIs for simple numeric code translation.
* **Result**: Eliminates API costs entirely for products with recognized barcodes.
