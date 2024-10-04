//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include "NN.mqh"
#include <Trade\Trade.mqh> //Instantiate Trades Execution Library
#include <Trade\OrderInfo.mqh> //Instantiate Library for Orders Information
#include <Trade\PositionInfo.mqh> //Instantiate Library for Positions Information
#include <Generic\HashMap.mqh>

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
class Currency
{
private:
   NeuralNetwork nn;
   int handle_macd;
   int handle_rsi;
   int handle_stoch;
   int handle_adx;
   int inputNeurons;
   int outputNeurons;
   int trainingEpochs;
   double learningRate;
   string _symbolName;
   double _lotSize;
   double _closeInProfit;
   CTrade _trade;
   CPositionInfo _myPositionInfo;
   CHashMap<ulong, double> previousProfits;
   int _numberOfData;

public:
   Currency(int &layers[], int numLayers, int inpTrainingEpochs, double inpLearningRate,
            string symbolName, double lotSize, double closeInProfit, int numberOfData)
   {
      if(numLayers < 2)
      {
         Print("Error: Neural network must have at least 2 layers");
         return;
      }

      inputNeurons = layers[0];
      outputNeurons = layers[numLayers-1]; // Get outputNeurons from last element in layers
      trainingEpochs = inpTrainingEpochs;
      learningRate = inpLearningRate;
      _symbolName = symbolName;
      _lotSize = lotSize;
      _closeInProfit = closeInProfit;
      _numberOfData = numberOfData;
      // Initialize the neural network
      nn.BuildModel(layers, numLayers);
   }

   bool Init()
   {
      // Initialize indicators
      handle_macd = iMACD(_symbolName, PERIOD_M30, 12, 26, 9, PRICE_CLOSE);
      handle_rsi = iRSI(_symbolName, PERIOD_M30, 14, PRICE_CLOSE);
      handle_stoch = iStochastic(_symbolName, PERIOD_M30, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      handle_adx = iADX(_symbolName, PERIOD_M30, 14);
      if(handle_macd == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || handle_stoch == INVALID_HANDLE || handle_adx == INVALID_HANDLE)
      {
         Print("Failed to create indicators");
         return false;
      }
      Sleep(5000);

      // Prepare training data
      double inputs[];
      double targets[];
      ArrayResize(inputs, inputNeurons);
      ArrayResize(targets, outputNeurons);
      // Initialize targets and inputs with 0
      ArrayInitialize(targets, -555);
      ArrayInitialize(inputs, -444);

      // Get historical data for training
      double macd_main[];
      double macd_signal[];
      double rsi[];
      double stoch_main[];
      double stoch_signal[];
      double adx[];
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(stoch_main, true);
      ArraySetAsSeries(stoch_signal, true);
      ArraySetAsSeries(adx, true);
      int requiredSamples = _numberOfData * inputNeurons / 6;
      if (CopyBuffer(handle_macd, 0, 1, requiredSamples, macd_main) <= 0 ||
          CopyBuffer(handle_macd, 1, 1, requiredSamples, macd_signal) <= 0 ||
          CopyBuffer(handle_rsi, 0, 1, requiredSamples, rsi) <= 0 ||
          CopyBuffer(handle_stoch, MAIN_LINE, 1, requiredSamples, stoch_main) <= 0 ||
          CopyBuffer(handle_stoch, SIGNAL_LINE, 1, requiredSamples, stoch_signal) <= 0 ||
          CopyBuffer(handle_adx, 0, 1, requiredSamples, adx) <= 0)
      {
         Print("Error copying indicator buffers in Init. Error code: ", GetLastError());
         return false;
      }

      int totalSamples = ArraySize(macd_main); 
      int totalInputs = totalSamples * 6;
      int totalTargets = totalInputs/inputNeurons * outputNeurons;
      
      if (!ArrayResize(inputs, totalInputs) || !ArrayResize(targets, totalTargets))
      {
         Print("Error resizing arrays. Error code: ", GetLastError());
         return false;
      }

      for (int i = 0; i < totalSamples; i++)
      {
         int index = i * 6;
         if (index + 5 < ArraySize(inputs))
         {
            // Normalize MACD to range [-1, 1]
            double macd_min = MathMin(macd_main[ArrayMinimum(macd_main)], macd_signal[ArrayMinimum(macd_signal)]);
            double macd_max = MathMax(macd_main[ArrayMaximum(macd_main)], macd_signal[ArrayMaximum(macd_signal)]);
            inputs[index] = 2 * (macd_main[i] - macd_min) / (macd_max - macd_min) - 1;
            inputs[index + 1] = 2 * (macd_signal[i] - macd_min) / (macd_max - macd_min) - 1;
            // Normalize RSI to range [-1, 1]
            inputs[index + 2] = 2 * (rsi[i] / 100.0) - 1;
            // Normalize Stochastic to range [-1, 1]
            inputs[index + 3] = 2 * (stoch_main[i] / 100.0) - 1;
            inputs[index + 4] = 2 * (stoch_signal[i] / 100.0) - 1;
            // Normalize ADX to range [-1, 1]
            inputs[index + 5] = 2 * (adx[i] / 100.0) - 1;
         }

         // Simple target: if conditions for buy are met, set target to [0, 1], if conditions for sell are met, set target to [1, 0], else [0, 0]
         if (i < ArraySize(adx) - 1 && i < ArraySize(macd_main) - 1 && i < ArraySize(macd_signal) - 1 && i < ArraySize(rsi) - 1 && i < ArraySize(stoch_main) - 1 && i < ArraySize(stoch_signal) - 1)
         {
            int targetIndex = i * outputNeurons;
            if (targetIndex + outputNeurons - 1 < ArraySize(targets))  // Add this check to prevent array out of range error
            {
               if (macd_main[i] > macd_signal[i] && rsi[i] > 70 && stoch_main[i] > stoch_signal[i] && adx[i] > 25 && stoch_main[i] > 80 )
               {
                  targets[targetIndex] = 0.0; // Buy signal
                  targets[targetIndex+1] = 1.0;
               }
               else if (macd_main[i] < macd_signal[i] && rsi[i] < 30 && stoch_main[i] < stoch_signal[i] && adx[i] > 25 && stoch_main[i] < 20 )
               {
                  targets[targetIndex] = 1.0; // Sell signal
                  targets[targetIndex+1] = 0.0;
               }
               else
               {
                  targets[targetIndex] = 0.0; // No trade signal
                  targets[targetIndex+1] = 0.0;
               }
            }
         }
      }

      nn.Train(inputs, targets, trainingEpochs, learningRate);

      Print("Neural network training completed.");

      return true;
   }

   void Run(double accountMargin, double maxRiskAmount)
   {
      // Prepare input data
      double inputs[];
      ArrayResize(inputs, inputNeurons);

      // Get indicator values
      double macd_main[], macd_signal[], rsi[], stoch_main[], stoch_signal[], adx[];
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(stoch_main, true);
      ArraySetAsSeries(stoch_signal, true);
      ArraySetAsSeries(adx, true);

      if (CopyBuffer(handle_macd, 0, 0, inputNeurons / 6, macd_main) <= 0 ||
            CopyBuffer(handle_macd, 1, 0, inputNeurons / 6, macd_signal) <= 0 ||
            CopyBuffer(handle_rsi, 0, 0, inputNeurons / 6, rsi) <= 0 ||
            CopyBuffer(handle_stoch, MAIN_LINE, 0, inputNeurons / 6, stoch_main) <= 0 ||
            CopyBuffer(handle_stoch, SIGNAL_LINE, 0, inputNeurons / 6, stoch_signal) <= 0 ||
            CopyBuffer(handle_adx, 0, 0, inputNeurons / 6, adx) <= 0)
      {
         Print("Error copying indicator buffers: ", GetLastError());
         return;
      }

      for (int i = 0; i < inputNeurons / 6; i++)
      {
         int index = i * 6;
         if (index + 5 < ArraySize(inputs))
         {
            double macd_min = MathMin(macd_main[ArrayMinimum(macd_main)], macd_signal[ArrayMinimum(macd_signal)]);
            double macd_max = MathMax(macd_main[ArrayMaximum(macd_main)], macd_signal[ArrayMaximum(macd_signal)]);
            inputs[index] = 2 * (macd_main[i] - macd_min) / (macd_max - macd_min) - 1;
            inputs[index + 1] = 2 * (macd_signal[i] - macd_min) / (macd_max - macd_min) - 1;
            
            // Normalize RSI to range [-1, 1]
            inputs[index + 2] = 2 * (rsi[i] / 100.0) - 1;
            
            // Normalize Stochastic to range [-1, 1]
            inputs[index + 3] = 2 * (stoch_main[i] / 100.0) - 1;
            inputs[index + 4] = 2 * (stoch_signal[i] / 100.0) - 1;
            
            // Normalize ADX to range [-1, 1]
            inputs[index + 5] = 2 * (adx[i] / 100.0) - 1;
         }
      }

      // Feed forward (predict)
      nn.FeedForward(inputs);
      // Get output
      double output[];
      nn.GetOutputs(output);

      // Make trading decision based on output
      if(ArraySize(output) >= 1)
      {
         // Print("output: ", output[0]);
         // Print("Current risk: ", accountMargin, " Max risk amount: ", maxRiskAmount);
         if(output[0] < -0.6 && GlobaltimeOutExpiredSell && accountMargin < maxRiskAmount)
         {
            // Consider opening a sell position
            //Print("Sell signal: ", output[0]);
            openSellOrder();
            GlobaltimeOutExpiredSell = false;
         }
         else if(output[0] > 0.6 && GlobaltimeOutExpiredBuy && accountMargin < maxRiskAmount)
         {
            // Consider opening a buy position
            //Print("Buy signal: ", output[0]);
            openBuyOrder();
            GlobaltimeOutExpiredBuy = false;
         }
      }
      else
      {
         Print("Error: Unexpected number of outputs from neural network. Expected 1, got ", ArraySize(output));
      }

      if(!checkAndCloseSingleProfitOrders())
      {
         Print("Error in checkAndCloseSingleProfitOrders()");
      }
      // Add your trading logic here
   }

   bool checkAndCloseSingleProfitOrders()
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
            //Print("_closeInProfit: ", _closeInProfit, ", singleProfit: ", singleProfit);
            if(singleProfit > _closeInProfit)// && singleProfit < previousProfit-0.5 )
            {
               Print("ticket: ", ticket," singleProfit < previousProfit: ", singleProfit," < ",previousProfit-3 );
               if (_trade.PositionClose(ticket))
               {
                  previousProfits.Remove(ticket);
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

   double profitAllPositions()
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

   bool checkAndCloseAllOrdersForProfit()
   {
      if(PositionSelect(_symbolName))
      {
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentPrice = 0.0;
         double profit = 0.0;

         if(profitAllPositions() > _closeInProfit)
         {
            Print("Garbage collector active!");
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

   int openPos()
   {
      int total=PositionsTotal();
      int count=0;
      for(int cnt=0; cnt<total; cnt++)
      {
         if(PositionSelect(_symbolName))
         {
            count++;
         }
      }
      return(count);
   }

   double calculateCurrentRisk()
   {
      double totalRisk = 0.0;

      Print("OrdersTotal: ", OrdersTotal());

      for(int i = 0; i < openPos(); i++)
      {
         if(OrderGetTicket(i)>0 && OrderGetString(ORDER_SYMBOL) == _symbolName)
         {
            totalRisk += AccountInfoDouble(ACCOUNT_MARGIN);
         }
      }

      return totalRisk;
   }

   bool openBuyOrder()
   {
      double Ask=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
      double Bid=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);
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
   }

   bool openSellOrder()
   {
      double Bid=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_BID),_Digits);
      double Ask=NormalizeDouble(SymbolInfoDouble(_symbolName,SYMBOL_ASK),_Digits);
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
   }

   void closeBuyPosition()
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

   void closeSellPosition()
   {
      for(int i=PositionsTotal()-1; i >= 0; i--)
      {
         if(_myPositionInfo.SelectByIndex(i) && PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL &&  PositionGetString(POSITION_SYMBOL) == _symbolName)
         {
            ulong ticket;
            ticket = _myPositionInfo.Ticket();

            if(!_trade.PositionClose(ticket))
               Print("Error closing sell order: ");
            else
            {
               Print("CloseSellOrder with ticket: ", ticket);
               previousProfits.Remove(ticket);
            }
         }
      }
   }

   void closeAllPosition()
   {
      closeSellPosition();
      closeBuyPosition();
   }

   ~Currency()
   {
      // Release indicator handles
      IndicatorRelease(handle_macd);
      IndicatorRelease(handle_rsi);
      IndicatorRelease(handle_stoch);
      IndicatorRelease(handle_adx);
   }
};
//+------------------------------------------------------------------+

