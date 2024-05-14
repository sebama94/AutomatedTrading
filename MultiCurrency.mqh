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
   void              closeAllPosition();
   int               candlePatterns(double high,double low,double open,double close,double uod,double &xInputs[]);

protected:

   int               _rsiHandler,_rsiHandler_M30, _rsiHandler_H4;
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
   int               _iMACD_handle, _iMACD_handle_M30, _iMACD_handle_H4;
   int               _momentumDef,_stochDef, _momentumDef_M5;
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
                         , const int numOutput
                         , double &weights[] )
{
   _rsiPeriod = rsiPeriod;
   _symbolName = symbolName;

   //_rsiHandler = iRSI(_symbolName,PERIOD_M5, _rsiPeriod, PRICE_CLOSE);
   // _iMACD_handle=iMACD(_symbolName,PERIOD_M5,12,26,9,PRICE_CLOSE);

   _rsiHandler_M30   = iRSI(_symbolName,PERIOD_M10, _rsiPeriod, PRICE_CLOSE);
   _iMACD_handle_M30 = iMACD(_symbolName,PERIOD_M10,12,26,9,PRICE_CLOSE);

// _rsiHandler_H4   = iRSI(_symbolName,PERIOD_M10, _rsiPeriod, PRICE_CLOSE);
   // _iMACD_handle_H4 = iMACD(_symbolName,PERIOD_H4,12,26,9,PRICE_CLOSE);
//_momentumDef_M5 =  iMomentum(_symbolName,PERIOD_M5,14,PRICE_CLOSE);
   _momentumDef =  iMomentum(_symbolName,PERIOD_M10,14,PRICE_CLOSE);
   _stochDef = iStochastic(_symbolName,PERIOD_M10,5,3,3,MODE_SMA,STO_LOWHIGH);


   if( _iMACD_handle==INVALID_HANDLE ||_rsiHandler==INVALID_HANDLE || _volDef==INVALID_HANDLE ||
         _rsiHandler_M30==INVALID_HANDLE || _iMACD_handle_M30 == INVALID_HANDLE || _stochDef == INVALID_HANDLE  || _momentumDef == INVALID_HANDLE)
   {
      //--- no handle obtained, print the error message into the log file, complete handling the error
      Print("Failed to get the indicator handle");
   }

   _dnn.Init(numInput,numHiddenA,numHiddenB, numOutput);
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
   IndicatorRelease(_rsiHandler_M30);
   IndicatorRelease(_iMACD_handle_M30);
   IndicatorRelease(_rsiHandler_H4);
   IndicatorRelease(_iMACD_handle_H4);
   IndicatorRelease(_momentumDef);
   IndicatorRelease(_stochDef);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Run(const double& accountMargin
                        , const double& maxRiskAmount
                        , const double& closeInProfit
                        , bool timeOutExpired)
{
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(_symbolName,PERIOD_M10,1,5,rates);
   double xValueRaw[4];

   double rsiBuff[],volBuff[],iMACD_mainbuf[],iMACD_signalbuf[],volumeRealTime[],
          rsiBuff_M30[],iMACD_mainbuf_M30[],iMACD_signalbuf_M30[],
          rsiBuff_H4[],iMACD_mainbuf_H4[],iMACD_signalbuf_H4[], rsiRealTIme[],
          momentumBuff[], Karray[], Darray[], momentumBuffRealTime[],
          KarrayRealTime[],DarrayRealTime[];

   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;
   _closeInProfit = closeInProfit;

   ArraySetAsSeries(iMACD_mainbuf,true);
   ArraySetAsSeries(iMACD_signalbuf,true);
   ArraySetAsSeries(rsiBuff,true);
   ArraySetAsSeries(volBuff,true);
   ArraySetAsSeries(rsiBuff_M30,true);
   ArraySetAsSeries(iMACD_signalbuf_M30,true);
   ArraySetAsSeries(iMACD_mainbuf_M30,true);
   ArraySetAsSeries(iMACD_signalbuf_H4,true);
   ArraySetAsSeries(iMACD_mainbuf_H4,true);
   ArraySetAsSeries(rsiRealTIme,true);
   ArraySetAsSeries(momentumBuff,true);
   ArraySetAsSeries(Karray, true);
   ArraySetAsSeries(Darray, true);
   ArraySetAsSeries(KarrayRealTime, true);
   ArraySetAsSeries(DarrayRealTime, true);
   ArraySetAsSeries(momentumBuffRealTime,true);

   if (  candlePatterns(rates[0].high,rates[0].low,rates[0].open,rates[0].close,rates[0].close-rates[0].open,xValueRaw) <= 0 ||
         //CopyBuffer(_rsiHandler,0,1,ArraySize(_xValues)/6,rsiBuff)<= 0  ||
         // CopyBuffer(_iMACD_handle,0,1,ArraySize(_xValues)/6,iMACD_mainbuf) <= 0||
         // CopyBuffer(_iMACD_handle,1,1,ArraySize(_xValues)/6,iMACD_signalbuf) <= 0 ||
         CopyBuffer(_rsiHandler_M30,0,1,ArraySize(_xValues)/6,rsiBuff_M30)<= 0 ||
         CopyBuffer(_iMACD_handle_M30,0,1,ArraySize(_xValues)/6,iMACD_mainbuf_M30) <= 0||
         CopyBuffer(_iMACD_handle_M30,1,1,ArraySize(_xValues)/6,iMACD_signalbuf_M30) <= 0 ||
         CopyBuffer(_rsiHandler_M30,0,0,3,rsiRealTIme)<= 0 ||
         // CopyBuffer(_iMACD_handle_H4,0,1,ArraySize(_xValues)/6,iMACD_mainbuf_H4) <= 0||
         // CopyBuffer(_iMACD_handle_H4,1,1,ArraySize(_xValues)/6,iMACD_signalbuf_H4) <= 0 ||
         CopyBuffer(_rsiHandler_M30,0,0,2,rsiRealTIme) <= 0  ||
         CopyBuffer(_momentumDef,0,1,ArraySize(_xValues)/6,momentumBuff) <= 0 ||
         CopyBuffer(_stochDef,0,1,ArraySize(_xValues)/6,Karray) <= 0 ||
         CopyBuffer(_stochDef,1,1,ArraySize(_xValues)/6,Darray) <= 0 ||

         CopyBuffer(_stochDef,0,0,3,KarrayRealTime) <= 0 ||
         CopyBuffer(_stochDef,1,0,3,DarrayRealTime) <= 0
      )
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

   double d1RSI=-1.0;                                 //lower limit of the normalization range
   double d2RSI=1.0;                                 //upper limit of the normalization range

   // double x_minRSI=rsiBuff[ArrayMinimum(rsiBuff)]; //minimum value over the range
   // double x_maxRSI=rsiBuff[ArrayMaximum(rsiBuff)]; //maximum value over the range
   // double diff_min_max_RSI = x_maxRSI-x_minRSI;
   // if( diff_min_max_RSI == 0)
   // {
   //    diff_min_max_RSI=0.000001;
   //    ///Print("error");
   // }

   double x_minRSI_M30=rsiBuff_M30[ArrayMinimum(rsiBuff_M30)]; //minimum value over the range
   double x_maxRSIM30=rsiBuff_M30[ArrayMaximum(rsiBuff_M30)]; //maximum value over the range
   double diff_min_max_RSI_M30 = x_maxRSIM30-x_minRSI_M30;
   if( diff_min_max_RSI_M30 == 0)
   {
      diff_min_max_RSI_M30=0.000001;
      ///Print("error");
   }

   // double x_minRSI_H4=rsiBuff_H4[ArrayMinimum(rsiBuff_H4)]; //minimum value over the range
   // double x_maxRSI_H4=rsiBuff_H4[ArrayMaximum(rsiBuff_H4)]; //maximum value over the range
   // double diff_min_max_RSI_H4 = x_maxRSI_H4-x_minRSI_H4;
   // if( diff_min_max_RSI_H4 == 0)
   // {
   //    diff_min_max_RSI_H4=0.000001;
   //    ///Print("error");
   // }


   double d1MACD=-1.0; //lower limit of the normalization range
   double d2MACD=1.0;  //upper limit of the normalization range
   // double x_minMACD=MathMin(iMACD_mainbuf[ArrayMinimum(iMACD_mainbuf)],iMACD_signalbuf[ArrayMinimum(iMACD_signalbuf)]);
   // double x_maxMACD=MathMax(iMACD_mainbuf[ArrayMaximum(iMACD_mainbuf)],iMACD_signalbuf[ArrayMaximum(iMACD_signalbuf)]);
   double x_minMACD_M30 = MathMin(iMACD_mainbuf_M30[ArrayMinimum(iMACD_mainbuf_M30)],iMACD_signalbuf_M30[ArrayMinimum(iMACD_signalbuf_M30)]);
   double x_maxMACD_M30 = MathMax(iMACD_mainbuf_M30[ArrayMaximum(iMACD_mainbuf_M30)],iMACD_signalbuf_M30[ArrayMaximum(iMACD_signalbuf_M30)]);
   // double x_minMACD_H4 = MathMin(iMACD_mainbuf_H4[ArrayMinimum(iMACD_mainbuf_H4)],iMACD_signalbuf_H4[ArrayMinimum(iMACD_signalbuf_H4)]);
   // double x_maxMACD_H4 = MathMax(iMACD_mainbuf_H4[ArrayMaximum(iMACD_mainbuf_H4)],iMACD_signalbuf_H4[ArrayMaximum(iMACD_signalbuf_H4)]);


   double d1Momenntum = -1.0;
   double d2Momenntum = 1.0;
   double x_minMomentum=momentumBuff[ArrayMinimum(momentumBuff)]; //minimum value over the range
   double x_maxMomentum=momentumBuff[ArrayMaximum(momentumBuff)]; //maximum value over the range
   double diff_min_maxMomentum = x_maxMomentum-x_minMomentum;
   if( diff_min_maxMomentum == 0)
   {
      diff_min_maxMomentum=0.000001;
      ///Print("error");
   }

   double d1Stoch =-1.0; //lower limit of the normalization range
   double d2Stoch =1.0;  //upper limit of the normalization range
   double x_minStoch = MathMin(Karray[ArrayMinimum(Karray)],Darray[ArrayMinimum(Darray)]);
   double x_maxStoch = MathMax(Karray[ArrayMaximum(Karray)],Darray[ArrayMaximum(Darray)]);




   for(int i=0;i<ArraySize(_xValues)/6;i++)
   {
      //_xValues[i*12]=(((iMACD_mainbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      //_xValues[i*12+1]=(((iMACD_signalbuf[i]-x_minMACD)*(d2MACD-d1MACD))/(x_maxMACD-x_minMACD))+d1MACD;
      _xValues[i*6]=(((iMACD_mainbuf_M30[i]-x_minMACD_M30)*(d2MACD-d1MACD))/(x_maxMACD_M30-x_minMACD_M30))+d1MACD;
      _xValues[i*6+1]= (((iMACD_signalbuf_M30[i]-x_minMACD_M30)*(d2MACD-d1MACD))/(x_maxMACD_M30-x_minMACD_M30))+d1MACD;
      //_xValues[i*12+4]=(((iMACD_mainbuf_H4[i]-x_minMACD_H4)*(d2MACD-d1MACD))/(x_maxMACD_H4-x_minMACD_H4))+d1MACD;
      //_xValues[i*12+5]= (((iMACD_signalbuf_H4[i]-x_minMACD_H4)*(d2MACD-d1MACD))/(x_maxMACD_H4-x_minMACD_H4))+d1MACD;12
      //_xValues[i*8+2]=(((rsiBuff[i]-x_minRSI)*(d2RSI-d1RSI))/diff_min_max_RSI)+d1RSI;
      _xValues[i*6+2]=(((rsiBuff_M30[i]-x_minRSI_M30)*(d2RSI-d1RSI))/diff_min_max_RSI_M30)+d1RSI;
      //_xValues[i*8+4]=(((rsiBuff_H4[i]-x_minRSI_H4)*(d2RSI-d1RSI))/diff_min_max_RSI_H4)+d1RSI;
      _xValues[i*6+3]=(((momentumBuff[i]-x_minMomentum)*(d2Momenntum-d1Momenntum))/diff_min_maxMomentum)+d1Momenntum;
      _xValues[i*6+4]=(((Karray[i]-x_minStoch)*(d2Stoch-d1Stoch))/(x_maxStoch-x_minStoch))+d1Stoch;
      _xValues[i*6+5]=(((Darray[i]-x_minStoch)*(d2Stoch-d1Stoch))/(x_maxStoch-x_minStoch))+d1Stoch;
   }
   ArrayInsert(_xValues, xValueRaw, ArraySize(_xValues), 0,WHOLE_ARRAY);

   double yValues[];
   _dnn.ComputeOutputs(_xValues,yValues);

   if(yValues[0] > 0.6 )
   {
      closeBuyPosition();

      if(_accountMargin < _maxRiskAmount && _oldYValue[0] != yValues[0] /* && rsiRealTIme[0] > _overboughtLevel */ &&
            KarrayRealTime[0] > 80 && DarrayRealTime[0] > 80 && KarrayRealTime[0] < DarrayRealTime[0] && Karray[0] > Darray[0] )
      {

         //Print(" Sell - rsiRealTIme_M30[0]  " , rsiRealTIme[0]," momentumBuffRealTime ",momentumBuffRealTime[0] );
         _oldYValue[0] = yValues[0];
         openSellOrder();
      }

   }

   if(yValues[1] > 0.6 )
   {
      closeSellPosition();

      if(_accountMargin < _maxRiskAmount && _oldYValue[1] != yValues[1] /* && rsiRealTIme[0] < _oversoldLevel */ &&
            KarrayRealTime[0] < 20 && DarrayRealTime[0] < 20 && KarrayRealTime[0] > DarrayRealTime[0] && Karray[0] < Darray[0] )
      {
         //Print(" Buy - rsiRealTIme_M30[0]  " , rsiRealTIme[0]," momentumBuffRealTime ",momentumBuffRealTime[0] );
         _oldYValue[1] = yValues[1];
         openBuyOrder();
      }

   }

   checkAndCloseSingleProfitOrders();

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
         if(singleProfit > _closeInProfit )
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

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::closeAllPosition()
{
   closeSellPosition();
   closeBuyPosition();
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int MultiCurrency::candlePatterns(double high,double low,double open,double close,double uod,double &xInputs[])
{
   double p100=high-low;
   double highPer=0;
   double lowPer=0;
   double bodyPer=0;
   double trend=0;

   if(uod>0)
   {
      highPer=high-close;
      lowPer=open-low;
      bodyPer=close-open;
      trend=1;

   }
   else
   {
      highPer=high-open;
      lowPer=close-low;
      bodyPer=open-close;
      trend=0;
   }

   if( p100 == 0 )
   {
      p100 = 0.00001;
   }

   xInputs[0]=highPer/p100;
   xInputs[1]=lowPer/p100;
   xInputs[2]=bodyPer/p100;
   xInputs[3]=trend;

   return(1);

}


#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
