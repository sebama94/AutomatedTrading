//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"

#define  TRAIN_BARS 50000 //The total number of bars we want to train our model

const double rsiPeriod = 14;
bool timeOutExpired = false;
Multicurrency usdCurrency;

int OnInit()
{
   EventSetTimer(60);
   usdCurrency.Init("EURUSD",rsiPeriod, TRAIN_BARS, timeOutExpired);
   usdCurrency.trainModel();

   return(INIT_SUCCEEDED);

}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- destroy timer
   EventKillTimer();
   IndicatorRelease(rsi_handle);
//IndicatorRelease(macdHandle);
// delete(Log_reg);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (MaxRiskPercentage / 100.0);
   double closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.001;
   
   usdCurrency.Run(accountMargin, maxRiskAmount, closeInProfit);
   
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   Print("Running...");
   timeOutExpired = true;
}