//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2018, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, anddycabrera@gmail.com."
#property link      "https://www.mql5.com/en/users/waygrow"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>        //include the library for execution of trades
#include <Trade\PositionInfo.mqh> //include the library for obtaining information on positions
#include <..\Experts\AutomatedTrading\example\DeepNeuralNetwork.mqh> 

int numInput=4;
int numHiddenA = 4;
int numHiddenB = 5;
int numOutput=3;

DeepNeuralNetwork dnn(numInput,numHiddenA,numHiddenB,numOutput);

//--- weight values
input double w0=1.0;
input double w1=1.0;
input double w2=1.0;
input double w3=1.0;
input double w4=1.0;
input double w5=1.0;
input double w6=1.0;
input double w7=1.0;
input double w8=1.0;
input double w9=1.0;
input double w10=1.0;
input double w11=1.0;
input double w12=1.0;
input double w13=1.0;
input double w14=1.0;
input double w15=1.0;
input double b0=1.0;
input double b1=1.0;
input double b2=1.0;
input double b3=1.0;
input double w40=1.0;
input double w41=1.0;
input double w42=1.0;
input double w43=1.0;
input double w44=1.0;
input double w45=1.0;
input double w46=1.0;
input double w47=1.0;
input double w48=1.0;
input double w49=1.0;
input double w50=1.0;
input double w51=1.0;
input double w52=1.0;
input double w53=1.0;
input double w54=1.0;
input double w55=1.0;
input double w56=1.0;
input double w57=1.0;
input double w58=1.0;
input double w59=1.0;
input double b4=1.0;
input double b5=1.0;
input double b6=1.0;
input double b7=1.0;
input double b8=1.0;
input double w60=1.0;
input double w61=1.0;
input double w62=1.0;
input double w63=1.0;
input double w64=1.0;
input double w65=1.0;
input double w66=1.0;
input double w67=1.0;
input double w68=1.0;
input double w69=1.0;
input double w70=1.0;
input double w71=1.0;
input double w72=1.0;
input double w73=1.0;
input double w74=1.0;
input double b9=1.0;
input double b10=1.0;
input double b11=1.0;

input double Lot=0.1;

input long order_magic=55555;//MagicNumber

double            _xValues[4];   // array for storing inputs
double            weight[63];   // array for storing weights

double            out;          // variable for storing the output of the neuron

string            my_symbol;    // variable for storing the symbol
ENUM_TIMEFRAMES   my_timeframe; // variable for storing the time frame
double            lot_size;     // variable for storing the minimum lot size of the transaction to be performed

CTrade            m_Trade;      // entity for execution of trades
CPositionInfo     m_Position;   // entity for obtaining information on positions
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
  {
   my_symbol=Symbol();
   my_timeframe=PERIOD_CURRENT;
   lot_size=Lot;
   m_Trade.SetExpertMagicNumber(order_magic);

   weight[0]=w0;
   weight[1]=w1;
   weight[2]=w2;
   weight[3]=w3;
   weight[4]=w4;
   weight[5]=w5;
   weight[6]=w6;
   weight[7]=w7;
   weight[8]=w8;
   weight[9]=w9;
   weight[10]=w10;
   weight[11]=w11;
   weight[12]=w12;
   weight[13]=w13;
   weight[14]=w14;
   weight[15]=w15;
   weight[16]=b0;
   weight[17]=b1;
   weight[18]=b2;
   weight[19]=b3;
   weight[20]=w40;
   weight[21]=w41;
   weight[22]=w42;
   weight[23]=w43;
   weight[24]=w44;
   weight[25]=w45;
   weight[26]=w46;
   weight[27]=w47;
   weight[28]=w48;
   weight[29]=w49;
   weight[30]=w50;
   weight[31]=w51;
   weight[32]=w52;
   weight[33]=w53;
   weight[34]=w54;
   weight[35]=w55;
   weight[36]=w56;
   weight[37]=w57;
   weight[38]=w58;
   weight[39]=w59;
   weight[40]=b4;
   weight[41]=b5;
   weight[42]=b6;
   weight[43]=b7;
   weight[44]=b8;
   weight[45]=w60;
   weight[46]=w61;
   weight[47]=w62;
   weight[48]=w63;
   weight[49]=w64;
   weight[50]=w65;
   weight[51]=w66;
   weight[52]=w67;
   weight[53]=w68;
   weight[54]=w69;
   weight[55]=w70;
   weight[56]=w71;
   weight[57]=w72;
   weight[58]=w73;
   weight[59]=w74;
   weight[60]=b9;
   weight[61]=b10;
   weight[62]=b11;


//--- return 0, initialization complete
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   int copied=CopyRates(_Symbol,0,1,5,rates);

//compute the percent of the upper shadow, lower shadow and body in base of sum 100%
   int error=CandlePatterns(rates[0].high,rates[0].low,rates[0].open,rates[0].close,rates[0].close-rates[0].open,_xValues);

   if(error<0)return;

   dnn.SetWeights(weight);

   double yValues[];
   dnn.ComputeOutputs(_xValues,yValues);

//--- if the output value of the neuron is mare than 60%
   if(yValues[0]>0.6)
     {
      if(m_Position.Select(my_symbol))//check if there is an open position
        {
         if(m_Position.PositionType()==POSITION_TYPE_SELL) m_Trade.PositionClose(my_symbol);//Close the opposite position if exists
         if(m_Position.PositionType()==POSITION_TYPE_BUY) return;
        }
      m_Trade.Buy(lot_size,my_symbol);//open a Long position
     }
//--- if the output value of the neuron is mare than 60%
   if(yValues[1]>0.6)
     {
      if(m_Position.Select(my_symbol))//check if there is an open position
        {
         if(m_Position.PositionType()==POSITION_TYPE_BUY) m_Trade.PositionClose(my_symbol);//Close the opposite position if exists
         if(m_Position.PositionType()==POSITION_TYPE_SELL) return;
        }
      m_Trade.Sell(lot_size,my_symbol);//open a Short position
     }

   if(yValues[2]>0.6)
     {
      m_Trade.PositionClose(my_symbol);//close any position

     }

  }
//+------------------------------------------------------------------+
//|percentage of each part of the candle respecting total size       |
//+------------------------------------------------------------------+
int CandlePatterns(double high,double low,double open,double close,double uod,double &xInputs[])
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
   if(p100==0)return(-1);
   xInputs[0]=highPer/p100;
   xInputs[1]=lowPer/p100;
   xInputs[2]=bodyPer/p100;
   xInputs[3]=trend;

   return(1);

  }
//+------------------------------------------------------------------+
