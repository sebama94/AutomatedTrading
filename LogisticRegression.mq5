//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"

#define  TRAIN_BARS 500

input double MaxRiskPercentage = 20; // Max Risk in Percentage [%]]
const int rsiPeriod = 14;
bool timeOutExpired = false;
MultiCurrency usdCurrency;

int OnInit()
{
   EventSetTimer(60);
   usdCurrency.Init("EURUSD",rsiPeriod, TRAIN_BARS);
   usdCurrency.TrainModel();

   return(INIT_SUCCEEDED);

}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- destroy timer
   EventKillTimer();
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
   //Run(const double& accountMargin, const double& maxRiskAmount, const double& closeInProfit,bool timeOutExpired)

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