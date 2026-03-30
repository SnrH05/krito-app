import 'package:flutter/material.dart';

// ═══════════════════════════════════════════════════════════════
// RENK PALETİ — CYAN YOK! Profesyonel Fintech renkleri
// ═══════════════════════════════════════════════════════════════
const String kBaseUrl = 'http://127.0.0.1:8000';

const Color kBg = Color(0xFF000000);
const Color kSurface = Color(0xFF0A0D11);
const Color kCard = Color(0xFF111419);
const Color kBorder = Color(0xFF1A1E25);

// Ana renkler — Cyan olmadan
const Color kAccentBlue = Color(0xFF1565C0);    // Koyu Mavi (Primary)
const Color kAccentOrange = Color(0xFFFF8F00);   // Turuncu (Accent)
const Color kPurple = Color(0xFF7C4DFF);         // Mor (Secondary)
const Color kEmerald = Color(0xFF00C853);        // Zümrüt Yeşili
const Color kGreen = Color(0xFF00E676);          // Bullish
const Color kRed = Color(0xFFFF5252);            // Bearish
const Color kGold = Color(0xFFFFD740);           // Gold accent

// ═══════════════════════════════════════════════════════════════
// İNDİKATÖR TİPLERİ
// ═══════════════════════════════════════════════════════════════
enum IndType {
  sma7, sma25, sma99,
  ema7, ema25, ema99,
  bollinger, vwap,
  rsi, macd, stochastic,
  adx, atr, cci, williamsR,
  obv, mfi, momentum, roc,
  wma, dema, tema, hma,
  keltner, donchian,
  parabolicSar, ichimoku,
  stdDev, chaikinMF, forceIndex,
  volume,
}

enum IndCat { overlay, panel }

class IndInfo {
  final String name;
  final IndCat cat;
  final Color color;
  final Map<String, dynamic> defaultParams;
  const IndInfo(this.name, this.cat, this.color, [this.defaultParams = const {}]);
}

final Map<IndType, IndInfo> kIndicators = {
  IndType.sma7: const IndInfo('SMA 7', IndCat.overlay, Color(0xFFFFD740), {'period': 7}),
  IndType.sma25: const IndInfo('SMA 25', IndCat.overlay, Color(0xFF42A5F5), {'period': 25}),
  IndType.sma99: const IndInfo('SMA 99', IndCat.overlay, Color(0xFFE040FB), {'period': 99}),
  IndType.ema7: const IndInfo('EMA 7', IndCat.overlay, Color(0xFFFF6E40), {'period': 7}),
  IndType.ema25: const IndInfo('EMA 25', IndCat.overlay, Color(0xFF69F0AE), {'period': 25}),
  IndType.ema99: const IndInfo('EMA 99', IndCat.overlay, Color(0xFFEA80FC), {'period': 99}),
  IndType.bollinger: const IndInfo('Bollinger', IndCat.overlay, Color(0xFF90CAF9), {'period': 20, 'multiplier': 2.0}),
  IndType.vwap: const IndInfo('VWAP', IndCat.overlay, Color(0xFFCE93D8)),
  IndType.rsi: const IndInfo('RSI', IndCat.panel, Color(0xFFFFD740), {'period': 14, 'source': 'close'}),
  IndType.macd: const IndInfo('MACD', IndCat.panel, Color(0xFF42A5F5), {'fast': 12, 'slow': 26, 'signal': 9, 'source': 'close'}),
  IndType.stochastic: const IndInfo('Stochastic', IndCat.panel, Color(0xFFFF6E40), {'kPeriod': 14, 'dPeriod': 3}),
  IndType.adx: const IndInfo('ADX', IndCat.panel, Color(0xFF69F0AE), {'period': 14}),
  IndType.atr: const IndInfo('ATR', IndCat.panel, Color(0xFFEA80FC), {'period': 14}),
  IndType.cci: const IndInfo('CCI', IndCat.panel, Color(0xFF80CBC4), {'period': 20}),
  IndType.williamsR: const IndInfo('Williams %R', IndCat.panel, Color(0xFFCE93D8), {'period': 14}),
  IndType.obv: const IndInfo('OBV', IndCat.panel, Color(0xFFA5D6A7)),
  IndType.mfi: const IndInfo('MFI', IndCat.panel, Color(0xFFFFCC80), {'period': 14}),
  IndType.momentum: const IndInfo('Momentum', IndCat.panel, Color(0xFF90CAF9), {'period': 10}),
  IndType.roc: const IndInfo('ROC', IndCat.panel, Color(0xFFEF9A9A), {'period': 10}),
  IndType.wma: const IndInfo('WMA', IndCat.overlay, Color(0xFFB39DDB), {'period': 20}),
  IndType.dema: const IndInfo('DEMA', IndCat.overlay, Color(0xFF80CBC4), {'period': 20}),
  IndType.tema: const IndInfo('TEMA', IndCat.overlay, Color(0xFFA5D6A7), {'period': 20}),
  IndType.hma: const IndInfo('HMA', IndCat.overlay, Color(0xFFFFCC80), {'period': 20}),
  IndType.keltner: const IndInfo('Keltner', IndCat.overlay, Color(0xFF90CAF9), {'period': 20, 'multiplier': 1.5}),
  IndType.donchian: const IndInfo('Donchian', IndCat.overlay, Color(0xFFEF9A9A), {'period': 20}),
  IndType.parabolicSar: const IndInfo('Parabolic SAR', IndCat.overlay, Color(0xFFFFAB40), {'af': 0.02, 'maxAf': 0.2}),
  IndType.ichimoku: const IndInfo('Ichimoku', IndCat.overlay, Color(0xFF5C6BC0), {'tenkan': 9, 'kijun': 26, 'senkou': 52}),
  IndType.stdDev: const IndInfo('Std Dev', IndCat.panel, Color(0xFFB39DDB), {'period': 20}),
  IndType.chaikinMF: const IndInfo('Chaikin MF', IndCat.panel, Color(0xFF5C6BC0), {'period': 20}),
  IndType.forceIndex: const IndInfo('Force Index', IndCat.panel, Color(0xFFFFAB40), {'period': 13}),
  IndType.volume: const IndInfo('Volume', IndCat.panel, Color(0xFF78909C)),
};

// ═══════════════════════════════════════════════════════════════
// 100 COİN LİSTESİ
// ═══════════════════════════════════════════════════════════════
const List<Map<String, String>> kCoins = [
  {'s':'BTCUSDT','n':'Bitcoin'},{'s':'ETHUSDT','n':'Ethereum'},{'s':'BNBUSDT','n':'BNB'},
  {'s':'SOLUSDT','n':'Solana'},{'s':'XRPUSDT','n':'XRP'},{'s':'DOGEUSDT','n':'Dogecoin'},
  {'s':'ADAUSDT','n':'Cardano'},{'s':'AVAXUSDT','n':'Avalanche'},{'s':'TRXUSDT','n':'TRON'},
  {'s':'DOTUSDT','n':'Polkadot'},{'s':'LINKUSDT','n':'Chainlink'},{'s':'MATICUSDT','n':'Polygon'},
  {'s':'SHIBUSDT','n':'Shiba Inu'},{'s':'LTCUSDT','n':'Litecoin'},{'s':'BCHUSDT','n':'Bitcoin Cash'},
  {'s':'UNIUSDT','n':'Uniswap'},{'s':'ATOMUSDT','n':'Cosmos'},{'s':'XLMUSDT','n':'Stellar'},
  {'s':'ETCUSDT','n':'Ethereum Classic'},{'s':'FILUSDT','n':'Filecoin'},{'s':'NEARUSDT','n':'NEAR Protocol'},
  {'s':'APTUSDT','n':'Aptos'},{'s':'ICPUSDT','n':'Internet Computer'},{'s':'VETUSDT','n':'VeChain'},
  {'s':'HBARUSDT','n':'Hedera'},{'s':'ARBUSDT','n':'Arbitrum'},{'s':'OPUSDT','n':'Optimism'},
  {'s':'MKRUSDT','n':'Maker'},{'s':'GRTUSDT','n':'The Graph'},{'s':'AAVEUSDT','n':'Aave'},
  {'s':'ALGOUSDT','n':'Algorand'},{'s':'QNTUSDT','n':'Quant'},{'s':'FTMUSDT','n':'Fantom'},
  {'s':'SANDUSDT','n':'The Sandbox'},{'s':'MANAUSDT','n':'Decentraland'},{'s':'THETAUSDT','n':'Theta'},
  {'s':'AXSUSDT','n':'Axie Infinity'},{'s':'EOSUSDT','n':'EOS'},{'s':'EGLDUSDT','n':'MultiversX'},
  {'s':'XTZUSDT','n':'Tezos'},{'s':'FLOWUSDT','n':'Flow'},{'s':'CFXUSDT','n':'Conflux'},
  {'s':'IMXUSDT','n':'Immutable'},{'s':'NEOUSDT','n':'Neo'},{'s':'KAVAUSDT','n':'Kava'},
  {'s':'PEPEUSDT','n':'Pepe'},{'s':'SUIUSDT','n':'Sui'},{'s':'INJUSDT','n':'Injective'},
  {'s':'SEIUSDT','n':'Sei'},{'s':'RUNEUSDT','n':'THORChain'},{'s':'LDOUSDT','n':'Lido DAO'},
  {'s':'SNXUSDT','n':'Synthetix'},{'s':'CRVUSDT','n':'Curve DAO'},{'s':'COMPUSDT','n':'Compound'},
  {'s':'APEUSDT','n':'ApeCoin'},{'s':'DYDXUSDT','n':'dYdX'},{'s':'ENSUSDT','n':'ENS'},
  {'s':'FETUSDT','n':'Fetch.ai'},{'s':'RNDRUSDT','n':'Render'},{'s':'AGIXUSDT','n':'SingularityNET'},
  {'s':'WLDUSDT','n':'Worldcoin'},{'s':'BLURUSDT','n':'Blur'},{'s':'FLOKIUSDT','n':'Floki'},
  {'s':'GALAUSDT','n':'Gala'},{'s':'CHZUSDT','n':'Chiliz'},{'s':'ENJUSDT','n':'Enjin Coin'},
  {'s':'ZILUSDT','n':'Zilliqa'},{'s':'BATUSDT','n':'BAT'},{'s':'ONEUSDT','n':'Harmony'},
  {'s':'HOTUSDT','n':'Holo'},{'s':'IOTAUSDT','n':'IOTA'},{'s':'ZECUSDT','n':'Zcash'},
  {'s':'DASHUSDT','n':'Dash'},{'s':'WAVESUSDT','n':'Waves'},{'s':'CELOUSDT','n':'Celo'},
  {'s':'ANKRUSDT','n':'Ankr'},{'s':'ROSEUSDT','n':'Oasis Network'},{'s':'SKLUSDT','n':'SKALE'},
  {'s':'ICXUSDT','n':'ICON'},{'s':'ZRXUSDT','n':'0x'},{'s':'STORJUSDT','n':'Storj'},
  {'s':'CELRUSDT','n':'Celer Network'},{'s':'RVNUSDT','n':'Ravencoin'},{'s':'SXPUSDT','n':'Solar'},
  {'s':'OCEANUSDT','n':'Ocean Protocol'},{'s':'MASKUSDT','n':'Mask Network'},
  {'s':'GMXUSDT','n':'GMX'},{'s':'PENDLEUSDT','n':'Pendle'},{'s':'SSVUSDT','n':'SSV Network'},
  {'s':'STXUSDT','n':'Stacks'},{'s':'TIAUSDT','n':'Celestia'},{'s':'ORDIUSDT','n':'ORDI'},
  {'s':'JTOUSDT','n':'Jito'},{'s':'PYTHUSDT','n':'Pyth Network'},{'s':'JUPUSDT','n':'Jupiter'},
  {'s':'WUSDT','n':'Wormhole'},{'s':'STRKUSDT','n':'StarkNet'},{'s':'PIXELUSDT','n':'Pixels'},
  {'s':'MANTAUSDT','n':'Manta Network'},{'s':'DYMUSDT','n':'Dymension'},
  {'s':'TAOUSDT','n':'Bittensor'},{'s':'KASUSDT','n':'Kaspa'},{'s':'BONKUSDT','n':'Bonk'},
  {'s':'1000SATSUSDT','n':'1000SATS'},
];

// ═══════════════════════════════════════════════════════════════
// ZAMAN DİLİMLERİ
// ═══════════════════════════════════════════════════════════════
const List<String> kIntervals = ['1s', '10s', '1m', '5m', '1h', '1d', '1w'];
