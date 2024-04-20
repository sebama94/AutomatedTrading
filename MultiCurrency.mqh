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
#include <Trade\Trade.mqh> //Instatiate Trades Execution Library
#include <Trade\OrderInfo.mqh> //Instatiate Library for Orders Information
#include <Trade\PositionInfo.mqh> //Instatiate Library for Positions Information
#include <..\example\DeepNeuralNetwork.mqh>

#define SIZEI 30
#define SIZEA 10
#define SIZEB 6
#define SIZEC 3
#define SIZEO 2  // New layer size

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MultiCurrency
{
public:
                     MultiCurrency();
                    ~MultiCurrency();


   void              Init(const string& symbolName
                          , const int rsiPeriod
                          , const double overboughtLevel
                          , const double oversoldLevel
                          , const double lotSize
                          , const int numInput
                          , const int numHiddenA
                          , const int numHiddenB
                          , const int numHiddenC
                          , const int numOutput
                          , double &weights[] );

   void              Run(const double& accountMargin,
                         const double& maxRiskAmount,
                         const double& closeInProfit,
                         bool timeOutExpired);


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

   int               _rsiHandlerM1,  _rsiHandlerM5,_rsiHandlerM10;
   ENUM_TIMEFRAMES   _enumTimeFrames;
   uint              _trainBars;
   bool              _timeOutExpired;
   double            _maxRiskAmount;
   string            _symbolName;
   double            _lotSize;
   double            _maxRiskPercentage; // Maximum percentage of balance to use
   double            _overboughtLevel;
   double            _oversoldLevel;
   double            _closeInProfit;
   CTrade            _trade;
   CPositionInfo     _myPositionInfo;
   COrderInfo        _orderInfo;
   DeepNeuralNetwork _dnn;
   double            _accountMargin;
   int               _rsiPeriod, _bbPeriod;
   int               _fiDef;
   bool              _timeOutExpiredOpenSell, _timeOutExpiredOpenBuy;
   double            _upperBand, _lowerBand, _middleBand, _bbDeviation;
   int               _bbBandShift;
   int               _iMACD_handle;
   double            _iMACD_mainbuf[];   // dynamic array for storing indicator values
   double            _iMACD_signalbuf[]; // dynamic array for storing indicator values
   double            _weight[];
   double            _out;
   double            _xValues[SIZEI];        // array for storing inputs

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
                         , const double overboughtLevel
                         , const double oversoldLevel
                         , const double lotSize
                         , const int numInput
                         , const int numHiddenA
                         , const int numHiddenB
                         , const int numHiddenC
                         , const int numOutput
                         , double &weights[] )
{
   _rsiPeriod = rsiPeriod;
   _symbolName = symbolName;

   _rsiHandlerM5 = iRSI(_symbolName, PERIOD_H4, _rsiPeriod, PRICE_CLOSE);
   _iMACD_handle=iMACD(_symbolName,PERIOD_H4,12,26,9,PRICE_CLOSE);
   if( _iMACD_handle==INVALID_HANDLE ||_rsiHandlerM5==INVALID_HANDLE )
   {
      //--- no handle obtained, print the error message into the log file, complete handling the error
      Print("Failed to get the indicator handle");
   }

   _dnn.Init(numInput,numHiddenA,numHiddenB,numHiddenC, numOutput);
   _dnn.SetWeights(weights);
   _timeOutExpired=_timeOutExpired;

   _overboughtLevel = overboughtLevel;
   _oversoldLevel = oversoldLevel;
   _lotSize = lotSize;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MultiCurrency::~MultiCurrency()
{
   IndicatorRelease(_rsiHandlerM5);
   IndicatorRelease(_iMACD_handle);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Run(const double& accountMargin
                        , const double& maxRiskAmount
                        , const double& closeInProfit
                        , bool timeOutExpired)
{


   double rsiBuffM5[];
   vector rsiBuffVecM5;


   if(timeOutExpired || PositionsTotal()==0 )
   {
      _timeOutExpiredOpenSell= true;
      _timeOutExpiredOpenBuy = true;
      
   }
   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;
   _closeInProfit = closeInProfit;

   ArraySetAsSeries(_iMACD_mainbuf,true);
   ArraySetAsSeries(_iMACD_signalbuf,true);

   ArraySetAsSeries(rsiBuffM5,true);

   if (  CopyBuffer(_rsiHandlerM5,0,1,ArraySize(_xValues)/3,rsiBuffM5)<= 0  ||
         CopyBuffer(_iMACD_handle,0,2,ArraySize(_xValues)/3,_iMACD_mainbuf) <= 0||
         CopyBuffer(_iMACD_handle,1,2,ArraySize(_xValues)/3,_iMACD_signalbuf) <= 0
      )
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

   double d1RSI=0.0;                                 //lower limit of the normalization range
   double d2RSI=1.0;                                 //upper limit of the normalization range
   double x_minRSI=rsiBuffM5[ArrayMinimum(rsiBuffM5)]; //minimum value over the range
   double x_maxRSI=rsiBuffM5[ArrayMaximum(rsiBuffM5)]; //maximum value over the range

   double d1MACD=-1.0; //lower limit of the normalization range
   double d2MACD=1.0;  //upper limit of the normalization range
//--- minimum value over the range
   double x_minMACD=MathMin(_iMACD_mainbuf[ArrayMinimum(_iMACD_mainbuf)],_iMACD_signalbuf[ArrayMinimum(_iMACD_signalbuf)]);
//--- maximum value over the range
   double x_maxMACD=MathMax(_iMACD_mainbuf[ArrayMaximum(_iMACD_mainbuf)],_iMACD_signalbuf[ArrayMaximum(_iMACD_signalbuf)]);
   for(int i=0;i<ArraySize(_xValues)/3;i++)
   {
      _xValues[i*3]=(((_iMACD_mainbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      _xValues[i*3+1]=(((_iMACD_signalbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      _xValues[i*3+2]=(((rsiBuffM5[i]-x_minRSI)*(d2RSI-d1RSI))/(x_maxRSI-x_minRSI))+d1RSI;
   }

   double yValues[];
   _dnn.ComputeOutputs(_xValues,yValues);

   //Print("yValues[0]: ", yValues[0], " yValues[1]: ", yValues[1]);

//define Ask, Bid
   double Ask = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);

   if(_accountMargin < _maxRiskAmount )
   {
      if(_timeOutExpiredOpenSell && yValues[0] > 0.8)
      {
         openSellOrder();
         _timeOutExpiredOpenSell = false;
      }
         
      if( _timeOutExpiredOpenBuy && yValues[1] > 0.8 )
      {
            openBuyOrder();
            _timeOutExpiredOpenBuy = false;
      }
   }

//   if( yValues[2] > 0.6 )
//   {
//       checkAndCloseProfitableOrders();
//       _timeOutExpiredOpenBuy = false;
//       _timeOutExpiredOpenSell = false;
//   }
// 

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
         Print("Garabage collector active!");
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
   double Bid=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);

   //if(_trade.Buy(_lotSize, _symbolName,Ask,(Bid-200*_Point),(Bid+150* _Point))) //,NULL))
   if(_trade.Buy(_lotSize, _symbolName,Ask,(Bid-close_loss*_Point),(Bid+close* _Point)))
//   if(_trade.Buy(_lotSize, _symbolName,Ask,0,(Ask+300 * _Point)))
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
   double Ask=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);

//    if(_trade.Sell(_lotSize, _symbolName,Bid,(Ask+200*_Point),(Ask-150* _Point)))//,NULL))
   if(_trade.Sell(_lotSize, _symbolName,Bid,(Ask+close_loss*_Point),(Ask-close* _Point)))
//   if(_trade.Sell(_lotSize, _symbolName,Bid,0,(Bid-300 * _Point)))
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
