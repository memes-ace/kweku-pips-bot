
//+------------------------------------------------------------------+
//|                      BTCUSD Sniper Bot.mq5                       |
//|       Auto trade BTCUSD using S&R + Candle Confirmation          |
//|       For Exness - London & NY Sessions - April 2025             |
//+------------------------------------------------------------------+
#property copyright "Rebecca"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
CTrade trade;

//--- input parameters
input string TradingSymbol = "BTCUSD";
input double RiskPercent = 2.0;
input int StopLossPips = 20;
input int TakeProfitPips = 50;
input int MaxTradesPerDay = 4;
input ENUM_TIMEFRAMES EntryTF = PERIOD_M15;
input ENUM_TIMEFRAMES SRTF = PERIOD_H1;

//--- internal variables
datetime lastTradeDay = 0;
int tradesToday = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   lastTradeDay = TimeCurrent();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Main Tick Function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(Symbol() != TradingSymbol) return;

   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);

   // Reset trade counter if new day
   MqlDateTime lastTm;
   TimeToStruct(lastTradeDay, lastTm);
   if (tm.day != lastTm.day)
   {
      tradesToday = 0;
      lastTradeDay = now;
   }

   // Trade only during London or NY session
   if (!IsSession(tm)) return;
   if (tradesToday >= MaxTradesPerDay) return;

   double zoneHigh, zoneLow;
   if (!GetSupportResistanceZone(zoneHigh, zoneLow)) return;

   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lotSize = CalculateLotSize(RiskPercent, StopLossPips);
   if (lotSize < 0.01) lotSize = 0.01;

   if (price <= zoneLow && ConfirmBullishReversal())
   {
      double sl = price - StopLossPips * _Point * 10;
      double tp = price + TakeProfitPips * _Point * 10;
      if (trade.Buy(lotSize, NULL, price, sl, tp, "BTC Buy"))
         tradesToday++;
   }

   if (price >= zoneHigh && ConfirmBearishReversal())
   {
      double sl = price + StopLossPips * _Point * 10;
      double tp = price - TakeProfitPips * _Point * 10;
      if (trade.Sell(lotSize, NULL, price, sl, tp, "BTC Sell"))
         tradesToday++;
   }
}

//+------------------------------------------------------------------+
//| Check if the time is in London (7-10) or NY (13-17)              |
//+------------------------------------------------------------------+
bool IsSession(MqlDateTime &tm)
{
   return ((tm.hour >= 7 && tm.hour < 10) || (tm.hour >= 13 && tm.hour < 17));
}

//+------------------------------------------------------------------+
//| Lot Size Calculation                                             |
//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, int stopLossPips)
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * riskPercent / 100.0;
   double pipValue = 10.0;
   double lotSize = riskAmount / (stopLossPips * pipValue);
   return NormalizeDouble(lotSize, 2);
}

//+------------------------------------------------------------------+
//| Support and Resistance based on H1                               |
//+------------------------------------------------------------------+
bool GetSupportResistanceZone(double &zoneHigh, double &zoneLow)
{
   int bars = 20;
   double high[], low[];
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   if(CopyHigh(_Symbol, SRTF, 1, bars, high) <= 0) return false;
   if(CopyLow(_Symbol, SRTF, 1, bars, low) <= 0) return false;
   double highest = high[ArrayMaximum(high, 0, bars)];
   double lowest = low[ArrayMinimum(low, 0, bars)];
   double range = highest - lowest;
   zoneHigh = highest - 0.2 * range;
   zoneLow = lowest + 0.2 * range;
   return true;
}

//+------------------------------------------------------------------+
//| Bullish Engulfing / Pin Bar Confirmation                         |
//+------------------------------------------------------------------+
bool ConfirmBullishReversal()
{
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   if(CopyOpen(_Symbol, EntryTF, 0, 2, open) <= 0) return false;
   if(CopyClose(_Symbol, EntryTF, 0, 2, close) <= 0) return false;
   double o0 = open[0], c0 = close[0];
   double o1 = open[1], c1 = close[1];
   return (c0 > o0 && o0 < c1 && c0 > o1);
}

//+------------------------------------------------------------------+
//| Bearish Engulfing / Shooting Star Confirmation                   |
//+------------------------------------------------------------------+
bool ConfirmBearishReversal()
{
   double open[], close[];
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(close, true);
   if(CopyOpen(_Symbol, EntryTF, 0, 2, open) <= 0) return false;
   if(CopyClose(_Symbol, EntryTF, 0, 2, close) <= 0) return false;
   double o0 = open[0], c0 = close[0];
   double o1 = open[1], c1 = close[1];
   return (c0 < o0 && o0 > c1 && c0 < o1);
}
