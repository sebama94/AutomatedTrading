//+------------------------------------------------------------------+
//| RegimeDetector.mqh                                               |
//| Classifica il mercato in 3 regimi:                               |
//|   TREND    → ADX > 25, trading direzionale preferito             |
//|   RANGE    → ADX < 20, mean-reversion preferita                 |
//|   VOLATILE → ATR spike, evitare nuovi trade                      |
//|                                                                  |
//| Logica:                                                          |
//|   ATR_fast = ATR(5, H1)   / ATR_slow = ATR(50, H1)              |
//|   ratio = ATR_fast / ATR_slow                                    |
//|   ratio > 1.5  →  VOLATILE  (espansione improvvisa)              |
//|   ratio < 0.5  →  VOLATILE  (compressione eccessiva = fakeout)   |
//|   ADX(14,H1) > 25  →  TREND                                      |
//|   ADX(14,H1) < 20  →  RANGE                                      |
//|   altrimenti        →  TREND  (trend moderato, ok per trade)     |
//+------------------------------------------------------------------+
#pragma once

enum ENUM_MARKET_REGIME
{
   REGIME_TREND    = 0,
   REGIME_RANGE    = 1,
   REGIME_VOLATILE = 2
};

class RegimeDetector
{
private:
   string _sym;
   int    _hADX;
   int    _hATR_fast;
   int    _hATR_slow;

   double _adxTrend;    // soglia trend (default 25)
   double _adxRange;    // soglia range (default 20)
   double _spikeRatio;  // ratio ATR per volatile (default 1.5)

public:
   RegimeDetector() : _sym(""), _hADX(INVALID_HANDLE),
                      _hATR_fast(INVALID_HANDLE), _hATR_slow(INVALID_HANDLE),
                      _adxTrend(25), _adxRange(20), _spikeRatio(1.5) {}

   ~RegimeDetector()
   {
      if(_hADX      != INVALID_HANDLE) IndicatorRelease(_hADX);
      if(_hATR_fast != INVALID_HANDLE) IndicatorRelease(_hATR_fast);
      if(_hATR_slow != INVALID_HANDLE) IndicatorRelease(_hATR_slow);
   }

   bool Init(string symbol, double adxTrend = 25, double adxRange = 20, double spikeRatio = 1.5)
   {
      _sym       = symbol;
      _adxTrend  = adxTrend;
      _adxRange  = adxRange;
      _spikeRatio = spikeRatio;

      _hADX      = iADX(symbol, PERIOD_H1, 14);
      _hATR_fast = iATR(symbol, PERIOD_H1, 5);
      _hATR_slow = iATR(symbol, PERIOD_H1, 50);

      if(_hADX == INVALID_HANDLE || _hATR_fast == INVALID_HANDLE || _hATR_slow == INVALID_HANDLE)
      {
         Print("RegimeDetector: impossibile creare handle");
         return false;
      }
      return true;
   }

   ENUM_MARKET_REGIME Detect()
   {
      double adx_v[], atr_f[], atr_s[];
      ArraySetAsSeries(adx_v, true);
      ArraySetAsSeries(atr_f, true);
      ArraySetAsSeries(atr_s, true);

      if(CopyBuffer(_hADX,      0, 1, 3, adx_v) <= 0 ||
         CopyBuffer(_hATR_fast, 0, 1, 3, atr_f) <= 0 ||
         CopyBuffer(_hATR_slow, 0, 1, 3, atr_s) <= 0)
         return REGIME_TREND; // fallback sicuro

      double adx   = adx_v[0];
      double ratio = (atr_s[0] > 1e-10) ? atr_f[0] / atr_s[0] : 1.0;

      // Volatilità anomala: spike o compressione eccessiva
      if(ratio > _spikeRatio || ratio < (1.0 / _spikeRatio))
         return REGIME_VOLATILE;

      if(adx > _adxTrend)  return REGIME_TREND;
      if(adx < _adxRange)  return REGIME_RANGE;
      return REGIME_TREND; // zona intermedia: trattata come trend debole
   }

   string ToString(ENUM_MARKET_REGIME r)
   {
      switch(r)
      {
         case REGIME_TREND:    return "TREND";
         case REGIME_RANGE:    return "RANGE";
         case REGIME_VOLATILE: return "VOLATILE";
         default:              return "UNKNOWN";
      }
   }

   // Restituisce ADX corrente (utile per debug)
   double GetADX()
   {
      double adx_v[];
      ArraySetAsSeries(adx_v, true);
      if(CopyBuffer(_hADX, 0, 1, 1, adx_v) > 0) return adx_v[0];
      return 0;
   }

   // Restituisce ATR ratio (utile per debug)
   double GetATRRatio()
   {
      double atr_f[], atr_s[];
      ArraySetAsSeries(atr_f, true);
      ArraySetAsSeries(atr_s, true);
      if(CopyBuffer(_hATR_fast, 0, 1, 1, atr_f) > 0 &&
         CopyBuffer(_hATR_slow, 0, 1, 1, atr_s) > 0 && atr_s[0] > 1e-10)
         return atr_f[0] / atr_s[0];
      return 1.0;
   }
};
