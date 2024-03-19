//+------------------------------------------------------------------+
//|                                           Self Trained NN EA.mq5 |
//|                                    Copyright 2022, Fxalgebra.com |
//|                        https://www.mql5.com/en/users/omegajoctan |
//+------------------------------------------------------------------+
#property copyright "Copyright 2022, Fxalgebra.com"
#property link      "https://www.mql5.com/en/users/omegajoctan"
#property version   "1.00"

#include <..\Libraries\MALE5\Regressor Networks\selftrain NN.mqh>
#include <..\Libraries\MALE5\matrix_utils.mqh>
#include <..\Libraries\MALE5\metrics.mqh>
#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

CTrade m_trade;
CPositionInfo m_position;

CMetrics metrics;
CRegNeuralNets *nn;
CMatrixutils matrix_utils;

#define  MAGIC_NUMBER 230220231235

input string symbol_x = "Apple_Inc_(AAPL.O)"; 
input string symbol_x2 = "Tesco_(TSCO.L)";

input ENUM_COPY_RATES copy_rates_x = COPY_RATES_OPEN;  
input int n_samples = 100; 

bool train_nn = false;

//---

input group "TRADE PARAMS"
input int      slippage = 100;
input double   stop_loss = 2;
input double   take_profit = 1.5;
//---
double Lots, spread;
int stops_level;
double target_gap =0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {  
//---
   
   m_trade.SetDeviationInPoints(slippage);
   m_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   m_trade.SetTypeFillingBySymbol(Symbol());
   m_trade.SetMarginMode();
   
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

   delete (nn);
   train_nn = false;
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
     if (!train_nn)
       TrainNetwork(); //Train the network only once
     train_nn = true; 
     
     vector x1, x2;
     
     x1.CopyRates(symbol_x,PERIOD_CURRENT,copy_rates_x,0,1);
     x2.CopyRates(symbol_x2,PERIOD_CURRENT,copy_rates_x,0,1);
     
     vector inputs = {x1[0], x2[0]};
     
     matrix OUT = nn.ForwardPass(inputs);
     
     double pred = OUT[0][0];
     
     Comment("pred ",OUT);
     
     stops_level = (int)SymbolInfoInteger(Symbol(),SYMBOL_TRADE_STOPS_LEVEL);
     Lots = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
     spread = (double)SymbolInfoInteger(Symbol(), SYMBOL_SPREAD);
     
     MqlTick ticks;
     SymbolInfoTick(Symbol(), ticks);
     
     if (MathAbs(pred - ticks.ask) + spread > stops_level)
        {
          if (pred > ticks.ask && !PosExist(POSITION_TYPE_BUY))
            {
               target_gap  = pred - ticks.bid;
               
               m_trade.Buy(Lots, Symbol(), ticks.ask, ticks.bid - ((target_gap*stop_loss) * Point()) , ticks.bid + ((target_gap*take_profit) * Point()),"Self Train NN | Buy");
            }
         
          if (pred < ticks.bid && !PosExist(POSITION_TYPE_SELL))
            {
               target_gap = ticks.ask - pred;
               
               m_trade.Sell(Lots, Symbol(), ticks.bid, ticks.ask + ((target_gap*stop_loss) * Point()), ticks.ask - ((target_gap*take_profit) * Point()), "Self Train NN | Sell");
            }
          
        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void TrainNetwork()
 {
   matrix Matrix(n_samples,3); vector y_vector;
   vector x_vector; 
   
   x_vector.CopyRates(symbol_x,PERIOD_CURRENT,copy_rates_x,0,n_samples);
   Matrix.Col(x_vector, 0); 
   x_vector.CopyRates(symbol_x2, PERIOD_CURRENT,copy_rates_x,0,n_samples);
   Matrix.Col(x_vector, 1); 
   
   y_vector.CopyRates(Symbol(), PERIOD_CURRENT,COPY_RATES_CLOSE,0,n_samples);
   Matrix.Col(y_vector, 2);
   
//---

   matrix x_train, x_test; vector y_train, y_test;
   
   matrix_utils.TrainTestSplitMatrices(Matrix, x_train, y_train, x_test, y_test, 0.7, 42);
   
   nn = new CRegNeuralNets(x_train,y_train,0.01,1000, AF_RELU_, LOSS_MSE_,NORM_MIN_MAX_SCALER);
   
   vector test_pred = nn.ForwardPass(x_test);
    
   printf("Testing Accuracy =%.3f",metrics.r_squared(y_test, test_pred));
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool PosExist(ENUM_POSITION_TYPE type)
 {
   for (int i=PositionsTotal()-1; i>=0; i--)
      if (m_position.SelectByIndex(i))
         if (m_position.Magic() == MAGIC_NUMBER && m_position.Symbol()==Symbol() && m_position.PositionType() == type)
            return(true);
            
     return (false);
 }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
