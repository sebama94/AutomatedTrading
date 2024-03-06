//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <..\Libraries\MALE5\Linear Models\Logistic Regression.mqh>
#include <..\Libraries\MALE5\MatrixExtend.mqh>
#include <..\Libraries\MALE5\metrics.mqh>
#include <..\Libraries\MALE5\preprocessing.mqh>
#include <Trade\Trade.mqh> //Instatiate Trades Execution Library
#include <Trade\OrderInfo.mqh> //Instatiate Library for Orders Information
#include <Trade\PositionInfo.mqh> //Instatiate Library for Positions Information


#define  TRAIN_BARS 50000 //The total number of bars we want to train our model

CTrade         trade;        // trading object
CLogisticRegression Log_reg;
MatrixExtend matrix_utils;
Metrics metrics;
StandardizationScaler pre_processing;
//RobustScaler pre_processing;
CPositionInfo  my_position;     // position info object
COrderInfo     order;        // order info object
//CArrayLong     arr_tickets;  // array tickets

double lotSize = 0.1;
input double MaxRiskPercentage = 20.0; // Maximum percentage of balance to use
//input
double overboughtLevel = 70.0;
//input
double oversoldLevel = 30.0;
//input
double closeInProfit;
//input
int rsi_period = 13;
bool timeOutExpired = true;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
matrix xtrain(TRAIN_BARS,1); //1000 rows 1 column matrix
vector ytrain(TRAIN_BARS);   //1000 size vector
double maxRiskAmount;

double rsi_buff[];
vector rsi_buff_v(TRAIN_BARS);
int rsi_handle=0,macdHandle=0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
//--- create timer
   EventSetTimer(60);
//---Tra
//-- collecting the data
//time_start= GetTickCount();
// last_time_start = time_start + 6000;
// macdHandle = iMACD(Symbol(), 0, fastEMA, slowEMA, signalSMA, PRICE_CLOSE);
   rsi_handle = iRSI(Symbol(),PERIOD_M5,rsi_period,PRICE_CLOSE);
//rsi_handle =macdHandle;

   CopyBuffer(rsi_handle,0,0,TRAIN_BARS,rsi_buff); //get rsi values
   rsi_buff_v = matrix_utils.ArrayToVector(rsi_buff); //store the rsi values to a vector
   xtrain.Col(rsi_buff_v,0); //store that vector into a first and only column in the x matrix
   vector y_close(TRAIN_BARS), y_open(TRAIN_BARS);
   y_close.CopyRates(Symbol(),PERIOD_M1,COPY_RATES_CLOSE,0,TRAIN_BARS); //copy the closing prices into a y vector
   y_open.CopyRates(Symbol(),PERIOD_M1,COPY_RATES_OPEN,0,TRAIN_BARS);

   for(ulong i=0; i<TRAIN_BARS; i++)
   {
      if(y_close[i] > y_open[i])  //bullish = 1
         ytrain[i] = 1;
      else
         ytrain[i] = 0;
   }

//---

   Comment("Corr Coeff---> ",rsi_buff_v.CorrCoef(y_close));

   Log_reg = new CLogisticRegression();//(xtrain,ytrain); //Train the Linear model
   Log_reg.fit(xtrain,ytrain);
   vector train_pred = Log_reg.predict(xtrain);
//vector train_pred = Log_reg.LogregModelPred(xtrain);

   vector classes = {0,1};

   double accuracy = metrics.accuracy_score(ytrain,train_pred);//,classes,true);

   Print("Trained model Accuracy ",accuracy);
//---
   maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (MaxRiskPercentage / 100.0);
   closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.001;
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
//---

// Calculate the maximum amount to risk
   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
// Determine the amount already at risk
//   double currentRiskAmount = CalculateCurrentRisk();
// Amount you plan to risk with the new position
//   double newPositionRisk = CalculatePositionRisk();

   ArraySetAsSeries(rsi_buff,true);
   CopyBuffer(rsi_handle,0,0,1,rsi_buff); //get rsi values

   rsi_buff_v = matrix_utils.ArrayToVector(rsi_buff);
   xtrain.Row(rsi_buff_v,0);
   pre_processing.fit_transform(xtrain);

   int signal = (int)Log_reg.predict(rsi_buff_v);

//predict the next price using the CURRENT/RECENT RSI INDICATOR READINGS/VALUE
//double totalRisk = currentRiskAmount + newPositionRisk;
   if(accountMargin < maxRiskAmount && timeOutExpired ) //&& (start_now - last_start_now) > 1000)
   {
      // Print("signal  ", signal);
      if(signal != 0 && rsi_buff[0] > overboughtLevel)
      {
         //Print("Open a sell trade!");
         OpenSellOrder();

      }
      else
      {
         if(rsi_buff[0] < oversoldLevel )
         {
            //Print("Open a buy trade!");
            //Open a buy trade
            OpenBuyOrder();

         }
      }
      timeOutExpired = false;
   }
   CheckAndCloseSingleProfitOrders();
   CheckAndCloseProfitableOrders();
   
   


}
//+------------------------------------------------------------------+
//| Profit all positions                                             |
//+------------------------------------------------------------------+
void CheckAndCloseSingleProfitOrders()
{
   double singleProfit = 0.0;
   for(int i=PositionsTotal()-1; i >=0; i--)
   {
      if(my_position.SelectByIndex(i))
      {
         singleProfit=my_position.Commission()+my_position.Swap()+my_position.Profit();
         if(singleProfit > closeInProfit)
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
//| Profit all positions                                             |
//+------------------------------------------------------------------+
double ProfitAllPositions(void)
{
   double profit=0.0;

   for(int i=PositionsTotal()-1; i>=0; i--)
      if(my_position.SelectByIndex(i)) // selects the position by index for further access to its properties
         //      if(my_position.Symbol()==m_symbol.Name() && m_position.Magic()==InpMagic)
         profit+=my_position.Commission()+my_position.Swap()+my_position.Profit();
//---
   return(profit);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CheckAndCloseProfitableOrders()
{
   if(PositionSelect(Symbol())) // If there is at least one position for this symbol
   {
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = 0.0;
      double profit = 0.0;

      if(ProfitAllPositions() > closeInProfit)
      {

         // Assuming CloseSellOrder and CloseBuyOrder are functions defined to close orders correctly
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            CloseSellPosition(); // Your function to close sell order
         }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            CloseBuyPosition(); // Your function to close buy order
         }
      }
   }
   /*   else
        {
         Print("No open positions for ", Symbol());
        }
   */
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
//---
   Print("Running...");
   timeOutExpired = true;
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
//| Tester function                                                  |
//+------------------------------------------------------------------+
double OnTester()
{
//---
   double ret=0.0;
//---

//---
   return(ret);
}
//+------------------------------------------------------------------+
//| TesterInit function                                              |
//+------------------------------------------------------------------+
void OnTesterInit()
{
//---

}
//+------------------------------------------------------------------+
//| TesterPass function                                              |
//+------------------------------------------------------------------+
void OnTesterPass()
{
//---

}
//+------------------------------------------------------------------+
//| TesterDeinit function                                            |
//+------------------------------------------------------------------+
void OnTesterDeinit()
{
//---

}
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
//---

}
//+------------------------------------------------------------------+
//| BookEvent function                                               |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
//---

}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OpenPos()
{

   Print("PositionsTotal(): ", PositionsTotal());
   int total=PositionsTotal();
   int count=0;
   for(int cnt=0; cnt<=total; cnt++)
   {
      if(PositionSelect(Symbol()))
      {
         if(PositionGetInteger(POSITION_MAGIC)==0)
         {
            count++;
         }
      }
   }

   return(count);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateCurrentRisk()
{
// Implement logic to calculate the total amount at risk in open positions
// This could be based on margin used, or a calculation of potential loss based on stop-loss levels, etc.
   double totalRisk = 0.0;

   Print("OrdersTotal: ", OrdersTotal());

// Example: Sum of margins for all open positions
   for(int i = 0; i < OpenPos(); i++)
   {
      if(OrderGetTicket(i)>0 && OrderGetString(ORDER_SYMBOL) == Symbol())
      {
         totalRisk += AccountInfoDouble(ACCOUNT_MARGIN);
         // Print("Total Risk: ",totalRisk );
      }
   }

   return totalRisk;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculatePositionRisk()
{
// Implement logic to calculate the risk of the new position you plan to open
// This could include the margin required for the position, or a calculation based on your entry and stop-loss price
   double risk = 0.0;

// Example calculation here

   return risk;
}
//+------------------------------------------------------------------+
//| Open Buy Order                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
   MqlTradeRequest request;
   MqlTradeResult result;

   request.action = TRADE_ACTION_DEAL; // Immediate execution
   request.symbol = Symbol(); // Current symbol
   request.volume = lotSize; // Volume defined in input parameters
   request.type = ORDER_TYPE_BUY; // Order type
   request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK); // Current Ask price
   request.sl = 0; // Stop loss level (0 means no stop loss)
   request.tp = 0; // Take profit level (0 means no take profit)
   request.deviation = 20; // Maximum price deviation in points
   request.magic = 0; // Magic number to identify your orders
   request.comment = "Buy order opened"; // Comment

   if(!OrderSend(request, result))
      Print("Error opening buy order: ", result.comment);
}


//+------------------------------------------------------------------+
//| Open Sell Order                                                  |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
   MqlTradeRequest request;
   MqlTradeResult result;

   request.action = TRADE_ACTION_DEAL;
   request.symbol = Symbol();
   request.volume = lotSize;
   request.type = ORDER_TYPE_SELL;
   request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID); // Current Bid price
   request.sl = 0;
   request.tp = 0;
   request.deviation = 20;
   request.magic = 0;
   request.comment = "Sell order opened";

   if(!OrderSend(request, result))
      Print("Error opening sell order: ", result.comment);
}

//+------------------------------------------------------------------+
//| Close Buy Order                                                  |
//+------------------------------------------------------------------+
void CloseBuyPosition()
{
   for(int i=PositionsTotal()-1; i >= 0; i--)
   {
      if(my_position.SelectByIndex(i) && PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_BUY && PositionGetString(POSITION_SYMBOL) == Symbol())
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
//| Close Sell Order                                                 |
//+------------------------------------------------------------------+
void CloseSellPosition()
{
   for(int i=PositionsTotal()-1; i >= 0; i--)
   {
      if(my_position.SelectByIndex(i) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&  PositionGetString(POSITION_SYMBOL) == Symbol())
      {
         ulong ticket;
         ticket = my_position.Ticket();

         if(!trade.PositionClose(ticket)) // OrderSend(request, result))
            Print("Error closing sell order: ");
         else
         {
            Print("CloseSellOrder with ticket: ", ticket);
         }
         // Exit after the first match
      }
   }
}
//+------------------------------------------------------------------+
