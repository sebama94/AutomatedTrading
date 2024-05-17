//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"


/* 15x8 = 120 */
/*input*/ double w0   =  -0.80;
/*input*/ double w1   =  -0.95;
/*input*/ double w2   =  0.15 ;
/*input*/ double w3   =  0.50 ;
/*input*/ double w4   =  0.95 ;
/*input*/ double w5   =  0.75 ;
/*input*/ double w6   =  -1.00;
/*input*/ double w7   =  0.25 ;
/*input*/ double w8   =  -0.80;
/*input*/ double w9   =  -0.45;
/*input*/ double w10  =  0.85 ;
/*input*/ double w11  =  -0.25;
/*input*/ double w12  =  0.80 ;
/*input*/ double w13  =  0.10 ;
/*input*/ double w14  =  -0.65;
/*input*/ double w15  =  -0.80;
/*input*/ double w16  =  0.45 ;
/*input*/ double w17  =  0.10 ;
/*input*/ double w18  =  -0.75;
/*input*/ double w19  =  0.20 ;
/*input*/ double w20  =  0.25 ;
/*input*/ double w21  =  0.85 ;
/*input*/ double w22  =  0.90 ;
/*input*/ double w23  =  -0.80;
/*input*/ double w24  =  0.65 ;
/*input*/ double w25  =  -0.10;
/*input*/ double w26  =  -0.10;
/*input*/ double w27  =  0.85 ;
/*input*/ double w28  =  0.65 ;
/*input*/ double w29  =  -0.85;
/*input*/ double w30  =  -0.85;
/*input*/ double w31  =  -0.45;
/*input*/ double w32  =  0.35 ;
/*input*/ double w33  =  0.20 ;
/*input*/ double w34  =  -0.05;
/*input*/ double w35  =  0.25 ;
/*input*/ double w36  =  -0.40;
/*input*/ double w37  =  -0.95;
/*input*/ double w38  =  -0.65;
/*input*/ double w39  =  -0.10;
/*input*/ double w40  =  0.40 ;
/*input*/ double w41  =  0.35 ;
/*input*/ double w42  =  0.95 ;
/*input*/ double w43  =  0.15 ;
/*input*/ double w44  =  -0.50;
/*input*/ double w45  =  -0.65;
/*input*/ double w46  =  -0.70;
/*input*/ double w47  =  -0.35;
/*input*/ double w48  =  -0.20;
/*input*/ double w49  =  0.80 ;
/*input*/ double w50  =  -0.90;
/*input*/ double w51  =  -0.60;
/*input*/ double w52  =  0.05 ;
/*input*/ double w53  =  0.15 ;
/*input*/ double w54  =  0.60 ;
/*input*/ double w55  =  0.10 ;
/*input*/ double w56  =  -0.10;
/*input*/ double w57  =  0.30 ;
/*input*/ double w58  =  -0.45;
/*input*/ double w59  =  -0.35;
/*input*/ double w60  =  -1.00;
/*input*/ double w61  =  0.25 ;
/*input*/ double w62  =  -0.15;
/*input*/ double w63  =  -0.35;
/*input*/ double w64  =  -0.40;
/*input*/ double w65  =  -0.85;
/*input*/ double w66  =  0.15 ;
/*input*/ double w67  =  0.95 ;
/*input*/ double w68  =  -0.50;
/*input*/ double w69  =  0.30 ;
/*input*/ double w70  =  -0.90;
/*input*/ double w71  =  0.40 ;
/*input*/ double w72  =  -0.10;
/*input*/ double w73  =  -0.95;
/*input*/ double w74  =  0.10 ;
/*input*/ double w75  =  -0.50;
/*input*/ double w76  =  -0.05;
/*input*/ double w77  =  -0.35;
/*input*/ double w78  =  0.40 ;
/*input*/ double w79  =  -0.95;
/*input*/ double w80  =  -0.65;
/*input*/ double w81  =  -0.50;
/*input*/ double w82  =  0.75 ;
/*input*/ double w83  =  -0.15;
/*input*/ double w84  =  0.10 ;
/*input*/ double w85  =  0.00 ;
/*input*/ double w86  =  -0.70;
/*input*/ double w87  =  -0.45;
/*input*/ double w88  =  0.20 ;
/*input*/ double w89  =  -0.95;
/*input*/ double w90  =  0.40 ;
/*input*/ double w91  =  0.45 ;
/*input*/ double w92  =  -0.25;
/*input*/ double w93  =  0.55 ;
/*input*/ double w94  =  -1.00;
/*input*/ double w95  =  -0.45;
/*input*/ double w96  =  -0.15;
/*input*/ double w97  =  0.30 ;
/*input*/ double w98  =  0.80 ;
/*input*/ double w99  =  -0.85;
/*input*/ double w100 =  -0.25;
/*input*/ double w101 =  0.80 ;
/*input*/ double w102 =  0.35 ;
/*input*/ double w103 =  0.75 ;
/*input*/ double w104 =  -0.70;
/*input*/ double w105 =  -0.15;
/*input*/ double w106 =  -0.70;
/*input*/ double w107 =  -0.95;
/*input*/ double w108 =  0.05 ;
/*input*/ double w109 =  0.95 ;
/*input*/ double w110 =  0.20 ;
/*input*/ double w111 =  0.35 ;
/*input*/ double w112 =  0.70 ;
/*input*/ double w113 =  0.05 ;
/*input*/ double w114 =  0.90 ;
/*input*/ double w115 =  -0.95;
/*input*/ double w116 =  -1.00;
/*input*/ double w117 =  1.00 ;
/*input*/ double w118 =  -0.25;
/*input*/ double w119 =  0.60 ;
/*input*/ double b0   =  -0.05;
/*input*/ double b1   =  -0.85;
/*input*/ double b2   =  0.40 ;
/*input*/ double b3   =  -0.25;
/*input*/ double b4   =  -1.00;
/*input*/ double b5   =  0.45 ;
/*input*/ double b6   =  -0.75;
/*input*/ double b7   =  0.20 ;
/*input*/ double w224 =  0.90 ;
/*input*/ double w225 =  0.90 ;
/*input*/ double w226 =  0.85 ;
/*input*/ double w227 =  -0.85;
/*input*/ double w228 =  -0.90;
/*input*/ double w229 =  0.30 ;
/*input*/ double w230 =  -0.20;
/*input*/ double w231 =  0.15 ;
/*input*/ double w232 =  0.55 ;
/*input*/ double w233 =  -0.85;
/*input*/ double w234 =  -0.45;
/*input*/ double w235 =  0.45 ;
/*input*/ double w236 =  0.40 ;
/*input*/ double w237 =  -0.60;
/*input*/ double w238 =  -0.35;
/*input*/ double w239 =  0.25 ;
/*input*/ double w240 =  -0.20;
/*input*/ double w241 =  0.35 ;
/*input*/ double w242 =  -0.40;
/*input*/ double w243 =  0.15 ;
/*input*/ double w244 =  -0.35;
/*input*/ double w245 =  -0.30;
/*input*/ double w246 =  0.35 ;
/*input*/ double w247 =  0.35 ;
/*input*/ double w248 =  -0.15;
/*input*/ double w249 =  -0.80;
/*input*/ double w250 =  0.10 ;
/*input*/ double w251 =  0.50 ;
/*input*/ double w252 =  0.40 ;
/*input*/ double w253 =  0.50 ;
/*input*/ double w254 =  0.55 ;
/*input*/ double w255 =  0.80 ;
/*input*/ double w256 =  -1.00;
/*input*/ double w257 =  1.00 ;
/*input*/ double w258 =  0.75 ;
/*input*/ double w259 =  -0.45;
/*input*/ double w260 =  0.80 ;
/*input*/ double w261 =  0.15 ;
/*input*/ double w262 =  0.45 ;
/*input*/ double w263 =  -0.50;
/*input*/ double b8   =  0.25 ;
/*input*/ double b9   =  -0.50;
/*input*/ double b10  =  -0.25;
/*input*/ double b11  =  0.65 ;
/*input*/ double b12  =  -0.15;
/*input*/ double w264 =  -0.60;
/*input*/ double w265 =  0.30 ;
/*input*/ double w266 =  0.85 ;
/*input*/ double w267 =  -0.80;
/*input*/ double w268 =  -0.85;
/*input*/ double w269 =  0.85 ;
/*input*/ double w270 =  -0.60;
/*input*/ double w271 =  0.30 ;
/*input*/ double w272 =  0.95 ;
/*input*/ double w273 =  -0.90;
/*input*/ double w274 =  -0.60;
/*input*/ double w275 =  -0.85;
/*input*/ double w276 =  0.95 ;
/*input*/ double w277 =  -0.60;
/*input*/ double w278 =  0.65 ;
/*input*/ double b13  =  -0.25;
/*input*/ double b14  =  0.80 ;
/*input*/ double b15  =  -0.70;


double weight[] = {
                  w0, w1,w2,w3,w4,w5,w6,w7,w8,w9,
                  w10,w11,w12,w13,w14,w15,w16,w17,w18,w19,
                  w20,w21,w22,w23,w24,w25,w26,w27,w28,w29,
                  w30,w31,w32,w33,w34,w35,w36,w37,w38,w39,
                  w40,w41,w42,w43,w44,w45,w46,w47,w48,w49,
                  w50,w51,w52,w53,w54,w55,w56,w57,w58,w59,
                  w60,w61,w62,w63,w64,w65,w66,w67,w68,w69,
                  w70,w71,w72,w73,w74,w75,w76,w77,w78,w79,
                  w80,w81,w82,w83,w84,w85,w86,w87,w88,w89,
                  w90,w91,w92,w93,w94,w95,w96,w97,w98,w99,
                  w100,w101,w102,w103,w104,w105,w106,w107,w108,w109,
                  w110,w111,w112,w113,w114,w115,w116,w117,w118,w119,
                  /*w120,w121,w122,w123,w124,w125,w126,w127,w128,w129,
                  w130,w131,w132,w133,w134,w135,w136,w137,w138,w139,
                  w140,w141,w142,w143,w144,w145,w146,w147,w148,w149,
                  w150,w151,w152,w153,w154,w155,w156,w157,w158,w159, 
                  w160,w161,w162,w163,w164,w165,w166,w167,w168,w169,
                  w170,w171,w172,w173,w174,w175,w176,w177,w178,w179,
                  w180,w181,w182,w183,w184,w185,w186,w187,w188,w189,
                  w190,w191,w192,w193,w194,w195,w196,w197,w198,w199,
                  w200,w201,w202,w203,w204,w205,w206,w207,w208,w209,                        
                  w210,w211,w212,w213,w214,w215,w216,w217,w218,w219,*/
                 /* w220,w221,w222,w223,         */                      b0 ,b1 ,b2 ,b3 ,b4 ,b5 ,b6 ,b7,  
                  w224,w225,w226,w227,w228,w229,w230,w231,w232,w233,
                  w234,w235,w236,w237,w238,w239,w240,w241,w242,w243,
                  w244,w245,w246,w247,w248,w249,w250,w251,w252,w253,
                  w254,w255,w256,w257,w258,w259,w260,w261,w262,w263, b8,b9,b10,b11,b12,
                  w264,w265,w266,w267,w268,w269,w270,w271,w272,w273, 
                  w274,w275,w276,w277,w278,                          b13,b14,b15
                  };   // array for storing weights


double MaxRiskPercentage = 20; // Max Risk in Percentage [%]]
const int GlobalRsiPeriod = 14;
MultiCurrency eurUsdCurrency;
bool GlobaltimeOutExpired = true;

double GlobalLotSize = 1;
double close_profit  = 250;
double close_loss = 1500;


double GlobaloversoldLevel = 30;
double GlobaloverboughtLevel = 70;


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(60);
   
   int numInput   = 15;
   int numHiddenA = 8;
   int numHiddenB = 5;
   int numOutput  = 3;


   eurUsdCurrency.Init(Symbol(),GlobalRsiPeriod,
                       GlobaloverboughtLevel, GlobaloversoldLevel, GlobalLotSize, numInput,
                       numHiddenA, numHiddenB, numOutput, weight);
   return(INIT_SUCCEEDED);

}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
//--- destroy timer
   EventKillTimer();

//IndicatorRelease(macdHandle);
// delete(Log_reg);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{

   double accountMargin = AccountInfoDouble(ACCOUNT_MARGIN);
   double maxRiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * (MaxRiskPercentage / 100.0);
   //double closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01;
//Run(const double& accountMargin, const double& maxRiskAmount, const double& closeInProfit,bool timeOutExpired)
   double closeInProfit = 300;
   //Print("close in profit: ", closeInProfit);
   eurUsdCurrency.Run(accountMargin, maxRiskAmount, closeInProfit, GlobaltimeOutExpired);
   GlobaltimeOutExpired = false;
}


//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   GlobaltimeOutExpired = true;
}
//+------------------------------------------------------------------+
