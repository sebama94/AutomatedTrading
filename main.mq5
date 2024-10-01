//+------------------------------------------------------------------+
//|                                                        main.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "Currency.mqh"

// Input parameters
//input 
int InpInputNeurons = 6;     // Number of input neurons (features)
int InpHiddenNeurons1 = 64;   // Number of neurons in first hidden layer
int InpHiddenNeurons2 = 32;   // Number of neurons in second hidden layer
int InpHiddenNeurons3 = 16;   // Number of neurons in second hidden layer
int InpHiddenNeurons4 = 8;   // Number of neurons in second hidden layer
int InpHiddenNeurons5 = 8;   // Number of neurons in second hidden layer
int InpHiddenNeurons6 = 5;   // Number of neurons in second hidden layer
int InpOutputNeurons = 1;     // Number of output neurons (trading decisions)
int InpTrainingEpochs = 1000; // Number of training epochs
double InpLearningRate = 0.01; // Learning rate for the neural network
int InpNumberOfData = 1000;
//int InpBatchSize = 2;        // Batch size for training
//input 
string InpSymbolName = "EURUSD";
//input 
double InpLotSize = 0.1;
//input 
double InpCloseInProfit = 5.0;

bool GlobaltimeOutExpiredBuy = true;
bool GlobaltimeOutExpiredSell = true;
double MaxRiskPercentage = 0.2;
// Global variables
Currency *currency;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(60*30);
   int layers[] = {InpInputNeurons, InpHiddenNeurons1,InpHiddenNeurons2,InpHiddenNeurons3, InpHiddenNeurons4, InpOutputNeurons};
   int numLayers = ArraySize(layers);
   
   currency = new Currency(layers, numLayers, InpTrainingEpochs, InpLearningRate,
                           InpSymbolName, InpLotSize, InpCloseInProfit, InpNumberOfData);
  
   if (!currency.Init())
   {
      Print("Failed to initialize Currency");
      return INIT_FAILED;
   }

   Print("Currency initialization completed.");

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   delete currency;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * MaxRiskPercentage;
   currency.Run(accountMargin, maxRiskAmount);

}
//+------------------------------------------------------------------+
void OnTimer()
{
   //Print("Alive Symbol: ", Symbol());
   GlobaltimeOutExpiredBuy = true;
   GlobaltimeOutExpiredSell = true;
}