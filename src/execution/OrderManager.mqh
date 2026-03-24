//+------------------------------------------------------------------+
//| OrderManager.mqh                                                 |
//| Esecuzione ordini con filtri professionali:                      |
//|   - Filtro spread (salta se spread > soglia)                     |
//|   - Filtro sessione (London + NY, evita Asian illiquida)         |
//|   - Slippage massimo                                             |
//|   - Magic number per identificazione EA                          |
//|   - Trailing stop basato su ATR                                  |
//+------------------------------------------------------------------+
#pragma once

#include <Trade\Trade.mqh>
#include <Trade\PositionInfo.mqh>

class OrderManager
{
private:
   string        _sym;
   ulong         _magic;
   double        _maxSpreadPips;   // spread massimo in pips per entrare
   double        _slippagePips;    // slippage massimo accettato
   bool          _tradeLondon;
   bool          _tradeNewYork;
   bool          _tradeAsian;
   double        _trailATRMult;    // moltiplicatore ATR per trailing stop
   int           _hATR;

   CTrade        _trade;
   CPositionInfo _posInfo;

public:
   OrderManager();
   ~OrderManager() { if(_hATR != INVALID_HANDLE) IndicatorRelease(_hATR); }

   bool Init(string symbol, ulong magic,
             double maxSpreadPips = 2.0,
             double slippagePips  = 1.0,
             bool   tradeLondon   = true,
             bool   tradeNewYork  = true,
             bool   tradeAsian    = false,
             double trailATRMult  = 1.5);

   // Filtri
   bool IsGoodTimeToTrade();
   bool IsSpreadOk();
   bool CanOpenNew();            // sessione + spread

   // Apertura ordini (entry = 0 → market order)
   bool OpenBuy(double lots, double sl, double tp, string comment = "");
   bool OpenSell(double lots, double sl, double tp, string comment = "");

   // Gestione posizioni aperte
   void ManageOpenPositions();   // trailing stop + take profit parziale
   void CloseAll();
   void CloseByTicket(ulong ticket);
   void CloseProfitable(double minProfit);

   // Info
   int    CountPositions();
   double TotalFloatingPnL();

private:
   bool IsLondonSession();
   bool IsNewYorkSession();
   bool IsAsianSession();
   double GetATR();
};

OrderManager::OrderManager()
{
   _sym          = "";
   _magic        = 0;
   _maxSpreadPips = 2.0;
   _slippagePips  = 1.0;
   _tradeLondon  = true;
   _tradeNewYork = true;
   _tradeAsian   = false;
   _trailATRMult = 1.5;
   _hATR         = INVALID_HANDLE;
}

bool OrderManager::Init(string symbol, ulong magic, double maxSpreadPips,
                         double slippagePips, bool tradeLondon,
                         bool tradeNewYork, bool tradeAsian, double trailATRMult)
{
   _sym          = symbol;
   _magic        = magic;
   _maxSpreadPips = maxSpreadPips;
   _slippagePips  = slippagePips;
   _tradeLondon  = tradeLondon;
   _tradeNewYork = tradeNewYork;
   _tradeAsian   = tradeAsian;
   _trailATRMult = trailATRMult;

   _trade.SetExpertMagicNumber(magic);
   _trade.SetDeviationInPoints((ulong)(slippagePips * 10)); // 5-digit quotes

   _hATR = iATR(symbol, PERIOD_H1, 14);
   if(_hATR == INVALID_HANDLE)
   {
      Print("OrderManager: impossibile creare handle ATR");
      return false;
   }
   return true;
}

bool OrderManager::IsLondonSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return (dt.hour >= 7 && dt.hour < 16); // 07:00-16:00 GMT
}

bool OrderManager::IsNewYorkSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return (dt.hour >= 13 && dt.hour < 21); // 13:00-21:00 GMT
}

bool OrderManager::IsAsianSession()
{
   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);
   return (dt.hour >= 0 && dt.hour < 7); // 00:00-07:00 GMT
}

bool OrderManager::IsGoodTimeToTrade()
{
   if(_tradeLondon  && IsLondonSession())  return true;
   if(_tradeNewYork && IsNewYorkSession()) return true;
   if(_tradeAsian   && IsAsianSession())   return true;
   return false;
}

bool OrderManager::IsSpreadOk()
{
   double spread    = (double)SymbolInfoInteger(_sym, SYMBOL_SPREAD);
   double pipPoints = 10.0; // per 5-digit quotes, 1 pip = 10 points
   return (spread / pipPoints) <= _maxSpreadPips;
}

bool OrderManager::CanOpenNew()
{
   return IsGoodTimeToTrade() && IsSpreadOk();
}

bool OrderManager::OpenBuy(double lots, double sl, double tp, string comment)
{
   double ask = SymbolInfoDouble(_sym, SYMBOL_ASK);
   if(!_trade.Buy(lots, _sym, ask, sl, tp, comment))
   {
      Print("OrderManager: BUY fallito (", _trade.ResultRetcode(), ") spread=",
            SymbolInfoInteger(_sym, SYMBOL_SPREAD));
      return false;
   }
   Print("BUY aperto | lots=", lots, " ask=", ask, " SL=", sl, " TP=", tp);
   return true;
}

bool OrderManager::OpenSell(double lots, double sl, double tp, string comment)
{
   double bid = SymbolInfoDouble(_sym, SYMBOL_BID);
   if(!_trade.Sell(lots, _sym, bid, sl, tp, comment))
   {
      Print("OrderManager: SELL fallito (", _trade.ResultRetcode(), ") spread=",
            SymbolInfoInteger(_sym, SYMBOL_SPREAD));
      return false;
   }
   Print("SELL aperto | lots=", lots, " bid=", bid, " SL=", sl, " TP=", tp);
   return true;
}

//--- Gestione trailing stop e chiusura parziale
void OrderManager::ManageOpenPositions()
{
   double atr = GetATR();
   if(atr <= 0) return;

   double trailDist = atr * _trailATRMult;
   int    digits    = (int)SymbolInfoInteger(_sym, SYMBOL_DIGITS);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!_posInfo.SelectByIndex(i)) continue;
      if(_posInfo.Symbol() != _sym)  continue;
      if(_posInfo.Magic()  != _magic) continue;

      ulong  ticket  = _posInfo.Ticket();
      double openP   = _posInfo.PriceOpen();
      double curSL   = _posInfo.StopLoss();

      if(_posInfo.Type() == POSITION_TYPE_BUY)
      {
         double bid    = SymbolInfoDouble(_sym, SYMBOL_BID);
         double newSL  = NormalizeDouble(bid - trailDist, digits);
         // Sposta SL solo se migliora e supera il break-even
         if(newSL > curSL && newSL > openP)
            _trade.PositionModify(ticket, newSL, _posInfo.TakeProfit());
      }
      else if(_posInfo.Type() == POSITION_TYPE_SELL)
      {
         double ask    = SymbolInfoDouble(_sym, SYMBOL_ASK);
         double newSL  = NormalizeDouble(ask + trailDist, digits);
         if(newSL < curSL && newSL < openP)
            _trade.PositionModify(ticket, newSL, _posInfo.TakeProfit());
      }
   }
}

void OrderManager::CloseAll()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(_posInfo.SelectByIndex(i) && _posInfo.Symbol() == _sym && _posInfo.Magic() == _magic)
         _trade.PositionClose(_posInfo.Ticket());
}

void OrderManager::CloseByTicket(ulong ticket)
{
   _trade.PositionClose(ticket);
}

void OrderManager::CloseProfitable(double minProfit)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(!_posInfo.SelectByIndex(i)) continue;
      if(_posInfo.Symbol() != _sym)  continue;
      if(_posInfo.Magic()  != _magic) continue;
      double pnl = _posInfo.Commission() + _posInfo.Swap() + _posInfo.Profit();
      if(pnl >= minProfit)
         _trade.PositionClose(_posInfo.Ticket());
   }
}

int OrderManager::CountPositions()
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(_posInfo.SelectByIndex(i) && _posInfo.Symbol() == _sym && _posInfo.Magic() == _magic)
         n++;
   return n;
}

double OrderManager::TotalFloatingPnL()
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(_posInfo.SelectByIndex(i) && _posInfo.Symbol() == _sym && _posInfo.Magic() == _magic)
         total += _posInfo.Commission() + _posInfo.Swap() + _posInfo.Profit();
   return total;
}

double OrderManager::GetATR()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(_hATR != INVALID_HANDLE && CopyBuffer(_hATR, 0, 1, 1, atr) > 0)
      return atr[0];
   return 0;
}
