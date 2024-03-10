//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"

#define  TRAIN_BARS 1

input double MaxRiskPercentage = 30; // Max Risk in Percentage [%]]
const int GlobalRsiPeriod = 14;
MultiCurrency usdCurrency;
bool GlobaltimeOutExpired = true;
input double GlobalLotSize = 0.1;
input double GlobaloversoldLevel = 30;
input double GlobaloverboughtLevel =70;

int OnInit()
{
   EventSetTimer(7200); 

   usdCurrency.Init(Symbol(),GlobalRsiPeriod, TRAIN_BARS, GlobaloverboughtLevel, GlobaloversoldLevel, GlobalLotSize);
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
   double closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01;
   //Run(const double& accountMargin, const double& maxRiskAmount, const double& closeInProfit,bool timeOutExpired)

   usdCurrency.Run(accountMargin, maxRiskAmount, closeInProfit, GlobaltimeOutExpired);
   GlobaltimeOutExpired = false;
   
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   GlobaltimeOutExpired = true;
   
}