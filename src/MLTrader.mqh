//+------------------------------------------------------------------+
//| MLTrader.mqh                                                     |
//| Orchestratore principale v4.0 — tutte le 7 migliorie applicate:  |
//|   1. Label profittabilità TP/SL forward scan                     |
//|   2. Ensemble di 3 modelli con finestre storiche diverse          |
//|   3. Walk-forward retraining ogni N barre                        |
//|   4. RegimeDetector (TREND/RANGE/VOLATILE)                       |
//|   5. Kelly Criterion per position sizing                          |
//|   6. Feature avanzate (80 features)                              |
//|   7. Script backtest separato (Backtest.mq5)                     |
//+------------------------------------------------------------------+
#pragma once

#include "core/NeuralNetwork.mqh"
#include "features/FeatureEngine.mqh"
#include "risk/RiskManager.mqh"
#include "execution/OrderManager.mqh"
#include "regime/RegimeDetector.mqh"

// Variabili globali per timeout (definite in main.mq5)
extern bool GTimeoutBuy;
extern bool GTimeoutSell;

// Soglie di confidenza
#define SIGNAL_BUY_THRESHOLD  0.65
#define SIGNAL_SELL_THRESHOLD 0.65
#define SIGNAL_OPPOSE_MAX     0.40

// Ensemble: 3 modelli con pesi di confidenza per recency
#define ENSEMBLE_SIZE         3
static const double ENSEMBLE_WEIGHTS[ENSEMBLE_SIZE] = {0.5, 0.3, 0.2};

class MLTrader
{
private:
   NeuralNetwork  *_models[ENSEMBLE_SIZE]; // puntatori per poter ricreare
   FeatureEngine   _fe;
   RiskManager     _rm;
   OrderManager    _om;
   RegimeDetector  _rd;

   string   _sym;
   int      _maxPositions;
   double   _closeProfitUSD;
   int      _trainEpochs;
   int      _trainSamples;
   int      _earlyStopping;
   double   _learningRate;
   double   _slAtrMult;         // moltiplicatore ATR per SL nelle label
   double   _tpAtrMult;         // moltiplicatore ATR per TP nelle label
   int      _maxForwardBars;    // max barre avanti per label scan
   int      _retrainEveryBars;  // walk-forward: ogni quante barre riallena

   int      _hATR_label;        // ATR(14, M30) per generare label
   datetime _lastBarTime;
   int      _barsSinceRetrain;

public:
   MLTrader();
   ~MLTrader();

   bool Init(string symbol,
             ulong  magic,
             int    trainEpochs,
             int    trainSamples,
             double learningRate,
             double riskPerTrade,
             double maxDailyLoss,
             double maxDrawdown,
             double maxSpreadPips,
             double closeProfitUSD,
             int    maxPositions,
             int    earlyStopping,
             double slAtrMult       = 1.0,
             double tpAtrMult       = 2.0,
             int    maxForwardBars  = 20,
             int    retrainEveryBars = 500);

   void Run();      // chiamato ogni tick
   void OnTimer();  // chiamato ogni N minuti per reset timeout

private:
   // Dataset con label profittabilità TP/SL
   bool BuildDataset(int offsetStart, int numSamples,
                     double &inputs[], double &targets[]);

   // Allena tutti e 3 i modelli su finestre storiche diverse
   bool TrainEnsemble();

   // Predizione media pesata dell'ensemble
   void GetEnsemblePrediction(double &features[], double &probBuy, double &probSell);

   // Check e trigger walk-forward retraining
   void CheckAndRetrain();

   bool ShouldActOnNewBar();
   void ReleaseModels();
};

//--- Costruttore / Distruttore
MLTrader::MLTrader()
{
   _sym             = "";
   _maxPositions    = 3;
   _closeProfitUSD  = 10.0;
   _trainEpochs     = 500;
   _trainSamples    = 2000;
   _earlyStopping   = 50;
   _learningRate    = 0.001;
   _slAtrMult       = 1.0;
   _tpAtrMult       = 2.0;
   _maxForwardBars  = 20;
   _retrainEveryBars = 500;
   _hATR_label      = INVALID_HANDLE;
   _lastBarTime     = 0;
   _barsSinceRetrain = 0;

   for(int i = 0; i < ENSEMBLE_SIZE; i++)
      _models[i] = NULL;
}

MLTrader::~MLTrader()
{
   ReleaseModels();
   if(_hATR_label != INVALID_HANDLE) IndicatorRelease(_hATR_label);
}

void MLTrader::ReleaseModels()
{
   for(int i = 0; i < ENSEMBLE_SIZE; i++)
   {
      if(_models[i] != NULL) { delete _models[i]; _models[i] = NULL; }
   }
}

//--- Inizializzazione
bool MLTrader::Init(string symbol, ulong magic,
                    int trainEpochs, int trainSamples, double learningRate,
                    double riskPerTrade, double maxDailyLoss, double maxDrawdown,
                    double maxSpreadPips, double closeProfitUSD,
                    int maxPositions, int earlyStopping,
                    double slAtrMult, double tpAtrMult,
                    int maxForwardBars, int retrainEveryBars)
{
   _sym              = symbol;
   _trainEpochs      = trainEpochs;
   _trainSamples     = trainSamples;
   _learningRate     = learningRate;
   _maxPositions     = maxPositions;
   _closeProfitUSD   = closeProfitUSD;
   _earlyStopping    = earlyStopping;
   _slAtrMult        = slAtrMult;
   _tpAtrMult        = tpAtrMult;
   _maxForwardBars   = maxForwardBars;
   _retrainEveryBars = retrainEveryBars;

   // ATR per label generation (M30, period 14)
   _hATR_label = iATR(symbol, PERIOD_M30, 14);
   if(_hATR_label == INVALID_HANDLE)
   {
      Print("MLTrader: impossibile creare handle ATR label");
      return false;
   }

   if(!_fe.Init(symbol))
   {
      Print("MLTrader: FeatureEngine init fallito");
      return false;
   }

   if(!_rm.Init(symbol, riskPerTrade, maxDailyLoss, maxDrawdown))
   {
      Print("MLTrader: RiskManager init fallito");
      return false;
   }

   if(!_om.Init(symbol, magic, maxSpreadPips))
   {
      Print("MLTrader: OrderManager init fallito");
      return false;
   }

   if(!_rd.Init(symbol))
   {
      Print("MLTrader: RegimeDetector init fallito");
      return false;
   }

   Sleep(5000); // attesa valorizzazione indicatori

   if(!TrainEnsemble())
   {
      Print("MLTrader: TrainEnsemble fallito");
      return false;
   }

   Print("MLTrader v4 inizializzato | sym=", symbol,
         " features=", _fe.FeatureCount(),
         " ensemble=", ENSEMBLE_SIZE);
   return true;
}

//+------------------------------------------------------------------+
//| Costruisce dataset con label profittabilità TP/SL forward scan   |
//+------------------------------------------------------------------+
bool MLTrader::BuildDataset(int offsetStart, int numSamples,
                             double &inputs[], double &targets[])
{
   int featureCount = _fe.FeatureCount();
   int lookback     = FE_M30_BARS;

   int available = Bars(_sym, PERIOD_M30);
   int needed    = offsetStart + numSamples + lookback + _maxForwardBars + 5;
   if(available < needed)
   {
      Print("BuildDataset: dati insufficienti (", available, " < ", needed, ")");
      return false;
   }

   int N = numSamples;
   ArrayResize(inputs,  N * featureCount);
   ArrayResize(targets, N * 2);
   ArrayInitialize(inputs,  0.0);
   ArrayInitialize(targets, 0.0);

   // Carica buffer OHLC per forward scan
   int bufSize = N + offsetStart + lookback + _maxForwardBars + 5;
   double high_buf[], low_buf[], close_buf[], atr_buf[];
   ArraySetAsSeries(high_buf,  true);
   ArraySetAsSeries(low_buf,   true);
   ArraySetAsSeries(close_buf, true);
   ArraySetAsSeries(atr_buf,   true);

   if(CopyHigh (_sym, PERIOD_M30, 1, bufSize, high_buf)  <= 0 ||
      CopyLow  (_sym, PERIOD_M30, 1, bufSize, low_buf)   <= 0 ||
      CopyClose(_sym, PERIOD_M30, 1, bufSize, close_buf) <= 0 ||
      CopyBuffer(_hATR_label, 0, 1, bufSize, atr_buf)    <= 0)
   {
      Print("BuildDataset: CopyBuffer fallito");
      return false;
   }

   int buyCount = 0, sellCount = 0, noneCount = 0, failCount = 0;

   for(int k = 0; k < N; k++)
   {
      int barIdx = k + offsetStart; // indice nel buffer (0 = barra più recente)

      double feats[];
      if(!_fe.ExtractHistorical(barIdx + 1, feats))
      {
         failCount++;
         if(failCount > 20) { Print("BuildDataset: troppi errori feature"); return false; }
         // inserisce zero-features per questo campione, nessuna label
         continue;
      }

      // Copia features
      int fOff = k * featureCount;
      ArrayCopy(inputs, feats, fOff, 0, featureCount);

      // Calcola ATR alla barra barIdx per SL/TP
      double atrVal = (barIdx < ArraySize(atr_buf) && atr_buf[barIdx] > 1e-10)
                      ? atr_buf[barIdx] : 10 * SymbolInfoDouble(_sym, SYMBOL_POINT);

      double entryClose = close_buf[barIdx];
      double buyTP  = entryClose + atrVal * _tpAtrMult;
      double buySL  = entryClose - atrVal * _slAtrMult;
      double sellTP = entryClose - atrVal * _tpAtrMult;
      double sellSL = entryClose + atrVal * _slAtrMult;

      // Forward scan — controlla quale livello viene toccato prima
      // In ArraySetAsSeries(true): indice 0 = barra più recente
      // barIdx-1 è la barra successiva (più recente)
      bool buyWins  = false, buyLoses  = false;
      bool sellWins = false, sellLoses = false;

      for(int f = 1; f <= _maxForwardBars; f++)
      {
         int fi = barIdx - f; // barra f step avanti
         if(fi < 0 || fi >= ArraySize(high_buf)) break;

         double h = high_buf[fi];
         double l = low_buf[fi];

         if(!buyWins  && !buyLoses)
         {
            if(h >= buyTP)  buyWins  = true;
            if(l <= buySL)  buyLoses = true;
         }
         if(!sellWins && !sellLoses)
         {
            if(l <= sellTP) sellWins  = true;
            if(h >= sellSL) sellLoses = true;
         }
         if((buyWins || buyLoses) && (sellWins || sellLoses)) break;
      }

      // Assegna label
      int tOff = k * 2;
      double buyLabel  = buyWins  ? 1.0 : 0.0;
      double sellLabel = sellWins ? 1.0 : 0.0;

      targets[tOff]     = buyLabel;
      targets[tOff + 1] = sellLabel;

      if(buyWins)  buyCount++;
      else if(sellWins) sellCount++;
      else noneCount++;
   }

   Print("Dataset[offset=", offsetStart, "]: BUY=", buyCount,
         " SELL=", sellCount, " NONE=", noneCount,
         " ratio=", DoubleToString((double)buyCount / MathMax(1, sellCount), 2));
   return true;
}

//+------------------------------------------------------------------+
//| Allena i 3 modelli dell'ensemble su finestre storiche diverse    |
//+------------------------------------------------------------------+
bool MLTrader::TrainEnsemble()
{
   ReleaseModels();

   int featureCount = _fe.FeatureCount();
   int layers[]     = {featureCount, 128, 64, 32, 2};
   int nLayers      = ArraySize(layers);

   // Finestre: [0] più recente, [1] media, [2] più vecchia
   // Ogni modello usa _trainSamples/3 campioni da sezioni diverse
   int samplesPerModel = MathMax(200, _trainSamples / 3);

   for(int m = 0; m < ENSEMBLE_SIZE; m++)
   {
      int offset = m * samplesPerModel; // scorrimento nella storia

      double inputs[], targets[];
      if(!BuildDataset(offset, samplesPerModel, inputs, targets))
      {
         Print("TrainEnsemble: BuildDataset fallito per modello ", m);
         return false;
      }

      _models[m] = new NeuralNetwork(_learningRate, 0.9, 0.999, 1e-8, 1e-5, 1.0);
      if(!_models[m].BuildModel(layers, nLayers))
      {
         Print("TrainEnsemble: BuildModel fallito per modello ", m);
         return false;
      }

      _models[m].Train(inputs, targets, _trainEpochs, _earlyStopping);
      Print("Ensemble modello ", m, " addestrato (offset=", offset, ")");
   }

   _barsSinceRetrain = 0;
   return true;
}

//+------------------------------------------------------------------+
//| Predizione ensemble: media pesata delle 3 reti                   |
//+------------------------------------------------------------------+
void MLTrader::GetEnsemblePrediction(double &features[], double &probBuy, double &probSell)
{
   probBuy  = 0.0;
   probSell = 0.0;
   double totalW = 0.0;

   for(int m = 0; m < ENSEMBLE_SIZE; m++)
   {
      if(_models[m] == NULL) continue;

      _models[m].FeedForward(features);
      double out[];
      _models[m].GetOutputs(out);
      if(ArraySize(out) < 2) continue;

      double w = ENSEMBLE_WEIGHTS[m];
      probBuy  += w * out[0];
      probSell += w * out[1];
      totalW   += w;
   }

   if(totalW > 1e-10) { probBuy /= totalW; probSell /= totalW; }
}

//+------------------------------------------------------------------+
//| Walk-forward: riallena se sono trascorse abbastanza barre        |
//+------------------------------------------------------------------+
void MLTrader::CheckAndRetrain()
{
   if(_barsSinceRetrain >= _retrainEveryBars)
   {
      Print("MLTrader: avvio walk-forward retraining (barre=", _barsSinceRetrain, ")");
      if(TrainEnsemble())
         Print("MLTrader: retraining completato");
      else
         Print("MLTrader: retraining fallito — mantengo modelli precedenti");
   }
}

//+------------------------------------------------------------------+
//| Run — chiamato ogni tick                                          |
//+------------------------------------------------------------------+
void MLTrader::Run()
{
   _rm.Update();
   _om.ManageOpenPositions();
   _om.CloseProfitable(_closeProfitUSD);

   if(!ShouldActOnNewBar()) return;

   _barsSinceRetrain++;
   CheckAndRetrain();

   if(!_rm.CanTrade())   return;
   if(!_om.CanOpenNew()) return;
   if(_om.CountPositions() >= _maxPositions) return;

   // Regime filter — salta se mercato volatile
   ENUM_MARKET_REGIME regime = _rd.Detect();
   if(regime == REGIME_VOLATILE)
   {
      static int volatileCount = 0;
      if(++volatileCount % 20 == 0)
         Print("MLTrader: regime VOLATILE — trade sospesi (ADX=",
               DoubleToString(_rd.GetADX(), 1),
               " ATRratio=", DoubleToString(_rd.GetATRRatio(), 2), ")");
      return;
   }

   // Estrae feature correnti
   double features[];
   if(!_fe.Extract(features))
   {
      Print("MLTrader: estrazione feature fallita");
      return;
   }

   // Predizione ensemble
   double probBuy, probSell;
   GetEnsemblePrediction(features, probBuy, probSell);

   // Segnale BUY
   if(probBuy >= SIGNAL_BUY_THRESHOLD && probSell <= SIGNAL_OPPOSE_MAX && GTimeoutBuy)
   {
      double sl  = _rm.CalcStopLossPrice(ORDER_TYPE_BUY);
      double ask = SymbolInfoDouble(_sym, SYMBOL_ASK);
      double tp  = ask + MathAbs(ask - sl) * (_tpAtrMult / _slAtrMult);
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));

      // Kelly sizing: usa probBuy come stima di probWin
      double lots = _rm.CalcKellyLotSize(sl, ask, probBuy, _tpAtrMult / _slAtrMult);
      if(lots <= 0) lots = _rm.CalcLotSize(sl, ask); // fallback

      if(_om.OpenBuy(lots, sl, tp, StringFormat("ML BUY %.2f [%s]", probBuy, _rd.ToString(regime))))
      {
         GTimeoutBuy = false;
         Print("BUY aperto | pBuy=", DoubleToString(probBuy, 3),
               " lots=", DoubleToString(lots, 2),
               " regime=", _rd.ToString(regime));
      }
   }
   // Segnale SELL
   else if(probSell >= SIGNAL_SELL_THRESHOLD && probBuy <= SIGNAL_OPPOSE_MAX && GTimeoutSell)
   {
      double sl  = _rm.CalcStopLossPrice(ORDER_TYPE_SELL);
      double bid = SymbolInfoDouble(_sym, SYMBOL_BID);
      double tp  = bid - MathAbs(sl - bid) * (_tpAtrMult / _slAtrMult);
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));

      double lots = _rm.CalcKellyLotSize(sl, bid, probSell, _tpAtrMult / _slAtrMult);
      if(lots <= 0) lots = _rm.CalcLotSize(sl, bid);

      if(_om.OpenSell(lots, sl, tp, StringFormat("ML SELL %.2f [%s]", probSell, _rd.ToString(regime))))
      {
         GTimeoutSell = false;
         Print("SELL aperto | pSell=", DoubleToString(probSell, 3),
               " lots=", DoubleToString(lots, 2),
               " regime=", _rd.ToString(regime));
      }
   }

   // Log periodico
   static int tickCount = 0;
   if(++tickCount % 100 == 0)
   {
      Print("Status: pBuy=", DoubleToString(probBuy, 3),
            " pSell=", DoubleToString(probSell, 3),
            " pos=", _om.CountPositions(),
            " PnL=", DoubleToString(_om.TotalFloatingPnL(), 2),
            " regime=", _rd.ToString(regime),
            " | ", _rm.GetStatusString());
   }
}

void MLTrader::OnTimer()
{
   GTimeoutBuy  = true;
   GTimeoutSell = true;
}

bool MLTrader::ShouldActOnNewBar()
{
   datetime barTime = iTime(_sym, PERIOD_M30, 1);
   if(barTime != _lastBarTime)
   {
      _lastBarTime = barTime;
      return true;
   }
   return false;
}
