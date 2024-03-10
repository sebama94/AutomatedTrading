//+------------------------------------------------------------------+
//|                                           MultiCurrencyClass.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

#ifndef  __MultiCurrency__
#define  __MultiCurrency__

//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

#include <..\Libraries\MALE5\Linear Models\Logistic Regression.mqh>
#include <..\Libraries\MALE5\MatrixExtend.mqh>
#include <..\Libraries\MALE5\metrics.mqh>
#include <..\Libraries\MALE5\preprocessing.mqh>
#include <Trade\Trade.mqh> //Instatiate Trades Execution Library
#include <Trade\OrderInfo.mqh> //Instatiate Library for Orders Information
#include <Trade\PositionInfo.mqh> //Instatiate Library for Positions Information
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MultiCurrency
{
public:
                     MultiCurrency();
                    ~MultiCurrency();


   void              Init(const string& symbolName,
                          const int rsiPeriod,
                          const int trainBars,
                          const double overboughtLevel,
                          const double oversoldLevel,
                          const double lotSize);
   void              Run(const double& accountMargin,
                         const double& maxRiskAmount,
                         const double& closeInProfit,
                         bool timeOutExpired);
   bool              TrainModel();

private:



   bool              checkAndCloseSingleProfitOrders();
   bool              checkAndCloseProfitableOrders();
   double            profitAllPositions();
   int               openPosition();
   double            calculateCurrentRisk();
   bool              openBuyOrder();
   bool              openSellOrder();
   void              closeBuyPosition();
   void              closeSellPosition();
   int               openPos();


protected:

   int               _rsiHandler;
   ENUM_TIMEFRAMES   _enumTimeFrames;
   uint              _trainBars;
   bool              _timeOutExpired;
   matrix            _xTrain; //1000 rows 1 column matrix
   vector            _yTrain;   //1000 size vector
   double            _maxRiskAmount;
   string            _symbolName;
   double            _lotSize;
   double            _maxRiskPercentage; // Maximum percentage of balance to use
   double            _overboughtLevel;
   double            _oversoldLevel;
   double            _closeInProfit;
   CTrade            _trade;
   CLogisticRegression LogReg;
   MatrixExtend      _matrixUtils;
   Metrics           _metrics;
   StandardizationScaler _preProcessing;
   CPositionInfo     _myPositionInfo;
   COrderInfo        _orderInfo;
   double            _accountMargin;
   int               _rsiPeriod;
   int               _macdHandle;
   int               _fiDef;
   bool              _timeOutExpiredOpenSell, _timeOutExpiredOpenBuy;

};

//+------------------------------------------------------------------+
//|
//+------------------------------------------------------------------+
MultiCurrency::MultiCurrency() {};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Init(const string& symbolName
                         , const int rsiPeriod
                         , const int trainBars
                         , const double overboughtLevel
                         , const double oversoldLevel
                         , const double lotSize )
{
   int fastEMA = 12;
   int slowEMA = 26;
   int signalSMA = 9;

   _rsiPeriod = rsiPeriod;
   _symbolName = symbolName;
   _trainBars = trainBars;
   _rsiHandler = iRSI(_symbolName, PERIOD_M30, _rsiPeriod, PRICE_CLOSE);
//_fiDef = iForce(_symbolName,PERIOD_M5,_rsiPeriod,MODE_EMA,VOLUME_TICK);
   _timeOutExpired=_timeOutExpired;
   _yTrain.Init(_trainBars);
   _xTrain.Init(_trainBars,1);
   _overboughtLevel = overboughtLevel;
   _oversoldLevel = oversoldLevel;
   _lotSize = lotSize;
//_macdHandle = iMACD(NULL,PERIOD_M5, fastEMA, slowEMA, signalSMA, PRICE_CLOSE);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MultiCurrency::~MultiCurrency()
{
   IndicatorRelease(_rsiHandler);
//IndicatorRelease(_macdHandle);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MultiCurrency::TrainModel()
{
   vector y_close(_trainBars), y_open(_trainBars);
   LogReg = CLogisticRegression();
   vector train_pred;
   vector classes = {0,1};
   double accuracy;
   double            rsiBuff[];
   vector            rsiBuffVec(_trainBars);
   ArraySetAsSeries(rsiBuff,true);
   if(CopyBuffer(_rsiHandler,0,0,_trainBars,rsiBuff) <= 0)
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return false;
   }

   rsiBuffVec = _matrixUtils.ArrayToVector(rsiBuff);
   _xTrain.Col(rsiBuffVec,0);
   y_close.CopyRates(_symbolName,PERIOD_M5,COPY_RATES_CLOSE,0,_trainBars);
   y_open.CopyRates(_symbolName,PERIOD_M5,COPY_RATES_OPEN,0,_trainBars);
   for(ulong i=0; i<_trainBars; i++)
   {
      if(y_close[i] > y_open[i])  //bullish = 1
         _yTrain[i] = 1;
      else
         _yTrain[i] = 0;         // bears = 0
   }
   Comment("Corr Coeff---> ", rsiBuffVec.CorrCoef(y_close));
   LogReg.fit(_xTrain,_yTrain);
   train_pred = LogReg.predict(_xTrain);
   accuracy = _metrics.accuracy_score(_yTrain,train_pred);
   Print("Trained model Accuracy ",accuracy);
   return true;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Run(const double& accountMargin
                        , const double& maxRiskAmount
                        , const double& closeInProfit
                        , bool timeOutExpired)
{

   if(timeOutExpired || PositionsTotal()==0 )
   {
      _timeOutExpiredOpenSell= true;
      _timeOutExpiredOpenBuy = true;
   }
   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;
   _closeInProfit = closeInProfit;
   double            rsiBuff[];
   vector rsiBuffVec;
   ArraySetAsSeries(rsiBuff,true);

   if (CopyBuffer(_rsiHandler,0,0,1,rsiBuff)<= 0)
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

   rsiBuffVec = _matrixUtils.ArrayToVector(rsiBuff);
   _xTrain.Col(rsiBuffVec,0);
   _xTrain = _preProcessing.fit_transform(_xTrain);


   LogReg.fit(_xTrain, _yTrain);
   int signal = LogReg.predict(_xTrain.Row(0));

   if(_accountMargin < _maxRiskAmount )
   {
      if(signal != 0 &&  rsiBuffVec[0] > _overboughtLevel && _timeOutExpiredOpenSell  )//&&*/ fiVal > 0) //&& fastMA[0] > macdSignal[0])
      {
         openSellOrder();
         _timeOutExpiredOpenSell = false;
      }
      else
      {
         if(rsiBuffVec[0] < _oversoldLevel && _timeOutExpiredOpenBuy )// && fiVal < 0)// && fastMA[0]) // > macdSignal[0])
         {
            openBuyOrder();
            _timeOutExpiredOpenBuy = false;
         }
      }
   }
   if(timeOutExpired)
   {
      checkAndCloseSingleProfitOrders();
   }
// checkAndCloseProfitableOrders();

}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MultiCurrency::checkAndCloseSingleProfitOrders()
{
   double singleProfit = 0.0;
   for(int i=PositionsTotal()-1; i >=0; i--)
   {
      if(_myPositionInfo.SelectByIndex(i))
      {
         singleProfit=_myPositionInfo.Commission()+_myPositionInfo.Swap()+_myPositionInfo.Profit();
         if(singleProfit > _closeInProfit)
         {
            if(_myPositionInfo.SelectByIndex(i))
            {
               ulong ticket;
               ticket = _myPositionInfo.Ticket();
               if(!_trade.PositionClose(ticket))
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
   return true;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MultiCurrency::profitAllPositions()
{
   double profit=0.0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(_myPositionInfo.SelectByIndex(i))
      {
         profit+=_myPositionInfo.Commission()+_myPositionInfo.Swap()+_myPositionInfo.Profit();
      }
   }
   return(profit);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MultiCurrency::checkAndCloseProfitableOrders()
{
   if(PositionSelect(_symbolName)) // If there is at least one position for this symbol
   {
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentPrice = 0.0;
      double profit = 0.0;

      if(profitAllPositions() > _closeInProfit)
      {

         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            closeSellPosition();
         }
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         {
            closeBuyPosition();
         }
         return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int MultiCurrency::openPos()
{
   Print("PositionsTotal(): ", PositionsTotal());
   int total=PositionsTotal();
   int count=0;
   for(int cnt=0; cnt<=total; cnt++)
   {
      if(PositionSelect(_symbolName))
      {
         count++;
      }
   }
   return(count);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double MultiCurrency::calculateCurrentRisk()
{
// Implement logic to calculate the total amount at risk in open positions
// This could be based on margin used, or a calculation of potential loss based on stop-loss levels, etc.
   double totalRisk = 0.0;

   Print("OrdersTotal: ", OrdersTotal());

// Example: Sum of margins for all open positions
   for(int i = 0; i < openPos(); i++)
   {
      if(OrderGetTicket(i)>0 && OrderGetString(ORDER_SYMBOL) == _symbolName)
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
bool MultiCurrency::openBuyOrder()
{
   double Ask=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
// if(_trade.Buy(_lotSize, _symbolName,Ask,(Ask-200*_Point),(Ask+150 * _Point),NULL))
   if(_trade.Buy(_lotSize, _symbolName,Ask,0,(Ask+150 * _Point),NULL))
   {
      Print("Buy order placed.");
      return true;
   }
   else
   {
      Print("Buy order failed: ", GetLastError());
      return false;
   }
   return false;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MultiCurrency::openSellOrder()
{
   double Bid=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);
// if(_trade.Sell(_lotSize, _symbolName,Bid,(Bid+200*_Point),(Bid-150 * _Point),NULL))
   if(_trade.Sell(_lotSize, _symbolName,Bid,0,(Bid-150 * _Point),NULL))
   {
      Print("Sell order placed.");
      return true;
   }
   else
   {
      Print("Sell order failed: ", GetLastError());
      return false;
   }
   return false;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::closeBuyPosition()
{
   for(int i=PositionsTotal()-1; i >= 0; i--)
   {
      if(_myPositionInfo.SelectByIndex(i) && PositionGetInteger(POSITION_TYPE) == ORDER_TYPE_BUY && PositionGetString(POSITION_SYMBOL) == _symbolName)
      {
         ulong ticket = _myPositionInfo.Ticket();
         if(!_trade.PositionClose(ticket))
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
void MultiCurrency::closeSellPosition()
{
   for(int i=PositionsTotal()-1; i >= 0; i--)
   {
      if(_myPositionInfo.SelectByIndex(i) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&  PositionGetString(POSITION_SYMBOL) == _symbolName)
      {
         ulong ticket;
         ticket = _myPositionInfo.Ticket();

         if(!_trade.PositionClose(ticket)) // OrderSend(request, result))
            Print("Error closing sell order: ");
         else
         {
            Print("CloseSellOrder with ticket: ", ticket);
         }
         // Exit after the first match
      }
   }
}

#endif
//+------------------------------------------------------------------+
