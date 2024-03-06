//+------------------------------------------------------------------+
//|                                           MultiCurrencyClass.mqh |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"

//#ifdef __MultiCurrency__
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
                     Multicurrency(string _stringName, int rsi_period);
                     MultiCurrency();

protected:
   //void              Init();
   void              Run();
   bool              trainModel();
   CTrade            trade;
   CLogisticRegression Log_reg;
   MatrixExtend      matrix_utils;
   Metrics           metrics;
   StandardizationScaler pre_processing;
   CPositionInfo     my_position;
   COrderInfo        order;

private:
   double            _rsiHandler[];
   ENUM_TIMEFRAMES   _enumTimeFrames;
   const uint        _trainBars;
   bool&             _timeOutExpired;
   matrix            _xTrain; //1000 rows 1 column matrix
   vector            _yTrain;   //1000 size vector
   double            _maxRiskAmount;
   double            _rsiBuff[];
   vector            _rsiBuffVec;
   string            _symbolName
   double            _lotSize;
    double maxRiskPercentage; // Maximum percentage of balance to use
 double overboughtLevel = 70;
 double oversoldLevel = 30.0;
 double closeInProfit = 5.00;

};

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Multicurrency::Multicurrency(string stringName, int rsi_period, const int trainBars) 
{
   _rsi_period = rsi_period;
   _stringName = stringName;
   _xTrain(_trainBars);
   _yTrain(_trainBars);

}

Multicurrency::~Multicurrency() 
{
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
Multicurrency::trainModel()
{
   vector y_close(_trainBars), y_open(_trainBars);
   Log_reg = CLogisticRegression();
   vector train_pred;
   vector classes = {0,1};
   double accuracy;
   
   _rsi_handle = iRSI(_symbolName,PERIOD_M5,rsi_period,PRICE_CLOSE);
   CopyBuffer(_rsi_handle,0,0,_trainBars,_rsi_buff);
   _rsi_buff_v = matrix_utils.ArrayToVector(_rsi_buff); 
   _xtrain.Col(_rsi_buff_v,0);
   y_close.CopyRates(_symbolName,PERIOD_M1,COPY_RATES_CLOSE,0,_trainBars);
   y_open.CopyRates(_symbolName,PERIOD_M1,COPY_RATES_OPEN,0,_trainBars);
   for(ulong i=0; i<_trainBars; i++)
   {
      if(y_close[i] > y_open[i])  //bullish = 1
         _ytrain[i] = 1;
      else
         _ytrain[i] = 0;         // bears = 0
   }
   Comment("Corr Coeff---> ", _rsi_buff_v.CorrCoef(y_close));
   Log_reg.fit(xtrain,ytrain);
   train_pred = Log_reg.predict(xtrain);
   accuracy = metrics.accuracy_score(ytrain,train_pred);
   Print("Trained model Accuracy ",accuracy);
}


 //  _maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (MaxRiskPercentage / 100.0);
  // _closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.001;




//+------------------------------------------------------------------+

#endif