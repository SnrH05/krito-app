from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from typing import List, Optional
import indicators
import pandas as pd
import requests
import numpy as np
import math

app = FastAPI()

# CORS — Flutter web uygulamasının farklı port'tan erişebilmesi için
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

def convert_numpy(obj):
    """Numpy tiplerini Python native tiplerine çevirir (JSON uyumluluğu için)."""
    if isinstance(obj, dict):
        return {k: convert_numpy(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [convert_numpy(i) for i in obj]
    elif isinstance(obj, (np.integer,)):
        return int(obj)
    elif isinstance(obj, (np.floating,)):
        val = float(obj)
        return None if (math.isnan(val) or math.isinf(val)) else val
    elif isinstance(obj, (np.bool_,)):
        return bool(obj)
    elif isinstance(obj, np.ndarray):
        return [convert_numpy(x) for x in obj.tolist()]
    elif isinstance(obj, float):
        return None if (math.isnan(obj) or math.isinf(obj)) else obj
    return obj

def get_binance_data(symbol="BTCUSDT", interval="1h", limit=100):
    """Binance API'den canlı mum verilerini çeker ve Pandas DataFrame'e çevirir."""
    url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
    response = requests.get(url)
    data = response.json()
    
    df = pd.DataFrame(data, columns=['date', 'open', 'high', 'low', 'close', 'volume', 'close_time', 'qav', 'num_trades', 'taker_base_vol', 'taker_quote_vol', 'ignore'])
    
    df = df[['date', 'open', 'high', 'low', 'close', 'volume']]
    for col in ['open', 'high', 'low', 'close', 'volume']:
        df[col] = df[col].astype(float)
        
    return df


# ═══════════════════════════════════════════════════════════════
# ENDPOINT 1: Sinyal Verileri (mevcut)
# ═══════════════════════════════════════════════════════════════
@app.get("/api/signals")
def get_crypto_signals(symbol: str = "BTCUSDT"):
    try:
        df = get_binance_data(symbol=symbol, interval="1h", limit=100)
        signals = indicators.get_signal(df)
        all_indicators = indicators.get_all_indicators(df)
        
        return convert_numpy({
            "symbol": symbol,
            "status": "success",
            "signal_data": signals,
            "indicator_data": all_indicators
        })
    except Exception as e:
        return {"status": "error", "message": str(e)}


# ═══════════════════════════════════════════════════════════════
# ENDPOINT 2: Kline/Candlestick Verileri (YENİ)
# ═══════════════════════════════════════════════════════════════
@app.get("/api/klines")
def get_klines(symbol: str = "BTCUSDT", interval: str = "1h", limit: int = 500):
    """
    Binance kline verilerini proxy olarak döner.
    Her mum: [timestamp, open, high, low, close, volume]
    """
    try:
        # Limiti Binance max değerine kısıtla
        limit = min(limit, 1000)
        url = f"https://api.binance.com/api/v3/klines?symbol={symbol}&interval={interval}&limit={limit}"
        response = requests.get(url, timeout=10)
        raw = response.json()
        
        # Sadece ihtiyaç duyulan alanları döndür: [timestamp, O, H, L, C, V]
        candles = []
        for k in raw:
            candles.append({
                "t": int(k[0]),       # Open time (ms)
                "o": float(k[1]),     # Open
                "h": float(k[2]),     # High
                "l": float(k[3]),     # Low
                "c": float(k[4]),     # Close
                "v": float(k[5]),     # Volume
            })
        
        return {"status": "success", "symbol": symbol, "interval": interval, "candles": candles}
    except Exception as e:
        return {"status": "error", "message": str(e)}


# ═══════════════════════════════════════════════════════════════
# ENDPOINT 3: 24s Ticker Verileri (YENİ)
# ═══════════════════════════════════════════════════════════════
@app.get("/api/tickers")
def get_tickers():
    """
    Binance 24hr ticker verilerinden Flutter'ın ihtiyaç duyduğu
    en popüler 100 coinin fiyat ve değişim verilerini döner.
    """
    try:
        url = "https://api.binance.com/api/v3/ticker/24hr"
        response = requests.get(url, timeout=15)
        all_tickers = response.json()
        
        # Sadece USDT çiftlerini al ve fiyata göre sırala
        usdt_tickers = {}
        for t in all_tickers:
            sym = t.get("symbol", "")
            if sym.endswith("USDT"):
                usdt_tickers[sym] = {
                    "symbol": sym,
                    "price": float(t.get("lastPrice", 0)),
                    "change": float(t.get("priceChangePercent", 0)),
                    "volume": float(t.get("quoteVolume", 0)),
                    "high": float(t.get("highPrice", 0)),
                    "low": float(t.get("lowPrice", 0)),
                }
        
        return {"status": "success", "tickers": usdt_tickers}
    except Exception as e:
        return {"status": "error", "message": str(e)}