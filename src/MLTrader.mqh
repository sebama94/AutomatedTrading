//+------------------------------------------------------------------+
//| MLTrader.mqh                                                     |
//| Orchestratore principale: coordina FeatureEngine, NeuralNetwork, |
//| RiskManager e OrderManager.                                      |
//|                                                                  |
//| Pipeline:                                                        |
//|   Init():  raccoglie storico → costruisce dataset → addestra NN  |
//|   Run():   estrae feature → predice → filtra → esegue ordine     |
//+------------------------------------------------------------------+
#pragma once

#include "core/NeuralNetwork.mqh"
#include "features/FeatureEngine.mqh"
#include "risk/RiskManager.mqh"
#include "execution/OrderManager.mqh"

// Variabili globali per timeout (definite in main.mq5)
extern bool GTimeoutBuy;
extern bool GTimeoutSell;

// Soglie di confidenza per aprire un trade
#define SIGNAL_BUY_THRESHOLD  0.65
#define SIGNAL_SELL_THRESHOLD 0.65
#define SIGNAL_OPPOSE_MAX     0.40  // output opposto deve essere basso

class MLTrader
{
private:
   NeuralNetwork  _nn;
   FeatureEngine  _fe;
   RiskManager    _rm;
   OrderManager   _om;

   string  _sym;
   int     _maxPositions;
   double  _closeProfitUSD;
   int     _trainEpochs;
   int     _trainSamples;
   int     _earlyStopping;

   datetime _lastBarTime; // per eseguire segnali solo su nuova barra

public:
   MLTrader();
   ~MLTrader() {}

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
             int    earlyStopping);

   void Run();    // chiamato ogni tick
   void OnTimer();// chiamato ogni N minuti per reset timeout

private:
   bool BuildAndTrainModel(double lr, double l2 = 1e-5, double clipNorm = 1.0);
   bool ShouldActOnNewBar();
};

MLTrader::MLTrader()
{
   _sym          = "";
   _maxPositions = 3;
   _closeProfitUSD = 10.0;
   _trainEpochs  = 500;
   _trainSamples = 2000;
   _earlyStopping = 50;
   _lastBarTime  = 0;
}

bool MLTrader::Init(string symbol, ulong magic,
                    int    trainEpochs, int trainSamples, double learningRate,
                    double riskPerTrade, double maxDailyLoss, double maxDrawdown,
                    double maxSpreadPips, double closeProfitUSD,
                    int maxPositions, int earlyStopping)
{
   _sym           = symbol;
   _trainEpochs   = trainEpochs;
   _trainSamples  = trainSamples;
   _maxPositions  = maxPositions;
   _closeProfitUSD = closeProfitUSD;
   _earlyStopping = earlyStopping;

   // Feature engine
   if(!_fe.Init(symbol))
   {
      Print("MLTrader: FeatureEngine init fallito");
      return false;
   }

   // Risk manager
   if(!_rm.Init(symbol, riskPerTrade, maxDailyLoss, maxDrawdown))
   {
      Print("MLTrader: RiskManager init fallito");
      return false;
   }

   // Order manager
   if(!_om.Init(symbol, magic, maxSpreadPips))
   {
      Print("MLTrader: OrderManager init fallito");
      return false;
   }

   // Attesa valorizzazione indicatori
   Sleep(5000);

   // Costruisce e addestra il modello
   if(!BuildAndTrainModel(learningRate))
   {
      Print("MLTrader: training fallito");
      return false;
   }

   Print("MLTrader inizializzato | sym=", symbol, " features=", _fe.FeatureCount());
   return true;
}

//--- Costruisce dataset storico e addestra la rete
bool MLTrader::BuildAndTrainModel(double lr, double l2, double clipNorm)
{
   int featureCount = _fe.FeatureCount(); // FE_TOTAL = 76
   int lookback     = FE_M30_BARS;        // barre usate nel passato più recente per etichetta

   // Quante barre M30 servono:
   //   trainSamples campioni + lookback per il buffer + 2 extra
   int neededBars = _trainSamples + lookback + 2;

   // Verifica disponibilità dati storici
   int available = Bars(_sym, PERIOD_M30);
   if(available < neededBars)
   {
      Print("MLTrader: dati insufficienti (", available, " < ", neededBars, ")");
      return false;
   }

   int N = MathMin(_trainSamples, available - lookback - 2);
   Print("MLTrader: costruzione dataset | N=", N, " features=", featureCount);

   double inputs[];
   double targets[];
   ArrayResize(inputs,  N * featureCount);
   ArrayResize(targets, N * 2);
   ArrayInitialize(inputs,  0.0);
   ArrayInitialize(targets, 0.0);

   // Close prices per generare le label (direzione della barra successiva)
   double close_buf[];
   ArraySetAsSeries(close_buf, true);
   int closesNeeded = N + lookback + 2;
   if(CopyClose(_sym, PERIOD_M30, 1, closesNeeded, close_buf) <= 0)
   {
      Print("MLTrader: CopyClose fallito");
      return false;
   }

   int buyCount = 0, sellCount = 0, holdCount = 0;
   int failCount = 0;

   // Per ogni campione k (0..N-1):
   //   - Usa ExtractHistorical(k+1) → finestra storica k+1 barre fa
   //   - Label: close_buf[k] vs close_buf[k+1]  (barra k vs barra k+1 in series)
   //     In series: close_buf[k] è più recente di close_buf[k+1]
   //     close_buf[k] > close_buf[k+1] → barra k salita → BUY [1,0]
   for(int k = 0; k < N; k++)
   {
      double feats[];
      if(!_fe.ExtractHistorical(k + 1, feats))
      {
         failCount++;
         if(failCount > 10) { Print("MLTrader: troppi errori feature extraction"); return false; }
         continue;
      }

      int fOff = k * featureCount;
      int tOff = k * 2;
      ArrayCopy(inputs, feats, fOff, 0, featureCount);

      // Label forward-looking
      if(k < ArraySize(close_buf) - 1)
      {
         if(close_buf[k] > close_buf[k + 1])
         {
            targets[tOff]     = 1.0; targets[tOff + 1] = 0.0; buyCount++;
         }
         else if(close_buf[k] < close_buf[k + 1])
         {
            targets[tOff]     = 0.0; targets[tOff + 1] = 1.0; sellCount++;
         }
         else
         {
            targets[tOff]     = 0.0; targets[tOff + 1] = 0.0; holdCount++;
         }
      }
   }

   Print("Dataset: BUY=", buyCount, " SELL=", sellCount, " HOLD=", holdCount,
         " | Balance BUY/SELL: ", DoubleToString((double)buyCount / MathMax(1, sellCount), 2));

   // Costruisce rete neurale: 76 → 128 → 64 → 32 → 2
   int layers[] = {featureCount, 128, 64, 32, 2};
   int nLayers  = ArraySize(layers);
   _nn = NeuralNetwork(lr, 0.9, 0.999, 1e-8, l2, clipNorm);
   if(!_nn.BuildModel(layers, nLayers))
   {
      Print("MLTrader: BuildModel fallito");
      return false;
   }

   _nn.Train(inputs, targets, _trainEpochs, _earlyStopping);
   return true;
}

//--- Eseguito ogni tick
void MLTrader::Run()
{
   // Aggiorna risk manager
   _rm.Update();

   // Gestione trailing stop sulle posizioni aperte (ogni tick)
   _om.ManageOpenPositions();

   // Chiudi posizioni profittevoli
   _om.CloseProfitable(_closeProfitUSD);

   // Segnali solo su nuova barra M30 (evita rumore infrabar)
   if(!ShouldActOnNewBar()) return;

   // Risk check
   if(!_rm.CanTrade())
   {
      // Non loggare ogni tick per non intasare
      return;
   }

   // Filtro sessione + spread
   if(!_om.CanOpenNew()) return;

   // Limite posizioni aperte
   if(_om.CountPositions() >= _maxPositions) return;

   // Estrae feature correnti
   double features[];
   if(!_fe.Extract(features))
   {
      Print("MLTrader: estrazione feature fallita");
      return;
   }

   // Predizione
   _nn.FeedForward(features);
   double output[];
   _nn.GetOutputs(output);

   if(ArraySize(output) < 2) return;

   double probBuy  = output[0];
   double probSell = output[1];

   // Segnale BUY
   if(probBuy >= SIGNAL_BUY_THRESHOLD && probSell <= SIGNAL_OPPOSE_MAX && GTimeoutBuy)
   {
      double sl = _rm.CalcStopLossPrice(ORDER_TYPE_BUY);
      double ask = SymbolInfoDouble(_sym, SYMBOL_ASK);
      double tp  = ask + MathAbs(ask - sl) * 2.0; // R:R = 1:2
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));

      double lots = _rm.CalcLotSize(sl, ask);
      if(_om.OpenBuy(lots, sl, tp, StringFormat("ML BUY %.2f", probBuy)))
         GTimeoutBuy = false;
   }
   // Segnale SELL
   else if(probSell >= SIGNAL_SELL_THRESHOLD && probBuy <= SIGNAL_OPPOSE_MAX && GTimeoutSell)
   {
      double sl = _rm.CalcStopLossPrice(ORDER_TYPE_SELL);
      double bid = SymbolInfoDouble(_sym, SYMBOL_BID);
      double tp  = bid - MathAbs(sl - bid) * 2.0; // R:R = 1:2
      tp = NormalizeDouble(tp, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));

      double lots = _rm.CalcLotSize(sl, bid);
      if(_om.OpenSell(lots, sl, tp, StringFormat("ML SELL %.2f", probSell)))
         GTimeoutSell = false;
   }

   // Log periodico
   static int tickCount = 0;
   if(++tickCount % 100 == 0)
   {
      Print("Status: pBuy=", DoubleToString(probBuy, 3),
            " pSell=", DoubleToString(probSell, 3),
            " pos=", _om.CountPositions(),
            " PnL=", DoubleToString(_om.TotalFloatingPnL(), 2),
            " | ", _rm.GetStatusString());
   }
}

void MLTrader::OnTimer()
{
   GTimeoutBuy  = true;
   GTimeoutSell = true;
}

//--- Restituisce true solo alla prima chiamata di ogni nuova barra M30
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
