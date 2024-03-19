//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"

#define  TRAIN_BARS 5

double MaxRiskPercentage = 20; // Max Risk in Percentage [%]]
const int GlobalRsiPeriod = 14;
MultiCurrency eurUsdCurrency;
MultiCurrency gbpUsdCurrency;
bool GlobaltimeOutExpired = true;
double GlobalLotSize = 0.1;

double GlobaloversoldLevel = 29;
double GlobaloverboughtLevel = 71;

const int GlobalBBPeriod = 20;
const double GlobalBBDeviation = 2;
const int GlobalBBShift = 0;
/*
void MultiCurrency::Init(const string& symbolName
                         , const int bbPeriod
                         , const double bbDeviation
                         , const int bbBandShift
                         , const int rsiPeriod
                         , const int trainBars
                         , const double overboughtLevel
                         , const double oversoldLevel
                         , const double lotSize )
*/

int OnInit()
{
   EventSetTimer(7200); 

   eurUsdCurrency.Init(Symbol(),GlobalBBPeriod,GlobalBBDeviation,GlobalBBShift,GlobalRsiPeriod, TRAIN_BARS, GlobaloverboughtLevel, GlobaloversoldLevel, GlobalLotSize);
   eurUsdCurrency.TrainModel();
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

   eurUsdCurrency.Run(accountMargin, maxRiskAmount, closeInProfit, GlobaltimeOutExpired);
   GlobaltimeOutExpired = false;
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   GlobaltimeOutExpired = true;
   
}