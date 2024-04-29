//+------------------------------------------------------------------+
//|                                           LogisticRegression.mq5 |
//|                                  Copyright 2022, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+

#property copyright "Copyright 2022, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include "MultiCurrency.mqh"

int numInput   = 16;
int numHiddenA = 10;
int numHiddenB = 6;
int numOutput  = 2;


/* 16 * 10 = 160 */
input double w0   = 1.0;
input double w1   = 1.0;
input double w2   = 1.0;
input double w3   = 1.0;
input double w4   = 1.0;
input double w5   = 1.0;
input double w6   = 1.0;
input double w7   = 1.0;
input double w8   = 1.0;
input double w9   = 1.0;
input double w10  = 1.0;
input double w11  = 1.0;
input double w12  = 1.0;
input double w13  = 1.0;
input double w14  = 1.0;
input double w15  = 1.0;
input double w16  = 1.0;
input double w17  = 1.0;
input double w18  = 1.0;
input double w19  = 1.0;
input double w20  = 1.0;
input double w21  = 1.0;
input double w22  = 1.0;
input double w23  = 1.0;
input double w24  = 1.0;
input double w25  = 1.0;
input double w26  = 1.0;
input double w27  = 1.0;
input double w28  = 1.0;
input double w29  = 1.0;
input double w30  = 1.0;
input double w31  = 1.0;
input double w32  = 1.0;
input double w33  = 1.0;
input double w34  = 1.0;
input double w35  = 1.0;
input double w36  = 1.0;
input double w37  = 1.0;
input double w38  = 1.0;
input double w39  = 1.0;
input double w40  = 1.0;
input double w41  = 1.0;
input double w42  = 1.0;
input double w43  = 1.0;
input double w44  = 1.0;
input double w45  = 1.0;
input double w46  = 1.0;
input double w47  = 1.0;
input double w48  = 1.0;
input double w49  = 1.0;
input double w50  = 1.0;
input double w51  = 1.0;
input double w52  = 1.0;
input double w53  = 1.0;
input double w54  = 1.0;
input double w55  = 1.0;
input double w56  = 1.0;
input double w57  = 1.0;
input double w58  = 1.0;
input double w59  = 1.0;
input double w60  = 1.0;
input double w61  = 1.0;
input double w62  = 1.0;
input double w63  = 1.0;
input double w64  = 1.0;
input double w65  = 1.0;
input double w66  = 1.0;
input double w67  = 1.0;
input double w68  = 1.0;
input double w69  = 1.0;
input double w70  = 1.0;
input double w71  = 1.0;
input double w72  = 1.0;
input double w73  = 1.0;
input double w74  = 1.0;
input double w75  = 1.0;
input double w76  = 1.0;
input double w77  = 1.0;
input double w78  = 1.0;
input double w79  = 1.0;
input double w80  = 1.0;
input double w81  = 1.0;
input double w82  = 1.0;
input double w83  = 1.0;
input double w84  = 1.0;
input double w85  = 1.0;
input double w86  = 1.0;
input double w87  = 1.0;
input double w88  = 1.0;
input double w89  = 1.0;
input double w90  = 1.0;
input double w91  = 1.0;
input double w92  = 1.0;
input double w93  = 1.0;
input double w94  = 1.0;
input double w95  = 1.0;
input double w96  = 1.0;
input double w97  = 1.0;
input double w98  = 1.0;
input double w99  = 1.0;
input double w100 = 1.0;
input double w101 = 1.0;
input double w102 = 1.0;
input double w103 = 1.0;
input double w104 = 1.0;
input double w105 = 1.0;
input double w106 = 1.0;
input double w107 = 1.0;
input double w108 = 1.0;
input double w109 = 1.0;
input double w110 = 1.0;
input double w111 = 1.0;
input double w112 = 1.0;
input double w113 = 1.0;
input double w114 = 1.0;
input double w115 = 1.0;
input double w116 = 1.0;
input double w117 = 1.0;
input double w118 = 1.0;
input double w119 = 1.0;
input double w120 = 1.0;
input double w121 = 1.0;
input double w122 = 1.0;
input double w123 = 1.0;
input double w124 = 1.0;
input double w125 = 1.0;
input double w126 = 1.0;
input double w127 = 1.0;
input double w128 = 1.0;
input double w129 = 1.0;
input double w130 = 1.0;
input double w131 = 1.0;
input double w132 = 1.0;
input double w133 = 1.0;
input double w134 = 1.0;
input double w135 = 1.0;
input double w136 = 1.0;
input double w137 = 1.0;
input double w138 = 1.0;
input double w139 = 1.0;
input double w140 = 1.0;
input double w141 = 1.0;
input double w142 = 1.0;
input double w143 = 1.0;
input double w144 = 1.0;
input double w145 = 1.0;
input double w146 = 1.0;
input double w147 = 1.0;
input double w148 = 1.0;
input double w149 = 1.0;
input double w150 = 1.0;
input double w151 = 1.0;
input double w152 = 1.0;
input double w153 = 1.0;
input double w154 = 1.0;
input double w155 = 1.0;
input double w156 = 1.0;
input double w157 = 1.0;
input double w158 = 1.0;
input double w159 = 1.0;
/* bias 10 */
input double b0   = 1.0;
input double b1   = 1.0;
input double b2   = 1.0;
input double b3   = 1.0;
input double b4   = 1.0;
input double b5   = 1.0;
input double b6   = 1.0;
input double b7   = 1.0;
input double b8   = 1.0;
input double b9   = 1.0;

/* 10x6 = 60 */
input double w160 = 1.0;
input double w161 = 1.0;
input double w162 = 1.0;
input double w163 = 1.0;
input double w164 = 1.0;
input double w165 = 1.0;
input double w166 = 1.0;
input double w167 = 1.0;
input double w168 = 1.0;
input double w169 = 1.0;
input double w170 = 1.0;
input double w171 = 1.0;
input double w172 = 1.0;
input double w173 = 1.0;
input double w174 = 1.0;
input double w175 = 1.0;
input double w176 = 1.0;
input double w177 = 1.0;
input double w178 = 1.0;
input double w179 = 1.0;
input double w180 = 1.0;
input double w181 = 1.0;
input double w182 = 1.0;
input double w183 = 1.0;
input double w184 = 1.0;
input double w185 = 1.0;
input double w186 = 1.0;
input double w187 = 1.0;
input double w188 = 1.0;
input double w189 = 1.0;
input double w190 = 1.0;
input double w191 = 1.0;
input double w192 = 1.0;
input double w193 = 1.0;
input double w194 = 1.0;
input double w195 = 1.0;
input double w196 = 1.0;
input double w197 = 1.0;
input double w198 = 1.0;
input double w199 = 1.0;
input double w200 = 1.0;
input double w201 = 1.0;
input double w202 = 1.0;
input double w203 = 1.0;
input double w204 = 1.0;
input double w205 = 1.0;
input double w206 = 1.0;
input double w207 = 1.0;
input double w208 = 1.0;
input double w209 = 1.0;
input double w210 = 1.0;
input double w211 = 1.0;
input double w212 = 1.0;
input double w213 = 1.0;
input double w214 = 1.0;
input double w215 = 1.0;
input double w216 = 1.0;
input double w217 = 1.0;
input double w218 = 1.0;
input double w219 = 1.0;
/* bias 6 */
input double b10  = 1.0;
input double b11  = 1.0;
input double b12  = 1.0;
input double b13  = 1.0;
input double b14  = 1.0;
input double b15  = 1.0;

/* 6x2=12 */
input double w220 = 1.0;
input double w221 = 1.0;
input double w222 = 1.0;
input double w223 = 1.0;
input double w224 = 1.0;
input double w225 = 1.0;
input double w226 = 1.0;
input double w227 = 1.0;
input double w228 = 1.0;
input double w229 = 1.0;
input double w230 = 1.0;
input double w231 = 1.0;

/* bias 2 */
input double b16  = 1.0;
input double b17  = 1.0;

double close = 150;
double close_loss = 1500;



double weight[] = {
                   w0,w1,w2,w3,w4,w5,w6,w7,w8,w9,
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
                   w120,w121,w122,w123,w124,w125,w126,w127,w128,w129,
                   w130,w131,w132,w133,w134,w135,w136,w137,w138,w139,
                   w140,w141,w142,w143,w144,w145,w146,w147,w148,w149,
                   w150,w151,w152,w153,w154,w155,w156,w157,w158,w159, b0,b1,b2,b3,b4,b5,b6,b7,b8,b9,

                   w160,w161,w162,w163,w164,w165,w166,w167,w168,w169,
                   w170,w171,w172,w173,w174,w175,w176,w177,w178,w179,
                   w180,w181,w182,w183,w184,w185,w186,w187,w188,w189,
                   w190,w191,w192,w193,w194,w195,w196,w197,w198,w199,
                   w200,w201,w202,w203,w204,w205,w206,w207,w208,w209,                        
                   w210,w211,w212,w213,w214,w215,w216,w217,w218,w219, b10,b11,b12,b13,b14,b15,
                   
                   w220,w221,w222,w223,w224,w225,w226,w227,w228,w229,
                   w230,w231                          ,b16,b17
                  };   // array for storing weights


double MaxRiskPercentage = 20; // Max Risk in Percentage [%]]
const int GlobalRsiPeriod = 14;
MultiCurrency eurUsdCurrency;
bool GlobaltimeOutExpired = true;
input double GlobalLotSize = 0.1;

double GlobaloversoldLevel = 29;
double GlobaloverboughtLevel = 71;

/*
void MultiCurrency::Init(const string& symbolName
                         , const int bbPeriod
                         , const double bbDeviation
                         , const int bbBandShift
                         , const int rsiPeriod
                         , const int trainBars
                         , const double overboughtLevel
                         , const double oversoldLevel
                         , const double lotSize )
*/

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(60);


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
   double closeInProfit = AccountInfoDouble(ACCOUNT_BALANCE) * 0.01;
//Run(const double& accountMargin, const double& maxRiskAmount, const double& closeInProfit,bool timeOutExpired)

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
