//+------------------------------------------------------------------+
//|                                                        trial.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#property strict

// Input parameters
input int fastEMA = 12;
input int slowEMA = 26;
input int signalSMA = 9;
input int rsiPeriod = 14;
input double overboughtLevel = 75.0;
input double oversoldLevel = 25.0;
input double lotSize = 0.1;
input double MaxRiskPercentage = 20.0; // Maximum percentage of balance to use
input double closeInProfit = 1.00;
// input 
double closeInProfitSingleOrder = 5.00;

#include <Trade\Trade.mqh>
CTrade  trade;
CPositionInfo  my_position;     // position info object
uint start_now=0, last_start_now=0, timeCheckSinglePosition=0;
// Indicator handles
int macdHandle, rsiHandle;
double maxRiskAmount;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create timer
   EventSetTimer(60);
// Initialize MACD and RSI indicator handles

//macdHandle = iMACD(NULL,PERIOD_M1, fastEMA, slowEMA, signalSMA, PRICE_CLOSE);
// rsiHandle = iRSI(NULL, PERIOD_M1, rsiPeriod, PRICE_CLOSE);
   macdHandle = iMACD(NULL,PERIOD_M5, fastEMA, slowEMA, signalSMA, PRICE_CLOSE);
   rsiHandle = iRSI(NULL, PERIOD_M5, rsiPeriod, PRICE_CLOSE);
//---
   maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (MaxRiskPercentage / 100.0);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   IndicatorRelease(macdHandle);
   IndicatorRelease(rsiHandle);
//--- destroy timer
   EventKillTimer();

}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   CheckAndCloseProfitableOrders();

   double macdMain[], macdSignal[], rsiValue[];
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);

   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   ArraySetAsSeries(rsiValue, true);

// Get the latest values of MACD and its signal line, and RSI
   if(CopyBuffer(macdHandle, 0, 0, 3, macdMain) <= 0 || CopyBuffer(macdHandle, 1, 0, 3, macdSignal) <= 0 || CopyBuffer(rsiHandle, 0, 0, 1, rsiValue) <= 0)
   {
      Print("Failed to get data");
      return; // Failed to get data
   }

  // Print("rsiValue[0] ", rsiValue[0] ,"  < oversoldLevel ", oversoldLevel, " && macdMain[0] ", macdMain[0], " > macdSignal[0] ",macdSignal[0]  );
  // Print("rsiValue[0] ", rsiValue[0] ,"  > oversoldLevel ", oversoldLevel, " && macdMain[0] ", macdMain[0], " < macdSignal[0] ",macdSignal[0]  );
   if(accountMargin < maxRiskAmount )//&& (start_now - last_start_now) > 100 )
   {
      if( rsiValue[0] < oversoldLevel && macdMain[0] > macdSignal[0] )
      {

         OpenBuyOrder();
      }
      else if( rsiValue[0] > overboughtLevel && macdMain[0] < macdSignal[0])
      {

         OpenSellOrder();
      }
   }

//  CheckAndCloseSingleProfitOrders();
}

//+------------------------------------------------------------------+
//| Open Buy Order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   if(trade.Buy(lotSize, _Symbol))
   {
      Print("Buy order placed.");
   }
   else
   {
      Print("Buy order failed: ", GetLastError());
   }
}


//+------------------------------------------------------------------+
//| Open Sell Order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   if(trade.Sell(lotSize, _Symbol))
   {
      Print("Sell order placed.");
   }
   else
   {
      Print("Sell order failed: ", GetLastError());
   }
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
//---

}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
//---

}
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
//---

}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseOrderPosition()
{
   for(int i=PositionsTotal()-1; i >= 0; i--)
   {
      if(my_position.SelectByIndex(i))
      {
         ulong ticket = my_position.Ticket();
         if(!trade.PositionClose(ticket))
         {
            Print("Error closing buy order: ");
         }
         else
         {
            Print("CloseBuyOrder with ticket: ", ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double ProfitAllPositions(void)
{
   double profit=0.0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(my_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         //      if(my_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
      {
         profit+=my_position.Commission()+my_position.Swap()+my_position.Profit();
      }
   }
   return(profit);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAndCloseSingleProfitOrders()
{
   double singleProfit = 0.0;
   for(int i=PositionsTotal()-1; i >=0; i--)
   {
      if(my_position.SelectByIndex(i))
      {
         singleProfit=my_position.Commission()+my_position.Swap()+my_position.Profit();
         if(singleProfit > closeInProfitSingleOrder)
         {
            if(my_position.SelectByIndex(i))
            {
               ulong ticket;
               ticket = my_position.Ticket();
               if(!trade.PositionClose(ticket))
               {
                  Print("Error closing sell order: ");
               }
               else
               {
                  Print("CloseSellOrder with ticket: ", ticket);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAndCloseProfitableOrders()
{
   if(PositionSelect(Symbol()) && ProfitAllPositions() > closeInProfit)   // If there is at least one position for this symbol
   {
      CloseOrderPosition();
   }
}

//+------------------------------------------------------------------+
