//+------------------------------------------------------------------+
//| FeatureEngine.mqh                                                |
//| 80 feature da 3 timeframe + tempo + 4 feature globali            |
//|                                                                  |
//| Layout per barra (8 feature):                                    |
//|   [0] MACD histogram / ATR                                       |
//|   [1] RSI in [-1,1]                                              |
//|   [2] Stoch %K in [-1,1]                                         |
//|   [3] ADX in [-1,1]                                              |
//|   [4] Bollinger %B in [-1,1]                                     |
//|   [5] ATR% volatilità relativa (soft-clipped)                    |
//|   [6] Return barra (soft-clipped)                                |
//|   [7] Deviazione EMA50 / ATR (soft-clipped)                      |
//|                                                                  |
//| Gruppi:                                                          |
//|   M30 5 barre × 8 = 40   idx 0-39                               |
//|   H1  3 barre × 8 = 24   idx 40-63                              |
//|   H4  1 barra  × 8 =  8  idx 64-71                              |
//|   Tempo cicl.        4   idx 72-75                               |
//|   Globali            4   idx 76-79   ← NUOVO                    |
//|     [76] Vol expansion: ATR(14)/ATR(100) - 1 su M30             |
//|     [77] Momentum 10-barre M30 / ATR                            |
//|     [78] Allineamento M30/H1: +1 stessa dir, -1 opposta         |
//|     [79] Allineamento M30/H4: +1 stessa dir, -1 opposta         |
//| Totale: 80                                                        |
//+------------------------------------------------------------------+
#pragma once

#define FE_M30_BARS       5
#define FE_H1_BARS        3
#define FE_H4_BARS        1
#define FE_FEATURES_PER   8
#define FE_TIME_FEATURES  4
#define FE_GLOBAL_FEATURES 4
#define FE_TOTAL          ((FE_M30_BARS + FE_H1_BARS + FE_H4_BARS) * FE_FEATURES_PER \
                           + FE_TIME_FEATURES + FE_GLOBAL_FEATURES)
// = 72 + 4 + 4 = 80

class FeatureEngine
{
private:
   string _sym;
   // Handles M30
   int h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30, h_atr_m30, h_bb_m30, h_ema_m30;
   int h_atr_m30_slow;   // ATR(100, M30) per vol expansion — NUOVO
   // Handles H1
   int h_macd_h1,  h_rsi_h1,  h_stoch_h1,  h_adx_h1,  h_atr_h1,  h_bb_h1,  h_ema_h1;
   // Handles H4
   int h_macd_h4,  h_rsi_h4,  h_stoch_h4,  h_adx_h4,  h_atr_h4,  h_bb_h4,  h_ema_h4;

public:
   FeatureEngine() { _sym = ""; h_atr_m30_slow = INVALID_HANDLE; }
   ~FeatureEngine() { Release(); }

   bool Init(string symbol);
   void Release();

   bool Extract(double &features[]);
   bool ExtractHistorical(int barOffset, double &features[]);
   int  FeatureCount() { return FE_TOTAL; }

private:
   bool ExtractFromTF(ENUM_TIMEFRAMES tf, int numBars, int startBar,
                      int hMACD, int hRSI, int hStoch, int hADX,
                      int hATR, int hBB, int hEMA,
                      double &features[], int offset);

   bool AddGlobalFeatures(int barOffset, double &features[]);

   double SoftClip(double v, double scale)
   {
      double x = v / MathMax(scale, 1e-10);
      return (MathExp(2.0 * x) - 1.0) / (MathExp(2.0 * x) + 1.0);
   }

   bool CreateHandles(string sym, ENUM_TIMEFRAMES tf,
                      int &hMACD, int &hRSI, int &hStoch, int &hADX,
                      int &hATR, int &hBB, int &hEMA);
};

bool FeatureEngine::Init(string symbol)
{
   _sym = symbol;
   if(!CreateHandles(symbol, PERIOD_M30,
                     h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30,
                     h_atr_m30, h_bb_m30, h_ema_m30))  return false;
   if(!CreateHandles(symbol, PERIOD_H1,
                     h_macd_h1, h_rsi_h1, h_stoch_h1, h_adx_h1,
                     h_atr_h1, h_bb_h1, h_ema_h1))     return false;
   if(!CreateHandles(symbol, PERIOD_H4,
                     h_macd_h4, h_rsi_h4, h_stoch_h4, h_adx_h4,
                     h_atr_h4, h_bb_h4, h_ema_h4))     return false;

   h_atr_m30_slow = iATR(symbol, PERIOD_M30, 100);
   if(h_atr_m30_slow == INVALID_HANDLE)
   {
      Print("FeatureEngine: impossibile creare ATR lento M30");
      return false;
   }
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
      Print("FeatureEngine: handle invalido su TF=", EnumToString(tf));
      return false;
   }
   return true;
}

void FeatureEngine::Release()
{
   int handles[] = {h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30, h_atr_m30, h_bb_m30, h_ema_m30,
                    h_macd_h1,  h_rsi_h1,  h_stoch_h1,  h_adx_h1,  h_atr_h1,  h_bb_h1,  h_ema_h1,
                    h_macd_h4,  h_rsi_h4,  h_stoch_h4,  h_adx_h4,  h_atr_h4,  h_bb_h4,  h_ema_h4,
                    h_atr_m30_slow};
   for(int i = 0; i < ArraySize(handles); i++)
      if(handles[i] != INVALID_HANDLE) IndicatorRelease(handles[i]);
}

bool FeatureEngine::Extract(double &features[])    { return ExtractHistorical(0, features); }

bool FeatureEngine::ExtractHistorical(int barOffset, double &features[])
{
   ArrayResize(features, FE_TOTAL);
   ArrayInitialize(features, 0.0);

   if(!ExtractFromTF(PERIOD_M30, FE_M30_BARS, barOffset,
                     h_macd_m30, h_rsi_m30, h_stoch_m30, h_adx_m30,
                     h_atr_m30,  h_bb_m30,  h_ema_m30,
                     features, 0)) return false;

   if(!ExtractFromTF(PERIOD_H1, FE_H1_BARS, barOffset / 2,
                     h_macd_h1, h_rsi_h1, h_stoch_h1, h_adx_h1,
                     h_atr_h1,  h_bb_h1,  h_ema_h1,
                     features, FE_M30_BARS * FE_FEATURES_PER)) return false;

   if(!ExtractFromTF(PERIOD_H4, FE_H4_BARS, barOffset / 8,
                     h_macd_h4, h_rsi_h4, h_stoch_h4, h_adx_h4,
                     h_atr_h4,  h_bb_h4,  h_ema_h4,
                     features, (FE_M30_BARS + FE_H1_BARS) * FE_FEATURES_PER)) return false;

   // Feature temporali cicliche
   datetime t = (barOffset == 0) ? TimeCurrent() : iTime(_sym, PERIOD_M30, barOffset + 1);
   MqlDateTime dt;
   TimeToStruct(t, dt);
   double h   = (double)dt.hour;
   double dow = (double)(dt.day_of_week == 0 ? 4 : dt.day_of_week - 1);

   int tOff = (FE_M30_BARS + FE_H1_BARS + FE_H4_BARS) * FE_FEATURES_PER;
   features[tOff]     = MathSin(2.0 * M_PI * h   / 24.0);
   features[tOff + 1] = MathCos(2.0 * M_PI * h   / 24.0);
   features[tOff + 2] = MathSin(2.0 * M_PI * dow / 5.0);
   features[tOff + 3] = MathCos(2.0 * M_PI * dow / 5.0);

   // Feature globali (indicatori macro di mercato)
   if(!AddGlobalFeatures(barOffset, features)) return false;

   return true;
}

bool FeatureEngine::AddGlobalFeatures(int barOffset, double &features[])
{
   int gOff  = (FE_M30_BARS + FE_H1_BARS + FE_H4_BARS) * FE_FEATURES_PER + FE_TIME_FEATURES;
   int need  = barOffset + 12; // 10-bar momentum + buffer

   double atr_fast[], atr_slow[], close_g[];
   ArraySetAsSeries(atr_fast, true);
   ArraySetAsSeries(atr_slow, true);
   ArraySetAsSeries(close_g,  true);

   if(CopyBuffer(h_atr_m30,      0, 1, need, atr_fast) <= 0 ||
      CopyBuffer(h_atr_m30_slow, 0, 1, need, atr_slow) <= 0 ||
      CopyClose(_sym, PERIOD_M30, 1, need, close_g)    <= 0)
   {
      Print("FeatureEngine: AddGlobalFeatures copy fallito");
      return false;
   }

   int bar = barOffset; // indice nella serie

   // [76] Vol expansion: ATR(14)/ATR(100) - 1  (>0 = espansione, <0 = compressione)
   features[gOff] = (atr_slow[bar] > 1e-10)
                  ? SoftClip(atr_fast[bar] / atr_slow[bar] - 1.0, 0.5)
                  : 0.0;

   // [77] Momentum 10-barre M30: (close[bar] - close[bar+9]) / (ATR * 10)
   int m10 = bar + 9;
   features[gOff + 1] = (m10 < ArraySize(close_g) && atr_fast[bar] > 1e-10)
                       ? SoftClip((close_g[bar] - close_g[m10]) / (atr_fast[bar] * 10.0), 2.0)
                       : 0.0;

   // [78] Allineamento M30/H1: segno MACD histogram
   //   features[(FE_M30_BARS-1)*8 + 0] = MACD hist M30 più recente (già estratto)
   //   features[FE_M30_BARS*8 + (FE_H1_BARS-1)*8 + 0] = MACD hist H1 più recente
   double macdM30 = features[(FE_M30_BARS - 1) * FE_FEATURES_PER];
   double macdH1  = features[FE_M30_BARS * FE_FEATURES_PER + (FE_H1_BARS - 1) * FE_FEATURES_PER];
   features[gOff + 2] = (macdM30 * macdH1 > 0) ? 1.0 : -1.0;

   // [79] Allineamento M30/H4: stessa logica
   double macdH4 = features[(FE_M30_BARS + FE_H1_BARS) * FE_FEATURES_PER];
   features[gOff + 3] = (macdM30 * macdH4 > 0) ? 1.0 : -1.0;

   return true;
}

bool FeatureEngine::ExtractFromTF(ENUM_TIMEFRAMES tf, int numBars, int startBar,
                                   int hMACD, int hRSI, int hStoch, int hADX,
                                   int hATR,  int hBB,  int hEMA,
                                   double &features[], int offset)
{
   int needed = startBar + numBars + 2;

   double macd_m[], macd_s[], rsi[], stoch_k[], adx_v[];
   double atr_v[], bb_up[], bb_dn[], ema_v[], close_v[];

   ArraySetAsSeries(macd_m,  true); ArraySetAsSeries(macd_s,  true);
   ArraySetAsSeries(rsi,     true); ArraySetAsSeries(stoch_k, true);
   ArraySetAsSeries(adx_v,   true); ArraySetAsSeries(atr_v,   true);
   ArraySetAsSeries(bb_up,   true); ArraySetAsSeries(bb_dn,   true);
   ArraySetAsSeries(ema_v,   true); ArraySetAsSeries(close_v, true);

   if(CopyBuffer(hMACD,  0, 1, needed, macd_m)  <= 0 ||
      CopyBuffer(hMACD,  1, 1, needed, macd_s)  <= 0 ||
      CopyBuffer(hRSI,   0, 1, needed, rsi)     <= 0 ||
      CopyBuffer(hStoch, MAIN_LINE, 1, needed, stoch_k) <= 0 ||
      CopyBuffer(hADX,   0, 1, needed, adx_v)   <= 0 ||
      CopyBuffer(hATR,   0, 1, needed, atr_v)   <= 0 ||
      CopyBuffer(hBB,    1, 1, needed, bb_up)   <= 0 ||
      CopyBuffer(hBB,    2, 1, needed, bb_dn)   <= 0 ||
      CopyBuffer(hEMA,   0, 1, needed, ema_v)   <= 0 ||
      CopyClose(_sym, tf, 1, needed, close_v)   <= 0)
   {
      Print("FeatureEngine: CopyBuffer fallito TF=", EnumToString(tf));
      return false;
   }

   for(int b = 0; b < numBars; b++)
   {
      int barIdx = startBar + numBars - 1 - b; // b=0 oldest, b=numBars-1 most recent
      int fOff   = offset + b * FE_FEATURES_PER;

      double atr   = MathMax(atr_v[barIdx],  1e-10);
      double close = MathMax(close_v[barIdx], 1.0);
      double bbRng = bb_up[barIdx] - bb_dn[barIdx];

      features[fOff]     = SoftClip((macd_m[barIdx] - macd_s[barIdx]) / atr, 2.0);
      features[fOff + 1] = 2.0 * (rsi[barIdx] / 100.0) - 1.0;
      features[fOff + 2] = 2.0 * (stoch_k[barIdx] / 100.0) - 1.0;
      features[fOff + 3] = 2.0 * (MathMin(adx_v[barIdx], 100.0) / 100.0) - 1.0;
      features[fOff + 4] = (bbRng > 1e-10)
                         ? SoftClip((close - bb_dn[barIdx]) / bbRng * 2.0 - 1.0, 1.5) : 0.0;
      features[fOff + 5] = SoftClip((atr / close) * 100.0, 0.5);

      double prevClose = (barIdx + 1 < ArraySize(close_v)) ? close_v[barIdx + 1] : close;
      features[fOff + 6] = (prevClose > 1e-10)
                         ? SoftClip((close / prevClose - 1.0) * 100.0, 0.3) : 0.0;
      features[fOff + 7] = SoftClip((close - ema_v[barIdx]) / atr, 3.0);
   }
   return true;
}
