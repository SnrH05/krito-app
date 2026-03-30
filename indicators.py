
"""
indicators.py — Titanium Bot Teknik İndikatör Kütüphanesi
==========================================================
Tamamen bağımsız, saf matematiksel hesaplama modülü.
Telegram, bot, veritabanı veya ağ bağlantısı içermez.

Bağımlılıklar: pandas, numpy

Kullanım:
    import pandas as pd
    from indicators import calculate_rsi, get_all_indicators, get_signal

    df = pd.DataFrame(ohlcv_data, columns=['date','open','high','low','close','volume'])
    signals = get_signal(df)   # -> {'direction': 'LONG', 'score': 85, ...}
    values  = get_all_indicators(df)  # -> {'rsi': 42.3, 'adx': 28.1, ...}
"""

import pandas as pd
import numpy as np
from typing import Tuple, Optional, Dict, List


# ============================================================
# 📈 BÖLÜM 1: TEMEL İNDİKATÖRLER
# ============================================================

def calculate_ema(series: pd.Series, span: int) -> pd.Series:
    """
    Exponential Moving Average (EMA) hesapla.

    Args:
        series: Fiyat serisi (genellikle 'close')
        span:   EMA periyodu (örn. 9, 21, 50, 200)

    Returns:
        EMA serisi (pd.Series)
    """
    return series.ewm(span=span, adjust=False).mean()


def calculate_sma(series: pd.Series, window: int) -> pd.Series:
    """
    Simple Moving Average (SMA) hesapla.

    Args:
        series: Fiyat serisi
        window: SMA periyodu (örn. 20, 50, 200)

    Returns:
        SMA serisi (pd.Series)
    """
    return series.rolling(window=window).mean()


def calculate_rsi(series: pd.Series, period: int = 14) -> pd.Series:
    """
    Relative Strength Index (RSI) hesapla.

    Sıfıra bölme korumalı ve NaN-güvenli versiyon.

    Args:
        series: Fiyat serisi (genellikle 'close')
        period: RSI periyodu (default: 14)

    Returns:
        RSI serisi — 0-100 arasında kırpılmış, NaN → 50 (nötr)
    """
    delta = series.diff()
    gain  = (delta.where(delta > 0, 0)).rolling(window=period).mean()
    loss  = (-delta.where(delta < 0, 0)).rolling(window=period).mean()

    loss = loss.replace(0, 1e-10)          # Sıfıra bölme koruması
    rs   = gain / loss
    rsi  = 100 - (100 / (1 + rs))

    rsi = rsi.clip(0, 100)
    return rsi.fillna(50)                  # Yetersiz veri → nötr


def calculate_atr(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Average True Range (ATR) hesapla.

    Args:
        df:     OHLCV DataFrame — 'high', 'low', 'close' sütunları zorunlu
        period: ATR periyodu (default: 14)

    Returns:
        ATR serisi (pd.Series)
    """
    df = df.copy()
    df['_hl']  = df['high'] - df['low']
    df['_hpc'] = (df['high'] - df['close'].shift(1)).abs()
    df['_lpc'] = (df['low']  - df['close'].shift(1)).abs()
    df['_tr']  = df[['_hl', '_hpc', '_lpc']].max(axis=1)
    return df['_tr'].rolling(period).mean()


def calculate_adx(df: pd.DataFrame, period: int = 14) -> pd.Series:
    """
    Average Directional Index (ADX) hesapla.

    ADX trend gücünü ölçer (0-100):
      < 20 = zayıf/yok
      20-25 = orta
      > 25 = güçlü trend

    Args:
        df:     OHLCV DataFrame
        period: ADX periyodu (default: 14)

    Returns:
        ADX serisi — 0-100 arası, NaN/inf → 0
    """
    df = df.copy()
    df['_hl']  = df['high'] - df['low']
    df['_hpc'] = (df['high'] - df['close'].shift(1)).abs()
    df['_lpc'] = (df['low']  - df['close'].shift(1)).abs()
    df['_tr']  = df[['_hl', '_hpc', '_lpc']].max(axis=1)
    df['_atr'] = df['_tr'].rolling(period).mean()

    df['_up']   = df['high'] - df['high'].shift(1)
    df['_down'] = df['low'].shift(1) - df['low']

    df['_plus_dm']  = np.where(
        (df['_up'] > df['_down']) & (df['_up'] > 0), df['_up'], 0
    )
    df['_minus_dm'] = np.where(
        (df['_down'] > df['_up']) & (df['_down'] > 0), df['_down'], 0
    )

    atr_safe = df['_atr'].replace(0, 1e-10)
    df['_plus_di']  = 100 * (df['_plus_dm'].ewm(alpha=1/period).mean()  / atr_safe)
    df['_minus_di'] = 100 * (df['_minus_dm'].ewm(alpha=1/period).mean() / atr_safe)

    di_sum = (df['_plus_di'] + df['_minus_di']).replace(0, 1e-10)
    df['_dx']  = 100 * (df['_plus_di'] - df['_minus_di']).abs() / di_sum
    df['_adx'] = df['_dx'].ewm(alpha=1/period).mean()

    return df['_adx'].fillna(0).replace([np.inf, -np.inf], 0)


def calculate_adx_full(df: pd.DataFrame, period: int = 14) -> Dict:
    """
    ADX + +DI / -DI değerlerini birlikte döndür.

    Returns:
        {
            'adx':      float,
            'plus_di':  float,
            'minus_di': float,
            'trend':    'UP' | 'DOWN' | 'NEUTRAL'
        }
    """
    df = df.copy()
    df['_hl']  = df['high'] - df['low']
    df['_hpc'] = (df['high'] - df['close'].shift(1)).abs()
    df['_lpc'] = (df['low']  - df['close'].shift(1)).abs()
    df['_tr']  = df[['_hl', '_hpc', '_lpc']].max(axis=1)
    df['_atr'] = df['_tr'].rolling(period).mean()

    df['_up']   = df['high'] - df['high'].shift(1)
    df['_down'] = df['low'].shift(1) - df['low']

    df['_plus_dm']  = np.where(
        (df['_up'] > df['_down']) & (df['_up'] > 0), df['_up'], 0
    )
    df['_minus_dm'] = np.where(
        (df['_down'] > df['_up']) & (df['_down'] > 0), df['_down'], 0
    )

    atr_safe = df['_atr'].replace(0, 1e-10)
    df['_plus_di']  = 100 * (df['_plus_dm'].ewm(alpha=1/period).mean()  / atr_safe)
    df['_minus_di'] = 100 * (df['_minus_dm'].ewm(alpha=1/period).mean() / atr_safe)

    di_sum = (df['_plus_di'] + df['_minus_di']).replace(0, 1e-10)
    df['_dx']  = 100 * (df['_plus_di'] - df['_minus_di']).abs() / di_sum
    df['_adx'] = df['_dx'].ewm(alpha=1/period).mean()

    adx_val      = float(df['_adx'].fillna(0).iloc[-1])
    plus_di_val  = float(df['_plus_di'].fillna(0).iloc[-1])
    minus_di_val = float(df['_minus_di'].fillna(0).iloc[-1])

    if plus_di_val > minus_di_val:
        trend = 'UP'
    elif minus_di_val > plus_di_val:
        trend = 'DOWN'
    else:
        trend = 'NEUTRAL'

    return {
        'adx': round(adx_val, 2),
        'plus_di': round(plus_di_val, 2),
        'minus_di': round(minus_di_val, 2),
        'trend': trend,
    }


def calculate_bollinger(
    df: pd.DataFrame,
    period: int = 20,
    std_dev: float = 2.0
) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    Bollinger Bands hesapla.

    Args:
        df:      OHLCV DataFrame — 'close' sütunu zorunlu
        period:  SMA periyodu (default: 20)
        std_dev: Standart sapma çarpanı (default: 2)

    Returns:
        (lower_band, middle_band, upper_band) — hepsi pd.Series
    """
    sma   = df['close'].rolling(period).mean()
    std   = df['close'].rolling(period).std()
    upper = sma + (std * std_dev)
    lower = sma - (std * std_dev)
    return lower, sma, upper


def calculate_macd(
    series: pd.Series,
    fast: int = 12,
    slow: int = 26,
    signal: int = 9
) -> Tuple[pd.Series, pd.Series, pd.Series]:
    """
    MACD hesapla.

    Args:
        series: Fiyat serisi (close)
        fast:   Hızlı EMA periyodu (default: 12)
        slow:   Yavaş EMA periyodu (default: 26)
        signal: Signal line periyodu (default: 9)

    Returns:
        (macd_line, signal_line, histogram) — hepsi pd.Series
    """
    ema_fast    = calculate_ema(series, fast)
    ema_slow    = calculate_ema(series, slow)
    macd_line   = ema_fast - ema_slow
    signal_line = calculate_ema(macd_line, signal)
    histogram   = macd_line - signal_line
    return macd_line, signal_line, histogram


def calculate_stochastic_rsi(
    series: pd.Series,
    rsi_period: int = 14,
    stoch_period: int = 14,
    k_smooth: int = 3,
    d_smooth: int = 3
) -> Tuple[pd.Series, pd.Series]:
    """
    Stochastic RSI hesapla.

    RSI üzerine Stochastic formülü uygular — aşırı alım/satım
    bölgelerini daha erken yakalar.

    Args:
        series:       Fiyat serisi (close)
        rsi_period:   RSI periyodu (default: 14)
        stoch_period: Stochastic pencere periyodu (default: 14)
        k_smooth:     %K düzleştirme periyodu (default: 3)
        d_smooth:     %D düzleştirme periyodu (default: 3)

    Returns:
        (stoch_k, stoch_d) — 0-100 arası pd.Series
    """
    rsi      = calculate_rsi(series, period=rsi_period)
    rsi_low  = rsi.rolling(window=stoch_period).min()
    rsi_high = rsi.rolling(window=stoch_period).max()

    denom    = (rsi_high - rsi_low).replace(0, 1e-10)
    stoch    = ((rsi - rsi_low) / denom) * 100

    stoch_k  = stoch.rolling(window=k_smooth).mean()
    stoch_d  = stoch_k.rolling(window=d_smooth).mean()

    stoch_k  = stoch_k.clip(0, 100).fillna(50)
    stoch_d  = stoch_d.clip(0, 100).fillna(50)
    return stoch_k, stoch_d


def calculate_obv(df: pd.DataFrame) -> pd.Series:
    """
    On-Balance Volume (OBV) hesapla.

    Fiyat yönüne göre hacmi kümülatif toplar.

    Args:
        df: OHLCV DataFrame

    Returns:
        OBV serisi (pd.Series)
    """
    direction = ((df['close'].diff() > 0).astype(int) * 2 - 1)
    return (direction * df['volume']).cumsum()


def calculate_cmf(df: pd.DataFrame, period: int = 20) -> pd.Series:
    """
    Chaikin Money Flow (CMF) hesapla.

    Pozitif CMF = alım baskısı, negatif CMF = satış baskısı.

    Args:
        df:     OHLCV DataFrame — 'high', 'low', 'close', 'volume' zorunlu
        period: CMF periyodu (default: 20)

    Returns:
        CMF serisi — -1 ile +1 arasında
    """
    hl_range = (df['high'] - df['low']).replace(0, 1e-10)
    mf_mult  = ((df['close'] - df['low']) - (df['high'] - df['close'])) / hl_range
    mf_vol   = mf_mult * df['volume']

    vol_sum = df['volume'].rolling(window=period).sum().replace(0, 1e-10)
    cmf     = mf_vol.rolling(window=period).sum() / vol_sum
    return cmf.clip(-1, 1).fillna(0)


def calculate_supertrend(
    df: pd.DataFrame,
    period: int = 10,
    multiplier: float = 3.0
) -> Tuple[pd.Series, pd.Series]:
    """
    SuperTrend indikatörü hesapla.

    Args:
        df:         OHLCV DataFrame — 'high', 'low', 'close' zorunlu
        period:     ATR periyodu (default: 10)
        multiplier: ATR çarpanı (default: 3.0)

    Returns:
        (supertrend_line, trend_direction)
        trend_direction: 1 = uptrend, -1 = downtrend (pd.Series)
    """
    df        = df.copy()
    atr       = calculate_atr(df, period)
    hl2       = (df['high'] + df['low']) / 2
    basic_up  = hl2 + (multiplier * atr)
    basic_lo  = hl2 - (multiplier * atr)

    final_up  = basic_up.copy()
    final_lo  = basic_lo.copy()
    trend     = pd.Series(0, index=df.index)

    for i in range(1, len(df)):
        fu_prev = final_up.iloc[i-1]
        fl_prev = final_lo.iloc[i-1]
        c_prev  = df['close'].iloc[i-1]

        final_up.iloc[i] = basic_up.iloc[i] if (basic_up.iloc[i] < fu_prev or c_prev > fu_prev) else fu_prev
        final_lo.iloc[i] = basic_lo.iloc[i] if (basic_lo.iloc[i] > fl_prev or c_prev < fl_prev) else fl_prev

        prev_trend = trend.iloc[i-1] if i > 0 else 1
        if prev_trend == 1:
            trend.iloc[i] = -1 if df['close'].iloc[i] < final_lo.iloc[i] else 1
        else:
            trend.iloc[i] =  1 if df['close'].iloc[i] > final_up.iloc[i] else -1

    supertrend = pd.Series(index=df.index, dtype='float64')
    supertrend[trend == 1]  = final_lo[trend == 1]
    supertrend[trend == -1] = final_up[trend == -1]
    return supertrend, trend


# ============================================================
# 🔄 BÖLÜM 2: REVERSAL TESPİTİ
# ============================================================

def calculate_momentum_reversal(
    df: pd.DataFrame,
    lookback: int = 5,
    threshold: float = 2.0
) -> Tuple[Optional[str], float]:
    """
    Son N mumda ani momentum değişimi tespiti.

    Args:
        df:        OHLCV DataFrame
        lookback:  Kaç mum geriye bakılacak (default: 5)
        threshold: Tetikleyici yüzde değişim eşiği (default: 2.0)

    Returns:
        (reversal_type, change_pct)
        reversal_type: 'REVERSAL_UP' | 'REVERSAL_DOWN' | None
    """
    if len(df) < lookback + 1:
        return None, 0.0

    recent     = df['close'].tail(lookback)
    first, last = float(recent.iloc[0]), float(recent.iloc[-1])
    change_pct  = ((last - first) / first) * 100

    if change_pct > threshold:
        return 'REVERSAL_UP', change_pct
    elif change_pct < -threshold:
        return 'REVERSAL_DOWN', change_pct
    return None, change_pct


def check_rsi_divergence(
    df: pd.DataFrame,
    lookback: int = 14
) -> Tuple[Optional[str], int]:
    """
    RSI Diverjans tespiti.

    Bullish Div : Fiyat düşük dip yaparken RSI yüksek dip yapar
    Bearish Div : Fiyat yüksek zirve yaparken RSI düşük zirve yapar

    Args:
        df:       OHLCV DataFrame
        lookback: Tarihsel pencere (default: 14)

    Returns:
        (divergence_type, strength)
        divergence_type: 'BULLISH_DIV' | 'BEARISH_DIV' | None
        strength:        0-100 arası güç skoru
    """
    if len(df) < lookback + 1:
        return None, 0

    price = df['close'].tail(lookback)
    rsi   = calculate_rsi(df['close']).tail(lookback)

    # Son 3 mumdaki yönelim (basit ama güvenilir yaklaşım)
    price_falling = float(price.iloc[-1]) < float(price.iloc[-3])
    rsi_rising    = float(rsi.iloc[-1])   > float(rsi.iloc[-3])
    curr_rsi      = float(rsi.iloc[-1])

    if price_falling and rsi_rising and curr_rsi < 40:
        strength = min(100, int(abs(float(rsi.iloc[-1]) - float(rsi.iloc[-3])) * 5))
        return 'BULLISH_DIV', strength

    price_rising  = float(price.iloc[-1]) > float(price.iloc[-3])
    rsi_falling   = float(rsi.iloc[-1])   < float(rsi.iloc[-3])

    if price_rising and rsi_falling and curr_rsi > 60:
        strength = min(100, int(abs(float(rsi.iloc[-3]) - float(rsi.iloc[-1])) * 5))
        return 'BEARISH_DIV', strength

    return None, 0


def check_volatility_spike(
    df: pd.DataFrame,
    period: int = 14,
    multiplier: float = 2.0
) -> Tuple[Optional[str], float]:
    """
    Volatilite patlaması tespiti.

    Mevcut ATR / Ortalama ATR oranı eşiği aştığında sinyal üretir.

    Args:
        df:         OHLCV DataFrame
        period:     ATR periyodu (default: 14)
        multiplier: Eşik çarpanı (default: 2.0)

    Returns:
        (spike_type, atr_ratio)
        spike_type: 'SPIKE_UP' | 'SPIKE_DOWN' | None
    """
    atr = calculate_atr(df, period)
    if atr.isna().all():
        return None, 1.0

    curr_atr = float(atr.iloc[-1])
    avg_atr  = float(atr.rolling(50).mean().iloc[-1])

    if np.isnan(avg_atr) or avg_atr == 0:
        return None, 1.0

    ratio    = curr_atr / avg_atr
    bullish  = float(df['close'].iloc[-1]) > float(df['open'].iloc[-1])

    if ratio > multiplier:
        return ('SPIKE_UP' if bullish else 'SPIKE_DOWN'), ratio

    return None, ratio


# ============================================================
# 📊 BÖLÜM 3: RANGE TRADING
# ============================================================

def detect_volatility_squeeze(
    df: pd.DataFrame,
    bb_period: int = 20,
    vol_lookback: int = 10
) -> Tuple[bool, int, Dict]:
    """
    Volatility Squeeze tespiti.

    Bollinger daralması + hacim artışı + ATR normale = patlama öncesi.

    Args:
        df:          OHLCV DataFrame
        bb_period:   Bollinger SMA periyodu (default: 20)
        vol_lookback: Kullanılmayan (uyumluluk için tutuldu)

    Returns:
        (is_squeeze, squeeze_score, details_dict)
        squeeze_score: 0-15 bonus puan
    """
    try:
        sma = df['close'].rolling(bb_period).mean()
        std = df['close'].rolling(bb_period).std()

        bb_width = float(((std * 2) / sma * 100).iloc[-1])
        bb_width_hist = ((std * 2) / sma * 100).tail(50)
        bb_pct    = float((bb_width_hist < bb_width).sum() / len(bb_width_hist) * 100)
        is_tight  = bb_pct < 20

        vol_sma   = float(df['volume'].rolling(20).mean().iloc[-1])
        vol_recent = float(df['volume'].tail(3).mean())
        vol_ratio = vol_recent / vol_sma if vol_sma > 0 else 1.0
        vol_expanding = vol_ratio > 1.5

        atr       = calculate_atr(df)
        atr_curr  = float(atr.iloc[-1])
        atr_hist  = atr.rolling(50)
        atr_sma_v = float(atr_hist.mean().iloc[-1])
        atr_std_v = float(atr_hist.std().iloc[-1])

        atr_z     = 0.0
        atr_normal = True
        if (not np.isnan(atr_std_v)) and atr_std_v > 0:
            atr_z      = (atr_curr - atr_sma_v) / atr_std_v
            atr_normal = atr_z < 1.5

        is_squeeze     = is_tight and vol_expanding and atr_normal
        squeeze_score  = 0
        if is_squeeze:
            bb_score      = min(8, int((20 - bb_pct) / 2.5))
            vol_score     = min(7, int((vol_ratio - 1) * 3.5))
            squeeze_score = bb_score + vol_score

        details = {
            'bb_width':      round(bb_width, 2),
            'bb_percentile': round(bb_pct, 1),
            'vol_ratio':     round(vol_ratio, 2),
            'atr_z_score':   round(atr_z, 2),
            'is_bb_tight':   is_tight,
            'vol_expanding': vol_expanding,
            'is_atr_normal': atr_normal,
            'squeeze_score': squeeze_score,
        }
        return is_squeeze, squeeze_score, details

    except Exception:
        return False, 0, {}


def is_ranging_market(df: pd.DataFrame, adx_threshold: float = 20) -> Tuple[bool, Dict]:
    """
    Düz/sıkışık piyasa tespiti.

    Kriterler (en az 2 sağlanmalı):
    - ADX < eşik
    - ATR ortalamanın altında
    - Bollinger bantları daralmış

    Args:
        df:            OHLCV DataFrame
        adx_threshold: ADX trend eşiği (default: 20)

    Returns:
        (is_ranging, details_dict)
    """
    adx_val    = float(calculate_adx(df).iloc[-1])
    atr_series = calculate_atr(df)
    atr_val    = float(atr_series.iloc[-1])
    atr_sma_v  = float(atr_series.rolling(50).mean().iloc[-1])

    if np.isnan(adx_val) or np.isnan(atr_val):
        return False, {'adx': 0, 'atr_ratio': 1, 'bb_width': 0, 'criteria_met': 0}

    lower, mid, upper = calculate_bollinger(df)
    m_val  = float(mid.iloc[-1])
    bb_w   = ((float(upper.iloc[-1]) - float(lower.iloc[-1])) / m_val * 100) if m_val > 0 else 0
    bb_avg = float(((upper - lower) / mid * 100).rolling(50).mean().iloc[-1])

    is_low_adx    = adx_val < adx_threshold
    is_low_vol    = (not np.isnan(atr_sma_v)) and atr_sma_v > 0 and atr_val < atr_sma_v * 0.9
    is_bb_tight   = (not np.isnan(bb_avg)) and bb_avg > 0 and bb_w < bb_avg * 0.9

    criteria_met = sum([is_low_adx, is_low_vol, is_bb_tight])
    is_ranging   = criteria_met >= 2

    details = {
        'adx':              round(adx_val, 2),
        'atr_ratio':        round(atr_val / atr_sma_v, 2) if (not np.isnan(atr_sma_v) and atr_sma_v > 0) else 1,
        'bb_width':         round(bb_w, 2),
        'is_low_adx':       is_low_adx,
        'is_low_volatility':is_low_vol,
        'is_bb_tight':      is_bb_tight,
        'criteria_met':     criteria_met,
    }
    return is_ranging, details


# ============================================================
# ⚡ BÖLÜM 4: RAPID REVERSAL TESPİTİ
# ============================================================

def detect_flash_move(
    df: pd.DataFrame,
    threshold_pct: float = 3.0,
    lookback: int = 3
) -> Tuple[Optional[str], float]:
    """
    Ani fiyat hareketi (flash move) tespiti.

    Args:
        df:            OHLCV DataFrame
        threshold_pct: Yüzde değişim eşiği (default: 3.0)
        lookback:      Kaç mum geriye bakılacak (default: 3)

    Returns:
        (flash_type, change_pct_abs)
        flash_type: 'FLASH_UP' | 'FLASH_DOWN' | None
        'FLASH_UP'  = Düşüş sonrası bu mum yeşil (LONG fırsatı)
        'FLASH_DOWN'= Yükseliş sonrası bu mum kırmızı (SHORT fırsatı)
    """
    if len(df) < lookback + 1:
        return None, 0.0

    closes      = df['close'].tail(lookback + 1)
    start, end  = float(closes.iloc[0]), float(closes.iloc[-1])
    change_pct  = ((end - start) / start) * 100
    bullish     = float(df['close'].iloc[-1]) > float(df['open'].iloc[-1])

    if change_pct < -threshold_pct and bullish:
        return 'FLASH_UP', abs(change_pct)
    if change_pct > threshold_pct and not bullish:
        return 'FLASH_DOWN', abs(change_pct)
    return None, abs(change_pct)


def detect_volume_spike(
    df: pd.DataFrame,
    multiplier: float = 3.0,
    lookback: int = 20
) -> Tuple[Optional[str], float]:
    """
    Hacim patlaması tespiti.

    Args:
        df:         OHLCV DataFrame
        multiplier: Ortalama hacmin kaç katı olacak (default: 3.0)
        lookback:   Ortalama hesap penceresi (default: 20)

    Returns:
        (spike_type, vol_ratio)
        spike_type: 'VOL_SPIKE_UP' | 'VOL_SPIKE_DOWN' | None
    """
    if len(df) < lookback:
        return None, 1.0

    vol_sma  = float(df['volume'].tail(lookback).mean())
    curr_vol = float(df['volume'].iloc[-1])
    if vol_sma == 0:
        return None, 1.0

    ratio   = curr_vol / vol_sma
    bullish = float(df['close'].iloc[-1]) > float(df['open'].iloc[-1])

    if ratio >= multiplier:
        return ('VOL_SPIKE_UP' if bullish else 'VOL_SPIKE_DOWN'), ratio
    return None, ratio


def detect_wick_rejection(
    df: pd.DataFrame,
    wick_body_ratio: float = 2.0
) -> Tuple[Optional[str], float]:
    """
    Fitil reddi tespiti — önemli seviyelerdeki alıcı/satıcı baskısını gösterir.

    Args:
        df:             OHLCV DataFrame
        wick_body_ratio: Fitil/gövde minimum oranı (default: 2.0)

    Returns:
        (wick_type, dominant_ratio)
        wick_type: 'WICK_UP' (alt fitil, alıcı baskısı) |
                   'WICK_DOWN' (üst fitil, satıcı baskısı) | None
    """
    row    = df.iloc[-1]
    body   = abs(float(row['close']) - float(row['open'])) or 0.0001   # Doji koruması
    hi, lo = float(row['high']), float(row['low'])
    top    = max(float(row['close']), float(row['open']))
    bot    = min(float(row['close']), float(row['open']))

    upper_wick = hi - top
    lower_wick = bot - lo
    u_ratio    = upper_wick / body
    l_ratio    = lower_wick / body

    if l_ratio >= wick_body_ratio and l_ratio > u_ratio:
        return 'WICK_UP', l_ratio
    if u_ratio >= wick_body_ratio and u_ratio > l_ratio:
        return 'WICK_DOWN', u_ratio
    return None, max(u_ratio, l_ratio)


def detect_rsi_extreme_bounce(
    df: pd.DataFrame,
    oversold: float = 25,
    overbought: float = 75
) -> Tuple[Optional[str], float]:
    """
    RSI aşırı bölgeden dönüş tespiti.

    Args:
        df:         OHLCV DataFrame
        oversold:   Aşırı satım eşiği (default: 25)
        overbought: Aşırı alım eşiği (default: 75)

    Returns:
        (bounce_type, current_rsi)
        bounce_type: 'RSI_BOUNCE_UP' | 'RSI_BOUNCE_DOWN' | None
    """
    if len(df) < 15:
        return None, 50.0

    rsi      = calculate_rsi(df['close'])
    curr_rsi = float(rsi.iloc[-1])
    prev_rsi = float(rsi.iloc[-2])
    bullish  = float(df['close'].iloc[-1]) > float(df['open'].iloc[-1])

    if prev_rsi < oversold and curr_rsi > prev_rsi and bullish:
        return 'RSI_BOUNCE_UP', curr_rsi
    if prev_rsi > overbought and curr_rsi < prev_rsi and not bullish:
        return 'RSI_BOUNCE_DOWN', curr_rsi
    return None, curr_rsi


# ============================================================
# 🛡️ BÖLÜM 5: DİNAMİK STOP-LOSS HESAPLAMA
# ============================================================

def calculate_trend_aware_sl_multiplier(
    df: pd.DataFrame,
    direction: str
) -> Tuple[float, str]:
    """
    Trend gücüne göre dinamik ATR stop-loss çarpanı.

    ADX > 35 + trend uyumlu → 4.0x ATR
    ADX > 25 + trend uyumlu + RSI onaylı → 2.5x ATR
    ADX > 20 → 2.0x ATR
    Zayıf/sideways → 2.0x ATR

    Args:
        df:        OHLCV DataFrame
        direction: 'LONG' veya 'SHORT'

    Returns:
        (sl_multiplier, trend_strength)
        trend_strength: 'ÇOK GÜÇLÜ' | 'GÜÇLÜ' | 'NORMAL' | 'ZAYIF' | 'DEFAULT'
    """
    try:
        adx_val = float(calculate_adx(df).iloc[-1])
        ema9    = float(calculate_ema(df['close'],  9).iloc[-1])
        ema21   = float(calculate_ema(df['close'], 21).iloc[-1])
        ema50   = float(calculate_ema(df['close'], 50).iloc[-1])

        bull_align = ema9 > ema21 > ema50
        bear_align = ema9 < ema21 < ema50
        aligned    = (direction == 'LONG' and bull_align) or \
                     (direction == 'SHORT' and bear_align)

        rsi_val   = float(calculate_rsi(df['close']).iloc[-1])
        rsi_ok    = (direction == 'LONG'  and 40 < rsi_val < 70) or \
                    (direction == 'SHORT' and 30 < rsi_val < 60)

        if adx_val > 35 and aligned:
            return 4.0, 'ÇOK GÜÇLÜ'
        elif adx_val > 25 and aligned and rsi_ok:
            return 2.5, 'GÜÇLÜ'
        elif adx_val > 20:
            return 2.0, 'NORMAL'
        else:
            return 2.0, 'ZAYIF'
    except Exception:
        return 2.0, 'DEFAULT'


# ============================================================
# 🎯 BÖLÜM 6: SKOR FONKSİYONLARI
# ============================================================

def calculate_reversal_score(df: pd.DataFrame) -> Tuple[int, int, List[str]]:
    """
    Reversal indikatörlerini birleştirerek LONG/SHORT reversal skoru üretir.

    Puanlama:
    - Momentum Reversal: maks 10 puan
    - RSI Divergence:    maks 12 puan
    - Volatility Spike:  maks  8 puan

    Args:
        df: OHLCV DataFrame

    Returns:
        (long_score, short_score, details_list)
    """
    long_score  = 0
    short_score = 0
    details: List[str] = []

    # 1. Momentum Reversal
    mom_type, mom_pct = calculate_momentum_reversal(df, lookback=5, threshold=1.5)
    if mom_type == 'REVERSAL_UP':
        s = min(10, int(abs(mom_pct) * 3))
        long_score += s;  details.append(f"MOM↑:{s}")
    elif mom_type == 'REVERSAL_DOWN':
        s = min(10, int(abs(mom_pct) * 3))
        short_score += s; details.append(f"MOM↓:{s}")

    # 2. RSI Divergence
    div_type, div_str = check_rsi_divergence(df, lookback=14)
    if div_type == 'BULLISH_DIV':
        s = min(12, int(div_str / 8))
        long_score += s;  details.append(f"DIV↑:{s}")
    elif div_type == 'BEARISH_DIV':
        s = min(12, int(div_str / 8))
        short_score += s; details.append(f"DIV↓:{s}")

    # 3. Volatility Spike
    spk_type, atr_ratio = check_volatility_spike(df, period=14, multiplier=1.8)
    if spk_type == 'SPIKE_UP':
        s = min(8, int((atr_ratio - 1) * 5))
        long_score += s;  details.append(f"VOL↑:{s}")
    elif spk_type == 'SPIKE_DOWN':
        s = min(8, int((atr_ratio - 1) * 5))
        short_score += s; details.append(f"VOL↓:{s}")

    return long_score, short_score, details


def calculate_rapid_score(df: pd.DataFrame) -> Tuple[int, int, List[str], List[str]]:
    """
    Rapid Reversal için LONG/SHORT skoru üretir (0-100 üzerinden).

    Puanlama:
    - Flash Move:    25 puan
    - Volume Spike:  25 puan
    - RSI Extreme:   20 puan
    - ATR Explosion: 15 puan
    - Wick Rejection:15 puan

    Args:
        df: OHLCV DataFrame

    Returns:
        (long_score, short_score, details_list, trigger_list)
    """
    long_score  = 0
    short_score = 0
    details: List[str]  = []
    triggers: List[str] = []

    # 1. Flash Move
    fl_type, fl_pct = detect_flash_move(df, threshold_pct=3.0)
    if fl_type == 'FLASH_UP':
        s = min(25, int(fl_pct * 5))
        long_score += s;  details.append(f"Flash:{s}"); triggers.append(f"Flash Move {fl_pct:.1f}%")
    elif fl_type == 'FLASH_DOWN':
        s = min(25, int(fl_pct * 5))
        short_score += s; details.append(f"Flash:{s}"); triggers.append(f"Flash Move {fl_pct:.1f}%")

    # 2. Volume Spike
    vl_type, vl_ratio = detect_volume_spike(df, multiplier=3.0)
    if vl_type == 'VOL_SPIKE_UP':
        s = min(25, int((vl_ratio - 1) * 8))
        long_score += s;  details.append(f"Vol:{s}"); triggers.append(f"Volume {vl_ratio:.1f}x")
    elif vl_type == 'VOL_SPIKE_DOWN':
        s = min(25, int((vl_ratio - 1) * 8))
        short_score += s; details.append(f"Vol:{s}"); triggers.append(f"Volume {vl_ratio:.1f}x")

    # 3. RSI Extreme Bounce
    rb_type, rb_rsi = detect_rsi_extreme_bounce(df)
    if rb_type == 'RSI_BOUNCE_UP':
        long_score += 20;  details.append("RSI:20"); triggers.append(f"RSI Bounce ({rb_rsi:.0f})")
    elif rb_type == 'RSI_BOUNCE_DOWN':
        short_score += 20; details.append("RSI:20"); triggers.append(f"RSI Bounce ({rb_rsi:.0f})")

    # 4. ATR Explosion
    sp_type, sp_ratio = check_volatility_spike(df, period=14, multiplier=2.5)
    if sp_type == 'SPIKE_UP':
        s = min(15, int((sp_ratio - 1) * 6))
        long_score += s;  details.append(f"ATR:{s}")
    elif sp_type == 'SPIKE_DOWN':
        s = min(15, int((sp_ratio - 1) * 6))
        short_score += s; details.append(f"ATR:{s}")

    # 5. Wick Rejection
    wk_type, wk_ratio = detect_wick_rejection(df, wick_body_ratio=2.0)
    if wk_type == 'WICK_UP':
        s = min(15, int(wk_ratio * 3))
        long_score += s;  details.append(f"Wick:{s}"); triggers.append("Wick Rejection")
    elif wk_type == 'WICK_DOWN':
        s = min(15, int(wk_ratio * 3))
        short_score += s; details.append(f"Wick:{s}"); triggers.append("Wick Rejection")

    return long_score, short_score, details, triggers


def calculate_range_score(df: pd.DataFrame) -> Tuple[int, int, List[str], List[str], Dict]:
    """
    Range Trading için skor hesapla (60 puan üzerinden).

    Puanlama:
    - Bollinger Bant Pozisyonu: 20 puan
    - RSI Oversold/Overbought:  15 puan
    - SMA20'den Sapma:          12 puan
    - Wick Rejection:            8 puan
    - Stochastic benzeri:        5 puan

    Args:
        df: OHLCV DataFrame

    Returns:
        (long_score, short_score, long_breakdown, short_breakdown, tp_sl_info)
    """
    long_score   = 0
    short_score  = 0
    long_bd: List[str]  = []
    short_bd: List[str] = []

    price = float(df['close'].iloc[-1])
    lower, mid, upper = calculate_bollinger(df)
    bb_lo = float(lower.iloc[-1])
    bb_mi = float(mid.iloc[-1])
    bb_up = float(upper.iloc[-1])

    # 1. Bollinger Bant Pozisyonu (maks 20 puan)
    bb_pos = (price - bb_lo) / (bb_up - bb_lo) if bb_up != bb_lo else 0.5

    if bb_pos < 0.15:   long_score += 20; long_bd.append("BB:20")
    elif bb_pos < 0.25: long_score += 15; long_bd.append("BB:15")
    elif bb_pos < 0.35: long_score +=  8; long_bd.append("BB:8")

    if bb_pos > 0.85:   short_score += 20; short_bd.append("BB:20")
    elif bb_pos > 0.75: short_score += 15; short_bd.append("BB:15")
    elif bb_pos > 0.65: short_score +=  8; short_bd.append("BB:8")

    # 2. RSI (maks 15 puan)
    rsi = float(calculate_rsi(df['close']).iloc[-1])

    if rsi < 30:    long_score += 15; long_bd.append("RSI:15")
    elif rsi < 35:  long_score += 12; long_bd.append("RSI:12")
    elif rsi < 40:  long_score +=  8; long_bd.append("RSI:8")

    if rsi > 70:    short_score += 15; short_bd.append("RSI:15")
    elif rsi > 65:  short_score += 12; short_bd.append("RSI:12")
    elif rsi > 60:  short_score +=  8; short_bd.append("RSI:8")

    # 3. SMA20'den Sapma (maks 12 puan)
    sma20   = float(df['close'].rolling(20).mean().iloc[-1])
    dev_pct = ((price - sma20) / sma20 * 100) if sma20 > 0 else 0

    if dev_pct < -2.0:   long_score += 12; long_bd.append("DEV:12")
    elif dev_pct < -1.5: long_score +=  8; long_bd.append("DEV:8")
    elif dev_pct < -1.0: long_score +=  5; long_bd.append("DEV:5")

    if dev_pct > 2.0:   short_score += 12; short_bd.append("DEV:12")
    elif dev_pct > 1.5: short_score +=  8; short_bd.append("DEV:8")
    elif dev_pct > 1.0: short_score +=  5; short_bd.append("DEV:5")

    # 4. Wick Rejection (maks 8 puan)
    row  = df.iloc[-1]
    body = abs(float(row['close']) - float(row['open'])) or 0.0001
    up_w = float(row['high']) - max(float(row['close']), float(row['open']))
    lo_w = min(float(row['close']), float(row['open'])) - float(row['low'])
    lo_r = lo_w / body
    up_r = up_w / body

    if lo_r > 2.0:   long_score +=  8; long_bd.append("WICK:8")
    elif lo_r > 1.5: long_score +=  5; long_bd.append("WICK:5")

    if up_r > 2.0:   short_score +=  8; short_bd.append("WICK:8")
    elif up_r > 1.5: short_score +=  5; short_bd.append("WICK:5")

    # 5. Stochastic-benzeri (maks 5 puan)
    lo14  = float(df['low'].tail(14).min())
    hi14  = float(df['high'].tail(14).max())
    stk   = ((price - lo14) / (hi14 - lo14) * 100) if hi14 != lo14 else 50

    if stk < 20:    long_score  += 5; long_bd.append("STOCH:5")
    elif stk < 30:  long_score  += 3; long_bd.append("STOCH:3")
    if stk > 80:    short_score += 5; short_bd.append("STOCH:5")
    elif stk > 70:  short_score += 3; short_bd.append("STOCH:3")

    atr_val = float(calculate_atr(df).iloc[-1])
    tp_sl_info = {
        'bb_mid':    bb_mi,
        'bb_lower':  bb_lo,
        'bb_upper':  bb_up,
        'atr':       atr_val,
        'bb_position': bb_pos,
    }
    return long_score, short_score, long_bd, short_bd, tp_sl_info


# ============================================================
# 📦 BÖLÜM 7: TOPLU HESAPLAMA — ANA API
# ============================================================

def get_all_indicators(df: pd.DataFrame) -> Dict:
    """
    DataFrame'deki tüm teknik indikatörleri tek seferde hesaplar.

    Args:
        df: OHLCV DataFrame — sütunlar: open, high, low, close, volume

    Returns:
        Tüm indikatör değerlerini içeren sözlük.
        Örnek anahtarlar:
            rsi, adx, atr, ema9, ema21, ema50, ema200,
            sma20, sma50, sma200,
            bb_upper, bb_mid, bb_lower, bb_width, bb_position,
            macd, macd_signal, macd_hist,
            stoch_k, stoch_d, obv, cmf,
            vol_ratio, price, is_bullish_candle,
            supertrend, supertrend_direction,
            ema_alignment ('BULLISH'|'BEARISH'|'NEUTRAL')
    """
    price = float(df['close'].iloc[-1])

    # RSI
    rsi_series = calculate_rsi(df['close'])
    rsi_val    = float(rsi_series.iloc[-1])

    # ATR
    atr_series = calculate_atr(df)
    atr_val    = float(atr_series.iloc[-1])

    # ADX
    adx_val = float(calculate_adx(df).iloc[-1])

    # EMA
    ema9   = float(calculate_ema(df['close'],   9).iloc[-1])
    ema21  = float(calculate_ema(df['close'],  21).iloc[-1])
    ema50  = float(calculate_ema(df['close'],  50).iloc[-1])
    ema200 = float(calculate_ema(df['close'], 200).iloc[-1])

    # SMA
    sma20  = float(calculate_sma(df['close'],  20).iloc[-1])
    sma50  = float(calculate_sma(df['close'],  50).iloc[-1])
    sma200 = float(calculate_sma(df['close'], 200).iloc[-1])

    # Bollinger
    lower, mid, upper = calculate_bollinger(df)
    bb_lo  = float(lower.iloc[-1])
    bb_mi  = float(mid.iloc[-1])
    bb_up  = float(upper.iloc[-1])
    bb_w   = ((bb_up - bb_lo) / bb_mi * 100) if bb_mi > 0 else 0
    bb_pos = (price - bb_lo) / (bb_up - bb_lo) if bb_up != bb_lo else 0.5

    # MACD
    ml, sl_m, mh = calculate_macd(df['close'])
    macd_val   = float(ml.iloc[-1])
    macd_sig   = float(sl_m.iloc[-1])
    macd_hist  = float(mh.iloc[-1])

    # Stochastic RSI
    sk, sd = calculate_stochastic_rsi(df['close'])
    stk = float(sk.iloc[-1])
    std = float(sd.iloc[-1])

    # OBV & CMF
    obv_val = float(calculate_obv(df).iloc[-1])
    cmf_val = float(calculate_cmf(df).iloc[-1])

    # Volume ratio
    vol_sma   = float(df['volume'].rolling(20).mean().iloc[-1])
    curr_vol  = float(df['volume'].iloc[-1])
    vol_ratio = curr_vol / vol_sma if vol_sma > 0 else 1.0

    # SuperTrend
    st_line, st_dir = calculate_supertrend(df)
    st_val = float(st_line.iloc[-1]) if not st_line.empty else float('nan')
    st_d   = int(st_dir.iloc[-1])

    # EMA Dizilimi
    if ema9 > ema21 > ema50:
        ema_align = 'BULLISH'
    elif ema9 < ema21 < ema50:
        ema_align = 'BEARISH'
    else:
        ema_align = 'NEUTRAL'

    return {
        # Fiyat & Mum
        'price':              price,
        'is_bullish_candle':  float(df['close'].iloc[-1]) > float(df['open'].iloc[-1]),
        # RSI
        'rsi':                round(rsi_val, 2),
        # ATR
        'atr':                round(atr_val, 8),
        # ADX
        'adx':                round(adx_val, 2),
        # EMA
        'ema9':               round(ema9, 8),
        'ema21':              round(ema21, 8),
        'ema50':              round(ema50, 8),
        'ema200':             round(ema200, 8),
        'ema_alignment':      ema_align,
        # SMA
        'sma20':              round(sma20, 8),
        'sma50':              round(sma50, 8),
        'sma200':             round(sma200, 8),
        # Bollinger
        'bb_upper':           round(bb_up, 8),
        'bb_mid':             round(bb_mi, 8),
        'bb_lower':           round(bb_lo, 8),
        'bb_width_pct':       round(bb_w, 2),
        'bb_position':        round(bb_pos, 3),
        # MACD
        'macd':               round(macd_val, 8),
        'macd_signal':        round(macd_sig, 8),
        'macd_hist':          round(macd_hist, 8),
        # Stochastic RSI
        'stoch_k':            round(stk, 2),
        'stoch_d':            round(std, 2),
        # Volume
        'obv':                round(obv_val, 2),
        'cmf':                round(cmf_val, 4),
        'vol_ratio':          round(vol_ratio, 2),
        # SuperTrend
        'supertrend':         round(st_val, 8) if not np.isnan(st_val) else None,
        'supertrend_direction': st_d,   # 1 = uptrend, -1 = downtrend
    }


def get_signal(
    df: pd.DataFrame,
    long_threshold: int = 35,
    short_threshold: int = 35
) -> Dict:
    """
    Birleşik sinyal üret.

    Tüm puan mekanizmalarını çalıştırır ve bir sinyal sözlüğü döndürür.
    Bu fonksiyon tamamen Telegram/bot bağımsızdır.

    Args:
        df:               OHLCV DataFrame
        long_threshold:   LONG sinyali için minimum reversal puanı (default: 35)
        short_threshold:  SHORT sinyali için minimum reversal puanı (default: 35)

    Returns:
        {
            'direction':     'LONG' | 'SHORT' | 'NEUTRAL',
            'signal_type':   'TREND' | 'REVERSAL' | 'RAPID' | 'RANGE' | 'NEUTRAL',

            # Reversal skorları
            'reversal_long':  int,
            'reversal_short': int,
            'reversal_details': list,

            # Rapid skorları
            'rapid_long':  int,
            'rapid_short': int,
            'rapid_details':   list,
            'rapid_triggers':  list,

            # Range skorları
            'range_long':  int,
            'range_short': int,
            'range_long_breakdown':  list,
            'range_short_breakdown': list,
            'range_tp_sl': dict,

            # Piyasa durumu
            'is_ranging':  bool,
            'is_squeeze':  bool,
            'squeeze_score': int,

            # Temel indikatörler (özet)
            'rsi':  float,
            'adx':  float,
            'atr':  float,

            # SL için ADX çarpanı (belirlenen yöne göre)
            'sl_multiplier': float,
            'trend_strength': str,
        }
    """
    rev_l, rev_s, rev_det = calculate_reversal_score(df)
    rap_l, rap_s, rap_det, rap_trg = calculate_rapid_score(df)
    rng_l, rng_s, rng_lb, rng_sb, rng_tpsl = calculate_range_score(df)
    is_ranging, _    = is_ranging_market(df)
    is_sq, sq_score, _ = detect_volatility_squeeze(df)

    rsi_val = float(calculate_rsi(df['close']).iloc[-1])
    adx_val = float(calculate_adx(df).iloc[-1])
    atr_val = float(calculate_atr(df).iloc[-1])

    # Baskın yönü belirle
    total_long  = rev_l + rap_l
    total_short = rev_s + rap_s

    direction   = 'NEUTRAL'
    signal_type = 'NEUTRAL'

    if total_long > total_short and total_long >= long_threshold:
        direction   = 'LONG'
        signal_type = 'REVERSAL'
    elif total_short > total_long and total_short >= short_threshold:
        direction   = 'SHORT'
        signal_type = 'REVERSAL'
    elif rng_l > rng_s and rng_l >= 35:
        direction   = 'LONG'
        signal_type = 'RANGE'
    elif rng_s > rng_l and rng_s >= 35:
        direction   = 'SHORT'
        signal_type = 'RANGE'

    sl_mult, trend_str = calculate_trend_aware_sl_multiplier(df, direction) \
        if direction != 'NEUTRAL' else (2.0, 'DEFAULT')

    return {
        'direction':    direction,
        'signal_type':  signal_type,

        'reversal_long':    rev_l,
        'reversal_short':   rev_s,
        'reversal_details': rev_det,

        'rapid_long':     rap_l,
        'rapid_short':    rap_s,
        'rapid_details':  rap_det,
        'rapid_triggers': rap_trg,

        'range_long':  rng_l,
        'range_short': rng_s,
        'range_long_breakdown':  rng_lb,
        'range_short_breakdown': rng_sb,
        'range_tp_sl':           rng_tpsl,

        'is_ranging':    is_ranging,
        'is_squeeze':    is_sq,
        'squeeze_score': sq_score,

        'rsi': round(rsi_val, 2),
        'adx': round(adx_val, 2),
        'atr': round(atr_val, 8),

        'sl_multiplier':  sl_mult,
        'trend_strength': trend_str,
    }