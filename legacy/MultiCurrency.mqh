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
#include <Generic\HashMap.mqh>


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class MultiCurrency
{
public:
   MultiCurrency();
   ~MultiCurrency();


   void              Init(const string& symbolName
                          , const double closeProfit
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
   CHashMap<ulong, double> previousProfits;
protected:

   int               _rsiHandler_H4,_rsiHandler_M30;
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
   int               _iMACD_handle_H4, _iMACD_handle_M30;
   int               _bollingerBands_M30,_stochDef_H4, _momentumDef_M5, _stochDef_M30;
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
                         , const double closeProfit
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

   _rsiHandler_H4    = iRSI(_symbolName,PERIOD_M30, 14, PRICE_CLOSE);
   _iMACD_handle_H4  = iMACD(_symbolName,PERIOD_M30,12,26,9,PRICE_CLOSE);
   _stochDef_H4      = iStochastic(_symbolName,PERIOD_M30,5,3,3,MODE_SMA,STO_LOWHIGH);

   _rsiHandler_M30   = iRSI(_symbolName,PERIOD_M30, 14, PRICE_CLOSE);
   _stochDef_M30     = iStochastic(_symbolName,PERIOD_M30,5,3,3,MODE_SMA,STO_LOWHIGH);

   _bollingerBands_M30 = iBands(_symbolName,PERIOD_M30,20,0,2,PRICE_CLOSE);

   if( _rsiHandler_H4==INVALID_HANDLE || _volDef==INVALID_HANDLE ||
         _rsiHandler_M30==INVALID_HANDLE || _iMACD_handle_M30 == INVALID_HANDLE ||
         _stochDef_H4 == INVALID_HANDLE  || _bollingerBands_M30 == INVALID_HANDLE )
   {
      //--- no handle obtained, print the error message into the log file, complete handling the error
      Print("Failed to get the indicator handle");
   }

   _dnn.Init(numInput,numHiddenA,numHiddenB, numOutput);
   _dnn.SetWeights(weights);
   _timeOutExpired=_timeOutExpired;
   _closeInProfit = closeProfit;

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
   IndicatorRelease(_rsiHandler_H4);
   IndicatorRelease(_iMACD_handle_H4);
   IndicatorRelease(_rsiHandler_M30);
   IndicatorRelease(_iMACD_handle_M30);
   IndicatorRelease(_stochDef_H4);

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Run(const double& accountMargin
                        , const double& maxRiskAmount
                        , bool timeOutExpired)
{

   double xValueRaw[4];

   double iMACD_mainbuf_H4[],iMACD_signalbuf_H4[],
          rsiBuff_H4[],iMACD_mainbuf_M30[],iMACD_signalbuf_M30[], rsiRealTime_M30[],
          Karray_H4[], Darray_H4[],
          KarrayRealTime_M30[],DarrayRealTime_M30[];

   double MiddleBandArray[];
   double UpperBandArray[];
   double LowerBandArray[];


   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;

   ArraySetAsSeries(iMACD_mainbuf_H4,true);
   ArraySetAsSeries(iMACD_signalbuf_H4,true);
   ArraySetAsSeries(rsiBuff_H4,true);
   ArraySetAsSeries(iMACD_signalbuf_M30,true);
   ArraySetAsSeries(iMACD_mainbuf_M30,true);
   ArraySetAsSeries(iMACD_signalbuf_H4,true);
   ArraySetAsSeries(iMACD_mainbuf_H4,true);
   ArraySetAsSeries(rsiRealTime_M30,true);
   ArraySetAsSeries(Karray_H4, true);
   ArraySetAsSeries(Darray_H4, true);
   ArraySetAsSeries(KarrayRealTime_M30, true);
   ArraySetAsSeries(DarrayRealTime_M30, true);
   ArraySetAsSeries(MiddleBandArray,true);
   ArraySetAsSeries(UpperBandArray,true);
   ArraySetAsSeries(LowerBandArray,true);

   if (  CopyBuffer(_iMACD_handle_H4,0,1,ArraySize(_xValues)/5,iMACD_mainbuf_H4) <= 0||
         CopyBuffer(_iMACD_handle_H4,1,1,ArraySize(_xValues)/5,iMACD_signalbuf_H4) <= 0 ||
         CopyBuffer(_rsiHandler_H4,0,1,ArraySize(_xValues)/5,rsiBuff_H4)<= 0 ||
         CopyBuffer(_stochDef_H4,0,1,ArraySize(_xValues)/5,Karray_H4) <= 0 ||
         CopyBuffer(_stochDef_H4,1,1,ArraySize(_xValues)/5,Darray_H4) <= 0 ||

         CopyBuffer(_stochDef_M30,0,0,3,KarrayRealTime_M30) <= 0 ||
         CopyBuffer(_rsiHandler_M30,0,0,3,rsiRealTime_M30)<= 0 ||
         CopyBuffer(_stochDef_M30,1,0,3,DarrayRealTime_M30) <= 0 ||

         CopyBuffer(_bollingerBands_M30,0,0,3,MiddleBandArray) <= 0 ||
         CopyBuffer(_bollingerBands_M30,1,0,3,UpperBandArray) <= 0 ||
         CopyBuffer(_bollingerBands_M30,2,0,3,LowerBandArray) <= 0 
      )
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

   double d1RSI=-1.0;                                 //lower limit of the normalization range
   double d2RSI=1.0;                                 //upper limit of the normalization range
   double x_minRSI_H4=rsiBuff_H4[ArrayMinimum(rsiBuff_H4)]; //minimum value over the range
   double x_maxRSI_H4=rsiBuff_H4[ArrayMaximum(rsiBuff_H4)]; //maximum value over the range
   double diff_min_max_RSI_H4 = x_maxRSI_H4-x_minRSI_H4;
   if( diff_min_max_RSI_H4 == 0)
   {
      diff_min_max_RSI_H4=0.000001;
   }


   double d1MACD=-1.0; //lower limit of the normalization range
   double d2MACD=1.0;  //upper limit of the normalization range
   double x_minMACD_H4 = MathMin(iMACD_mainbuf_H4[ArrayMinimum(iMACD_mainbuf_H4)],iMACD_signalbuf_H4[ArrayMinimum(iMACD_signalbuf_H4)]);
   double x_maxMACD_H4 = MathMax(iMACD_mainbuf_H4[ArrayMaximum(iMACD_mainbuf_H4)],iMACD_signalbuf_H4[ArrayMaximum(iMACD_signalbuf_H4)]);


   double d1Stoch =-1.0; //lower limit of the normalization range
   double d2Stoch =1.0;  //upper limit of the normalization range
   double x_minStoch_H4 = MathMin(Karray_H4[ArrayMinimum(Karray_H4)],Darray_H4[ArrayMinimum(Darray_H4)]);
   double x_maxStoch_H4 = MathMax(Karray_H4[ArrayMaximum(Karray_H4)],Darray_H4[ArrayMaximum(Darray_H4)]);

   for(int i=0;i<ArraySize(_xValues)/5;i++)
   {
      _xValues[i*5]=(((iMACD_mainbuf_H4[i]-x_minMACD_H4)*(d2MACD-d1MACD))/(x_maxMACD_H4-x_minMACD_H4))+d1MACD;
      _xValues[i*5+1]= (((iMACD_mainbuf_H4[i]-x_minMACD_H4)*(d2MACD-d1MACD))/(x_maxMACD_H4-x_minMACD_H4))+d1MACD;
      _xValues[i*5+2]=(((rsiBuff_H4[i]-x_minRSI_H4)*(d2RSI-d1RSI))/diff_min_max_RSI_H4)+d1RSI;
      _xValues[i*5+3]=(((Karray_H4[i]-x_minStoch_H4)*(d2Stoch-d1Stoch))/(x_maxStoch_H4-x_minStoch_H4))+d1Stoch;
      _xValues[i*5+4]=(((Darray_H4[i]-x_minStoch_H4)*(d2Stoch-d1Stoch))/(x_maxStoch_H4-x_minStoch_H4))+d1Stoch;
   }


   double yValues[];
   _dnn.ComputeOutputs(_xValues,yValues);
   // Print("SymbolName: ", _symbolName, " Values[0]: ",yValues[0], " yValues[1]: ",yValues[1], " yValues[2]: ", yValues[2]);
   // Print(KarrayRealTime_M30[0], " > 80  && " ,DarrayRealTime_M30[0] ," > 80 && ", KarrayRealTime_M30[0] ," < ",DarrayRealTime_M30[0] ," && ", Karray_H4[0] ," > ", Darray_H4[0]);


   double Ask = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);
   double MiddleBandValue=MiddleBandArray[0];
   double UpperBandValue=UpperBandArray[0];
   double LowerBandValue=LowerBandArray[0];

   if(yValues[0] > 0.6 &&
         _accountMargin < _maxRiskAmount && _oldYValue[0] != yValues[0]  && rsiRealTime_M30[0] > _overboughtLevel  &&
         KarrayRealTime_M30[0] > 80 && DarrayRealTime_M30[0] > 80 && KarrayRealTime_M30[0] < DarrayRealTime_M30[0] && KarrayRealTime_M30[1] > DarrayRealTime_M30[1] && Bid>=UpperBandArray[0]
         //  && VolArray[0] > VolArray[1]
     )
   {

      //Print(" Sell - rsiRealTIme_M30[0]  " , rsiRealTime_M30[0]," momentumBuffRealTime ",momentumBuffRealTime[0] );
      _oldYValue[0] = yValues[0];
      openSellOrder();

   }



   if(yValues[1] > 0.6 && _accountMargin < _maxRiskAmount && _oldYValue[1] != yValues[1]  && rsiRealTime_M30[0] < _oversoldLevel  &&
         KarrayRealTime_M30[0] < 20 && DarrayRealTime_M30[0] < 20 && KarrayRealTime_M30[0] > DarrayRealTime_M30[0] && KarrayRealTime_M30[1] < DarrayRealTime_M30[1]  && Ask<=LowerBandArray[0]
         //&& VolArray[0] > VolArray[1]
     )
   {
      //Print(" Buy - rsiRealTIme_M30[0]  " , rsiRealTime_M30[0]," momentumBuffRealTime ",momentumBuffRealTime[0] );
      _oldYValue[1] = yValues[1];
      openBuyOrder();

   }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
   if(yValues[2] > 0.7 )
   {
      closeAllPosition();
   }

   if(!checkAndCloseSingleProfitOrders())
   {
      Print("Error in checkAndCloseSingleProfitOrders()");
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

         ulong ticket = _myPositionInfo.Ticket();
         double previousProfit = 0.0;
         if(previousProfits.ContainsKey(ticket))
         {
            if(!previousProfits.TryGetValue(ticket,previousProfit))
            {
               Print("Error in previousProfit.TryGetValue - Ticket: ", ticket);
               return false;
            }
         }
         else
         {
            if(!previousProfits.Add(ticket, previousProfit))
            {
               Print("Error in previousProfits.Add(ticket, previousProfit) - ticket: ", ticket, " previousProfit: ", previousProfit);
               return false;
            }
         }
         singleProfit=_myPositionInfo.Commission()+_myPositionInfo.Swap()+_myPositionInfo.Profit();
         //Print("ticket: ", ticket," singleProfit < previousProfit: ", singleProfit," < ",previousProfit );
         if(singleProfit > _closeInProfit && singleProfit < previousProfit-3 )
         {
            Print("ticket: ", ticket," singleProfit < previousProfit: ", singleProfit," < ",previousProfit-3 );
            if (_trade.PositionClose(ticket))
            {
               previousProfits.Remove(ticket); // Rimuove il profitto precedente
            }
            else
            {
               Print("Error closing sell order: ", _trade.ResultRetcode());
               return false;
            }
         }
         else
         {
             if(!previousProfits.TrySetValue(ticket, singleProfit))
             {
                Print("Error in previousProfits.TrySetValue" );
                return false;
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
            previousProfits.Remove(ticket);
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
            previousProfits.Remove(ticket);
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


#endif
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
