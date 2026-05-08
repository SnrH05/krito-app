# Kripto Analiz Platformu (Titanium Bot Modülü)

Bu proje, güçlü bir **FastAPI** tabancalı Python backend'ini ve modern bir **Flutter** frontend'ini birleştiren tam kapsamlı bir kripto para analiz platformudur. Uygulama, Binance API üzerinden canlı piyasa verilerini alır ve gelişmiş algoritmik göstergeleri hesaplayarak kullanıcıya kripto piyasasındaki anlık durumları, teknik analizleri ve güçlü alım/satım sinyallerini sunar.

---

## 📁 Proje Yapısı

Proje temel olarak iki ana bileşene ayrılmıştır:

1. **Python / FastAPI Backend (Kök Dizin)**: Veri çekme, proxy, sinyal yönetimi ve teknik gösterge (indicator) hesaplamalarından sorumlu arka uç.
2. **Flutter Frontend (`kripto_app/` dizini)**: Kullanıcı arabirimini (UI), grafikleri ve alarmları idare eden mobil/web odaklı istemci uygulaması.

### 🐍 Backend (Python)

Backend, performanslı veri analitiği yapmak için `pandas` ve `numpy` kullanır.

- `main.py`: REST API isteklerini karşılayan **FastAPI** uygulamasıdır. Varsayılan olarak aşağıdaki endpoint'leri sunar:
  - `/api/signals`: `BTCUSDT` vb. bir sembol için teknik indikatör puanlamasını ve sinyallerini gönderir.
  - `/api/klines`: Belirli bir periyot ve sembol için mum (candlestick) verilerini döndürür. (Binance Kline API proxy'si)
  - `/api/tickers`: Binance üzerindeki en popüler 100 USDT paritesinin anlık fiyatını ve değişim yüzdelerini (24hr ticker) çeker.
- `indicators.py`: "Titanium Bot Teknik İndikatör Kütüphanesi". Sistemin kalbidir; tamamen bağımsız çalışan matematiksel hesaplamaları barındırır.
  - **Temel İndikatörler**: EMA, SMA, RSI, ATR, ADX, Bollinger Bands, MACD, Stochastic RSI, OBV, CMF, Supertrend.
  - **Gelişmiş Formasyon Tespitleri**: Reversal tespiti, RSI Divergence, Volatilite Patlamaları, Volatility Squeeze (Daralma), Flash Move (Ani Hareketler), Hacim Patlamaları, Wick (Fitil) Reddi tespitleri.
  - **Risk Yönetimi**: Dinamik Stop-Loss çarpanı hesaplamaları ve trende duyarlı sinyal skorlama fonksiyonları (Bot mantığı).

### 📱 Frontend (Flutter)

Frontend `kripto_app` dizininde konumlandırılmıştır ve platform bağımsız çalışabilir.

- **Ana Odak**: Kripto para izleme ve sinyal platformu olmak.
- **Özellikler**:
  - `HomeTab` (Ana Sayfa) ve `MarketsTab` (Piyasalar) şeklinde iki ana sekmeli (Bottom Navigation) yapı.
  - Grafikler (`fl_chart` kullanılarak) ile verilerin görselleştirilmesi.
  - `alert_engine.dart` üzerinden çalışan fiyat/gösterge alarm motoru.
  - Mevcut API üzerinden fiyat dalgalanmalarını çekmek için `http` paketi, yerel bildirim saklama için `shared_preferences`.

---

## 🚀 Kurulum ve Çalıştırma

### Backend'i Başlatmak (FastAPI)

1. Gerekli Python bağımlılıklarını kurun (Python 3.8+ önerilir):
   ```bash
   pip install fastapi uvicorn pandas numpy requests
   ```
2. Uygulamayı ayağa kaldırın:
   ```bash
   uvicorn main:app --reload --host 0.0.0.0 --port 8000
   ```
3. Tarayıcınızda veya Postman'de `http://127.0.0.0:8000/docs` adresine giderek Swagger UI üzerinden API endpoint'lerini test edebilirsiniz.

### Frontend'i Başlatmak (Flutter)

1. Flutter ortamının sisteminizde düzgün yüklü olduğundan emin olun (`flutter doctor` komutunu kullanarak kontrol edebilirsiniz).
2. Terminal ile `kripto_app` dizinine gidin:
   ```bash
   cd kripto_app
   ```
3. Bağımlılıkları yükleyin:
   ```bash
   flutter pub get
   ```
4. Uygulamayı bağlı bir cihazda, emulator'de veya web üzerinde çalıştırın:
   ```bash
   flutter run
   ```

_Not: Flutter uygulamasının doğru çalışması için, `kripto_app/lib/core/constants.dart` vb. bir ayar dosyasında Backend (FastAPI) API IP/URL'sinin doğru yapılandırıldığından emin olun (Örn: Emulator için `10.0.2.2:8000`, gerçek cihaz/web için makinenizin yerel IP adresi)._
