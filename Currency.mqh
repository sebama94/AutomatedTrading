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
   int batchSize;

public:
   Currency(int &layers[], int numLayers, int inpTrainingEpochs, double inpLearningRate,
            string symbolName, double lotSize, double closeInProfit, int inpBatchSize)
   {
      if(numLayers < 2)
      {
         Print("Error: Neural network must have at least 2 layers");
         return;
      }

      inputNeurons = layers[0];
      outputNeurons = layers[numLayers-1];
      trainingEpochs = inpTrainingEpochs;
      learningRate = inpLearningRate;
      _symbolName = symbolName;
      _lotSize = lotSize;
      _closeInProfit = closeInProfit;
      batchSize = inpBatchSize;

      // Initialize the neural network
      if(!nn.Initialize(layers, numLayers))
      {
         Print("Failed to initialize neural network");
         return;
      }
      nn.BuildModel(layers, numLayers);
   }

   bool Init()
   {
      // Initialize indicators
      handle_macd = iMACD(_symbolName, PERIOD_M30, 12, 26, 9, PRICE_CLOSE);
      handle_rsi = iRSI(_symbolName, PERIOD_M30, 14, PRICE_CLOSE);
      handle_stoch = iStochastic(_symbolName, PERIOD_M30, 5, 3, 3, MODE_SMA, STO_LOWHIGH);
      if(handle_macd == INVALID_HANDLE || handle_rsi == INVALID_HANDLE || handle_stoch == INVALID_HANDLE)
      {
         Print("Failed to create indicators");
         return false;
      }
      Sleep(5000);

      // Prepare training data
      double inputs[];
      double targets[];
      ArrayResize(inputs, inputNeurons * batchSize);
      ArrayResize(targets, outputNeurons * batchSize);
      // Initialize targets with -555
      ArrayInitialize(targets, 0);
      ArrayInitialize(inputs, -444);

      // Get historical data for training
      double macd_main[];
      double macd_signal[];
      double rsi[];
      double stoch_main[];
      double stoch_signal[];
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(stoch_main, true);
      ArraySetAsSeries(stoch_signal, true);
      if (CopyBuffer(handle_macd, 0, 1, inputNeurons / 5 * batchSize, macd_main) <= 0 ||
            CopyBuffer(handle_macd, 1, 1, inputNeurons / 5 * batchSize, macd_signal) <= 0 ||
            CopyBuffer(handle_rsi, 0, 1, inputNeurons / 5 * batchSize, rsi) <= 0 ||
            CopyBuffer(handle_stoch, 0, 1, inputNeurons / 5 * batchSize, stoch_main) <= 0 ||
            CopyBuffer(handle_stoch, 1, 1, inputNeurons / 5 * batchSize, stoch_signal) <= 0)
      {
         Print("Error copying indicator buffers in Init: ", GetLastError());
         return false;
      }

      // Print the indicator values
      string macd_main_str = "", macd_signal_str = "", rsi_str = "", stoch_main_str = "", stoch_signal_str = "";
      for (int i = 0; i < ArraySize(macd_main) && i < 10; i++)
      {
         macd_main_str += (string)macd_main[i] + " ";
         macd_signal_str += (string)macd_signal[i] + " ";
         rsi_str += (string)rsi[i] + " ";
         stoch_main_str += (string)stoch_main[i] + " ";
         stoch_signal_str += (string)stoch_signal[i] + " ";
      }
      Print("MACD Main: ", macd_main_str);
      Print("MACD Signal: ", macd_signal_str);
      Print("RSI: ", rsi_str);
      Print("Stochastic Main: ", stoch_main_str);
      Print("Stochastic Signal: ", stoch_signal_str);

 
      for (int b = 0; b < batchSize; b++)
      {
         for (int i = 0; i < inputNeurons / 5; i++)
         {
            int index = b * inputNeurons + i * 5;
            if (index + 4 < ArraySize(inputs))
            {
               // Normalize MACD
               double macd_min = MathMin(macd_main[ArrayMinimum(macd_main)], macd_signal[ArrayMinimum(macd_signal)]);
               double macd_max = MathMax(macd_main[ArrayMaximum(macd_main)], macd_signal[ArrayMaximum(macd_signal)]);
               inputs[index] = (macd_main[b * inputNeurons / 5 + i] - macd_min) / (macd_max - macd_min);
               inputs[index + 1] = (macd_signal[b * inputNeurons / 5 + i] - macd_min) / (macd_max - macd_min);
               
               // Normalize RSI (already in range 0-100)
               inputs[index + 2] = rsi[b * inputNeurons / 5 + i] / 100.0;
               
               // Normalize Stochastic (already in range 0-100)
               inputs[index + 3] = stoch_main[b * inputNeurons / 5 + i] / 100.0;
               inputs[index + 4] = stoch_signal[b * inputNeurons / 5 + i] / 100.0;
            }

            // Simple target: if the next MACD histogram is positive and RSI > 50, set target to [0, 1],
            // if negative and RSI < 50 [1, 0]
            int targetIndex = b * outputNeurons;
            if (b * inputNeurons / 5 + i < ArraySize(macd_main) && 
                b * inputNeurons / 5 + i < ArraySize(macd_signal) && 
                b * inputNeurons / 5 + i < ArraySize(rsi) && 
                b * inputNeurons / 5 + i < ArraySize(stoch_main) &&
                b * inputNeurons / 5 + i < ArraySize(stoch_signal))
            {
               if (macd_main[b * inputNeurons / 5 + i] > macd_signal[b * inputNeurons / 5 + i] && 
                   rsi[b * inputNeurons / 5 + i] > 70 && 
                   stoch_main[b * inputNeurons / 5 + i] > stoch_signal[b * inputNeurons / 5 + i])
               {
                  targets[targetIndex] = 0.0;
                  targets[targetIndex + 1] = 1.0;
               }
               else if (macd_main[b * inputNeurons / 5 + i] < macd_signal[b * inputNeurons / 5 + i] && 
                        rsi[b * inputNeurons / 5 + i] < 30 && 
                        stoch_main[b * inputNeurons / 5 + i] < stoch_signal[b * inputNeurons / 5 + i])
               {
                  targets[targetIndex] = 1.0;
                  targets[targetIndex + 1] = 0.0;
               }
            }
         }
      }

      // Train the neural network with batch
      nn.Train(inputs, targets, trainingEpochs, learningRate, batchSize);

      Print("Neural network training completed.");

      return true;
   }

   void Run(double accountMargin, double maxRiskAmount)
   {
      // Prepare input data
      double inputs[];
      ArrayResize(inputs, inputNeurons);

      // Get indicator values
      double macd_main[], macd_signal[], rsi[], stoch_main[], stoch_signal[];
      ArraySetAsSeries(macd_main, true);
      ArraySetAsSeries(macd_signal, true);
      ArraySetAsSeries(rsi, true);
      ArraySetAsSeries(stoch_main, true);
      ArraySetAsSeries(stoch_signal, true);

      if (CopyBuffer(handle_macd, 0, 0, inputNeurons / 5, macd_main) <= 0 ||
            CopyBuffer(handle_macd, 1, 0, inputNeurons / 5, macd_signal) <= 0 ||
            CopyBuffer(handle_rsi, 0, 0, inputNeurons / 5, rsi) <= 0 ||
            CopyBuffer(handle_stoch, 0, 0, inputNeurons / 5, stoch_main) <= 0 ||
            CopyBuffer(handle_stoch, 1, 0, inputNeurons / 5, stoch_signal) <= 0)
      {
         Print("Error copying indicator buffers: ", GetLastError());
         return;
      }

      for (int i = 0; i < inputNeurons / 5; i++)
      {
         int index = i * 5;
         if (index + 4 < ArraySize(inputs))
         {
            double macd_min = MathMin(macd_main[ArrayMinimum(macd_main)], macd_signal[ArrayMinimum(macd_signal)]);
            double macd_max = MathMax(macd_main[ArrayMaximum(macd_main)], macd_signal[ArrayMaximum(macd_signal)]);
            inputs[index] = (macd_main[i] - macd_min) / (macd_max - macd_min);
            inputs[index + 1] = (macd_signal[i] - macd_min) / (macd_max - macd_min);
            
            // Normalize RSI (already in range 0-100)
            inputs[index + 2] = rsi[i] / 100.0;
            
            // Normalize Stochastic (already in range 0-100)
            inputs[index + 3] = stoch_main[i] / 100.0;
            inputs[index + 4] = stoch_signal[i] / 100.0;
         }
      }

      // Feed forward (predict)
      nn.FeedForward(inputs);

      // Get outputs
      double outputs[];
      nn.GetOutputs(outputs);

      // Make trading decision based on outputs
      if(ArraySize(outputs) >= 2)
      {
         // Print("outputs[0]: ", outputs[0], " outputs[1] ", outputs[1]);
         // Print("Current risk: ", accountMargin, " Max risk amount: ", maxRiskAmount);
         if(outputs[0] > outputs[1] && outputs[0] > 0.6 && GlobaltimeOutExpiredSell && accountMargin < maxRiskAmount)
         {
            // Consider opening a sell position
            //Print("Sell signal: ", outputs[0], " > ", outputs[1]);
            openSellOrder();
            GlobaltimeOutExpiredSell = false;
         }
         else if(outputs[1] > outputs[0] && outputs[1] > 0.6 && GlobaltimeOutExpiredBuy && accountMargin < maxRiskAmount)
         {
            // Consider opening a buy position
            //Print("Buy signal: ", outputs[1], " > ", outputs[0]);
            openBuyOrder();
            GlobaltimeOutExpiredBuy = false;
         }
      }
      else
      {
         Print("Error: Unexpected number of outputs from neural network. Expected 2, got ", ArraySize(outputs));
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
   }
};
//+------------------------------------------------------------------+
