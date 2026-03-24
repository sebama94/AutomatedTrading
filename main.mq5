//+------------------------------------------------------------------+
//|                                                         main.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "2.00"

#include "Currency.mqh"

//--- Network architecture
//    inputNeurons DEVE essere divisibile per 6 (features per bar)
//    Ex: 30 = 5 lookback bars * 6 features
input int    InpInputNeurons   = 30;   // Input neurons (multiplo di 6)
input int    InpHiddenNeurons1 = 64;   // Hidden layer 1
input int    InpHiddenNeurons2 = 32;   // Hidden layer 2
input int    InpHiddenNeurons3 = 16;   // Hidden layer 3
input int    InpOutputNeurons  = 2;    // Output neurons: [Buy, Sell]

//--- Training
input int    InpTrainingEpochs = 500;   // Epoche di training
input double InpLearningRate   = 0.001; // Learning rate
input int    InpNumberOfData   = 2000;  // Campioni di training

//--- Trading
input string InpSymbolName     = "EURUSD"; // Simbolo
input double InpLotSize        = 0.01;     // Lotto
input double InpStopLoss       = 50;       // Stop Loss in punti (0 = disabilitato)
input double InpTakeProfit     = 100;      // Take Profit in punti (0 = disabilitato)
input double InpCloseInProfit  = 5.0;      // Chiudi posizione a profitto ($)
input double InpMaxRiskPct     = 0.02;     // Rischio max (frazione del balance, es. 0.02 = 2%)
input int    InpMaxPositions   = 3;        // Posizioni aperte massime simultanee

bool GlobaltimeOutExpiredBuy  = true;
bool GlobaltimeOutExpiredSell = true;

Currency *currency;

int OnInit()
{
   EventSetTimer(60 * 30); // resetta il timeout ogni 30 minuti

   if(InpInputNeurons % 6 != 0)
   {
      Print("Errore: InpInputNeurons (", InpInputNeurons, ") deve essere divisibile per 6");
      return INIT_PARAMETERS_INCORRECT;
   }

   int layers[]  = {InpInputNeurons, InpHiddenNeurons1, InpHiddenNeurons2, InpHiddenNeurons3, InpOutputNeurons};
   int numLayers = ArraySize(layers);

   currency = new Currency(layers, numLayers,
                           InpTrainingEpochs, InpLearningRate,
                           InpSymbolName, InpLotSize,
                           InpCloseInProfit, InpNumberOfData,
                           InpStopLoss, InpTakeProfit, InpMaxPositions);

   if(!currency.Init())
   {
      Print("Inizializzazione Currency fallita");
      return INIT_FAILED;
   }

   Print("Inizializzazione completata con successo.");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   delete currency;
}

void OnTick()
{
   double maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * InpMaxRiskPct;
   currency.Run(maxRiskAmount);
}

void OnTimer()
{
   GlobaltimeOutExpiredBuy  = true;
   GlobaltimeOutExpiredSell = true;
}
