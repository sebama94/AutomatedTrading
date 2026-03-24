//+------------------------------------------------------------------+
//| Backtest.mq5                                                     |
//| Analisi statistica post-backtest per Strategy Tester            |
//| Metriche: Win Rate, Profit Factor, Max DD, Sharpe, Calmar       |
//+------------------------------------------------------------------+
#property copyright "2024"
#property version   "1.00"
#property strict

//=== PARAMETRI ===
input string InpSymbol       = "EURUSD";  // Simbolo
input ulong  InpMagic        = 20240001;  // Magic number da analizzare
input int    InpMinTrades    = 30;        // Minimo trade per risultati affidabili

//--- Statistiche calcolate
struct BacktestStats
{
   int    totalTrades;
   int    winTrades;
   int    lossTrades;
   double winRate;
   double profitFactor;
   double totalPnL;
   double grossProfit;
   double grossLoss;
   double maxDrawdown;
   double sharpeRatio;
   double calmarRatio;
   double avgWin;
   double avgLoss;
   double expectancy;
};

int OnInit()
{
   // Seleziona tutto lo storico ordini
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("Backtest: impossibile selezionare storico");
      return INIT_FAILED;
   }

   BacktestStats stats;
   ZeroMemory(stats);

   if(!ComputeStats(stats))
   {
      Print("Backtest: calcolo statistiche fallito (trades insufficienti: ",
            stats.totalTrades, " < ", InpMinTrades, ")");
      return INIT_FAILED;
   }

   PrintStats(stats);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason) {}
void OnTick() {}

//+------------------------------------------------------------------+
//| Calcola tutte le statistiche dai deal storici                    |
//+------------------------------------------------------------------+
bool ComputeStats(BacktestStats &s)
{
   int totalDeals = HistoryDealsTotal();
   if(totalDeals <= 0) return false;

   // Array per equity curve (per Sharpe e Max DD)
   double equityCurve[];
   int    equitySize = 0;

   double runningBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double peakEquity     = runningBalance;
   double maxDD          = 0.0;

   for(int i = 0; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;

      // Filtra per magic number e simbolo
      if((ulong)HistoryDealGetInteger(ticket, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != InpSymbol) continue;

      // Considera solo i deal di chiusura (DEAL_ENTRY_OUT)
      ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT) continue;

      double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT)
                    + HistoryDealGetDouble(ticket, DEAL_SWAP)
                    + HistoryDealGetDouble(ticket, DEAL_COMMISSION);

      s.totalTrades++;
      s.totalPnL += profit;
      runningBalance += profit;

      // Equity curve per Sharpe
      ArrayResize(equityCurve, equitySize + 1);
      equityCurve[equitySize++] = profit;

      if(profit > 0)
      {
         s.winTrades++;
         s.grossProfit += profit;
      }
      else
      {
         s.lossTrades++;
         s.grossLoss += MathAbs(profit);
      }

      // Max Drawdown
      if(runningBalance > peakEquity) peakEquity = runningBalance;
      double dd = (peakEquity > 0) ? (peakEquity - runningBalance) / peakEquity : 0;
      if(dd > maxDD) maxDD = dd;
   }

   if(s.totalTrades < InpMinTrades) return false;

   // Win Rate
   s.winRate = (s.totalTrades > 0) ? (double)s.winTrades / s.totalTrades : 0;

   // Profit Factor
   s.profitFactor = (s.grossLoss > 0) ? s.grossProfit / s.grossLoss : (s.grossProfit > 0 ? 99.0 : 0.0);

   // Max Drawdown
   s.maxDrawdown = maxDD;

   // Avg Win / Avg Loss
   s.avgWin  = (s.winTrades  > 0) ? s.grossProfit / s.winTrades  : 0;
   s.avgLoss = (s.lossTrades > 0) ? s.grossLoss   / s.lossTrades : 0;

   // Expectancy per trade: E = (winRate * avgWin) - (lossRate * avgLoss)
   s.expectancy = s.winRate * s.avgWin - (1.0 - s.winRate) * s.avgLoss;

   // Sharpe Ratio (annualizzato su M30: ~17520 barre/anno)
   if(equitySize > 1)
   {
      double mean = 0, variance = 0;
      for(int j = 0; j < equitySize; j++) mean += equityCurve[j];
      mean /= equitySize;
      for(int j = 0; j < equitySize; j++)
      {
         double d = equityCurve[j] - mean;
         variance += d * d;
      }
      variance /= (equitySize - 1);
      double stddev = MathSqrt(variance);
      // Annualizzazione: sqrt(17520 barre M30 per anno)
      s.sharpeRatio = (stddev > 1e-10) ? (mean / stddev) * MathSqrt(17520.0) : 0;
   }

   // Calmar Ratio = CAGR / Max DD
   // Approssimazione: totalPnL come CAGR proxy (rapporto lineare)
   double startBalance = AccountInfoDouble(ACCOUNT_BALANCE) - s.totalPnL;
   if(startBalance > 0 && s.maxDrawdown > 1e-10)
   {
      double totalReturn = s.totalPnL / startBalance;
      s.calmarRatio = totalReturn / s.maxDrawdown;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Stampa report completo nel log                                   |
//+------------------------------------------------------------------+
void PrintStats(const BacktestStats &s)
{
   string sep = "═══════════════════════════════════════════";
   Print(sep);
   Print("  BACKTEST REPORT — ", InpSymbol, " | Magic=", InpMagic);
   Print(sep);
   PrintFormat("  Trades totali    : %d  (wins=%d  losses=%d)",
               s.totalTrades, s.winTrades, s.lossTrades);
   PrintFormat("  Win Rate         : %.1f%%", s.winRate * 100);
   PrintFormat("  Profit Factor    : %.3f", s.profitFactor);
   PrintFormat("  Total PnL        : %.2f USD", s.totalPnL);
   PrintFormat("  Gross Profit     : %.2f  Gross Loss: %.2f", s.grossProfit, s.grossLoss);
   PrintFormat("  Avg Win          : %.2f  Avg Loss: %.2f", s.avgWin, s.avgLoss);
   PrintFormat("  Expectancy/trade : %.2f USD", s.expectancy);
   PrintFormat("  Max Drawdown     : %.2f%%", s.maxDrawdown * 100);
   PrintFormat("  Sharpe Ratio     : %.3f  (annualizzato M30)", s.sharpeRatio);
   PrintFormat("  Calmar Ratio     : %.3f", s.calmarRatio);
   Print(sep);

   // Valutazione qualitativa
   string verdict = "";
   if(s.profitFactor >= 1.5 && s.sharpeRatio >= 1.0 && s.winRate >= 0.45)
      verdict = "BUONO — sistema promettente";
   else if(s.profitFactor >= 1.2 && s.winRate >= 0.40)
      verdict = "DISCRETO — margini stretti, ottimizzare";
   else
      verdict = "INSUFFICIENTE — rivedere strategia";

   Print("  Verdetto         : ", verdict);
   Print(sep);
}
