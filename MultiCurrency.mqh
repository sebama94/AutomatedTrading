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


   void              Init(const string& symbolName
                          , const int bbPeriod
                          , const double bbDeviation
                          , const int bbBandShift
                          , const int rsiPeriod
                          , const int trainBars
                          , const double overboughtLevel
                          , const double oversoldLevel
                          , const double lotSize );
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

   int               _rsiHandlerM1,  _rsiHandlerM5,_rsiHandlerM10;
   ENUM_TIMEFRAMES   _enumTimeFrames;
   uint              _trainBars;
   bool              _timeOutExpired;
   matrix            _xTrainM5,_xTrainM1 ; //1000 rows 1 column matrix
   vector            _yTrainM5,_yTrainM1 ;  //1000 size vector
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
   int               _rsiPeriod, _bbPeriod;
   int               _bollingerBangsHandleM1,_bollingerBangsHandleM5,_bollingerBangsHandleM10;
   int               _fiDef;
   bool              _timeOutExpiredOpenSell, _timeOutExpiredOpenBuy;
   double            _upperBand, _lowerBand, _middleBand, _bbDeviation;
   int               _bbBandShift;

};

//+------------------------------------------------------------------+
//|
//+------------------------------------------------------------------+
MultiCurrency::MultiCurrency() {};
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MultiCurrency::Init(const string& symbolName
                         , const int bbPeriod
                         , const double bbDeviation
                         , const int bbBandShift
                         , const int rsiPeriod
                         , const int trainBars
                         , const double overboughtLevel
                         , const double oversoldLevel
                         , const double lotSize )
{
   _bbDeviation = bbDeviation;
   _bbPeriod = bbPeriod;
   _rsiPeriod = rsiPeriod;
   _symbolName = symbolName;
   _trainBars = trainBars;
   _bbBandShift = bbBandShift;

   _rsiHandlerM1 = iRSI(_symbolName, PERIOD_M30, _rsiPeriod, PRICE_CLOSE);
   _rsiHandlerM5 = iRSI(_symbolName, PERIOD_H1, _rsiPeriod, PRICE_CLOSE);
   _rsiHandlerM10 = iRSI(_symbolName, PERIOD_H4, _rsiPeriod, PRICE_CLOSE);

// Ottiene i valori delle bande per l'ultimo bar disponibile

   _bollingerBangsHandleM1 = iBands(_symbolName, PERIOD_M30, _bbPeriod, _bbBandShift, _bbDeviation, PRICE_CLOSE);
   _bollingerBangsHandleM5 = iBands(_symbolName, PERIOD_H1, _bbPeriod, _bbBandShift, _bbDeviation, PRICE_CLOSE);
   _bollingerBangsHandleM10 = iBands(_symbolName, PERIOD_H4, _bbPeriod, _bbBandShift, _bbDeviation, PRICE_CLOSE);

   _timeOutExpired=_timeOutExpired;

   _yTrainM5.Init(_trainBars);
   _xTrainM5.Init(_trainBars,1);

   _yTrainM1.Init(_trainBars);
   _xTrainM1.Init(_trainBars,1);


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
   IndicatorRelease(_rsiHandlerM1);
   IndicatorRelease(_bollingerBangsHandleM1);
   IndicatorRelease(_bollingerBangsHandleM5);
   IndicatorRelease(_bollingerBangsHandleM10);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool MultiCurrency::TrainModel()
{
   vector y_closeM1(_trainBars), y_openM1(_trainBars),
          y_closeM5(_trainBars), y_openM5(_trainBars);

   LogReg = CLogisticRegression();
   vector train_predM1, train_predM5, train_predM10, train_predH4;
   vector classes = {0,1};
   double accuracyM1,accuracyM5;
   double            rsiBuffM5[],rsiBuffM1[];
   vector            rsiBuffVecM1(_trainBars),
                     rsiBuffVecM5(_trainBars);

   ArraySetAsSeries(rsiBuffM1,true);
   ArraySetAsSeries(rsiBuffM5,true);

   if(CopyBuffer(_rsiHandlerM5,0,0,_trainBars,rsiBuffM5) <= 0 ||
         CopyBuffer(_rsiHandlerM1,0,0,_trainBars,rsiBuffM1) <= 0)
   {
      Print("Error copying Signal buffer: ", GetLastError());
   }

   rsiBuffVecM5 = _matrixUtils.ArrayToVector(rsiBuffM5);
   rsiBuffVecM1 = _matrixUtils.ArrayToVector(rsiBuffM1);



   _xTrainM5.Col(rsiBuffVecM5,0);
   _xTrainM1.Col(rsiBuffVecM1,0);

   y_closeM1.CopyRates(_symbolName,PERIOD_M1,COPY_RATES_CLOSE,0,_trainBars);
   y_openM1.CopyRates(_symbolName,PERIOD_M1,COPY_RATES_OPEN,0,_trainBars);

   y_closeM5.CopyRates(_symbolName,PERIOD_M5,COPY_RATES_CLOSE,0,_trainBars);
   y_openM5.CopyRates(_symbolName,PERIOD_M5,COPY_RATES_OPEN,0,_trainBars);


   for(ulong i=0; i<_trainBars; i++)
   {
      if(y_closeM5[i] > y_openM5[i])  //bullish = 1
         _yTrainM5[i] = 1;
      else
         _yTrainM5[i] = 0;         // bears = 0
   }

   LogReg.fit(_xTrainM5,_yTrainM5);
   train_predM5 = LogReg.predict(_xTrainM5);
   accuracyM5 = _metrics.accuracy_score(_yTrainM5,train_predM5);
   Print("Trained model Accuracy ",accuracyM5);

   for(ulong i=0; i<_trainBars; i++)
   {
      if(y_closeM1[i] > y_openM1[i])  //bullish = 1
         _yTrainM1[i] = 1;
      else
         _yTrainM1[i] = 0;         // bears = 0
   }

   LogReg.fit(_xTrainM1,_yTrainM1);
   train_predM1 = LogReg.predict(_xTrainM1);
   accuracyM1 = _metrics.accuracy_score(_yTrainM1,train_predM1);
   Print("Trained model Accuracy ",accuracyM1);

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


   double rsiBuffM5[],rsiBuffM1[], rsiBuffM10[];
   vector rsiBuffVecM5, rsiBuffVecM1, rsiBuffVecM10;
//create an array for several prices
   double MiddleBandArrayM1[],MiddleBandArrayM5[],MiddleBandArrayM10[];
   double UpperBandArrayM1[], UpperBandArrayM5[], UpperBandArrayM10[];
   double LowerBandArrayM1[], LowerBandArrayM5[],LowerBandArrayM10[];


   if(timeOutExpired || PositionsTotal()==0 )
   {
      _timeOutExpiredOpenSell= true;
      _timeOutExpiredOpenBuy = true;
   }
   _accountMargin = accountMargin;
   _maxRiskAmount = maxRiskAmount;
   _closeInProfit = closeInProfit;


//sort the price array from the cuurent candle downwards
   ArraySetAsSeries(MiddleBandArrayM1,true);
   ArraySetAsSeries(UpperBandArrayM1,true);
   ArraySetAsSeries(LowerBandArrayM1,true);

   ArraySetAsSeries(MiddleBandArrayM5,true);
   ArraySetAsSeries(UpperBandArrayM5,true);
   ArraySetAsSeries(LowerBandArrayM5,true);

   ArraySetAsSeries(MiddleBandArrayM10,true);
   ArraySetAsSeries(UpperBandArrayM10,true);
   ArraySetAsSeries(LowerBandArrayM10,true);


   ArraySetAsSeries(rsiBuffM1,true);
   ArraySetAsSeries(rsiBuffM5,true);
   ArraySetAsSeries(rsiBuffM10,true);

   if (  CopyBuffer(_rsiHandlerM1,0,0,1,rsiBuffM1)<= 0 ||
         CopyBuffer(_rsiHandlerM5,0,0,1,rsiBuffM5)<= 0  ||
         CopyBuffer(_rsiHandlerM10,0,0,1,rsiBuffM10)<= 0 ||

         CopyBuffer(_bollingerBangsHandleM1,0,0,3,MiddleBandArrayM1)<= 0 ||
         CopyBuffer(_bollingerBangsHandleM1,1,0,3,UpperBandArrayM1)<= 0  ||
         CopyBuffer(_bollingerBangsHandleM1,2,0,3,LowerBandArrayM1)<= 0 ||

         CopyBuffer(_bollingerBangsHandleM5,0,0,3,MiddleBandArrayM5)<= 0 ||
         CopyBuffer(_bollingerBangsHandleM5,1,0,3,UpperBandArrayM5)<= 0  ||
         CopyBuffer(_bollingerBangsHandleM5,2,0,3,LowerBandArrayM5)<= 0  ||

         CopyBuffer(_bollingerBangsHandleM10,0,0,3,MiddleBandArrayM10)<= 0 ||
         CopyBuffer(_bollingerBangsHandleM10,1,0,3,UpperBandArrayM10)<= 0  ||
         CopyBuffer(_bollingerBangsHandleM10,2,0,3,LowerBandArrayM10)<= 0
      )
   {
      Print("Error copying Signal buffer: ", GetLastError());
      return;
   };

//calcualte EA for the cuurent candle
   double MiddleBandValueM1=MiddleBandArrayM1[0];
   double UpperBandValueM1=UpperBandArrayM1[0];
   double LowerBandValueM1=LowerBandArrayM1[0];

   double MiddleBandValueM5=MiddleBandArrayM5[0];
   double UpperBandValueM5=UpperBandArrayM5[0];
   double LowerBandValueM5=LowerBandArrayM5[0];

   double MiddleBandValueM10=MiddleBandArrayM10[0];
   double UpperBandValueM10=UpperBandArrayM10[0];
   double LowerBandValueM10=LowerBandArrayM10[0];

   rsiBuffVecM1 = _matrixUtils.ArrayToVector(rsiBuffM1);
   _xTrainM1.Row(rsiBuffVecM1,0);
   _xTrainM1 = _preProcessing.fit_transform(_xTrainM1);
   int signalM1 = LogReg.predict(_xTrainM1.Row(0));

   rsiBuffVecM5 = _matrixUtils.ArrayToVector(rsiBuffM5);
   _xTrainM5.Row(rsiBuffVecM5,0);
   _xTrainM5 = _preProcessing.fit_transform(_xTrainM5);
   int signalM5 = LogReg.predict(_xTrainM5.Row(0));

//define Ask, Bid
   double Ask = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
   double Bid = NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);

   if(_accountMargin < _maxRiskAmount )
   {
      if(_timeOutExpiredOpenSell &&
         /*   signalM5 != 0 && signalM1!= 0 && */
            rsiBuffM5[0] > _overboughtLevel && rsiBuffM1[0] > _overboughtLevel && rsiBuffM10[0] > _overboughtLevel &&
            Bid>=UpperBandArrayM1[0] && Bid>=UpperBandArrayM5[0] && Bid>=UpperBandArrayM10[0] )
      {
         openSellOrder();
         _timeOutExpiredOpenSell = false;
      }
      else
      {
         if( _timeOutExpiredOpenBuy &&
             /*   signalM5 == 0 && signalM1==0 && */
               rsiBuffM5[0] < _oversoldLevel && rsiBuffM1[0] < _oversoldLevel && rsiBuffM10[0] < _oversoldLevel &&
               Ask<=LowerBandArrayM1[0] && Ask<=LowerBandArrayM5[0] && Ask<=LowerBandArrayM10[0])
         {
            openBuyOrder();
            _timeOutExpiredOpenBuy = false;
         }
      }
   }

 /*   if(timeOutExpired)
   {
      checkAndCloseSingleProfitOrders();
   }*/
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
   
   if(_trade.Buy(_lotSize, _symbolName,Ask,(Bid-1000*_Point),(Bid+150* _Point))) //,NULL))
//   if(_trade.Buy(_lotSize, _symbolName,Ask,0,(Ask+150 * _Point),NULL))
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
   
   if(_trade.Sell(_lotSize, _symbolName,Bid,(Ask+1000*_Point),(Ask-150* _Point)))//,NULL))
      //if(_trade.Sell(_lotSize, _symbolName,Bid,0,(Bid-150 * _Point),NULL))
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
