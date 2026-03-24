//+------------------------------------------------------------------+
//|                                                     Currency.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include "NN.mqh"
#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\PositionInfo.mqh>
#include <Generic\HashMap.mqh>

extern bool GlobaltimeOutExpiredBuy;
extern bool GlobaltimeOutExpiredSell;

// Numero di feature per ogni barra (MACD main, MACD signal, RSI, Stoch main, Stoch signal, ADX)
#define FEATURES_PER_BAR 6

class Currency
{
private:
   NeuralNetwork          nn;
   int                    handle_macd;
   int                    handle_rsi;
   int                    handle_stoch;
   int                    handle_adx;
   int                    inputNeurons;
   int                    outputNeurons;
   int                    lookbackBars;   // inputNeurons / FEATURES_PER_BAR
   int                    trainingEpochs;
   double                 learningRate;
   string                 _symbolName;
   double                 _lotSize;
   double                 _closeInProfit;
   double                 _stopLoss;
   double                 _takeProfit;
   int                    _maxPositions;
   CTrade                 _trade;
   CPositionInfo          _myPositionInfo;
   CHashMap<ulong,double> previousProfits;
   int                    _numberOfData;

   // Parametri di normalizzazione MACD calcolati sul training set
   // e riutilizzati in modo consistente in Run()
   double                 _macd_min;
   double                 _macd_max;

   //--- Helpers privati ---

   // Normalizza un valore MACD in [-1, 1] usando i parametri del training
   double NormMacd(double value)
   {
      double range = _macd_max - _macd_min;
      if(range < 1e-10) return 0.0;
      return MathMax(-1.0, MathMin(1.0, 2.0 * (value - _macd_min) / range - 1.0));
   }

   // Conta le posizioni aperte sul simbolo corrente
   int CountOpenPositions()
   {
      int count = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
         if(_myPositionInfo.SelectByIndex(i) && _myPositionInfo.Symbol() == _symbolName)
            count++;
      return count;
   }

public:
   Currency(int &layers[], int numLayers,
            int    inpTrainingEpochs,
            double inpLearningRate,
            string symbolName,
            double lotSize,
            double closeInProfit,
            int    numberOfData,
            double stopLoss,
            double takeProfit,
            int    maxPositions)
   {
      if(numLayers < 2)
      {
         Print("Errore: la rete deve avere almeno 2 layer");
         return;
      }

      inputNeurons   = layers[0];
      outputNeurons  = layers[numLayers - 1];
      lookbackBars   = inputNeurons / FEATURES_PER_BAR;
      trainingEpochs = inpTrainingEpochs;
      learningRate   = inpLearningRate;
      _symbolName    = symbolName;
      _lotSize       = lotSize;
      _closeInProfit = closeInProfit;
      _numberOfData  = numberOfData;
      _stopLoss      = stopLoss;
      _takeProfit    = takeProfit;
      _maxPositions  = maxPositions;
      _macd_min      = -0.001;
      _macd_max      =  0.001;

      nn.BuildModel(layers, numLayers);
   }

   //+------------------------------------------------------------------+
   //| Init: raccoglie dati storici, costruisce il dataset di training   |
   //| con label forward-looking (direzione del prossimo bar),           |
   //| addestra la rete neurale.                                         |
   //+------------------------------------------------------------------+
   bool Init()
   {
      handle_macd  = iMACD(_symbolName,  PERIOD_M30, 12, 26, 9, PRICE_CLOSE);
      handle_rsi   = iRSI(_symbolName,   PERIOD_M30, 14, PRICE_CLOSE);
      handle_stoch = iStochastic(_symbolName, PERIOD_M30, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      handle_adx   = iADX(_symbolName,   PERIOD_M30, 14);

      if(handle_macd  == INVALID_HANDLE || handle_rsi   == INVALID_HANDLE ||
         handle_stoch == INVALID_HANDLE || handle_adx   == INVALID_HANDLE)
      {
         Print("Errore: impossibile creare gli indicatori");
         return false;
      }
      Sleep(5000); // attesa per la valorizzazione iniziale degli indicatori

      // Barre necessarie:
      //   _numberOfData campioni,
      //   ognuno usa lookbackBars barre di storico,
      //   più 1 barra extra per generare la label del campione più recente
      int requiredBars = _numberOfData + lookbackBars + 2;

      double macd_main[], macd_signal[], rsi_buf[], stoch_main[], stoch_signal[], adx_buf[], close_buf[];
      ArraySetAsSeries(macd_main,    true);
      ArraySetAsSeries(macd_signal,  true);
      ArraySetAsSeries(rsi_buf,      true);
      ArraySetAsSeries(stoch_main,   true);
      ArraySetAsSeries(stoch_signal, true);
      ArraySetAsSeries(adx_buf,      true);
      ArraySetAsSeries(close_buf,    true);

      // Copia i buffer a partire dalla barra 1 (bar 0 = barra corrente non ancora chiusa)
      if(CopyBuffer(handle_macd,  0,           1, requiredBars, macd_main)    <= 0 ||
         CopyBuffer(handle_macd,  1,           1, requiredBars, macd_signal)  <= 0 ||
         CopyBuffer(handle_rsi,   0,           1, requiredBars, rsi_buf)      <= 0 ||
         CopyBuffer(handle_stoch, MAIN_LINE,   1, requiredBars, stoch_main)   <= 0 ||
         CopyBuffer(handle_stoch, SIGNAL_LINE, 1, requiredBars, stoch_signal) <= 0 ||
         CopyBuffer(handle_adx,   0,           1, requiredBars, adx_buf)      <= 0 ||
         CopyClose(_symbolName,   PERIOD_M30,  1, requiredBars, close_buf)    <= 0)
      {
         Print("Errore copia buffer indicatori (Init). Codice: ", GetLastError());
         return false;
      }

      int availableBars = ArraySize(macd_main);
      // Campioni massimi: ogni campione usa barre [k+1 .. k+lookbackBars] e label su barra k
      // => k varia da 0 a numSamples-1, quindi numSamples+lookbackBars < availableBars
      int maxSamples = availableBars - lookbackBars - 1;
      int numSamples = MathMin(_numberOfData, maxSamples);

      if(numSamples <= 0)
      {
         Print("Errore: dati storici insufficienti. Disponibili: ", availableBars,
               ", necessari: ", lookbackBars + 2);
         return false;
      }

      // --- Calcola normalizzazione MACD dal dataset completo ---
      _macd_min = MathMin(macd_main[ArrayMinimum(macd_main)], macd_signal[ArrayMinimum(macd_signal)]);
      _macd_max = MathMax(macd_main[ArrayMaximum(macd_main)], macd_signal[ArrayMaximum(macd_signal)]);
      if(_macd_max - _macd_min < 1e-10)
         _macd_max = _macd_min + 1e-6;

      // --- Costruzione dataset ---
      // Indicizzazione (ArraySetAsSeries=true):
      //   arr[0] = barra più recente (chiusa 1 tick fa, cioè 1 barra fa)
      //   arr[k] = barra chiusa k+1 barre fa
      //
      // Per campione k_target (0..numSamples-1):
      //   Finestra di osservazione: indici [k_target+1 .. k_target+lookbackBars]
      //     (da più recente a più vecchia)
      //   Label forward-looking: direzione di close_buf[k_target] rispetto a close_buf[k_target+1]
      //     close_buf[k_target] > close_buf[k_target+1] → bar k_target andò su → label BUY [1,0]
      //     close_buf[k_target] < close_buf[k_target+1] → bar k_target andò giù → label SELL [0,1]
      //     equal → Hold [0,0]  (raro)
      //
      // Questo insegna alla rete: "dato lo stato degli indicatori nelle ultime lookbackBars barre,
      // la barra successiva sale o scende?"

      double inputs[];
      double targets[];
      ArrayResize(inputs,  numSamples * inputNeurons);
      ArrayResize(targets, numSamples * outputNeurons);
      ArrayInitialize(inputs,  0.0);
      ArrayInitialize(targets, 0.0);

      int buyCount  = 0;
      int sellCount = 0;
      int holdCount = 0;

      for(int k = 0; k < numSamples; k++)
      {
         // Costruisci input: lookbackBars barre ordinate dalla più vecchia alla più recente
         for(int b = 0; b < lookbackBars; b++)
         {
            // b=0: barra più vecchia della finestra (k + lookbackBars)
            // b=lookbackBars-1: barra più recente della finestra (k + 1)
            int barIdx     = k + lookbackBars - b;
            int featOffset = k * inputNeurons + b * FEATURES_PER_BAR;

            inputs[featOffset + 0] = NormMacd(macd_main[barIdx]);
            inputs[featOffset + 1] = NormMacd(macd_signal[barIdx]);
            inputs[featOffset + 2] = 2.0 * (rsi_buf[barIdx]      / 100.0) - 1.0;
            inputs[featOffset + 3] = 2.0 * (stoch_main[barIdx]   / 100.0) - 1.0;
            inputs[featOffset + 4] = 2.0 * (stoch_signal[barIdx] / 100.0) - 1.0;
            inputs[featOffset + 5] = MathMax(-1.0, MathMin(1.0, 2.0 * (adx_buf[barIdx] / 100.0) - 1.0));
         }

         // Genera label dalla direzione del prossimo bar
         int targetOffset = k * outputNeurons;
         if(close_buf[k] > close_buf[k + 1])       // barra k salita
         {
            targets[targetOffset]     = 1.0; // BUY
            targets[targetOffset + 1] = 0.0;
            buyCount++;
         }
         else if(close_buf[k] < close_buf[k + 1])  // barra k scesa
         {
            targets[targetOffset]     = 0.0;
            targets[targetOffset + 1] = 1.0; // SELL
            sellCount++;
         }
         else                                        // invariata (Hold)
         {
            targets[targetOffset]     = 0.0;
            targets[targetOffset + 1] = 0.0;
            holdCount++;
         }
      }

      Print("Dataset: ", numSamples, " campioni | BUY=", buyCount,
            " SELL=", sellCount, " HOLD=", holdCount,
            " | lookback=", lookbackBars, " barre");

      nn.Train(inputs, targets, trainingEpochs, learningRate);
      Print("Training completato.");
      return true;
   }

   //+------------------------------------------------------------------+
   //| Run: esegue la predizione sul tick corrente e gestisce ordini    |
   //+------------------------------------------------------------------+
   void Run(double maxRiskAmount)
   {
      // Raccoglie le lookbackBars barre più recenti completate
      double macd_main[], macd_signal[], rsi_buf[], stoch_main[], stoch_signal[], adx_buf[];
      ArraySetAsSeries(macd_main,    true);
      ArraySetAsSeries(macd_signal,  true);
      ArraySetAsSeries(rsi_buf,      true);
      ArraySetAsSeries(stoch_main,   true);
      ArraySetAsSeries(stoch_signal, true);
      ArraySetAsSeries(adx_buf,      true);

      // +1 per coerenza con il training (indici 1..lookbackBars)
      int barsToLoad = lookbackBars + 1;
      if(CopyBuffer(handle_macd,  0,           1, barsToLoad, macd_main)    <= 0 ||
         CopyBuffer(handle_macd,  1,           1, barsToLoad, macd_signal)  <= 0 ||
         CopyBuffer(handle_rsi,   0,           1, barsToLoad, rsi_buf)      <= 0 ||
         CopyBuffer(handle_stoch, MAIN_LINE,   1, barsToLoad, stoch_main)   <= 0 ||
         CopyBuffer(handle_stoch, SIGNAL_LINE, 1, barsToLoad, stoch_signal) <= 0 ||
         CopyBuffer(handle_adx,   0,           1, barsToLoad, adx_buf)      <= 0)
      {
         Print("Errore copia buffer indicatori (Run). Codice: ", GetLastError());
         return;
      }

      // Costruisci input coerentemente con il training (k_target=0):
      //   Finestra osservazione: indici 1..lookbackBars (b=0: più vecchia, b=lookbackBars-1: più recente)
      //   barIdx = lookbackBars - b  →  b=0: arr[lookbackBars], b=lookbackBars-1: arr[1]
      double inputs[];
      ArrayResize(inputs, inputNeurons);

      for(int b = 0; b < lookbackBars; b++)
      {
         int barIdx     = lookbackBars - b;         // b=0: oldest, b=lookbackBars-1: most recent
         int featOffset = b * FEATURES_PER_BAR;

         inputs[featOffset + 0] = NormMacd(macd_main[barIdx]);
         inputs[featOffset + 1] = NormMacd(macd_signal[barIdx]);
         inputs[featOffset + 2] = 2.0 * (rsi_buf[barIdx]      / 100.0) - 1.0;
         inputs[featOffset + 3] = 2.0 * (stoch_main[barIdx]   / 100.0) - 1.0;
         inputs[featOffset + 4] = 2.0 * (stoch_signal[barIdx] / 100.0) - 1.0;
         inputs[featOffset + 5] = MathMax(-1.0, MathMin(1.0, 2.0 * (adx_buf[barIdx] / 100.0) - 1.0));
      }

      nn.FeedForward(inputs);

      double output[];
      nn.GetOutputs(output);

      if(ArraySize(output) < 2)
      {
         Print("Errore: attesi 2 output, ricevuti ", ArraySize(output));
         return;
      }

      // output[0] = probabilità BUY  ∈ [0,1]  (sigmoid)
      // output[1] = probabilità SELL ∈ [0,1]  (sigmoid)
      double probBuy  = output[0];
      double probSell = output[1];

      // Condizione di trading:
      //   Free margin sufficiente E posizioni aperte sotto il massimo
      double freeMargin = AccountInfoDouble(ACCOUNT_FREEMARGIN);
      bool   canTrade   = (freeMargin >= maxRiskAmount) && (CountOpenPositions() < _maxPositions);

      if(probBuy > 0.6 && probSell < 0.4 && GlobaltimeOutExpiredBuy && canTrade)
      {
         if(openBuyOrder())
            GlobaltimeOutExpiredBuy = false;
      }
      else if(probSell > 0.6 && probBuy < 0.4 && GlobaltimeOutExpiredSell && canTrade)
      {
         if(openSellOrder())
            GlobaltimeOutExpiredSell = false;
      }

      checkAndCloseProfitOrders();
   }

   //+------------------------------------------------------------------+
   //| Chiude posizioni che hanno raggiunto il target di profitto        |
   //+------------------------------------------------------------------+
   void checkAndCloseProfitOrders()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(!_myPositionInfo.SelectByIndex(i))       continue;
         if(_myPositionInfo.Symbol() != _symbolName) continue;

         ulong  ticket = _myPositionInfo.Ticket();
         double profit = _myPositionInfo.Commission() + _myPositionInfo.Swap() + _myPositionInfo.Profit();

         if(profit > _closeInProfit)
         {
            if(_trade.PositionClose(ticket))
               previousProfits.Remove(ticket);
            else
               Print("Errore chiusura posizione ", ticket, ": codice=", _trade.ResultRetcode());
         }
         else
         {
            previousProfits.TrySetValue(ticket, profit);
         }
      }
   }

   bool openBuyOrder()
   {
      double ask   = SymbolInfoDouble(_symbolName, SYMBOL_ASK);
      double point = SymbolInfoDouble(_symbolName, SYMBOL_POINT);
      double sl    = (_stopLoss   > 0) ? NormalizeDouble(ask - _stopLoss   * point, _Digits) : 0;
      double tp    = (_takeProfit > 0) ? NormalizeDouble(ask + _takeProfit * point, _Digits) : 0;

      if(_trade.Buy(_lotSize, _symbolName, ask, sl, tp))
      {
         Print("BUY aperto | Ask=", ask, " SL=", sl, " TP=", tp);
         return true;
      }
      Print("BUY fallito: ", GetLastError());
      return false;
   }

   bool openSellOrder()
   {
      double bid   = SymbolInfoDouble(_symbolName, SYMBOL_BID);
      double point = SymbolInfoDouble(_symbolName, SYMBOL_POINT);
      double sl    = (_stopLoss   > 0) ? NormalizeDouble(bid + _stopLoss   * point, _Digits) : 0;
      double tp    = (_takeProfit > 0) ? NormalizeDouble(bid - _takeProfit * point, _Digits) : 0;

      if(_trade.Sell(_lotSize, _symbolName, bid, sl, tp))
      {
         Print("SELL aperto | Bid=", bid, " SL=", sl, " TP=", tp);
         return true;
      }
      Print("SELL fallito: ", GetLastError());
      return false;
   }

   void closeBuyPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(_myPositionInfo.SelectByIndex(i) &&
            _myPositionInfo.Type()   == POSITION_TYPE_BUY &&
            _myPositionInfo.Symbol() == _symbolName)
         {
            ulong ticket = _myPositionInfo.Ticket();
            if(_trade.PositionClose(ticket))
               previousProfits.Remove(ticket);
         }
      }
   }

   void closeSellPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(_myPositionInfo.SelectByIndex(i) &&
            _myPositionInfo.Type()   == POSITION_TYPE_SELL &&
            _myPositionInfo.Symbol() == _symbolName)
         {
            ulong ticket = _myPositionInfo.Ticket();
            if(_trade.PositionClose(ticket))
               previousProfits.Remove(ticket);
         }
      }
   }

   void closeAllPositions()
   {
      closeSellPositions();
      closeBuyPositions();
   }

   ~Currency()
   {
      IndicatorRelease(handle_macd);
      IndicatorRelease(handle_rsi);
      IndicatorRelease(handle_stoch);
      IndicatorRelease(handle_adx);
   }
};
