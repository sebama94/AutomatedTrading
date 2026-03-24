//+------------------------------------------------------------------+
//|                                                         main.mq5 |
//|                     ML Trading System v4.0                       |
//|                                                                  |
//| Migliorie v4:                                                     |
//|   1. Label profittabilità TP/SL forward scan                     |
//|   2. Ensemble 3 modelli con finestre storiche diverse            |
//|   3. Walk-forward retraining ogni N barre                        |
//|   4. RegimeDetector (TREND/RANGE/VOLATILE)                       |
//|   5. Kelly Criterion position sizing (half-Kelly)                |
//|   6. 80 feature (+ vol expansion, momentum, MACD alignment)      |
//|   7. Backtest.mq5 per metriche post-test                        |
//+------------------------------------------------------------------+
#property copyright "2024"
#property version   "4.00"
#property strict

#include "src/MLTrader.mqh"

//=== PARAMETRI TRADING ===
input string   InpSymbol         = "EURUSD";   // Simbolo
input ulong    InpMagic          = 20240001;   // Magic number EA

//=== PARAMETRI TRAINING ===
input int      InpEpochs         = 500;        // Epoche di training per modello
input int      InpTrainSamples   = 2000;       // Campioni totali (divisi in 3 finestre)
input double   InpLearningRate   = 0.001;      // Learning rate Adam
input int      InpEarlyStopping  = 50;         // Patience early stopping

//=== LABEL GENERATION ===
input double   InpSLAtrMult      = 1.0;        // Moltiplicatore ATR per Stop Loss label
input double   InpTPAtrMult      = 2.0;        // Moltiplicatore ATR per Take Profit label
input int      InpMaxForwardBars = 20;         // Barre avanti max per scan label

//=== WALK-FORWARD RETRAINING ===
input int      InpRetrainEveryBars = 500;      // Barre M30 tra un retraining e l'altro

//=== RISK MANAGEMENT ===
input double   InpRiskPerTrade   = 0.01;       // Rischio base per trade (1% del balance)
input double   InpMaxDailyLoss   = 0.03;       // Perdita max giornaliera (3%)
input double   InpMaxDrawdown    = 0.10;       // Drawdown max circuit breaker (10%)

//=== ESECUZIONE ===
input double   InpMaxSpreadPips  = 2.0;        // Spread massimo in pips
input double   InpCloseProfitUSD = 10.0;       // Chiudi posizione a profitto ($)
input int      InpMaxPositions   = 3;          // Posizioni simultanee massime

//=== TIMER ===
input int      InpTimeoutMinutes = 30;         // Minuti tra un trade e l'altro per direzione

// Variabili globali timeout (lette da MLTrader)
bool GTimeoutBuy  = true;
bool GTimeoutSell = true;

MLTrader *trader;

int OnInit()
{
   EventSetTimer(InpTimeoutMinutes * 60);

   trader = new MLTrader();
   if(!trader.Init(InpSymbol,
                   InpMagic,
                   InpEpochs,
                   InpTrainSamples,
                   InpLearningRate,
                   InpRiskPerTrade,
                   InpMaxDailyLoss,
                   InpMaxDrawdown,
                   InpMaxSpreadPips,
                   InpCloseProfitUSD,
                   InpMaxPositions,
                   InpEarlyStopping,
                   InpSLAtrMult,
                   InpTPAtrMult,
                   InpMaxForwardBars,
                   InpRetrainEveryBars))
   {
      Print("Inizializzazione fallita");
      return INIT_FAILED;
   }

   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   delete trader;
}

void OnTick()
{
   trader.Run();
}

void OnTimer()
{
   trader.OnTimer();
}
