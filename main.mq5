//+------------------------------------------------------------------+
//|                                                         main.mq5 |
//|                     ML Trading System v3.0                       |
//|                                                                  |
//| Architettura:                                                     |
//|   FeatureEngine  → 76 feature da M30 + H1 + H4 + tempo          |
//|   NeuralNetwork  → 76→128→64→32→2 con Adam + early stopping      |
//|   RiskManager    → ATR sizing + drawdown + daily loss circuit     |
//|   OrderManager   → spread/sessione filter + trailing stop ATR    |
//+------------------------------------------------------------------+
#property copyright "2024"
#property version   "3.00"
#property strict

#include "src/MLTrader.mqh"

//=== PARAMETRI TRADING ===
input string   InpSymbol        = "EURUSD";  // Simbolo
input ulong    InpMagic         = 20240001;  // Magic number EA

//=== PARAMETRI TRAINING ===
input int      InpEpochs        = 500;       // Epoche di training
input int      InpTrainSamples  = 2000;      // Campioni di training
input double   InpLearningRate  = 0.001;     // Learning rate Adam
input int      InpEarlyStopping = 50;        // Patience early stopping

//=== RISK MANAGEMENT ===
input double   InpRiskPerTrade  = 0.01;      // Rischio per trade (1% del balance)
input double   InpMaxDailyLoss  = 0.03;      // Perdita max giornaliera (3%)
input double   InpMaxDrawdown   = 0.10;      // Drawdown max circuit breaker (10%)

//=== ESECUZIONE ===
input double   InpMaxSpreadPips = 2.0;       // Spread massimo in pips
input double   InpCloseProfitUSD = 10.0;     // Chiudi posizione a profitto ($)
input int      InpMaxPositions  = 3;         // Posizioni simultanee massime

//=== TIMER ===
input int      InpTimeoutMinutes = 30;       // Minuti tra un trade e l'altro per direzione

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
                   InpEarlyStopping))
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
