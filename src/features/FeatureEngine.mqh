//+------------------------------------------------------------------+
//| FeatureEngine.mqh                                                |
//| Estrae 76 feature da 3 timeframe (M30, H1, H4) + ora/giorno     |
//|                                                                  |
//| Layout feature (8 per barra):                                    |
//|   [0] MACD histogram / ATR  (momentum normalizzato)              |
//|   [1] RSI in [-1,1]                                              |
//|   [2] Stoch %K in [-1,1]                                         |
//|   [3] ADX in [-1,1]                                              |
//|   [4] Bollinger %B in [-1,1]                                     |
//|   [5] ATR% (volatilità relativa, soft-clipped)                   |
//|   [6] Return barra (close/prev_close - 1, soft-clipped)          |
//|   [7] Deviazione da EMA50 / ATR (soft-clipped)                   |
//|                                                                  |
//| M30: 5 barre × 8 = 40   idx 0-39                                 |
//| H1:  3 barre × 8 = 24   idx 40-63                                |
//| H4:  1 barra  × 8 = 8   idx 64-71                                |
//| Tempo: 4 feature ciclici   idx 72-75                             |
//| Totale: 76                                                        |
//+------------------------------------------------------------------+
#pragma once

#define FE_M30_BARS       5
#define FE_H1_BARS        3
#define FE_H4_BARS        1
#define FE_FEATURES_PER   8
#define FE_TIME_FEATURES  4
#define FE_TOTAL          ((FE_M30_BARS + FE_H1_BARS + FE_H4_BARS) * FE_FEATURES_PER + FE_TIME_FEATURES)
// = 9 * 8 + 4 = 76

class FeatureEngine
{
private:
   string _sym;

   // Handles M30
   int h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30, h_atr_m30, h_bb_m30, h_ema_m30;
   // Handles H1
   int h_macd_h1,  h_rsi_h1,  h_stoch_h1,  h_adx_h1,  h_atr_h1,  h_bb_h1,  h_ema_h1;
   // Handles H4
   int h_macd_h4,  h_rsi_h4,  h_stoch_h4,  h_adx_h4,  h_atr_h4,  h_bb_h4,  h_ema_h4;

public:
   FeatureEngine() { _sym = ""; }
   ~FeatureEngine() { Release(); }

   bool Init(string symbol);
   void Release();

   // Estrae feature per il tick corrente (usa barre completate)
   bool Extract(double &features[]);

   // Estrae feature per barra storica (barOffset = 0 → bar più recente completata)
   bool ExtractHistorical(int barOffset, double &features[]);

   // Conta feature totali (costante)
   int  FeatureCount() { return FE_TOTAL; }

private:
   bool ExtractFromTF(ENUM_TIMEFRAMES tf, int numBars, int startBar,
                      int hMACD, int hRSI, int hStoch, int hADX,
                      int hATR, int hBB, int hEMA,
                      double &features[], int offset);

   double SoftClip(double v, double scale)
   {
      // Mappa v/scale in [-1,1] tramite tanh per gestire outlier
      double x = v / scale;
      return (MathExp(2.0 * x) - 1.0) / (MathExp(2.0 * x) + 1.0); // tanh(x)
   }

   bool CreateHandles(string sym, ENUM_TIMEFRAMES tf,
                      int &hMACD, int &hRSI, int &hStoch, int &hADX,
                      int &hATR,  int &hBB,  int &hEMA);

   void ReleaseHandles(int &h1, int &h2, int &h3, int &h4, int &h5, int &h6, int &h7);
};

bool FeatureEngine::Init(string symbol)
{
   _sym = symbol;
   if(!CreateHandles(symbol, PERIOD_M30,
                     h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30,
                     h_atr_m30,  h_bb_m30,  h_ema_m30)) return false;
   if(!CreateHandles(symbol, PERIOD_H1,
                     h_macd_h1, h_rsi_h1, h_stoch_h1, h_adx_h1,
                     h_atr_h1,  h_bb_h1,  h_ema_h1))  return false;
   if(!CreateHandles(symbol, PERIOD_H4,
                     h_macd_h4, h_rsi_h4, h_stoch_h4, h_adx_h4,
                     h_atr_h4,  h_bb_h4,  h_ema_h4))  return false;
   return true;
}

bool FeatureEngine::CreateHandles(string sym, ENUM_TIMEFRAMES tf,
                                   int &hMACD, int &hRSI, int &hStoch, int &hADX,
                                   int &hATR,  int &hBB,  int &hEMA)
{
   hMACD  = iMACD(sym, tf, 12, 26, 9, PRICE_CLOSE);
   hRSI   = iRSI(sym, tf, 14, PRICE_CLOSE);
   hStoch = iStochastic(sym, tf, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
   hADX   = iADX(sym, tf, 14);
   hATR   = iATR(sym, tf, 14);
   hBB    = iBands(sym, tf, 20, 0, 2.0, PRICE_CLOSE);
   hEMA   = iMA(sym, tf, 50, 0, MODE_EMA, PRICE_CLOSE);

   if(hMACD == INVALID_HANDLE || hRSI == INVALID_HANDLE || hStoch == INVALID_HANDLE ||
      hADX  == INVALID_HANDLE || hATR == INVALID_HANDLE || hBB    == INVALID_HANDLE ||
      hEMA  == INVALID_HANDLE)
   {
      Print("FeatureEngine: impossibile creare handle per TF=", EnumToString(tf));
      return false;
   }
   return true;
}

void FeatureEngine::ReleaseHandles(int &h1, int &h2, int &h3, int &h4, int &h5, int &h6, int &h7)
{
   IndicatorRelease(h1); IndicatorRelease(h2); IndicatorRelease(h3);
   IndicatorRelease(h4); IndicatorRelease(h5); IndicatorRelease(h6);
   IndicatorRelease(h7);
}

void FeatureEngine::Release()
{
   ReleaseHandles(h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30, h_atr_m30, h_bb_m30, h_ema_m30);
   ReleaseHandles(h_macd_h1,  h_rsi_h1,  h_stoch_h1,  h_adx_h1,  h_atr_h1,  h_bb_h1,  h_ema_h1);
   ReleaseHandles(h_macd_h4,  h_rsi_h4,  h_stoch_h4,  h_adx_h4,  h_atr_h4,  h_bb_h4,  h_ema_h4);
}

//--- Estrae feature per il tick corrente
bool FeatureEngine::Extract(double &features[])
{
   return ExtractHistorical(0, features);
}

//--- Estrae feature da barOffset (0 = barra più recente completata)
bool FeatureEngine::ExtractHistorical(int barOffset, double &features[])
{
   ArrayResize(features, FE_TOTAL);
   ArrayInitialize(features, 0.0);

   // M30: 5 barre → offset 0
   if(!ExtractFromTF(PERIOD_M30, FE_M30_BARS, barOffset,
                     h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30,
                     h_atr_m30,  h_bb_m30,  h_ema_m30,
                     features, 0)) return false;

   // H1: 3 barre → offset 40
   if(!ExtractFromTF(PERIOD_H1, FE_H1_BARS, barOffset / 2,
                     h_macd_h1, h_rsi_h1, h_stoch_h1, h_adx_h1,
                     h_atr_h1,  h_bb_h1,  h_ema_h1,
                     features, FE_M30_BARS * FE_FEATURES_PER)) return false;

   // H4: 1 barra → offset 64
   if(!ExtractFromTF(PERIOD_H4, FE_H4_BARS, barOffset / 8,
                     h_macd_h4, h_rsi_h4, h_stoch_h4, h_adx_h4,
                     h_atr_h4,  h_bb_h4,  h_ema_h4,
                     features, (FE_M30_BARS + FE_H1_BARS) * FE_FEATURES_PER)) return false;

   // Feature temporali cicliche (ora e giorno della settimana)
   datetime t   = (barOffset == 0) ? TimeCurrent() : iTime(_sym, PERIOD_M30, barOffset + 1);
   MqlDateTime dt;
   TimeToStruct(t, dt);
   double h    = (double)dt.hour;
   double dow  = (double)(dt.day_of_week == 0 ? 4 : dt.day_of_week - 1); // 0=Mon,4=Fri

   int tOff = (FE_M30_BARS + FE_H1_BARS + FE_H4_BARS) * FE_FEATURES_PER;
   features[tOff + 0] = MathSin(2.0 * M_PI * h   / 24.0);
   features[tOff + 1] = MathCos(2.0 * M_PI * h   / 24.0);
   features[tOff + 2] = MathSin(2.0 * M_PI * dow / 5.0);
   features[tOff + 3] = MathCos(2.0 * M_PI * dow / 5.0);

   return true;
}

//--- Estrae numBars barre da startBar per un dato timeframe
bool FeatureEngine::ExtractFromTF(ENUM_TIMEFRAMES tf, int numBars, int startBar,
                                   int hMACD, int hRSI, int hStoch, int hADX,
                                   int hATR,  int hBB,  int hEMA,
                                   double &features[], int offset)
{
   int needed = startBar + numBars + 2; // +2 per return dell'ultima barra

   double macd_m[], macd_s[], rsi[], stoch_k[], adx_v[];
   double atr_v[], bb_up[], bb_mid[], bb_dn[], ema_v[], close_v[];

   ArraySetAsSeries(macd_m,  true); ArraySetAsSeries(macd_s,  true);
   ArraySetAsSeries(rsi,     true); ArraySetAsSeries(stoch_k, true);
   ArraySetAsSeries(adx_v,   true); ArraySetAsSeries(atr_v,   true);
   ArraySetAsSeries(bb_up,   true); ArraySetAsSeries(bb_mid,  true);
   ArraySetAsSeries(bb_dn,   true); ArraySetAsSeries(ema_v,   true);
   ArraySetAsSeries(close_v, true);

   if(CopyBuffer(hMACD,  0, 1, needed, macd_m)  <= 0 ||
      CopyBuffer(hMACD,  1, 1, needed, macd_s)  <= 0 ||
      CopyBuffer(hRSI,   0, 1, needed, rsi)     <= 0 ||
      CopyBuffer(hStoch, MAIN_LINE, 1, needed, stoch_k) <= 0 ||
      CopyBuffer(hADX,   0, 1, needed, adx_v)   <= 0 ||
      CopyBuffer(hATR,   0, 1, needed, atr_v)   <= 0 ||
      CopyBuffer(hBB,    1, 1, needed, bb_up)   <= 0 ||
      CopyBuffer(hBB,    0, 1, needed, bb_mid)  <= 0 ||
      CopyBuffer(hBB,    2, 1, needed, bb_dn)   <= 0 ||
      CopyBuffer(hEMA,   0, 1, needed, ema_v)   <= 0 ||
      CopyClose(_sym, tf, 1, needed, close_v)   <= 0)
   {
      Print("FeatureEngine: CopyBuffer fallito per TF=", EnumToString(tf));
      return false;
   }

   // Costruisce feature per ogni barra (dalla più vecchia alla più recente)
   for(int b = 0; b < numBars; b++)
   {
      // b=0 → barra più vecchia della finestra = startBar + numBars - 1
      // b=numBars-1 → barra più recente = startBar
      int barIdx = startBar + numBars - 1 - b;
      int fOff   = offset + b * FE_FEATURES_PER;

      double atr   = (atr_v[barIdx] > 1e-10) ? atr_v[barIdx] : 1e-10;
      double close = (close_v[barIdx] > 1e-10) ? close_v[barIdx] : 1.0;
      double bbRange = bb_up[barIdx] - bb_dn[barIdx];

      // [0] MACD histogram normalizzato per ATR
      features[fOff + 0] = SoftClip((macd_m[barIdx] - macd_s[barIdx]) / atr, 2.0);

      // [1] RSI in [-1,1]
      features[fOff + 1] = 2.0 * (rsi[barIdx] / 100.0) - 1.0;

      // [2] Stoch %K in [-1,1]
      features[fOff + 2] = 2.0 * (stoch_k[barIdx] / 100.0) - 1.0;

      // [3] ADX in [-1,1]  (ADX > 25 = trend forte)
      features[fOff + 3] = 2.0 * (MathMin(adx_v[barIdx], 100.0) / 100.0) - 1.0;

      // [4] Bollinger %B in [-1,1]  (0=lower, 1=upper, >1 o <0 possibile)
      features[fOff + 4] = (bbRange > 1e-10)
                         ? SoftClip((close - bb_dn[barIdx]) / bbRange * 2.0 - 1.0, 1.5)
                         : 0.0;

      // [5] ATR% = atr/close (volatilità relativa, tipicamente 0-0.5%)
      features[fOff + 5] = SoftClip((atr / close) * 100.0, 0.5);

      // [6] Return barra = (close[b] / close[b+1] - 1) * 100
      double prevClose = (barIdx + 1 < ArraySize(close_v)) ? close_v[barIdx + 1] : close;
      features[fOff + 6] = (prevClose > 1e-10)
                         ? SoftClip((close / prevClose - 1.0) * 100.0, 0.3)
                         : 0.0;

      // [7] Deviazione EMA50 in unità di ATR
      features[fOff + 7] = SoftClip((close - ema_v[barIdx]) / atr, 3.0);
   }

   return true;
}
