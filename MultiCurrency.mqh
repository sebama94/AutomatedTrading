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
#include <..\DeepNeuralNetwork.mqh>

#define SIZEI 16
#define SIZEA 12
#define SIZEB 8
#define SIZEC 5
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
   bool              checkAndCloseAllOrdersForProfit();
   double            profitAllPositions();
   int               openPosition();
   double            calculateCurrentRisk();
   bool              openBuyOrder();
   bool              openSellOrder();
   void              closeBuyPosition();
   void              closeSellPosition();
   int               openPos();


protected:

   int               _rsiHandlerM1,  _rsiHandler,_rsiHandlerM10;
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
   int               _rsiPeriod;
   int               _volDef;
   bool              _timeOutExpiredOpenSell, _timeOutExpiredOpenBuy;
   int               _iMACD_handle;
   double            iMACD_mainbuf[];   // dynamic array for storing indicator values
   double            iMACD_signalbuf[]; // dynamic array for storing indicator values
   double            _weight[];
   double            _out;
   double            _xValues[SIZEI];        // array for storing inputs
   int               _volumeDef;
   double            _oldYValue[2];

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

   _rsiHandler = iRSI(_symbolName, PERIOD_H4, _rsiPeriod, PRICE_CLOSE);
   _iMACD_handle=iMACD(_symbolName,PERIOD_H4,12,26,9,PRICE_CLOSE);
   _volDef=iVolumes(_symbolName,PERIOD_H4,VOLUME_TICK);

   if( _iMACD_handle==INVALID_HANDLE ||_rsiHandler==INVALID_HANDLE || _volDef==INVALID_HANDLE )
   {
      //--- no handle obtained, print the error message into the log file, complete handling the error
      Print("Failed to get the indicator handle");
   }

   _dnn.Init(numInput,numHiddenA,numHiddenB, numHiddenC, numOutput);
   _dnn.SetWeights(weights);
   _timeOutExpired=_timeOutExpired;

   _overboughtLevel = overboughtLevel;
   _oversoldLevel = oversoldLevel;
   _lotSize = lotSize;
   _oldYValue[0] = 0.0;
   _oldYValue[1] = 0.0;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
MultiCurrency::~MultiCurrency()
{
   IndicatorRelease(_rsiHandler);
   IndicatorRelease(_iMACD_handle);
   IndicatorRelease(_volumeDef);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Run(const double& accountMargin
                        , const double& maxRiskAmount
                        , const double& closeInProfit
                        , bool timeOutExpired)
{


   double rsiBuff[],volBuff[],iMACD_mainbuf[],iMACD_signalbuf[];

   if(timeOutExpired || PositionsTotal()==0 )
   {
      _timeOutExpiredOpenSell= true;
      _timeOutExpiredOpenBuy = true;

   }
   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;
   _closeInProfit = closeInProfit;

   ArraySetAsSeries(iMACD_mainbuf,true);
   ArraySetAsSeries(iMACD_signalbuf,true);
   ArraySetAsSeries(rsiBuff,true);
   ArraySetAsSeries(volBuff,true);


   if (  CopyBuffer(_rsiHandler,0,1,ArraySize(_xValues)/4,rsiBuff)<= 0  ||
         CopyBuffer(_iMACD_handle,0,1,ArraySize(_xValues)/4,iMACD_mainbuf) <= 0||
         CopyBuffer(_iMACD_handle,1,1,ArraySize(_xValues)/4,iMACD_signalbuf) <= 0 ||
         CopyBuffer(_volDef,0,1,ArraySize(_xValues)/4,volBuff) <= 0
      )
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

   double d1RSI=-1.0;                                 //lower limit of the normalization range
   double d2RSI=1.0;                                 //upper limit of the normalization range
   double x_minRSI=rsiBuff[ArrayMinimum(rsiBuff)]; //minimum value over the range
   double x_maxRSI=rsiBuff[ArrayMaximum(rsiBuff)]; //maximum value over the range
   double diff_min_max_RSI = x_maxRSI-x_minRSI;
   if( diff_min_max_RSI == 0)
   {
      diff_min_max_RSI=0.000001;
      ///Print("error");
   }

   double d1Vol=-1.0;                                 //lower limit of the normalization range
   double d2Vol=1.0;                                 //upper limit of the normalization range
   double x_minVol=volBuff[ArrayMinimum(volBuff)]; //minimum value over the range
   double x_maxVol=volBuff[ArrayMaximum(volBuff)]; //maximum value over the range
   double diff_min_max_Vol = x_maxVol-x_minVol;
   if( diff_min_max_Vol == 0)
   {
      diff_min_max_Vol=0.000001;
      ///Print("error");
   }


   double d1MACD=-1.0; //lower limit of the normalization range
   double d2MACD=1.0;  //upper limit of the normalization range
//--- minimum value over the range
   double x_minMACD=MathMin(iMACD_mainbuf[ArrayMinimum(iMACD_mainbuf)],iMACD_signalbuf[ArrayMinimum(iMACD_signalbuf)]);
//--- maximum value over the range
   double x_maxMACD=MathMax(iMACD_mainbuf[ArrayMaximum(iMACD_mainbuf)],iMACD_signalbuf[ArrayMaximum(iMACD_signalbuf)]);
   for(int i=0;i<ArraySize(_xValues)/4;i++)
   {
      _xValues[i*4]=(((iMACD_mainbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      _xValues[i*4+1]=(((iMACD_signalbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      _xValues[i*4+2]=(((rsiBuff[i]-x_minRSI)*(d2RSI-d1RSI))/diff_min_max_RSI)+d1RSI;
      _xValues[i*4+3]=(((volBuff[i]-x_minVol)*(d2Vol-d1Vol))/diff_min_max_Vol)+d1Vol;
   }

   double yValues[];
   _dnn.ComputeOutputs(_xValues,yValues);

 Print("yValues[0]: ", yValues[0], " yValues[1]: ", yValues[1]);//, " yValues[2]: ", yValues[2]);



   if(yValues[0] > 0.91)// && rsiBuff[0] > _overboughtLevel && volBuff[1] > volBuff[0])
   {
      closeBuyPosition();
      if(_accountMargin < _maxRiskAmount && _oldYValue[0] != yValues[0] ) // && _timeOutExpiredOpenSell )
      {
         _oldYValue[0] = yValues[0];
         openSellOrder();
      }
   }
   else
   {
      if(yValues[1] > 0.91) // && rsiBuff[0] < _oversoldLevel && volBuff[1] > volBuff[0])
      {
         closeSellPosition();
         if(_accountMargin < _maxRiskAmount && _oldYValue[1] != yValues[1])// && _timeOutExpiredOpenBuy )
         {
            _oldYValue[1] = yValues[1];
            openBuyOrder();
         }
      }
   }
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
bool MultiCurrency::checkAndCloseAllOrdersForProfit()
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
//Print("PositionsTotal(): ", PositionsTotal());
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
//if(_trade.Buy(_lotSize, _symbolName,Ask))
//if(_trade.Buy(_lotSize, _symbolName,Ask,(Bid-close_loss*_Point),(Bid+close* _Point)))
//if(_trade.Buy(_lotSize, _symbolName,Ask,(Bid-close_loss*_Point)))
   if(_trade.Buy(_lotSize, _symbolName))
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
//if(_trade.Sell(_lotSize, _symbolName,Bid))
//if(_trade.Sell(_lotSize, _symbolName,Bid,(Ask+close_loss*_Point),(Ask-close* _Point)))
//if(_trade.Sell(_lotSize, _symbolName,Bid,0,(Bid-1500 * _Point)))
   if(_trade.Sell(_lotSize, _symbolName))
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

//+------------------------------------------------------------------+
