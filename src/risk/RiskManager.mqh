//+------------------------------------------------------------------+
//| RiskManager.mqh                                                  |
//| Gestione del rischio professionale:                              |
//|   - Position sizing basato su ATR e rischio fisso per trade      |
//|   - Limite perdita giornaliera                                   |
//|   - Circuit breaker su drawdown massimo                          |
//|   - Tracciamento drawdown in tempo reale                         |
//+------------------------------------------------------------------+
#pragma once

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

class RiskManager
{
private:
   string        _sym;
   double        _riskPerTrade;    // frazione del balance per trade (es. 0.01 = 1%)
   double        _maxDailyLossPct; // perdita max giornaliera (es. 0.03 = 3%)
   double        _maxDrawdownPct;  // drawdown max per circuit breaker (es. 0.10 = 10%)
   double        _atrMultiplier;   // moltiplicatore ATR per SL (es. 2.0)
   int           _atrPeriod;       // periodo ATR
   int           _hATR;            // handle ATR

   double        _peakBalance;     // per calcolo drawdown
   double        _dailyStartBal;   // balance inizio giornata
   datetime      _lastDayCheck;    // ultimo reset giornaliero
   bool          _circuitOpen;     // true = trading bloccato

   CTrade        _trade;
   CPositionInfo _posInfo;

public:
   RiskManager();
   ~RiskManager() { if(_hATR != INVALID_HANDLE) IndicatorRelease(_hATR); }

   bool Init(string symbol,
             double riskPerTrade    = 0.01,
             double maxDailyLossPct = 0.03,
             double maxDrawdownPct  = 0.10,
             double atrMultiplier   = 2.0,
             int    atrPeriod       = 14);

   // Chiama ogni tick per aggiornare drawdown e daily loss
   void Update();

   // Ritorna true se è sicuro aprire nuovi trade
   bool CanTrade();

   // Calcola SL in price distance basato su ATR
   double CalcStopLossPrice(ENUM_ORDER_TYPE direction);

   // Calcola lot size in base al rischio e alla distanza SL
   double CalcLotSize(double slPrice, double entryPrice);

   // Stato
   double GetCurrentDrawdown();       // 0.0 - 1.0
   double GetDailyPnLPct();           // positivo = profitto
   bool   IsCircuitOpen()             { return _circuitOpen; }
   string GetStatusString();

   // Chiude tutte le posizioni (emergency)
   void EmergencyCloseAll();
};

RiskManager::RiskManager()
{
   _sym             = "";
   _riskPerTrade    = 0.01;
   _maxDailyLossPct = 0.03;
   _maxDrawdownPct  = 0.10;
   _atrMultiplier   = 2.0;
   _atrPeriod       = 14;
   _hATR            = INVALID_HANDLE;
   _peakBalance     = 0;
   _dailyStartBal   = 0;
   _lastDayCheck    = 0;
   _circuitOpen     = false;
}

bool RiskManager::Init(string symbol, double riskPerTrade, double maxDailyLossPct,
                       double maxDrawdownPct, double atrMultiplier, int atrPeriod)
{
   _sym             = symbol;
   _riskPerTrade    = riskPerTrade;
   _maxDailyLossPct = maxDailyLossPct;
   _maxDrawdownPct  = maxDrawdownPct;
   _atrMultiplier   = atrMultiplier;
   _atrPeriod       = atrPeriod;

   _hATR = iATR(symbol, PERIOD_H1, atrPeriod); // H1 ATR per SL più stabile
   if(_hATR == INVALID_HANDLE)
   {
      Print("RiskManager: impossibile creare handle ATR");
      return false;
   }

   _peakBalance   = AccountInfoDouble(ACCOUNT_BALANCE);
   _dailyStartBal = _peakBalance;
   _lastDayCheck  = TimeCurrent();
   _circuitOpen   = false;

   Print("RiskManager inizializzato | risk=", _riskPerTrade * 100, "%/trade",
         " | max_daily=", _maxDailyLossPct * 100, "%",
         " | max_dd=", _maxDrawdownPct * 100, "%");
   return true;
}

void RiskManager::Update()
{
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // Aggiorna peak (high watermark)
   if(equity > _peakBalance) _peakBalance = equity;

   // Reset giornaliero (alla mezzanotte del broker)
   MqlDateTime now, last;
   TimeToStruct(TimeCurrent(),    now);
   TimeToStruct(_lastDayCheck,    last);
   if(now.day != last.day)
   {
      _dailyStartBal = balance;
      _lastDayCheck  = TimeCurrent();
      Print("RiskManager: reset giornaliero | balance=", balance);
   }

   // Controlla circuit breaker
   if(!_circuitOpen)
   {
      if(GetCurrentDrawdown() >= _maxDrawdownPct)
      {
         _circuitOpen = true;
         Print("⚠ CIRCUIT BREAKER ATTIVATO: drawdown=",
               DoubleToString(GetCurrentDrawdown() * 100, 1), "% >= ",
               _maxDrawdownPct * 100, "%");
         EmergencyCloseAll();
      }
      else if(GetDailyPnLPct() <= -_maxDailyLossPct)
      {
         _circuitOpen = true;
         Print("⚠ LIMITE GIORNALIERO RAGGIUNTO: PnL=",
               DoubleToString(GetDailyPnLPct() * 100, 1), "%");
      }
   }
   else
   {
      // Reset circuit breaker al nuovo giorno (opzionale)
      MqlDateTime cd;
      TimeToStruct(TimeCurrent(), cd);
      if(cd.hour == 0 && cd.min < 5)
      {
         _circuitOpen = false;
         Print("RiskManager: circuit breaker resettato al nuovo giorno");
      }
   }
}

bool RiskManager::CanTrade()
{
   return !_circuitOpen;
}

double RiskManager::CalcStopLossPrice(ENUM_ORDER_TYPE direction)
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(_hATR, 0, 1, 1, atr) <= 0 || atr[0] <= 0)
   {
      // Fallback: usa 50 punti
      double pt = SymbolInfoDouble(_sym, SYMBOL_POINT);
      atr[0] = 50 * pt;
   }

   double sl_dist  = atr[0] * _atrMultiplier;
   double ask      = SymbolInfoDouble(_sym, SYMBOL_ASK);
   double bid      = SymbolInfoDouble(_sym, SYMBOL_BID);

   if(direction == ORDER_TYPE_BUY)
      return NormalizeDouble(ask - sl_dist, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));
   else
      return NormalizeDouble(bid + sl_dist, (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS));
}

double RiskManager::CalcLotSize(double slPrice, double entryPrice)
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * _riskPerTrade;

   double slDist = MathAbs(entryPrice - slPrice);
   if(slDist < 1e-10) return SymbolInfoDouble(_sym, SYMBOL_VOLUME_MIN);

   double tickSize  = SymbolInfoDouble(_sym, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_sym, SYMBOL_TRADE_TICK_VALUE);
   if(tickSize <= 0 || tickValue <= 0) return SymbolInfoDouble(_sym, SYMBOL_VOLUME_MIN);

   // Rischio monetario per 1 lot = (sl_dist / tick_size) * tick_value
   double riskPerLot = (slDist / tickSize) * tickValue;
   if(riskPerLot <= 0) return SymbolInfoDouble(_sym, SYMBOL_VOLUME_MIN);

   double lotStep = SymbolInfoDouble(_sym, SYMBOL_VOLUME_STEP);
   double lotMin  = SymbolInfoDouble(_sym, SYMBOL_VOLUME_MIN);
   double lotMax  = SymbolInfoDouble(_sym, SYMBOL_VOLUME_MAX);

   double lots = riskAmount / riskPerLot;
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(lotMin, MathMin(lotMax, lots));

   return lots;
}

double RiskManager::GetCurrentDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(_peakBalance <= 0) return 0;
   double dd = (_peakBalance - equity) / _peakBalance;
   return MathMax(0.0, dd);
}

double RiskManager::GetDailyPnLPct()
{
   if(_dailyStartBal <= 0) return 0;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return (equity - _dailyStartBal) / _dailyStartBal;
}

string RiskManager::GetStatusString()
{
   return StringFormat("DD=%.1f%% | Daily=%.1f%% | Circuit=%s",
                       GetCurrentDrawdown() * 100,
                       GetDailyPnLPct() * 100,
                       _circuitOpen ? "OPEN" : "OK");
}

void RiskManager::EmergencyCloseAll()
{
   Print("RiskManager: chiusura emergenza di tutte le posizioni");
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(_posInfo.SelectByIndex(i) && _posInfo.Symbol() == _sym)
      {
         if(!_trade.PositionClose(_posInfo.Ticket()))
            Print("Errore chiusura pos. ", _posInfo.Ticket(), ": ", _trade.ResultRetcode());
      }
   }
}
