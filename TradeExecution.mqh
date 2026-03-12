//+------------------------------------------------------------------+
//|                                                      TradeExecution.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for breakout strategy                           |
//+------------------------------------------------------------------+
enum ENUM_BREAKOUT_TYPE
{
   BREAKOUT_RANGE,      // Range
   BREAKOUT_BOLLINGER,  // Bollinger Bands
   BREAKOUT_ATR         // ATR
};

input ENUM_BREAKOUT_TYPE BreakoutType = BREAKOUT_RANGE;          // Breakout type
input bool               AllowLong = true;                       // Allow long positions
input bool               AllowShort = true;                      // Allow short positions
input bool               RequireVolumeConfirm = true;            // Require volume confirmation
input bool               RequireRetest = false;                  // Wait for retest before entry
input ENUM_TIMEFRAMES    RangeTF = PERIOD_D1;                    // Timeframe for range calculation
input int                TrendFilterEMA = 200;                   // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES    ExecTF = PERIOD_M15;                    // Timeframe for trade execution

//+------------------------------------------------------------------+
//| Input parameters for news filter                                 |
//+------------------------------------------------------------------+
input bool               UseNewsFilter = true;                   // Enable economic news filter
input int                NewsMinutesBefore = 60;                 // Minutes before news to suspend trading
input int                NewsMinutesAfter = 30;                  // Minutes after news to resume trading
input int                NewsImpactLevel = 3;                    // Minimum impact level: 1=low, 2=medium, 3=high
input bool               CloseOnHighImpact = true;               // Close positions before high impact news

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input bool               UseATRFilter = true;                    // Enable ATR filter
input int                ATRPeriod = 14;                         // ATR period
input double             MinATRPips = 20.0;                      // Minimum ATR required (pips)
input double             MaxATRPips = 150.0;                     // Maximum ATR allowed (pips)
input double             ATR_Mult_Min = 1.25;                    // Minimum ATR multiplier for breakout validation
input double             ATR_Mult_Max = 3.0;                     // Maximum ATR multiplier for breakout validation

input bool               UseBBFilter = true;                     // Enable Bollinger Bands filter
input int                BBPeriod = 20;                          // Bollinger Bands period
input double             BBDeviation = 2.0;                      // Bollinger Bands standard deviation
input double             Min_Width_Pips = 30.0;                  // Minimum BB width (pips)
input double             Max_Width_Pips = 120.0;                 // Maximum BB width (pips)

input bool               UseEMAFilter = true;                    // Enable EMA filter
input int                EMAPeriod = 200;                        // EMA period for trend filter
input ENUM_TIMEFRAMES    EMATf = PERIOD_H1;                      // EMA timeframe

input bool               UseADXFilter = true;                    // Enable ADX filter
input int                ADXPeriod = 14;                         // ADX period
input double             ADXThreshold = 20.0;                    // Minimum ADX threshold

input bool               UseRSIFilter = false;                   // Enable RSI filter
input int                RSIPeriod = 14;                         // RSI period
input double             RSIOverbought = 70.0;                   // RSI overbought level (do not buy above)
input double             RSIOversold = 30.0;                     // RSI oversold level (do not sell below)

//+------------------------------------------------------------------+
//| Input parameters for trade execution                             |
//+------------------------------------------------------------------+
input int                MagicNumber = 123456;                   // Magic number for orders
input string             OrderComment = "Breakout EA";           // Order comment
input double             MaxSlippage = 3.0;                      // Maximum slippage in points
input int                MaxRetries = 3;                         // Maximum order placement retries
input int                RetryDelayMs = 1000;                    // Delay between retries in milliseconds

//+------------------------------------------------------------------+
//| Class CTradeExecution                                            |
//| Handles order placement with retries, slippage, magic number     |
//| and order comments                                               |
//+------------------------------------------------------------------+
class CTradeExecution
{
private:
   // Trade request and result structures
   MqlTradeRequest   m_request;
   MqlTradeResult    m_result;
   
   // Symbol properties
   string            m_symbol;
   double            m_point;
   int               m_digits;
   
   // Helper methods
   bool              CheckNewsFilter();
   bool              CheckIndicatorFilters(const ENUM_ORDER_TYPE type);
   double            CalculateStopLoss(const ENUM_ORDER_TYPE type, const double entryPrice);
   double            CalculateTakeProfit(const ENUM_ORDER_TYPE type, const double entryPrice);
   
public:
   // Constructor
   CTradeExecution();
   
   // Main execution method
   bool ExecuteTrade(const ENUM_ORDER_TYPE type, const double volume, const double price = 0.0);
   
   // Position management
   bool CloseAllPositions();
   bool ClosePosition(const ulong ticket);
   
   // Getters
   MqlTradeResult    GetLastResult() const { return m_result; }
   string            GetLastError() const;
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CTradeExecution::CTradeExecution()
{
   m_symbol = Symbol();
   m_point = SymbolInfoDouble(m_symbol, SYMBOL_POINT);
   m_digits = (int)SymbolInfoInteger(m_symbol, SYMBOL_DIGITS);
   
   // Initialize trade request
   ZeroMemory(m_request);
   m_request.magic = MagicNumber;
   m_request.comment = OrderComment;
   m_request.symbol = m_symbol;
   m_request.deviation = (ulong)MaxSlippage;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CTradeExecution::CheckNewsFilter()
{
   if(!UseNewsFilter) return true;
   
   // Implementation would use FFCal indicator or economic calendar API
   // For now, return true (no news blocking)
   // In production, implement actual news checking logic
   return true;
}

//+------------------------------------------------------------------+
//| Check indicator filters                                          |
//+------------------------------------------------------------------+
bool CTradeExecution::CheckIndicatorFilters(const ENUM_ORDER_TYPE type)
{
   // Check EMA filter
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      double emaValue = iMA(m_symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE, 0);
      double currentPrice = SymbolInfoDouble(m_symbol, SYMBOL_BID);
      
      if(type == ORDER_TYPE_BUY && currentPrice <= emaValue) return false;
      if(type == ORDER_TYPE_SELL && currentPrice >= emaValue) return false;
   }
   
   // Check ADX filter
   if(UseADXFilter)
   {
      double adxValue = iADX(m_symbol, ExecTF, ADXPeriod, PRICE_CLOSE, MODE_MAIN, 0);
      if(adxValue < ADXThreshold) return false;
   }
   
   // Check RSI filter
   if(UseRSIFilter)
   {
      double rsiValue = iRSI(m_symbol, ExecTF, RSIPeriod, PRICE_CLOSE, 0);
      if(type == ORDER_TYPE_BUY && rsiValue >= RSIOverbought) return false;
      if(type == ORDER_TYPE_SELL && rsiValue <= RSIOversold) return false;
   }
   
   // Check ATR filter
   if(UseATRFilter)
   {
      double atrValue = iATR(m_symbol, ExecTF, ATRPeriod, 0);
      double atrPips = atrValue / m_point;
      
      if(atrPips < MinATRPips || atrPips > MaxATRPips) return false;
      
      // Check breakout validation
      if(BreakoutType == BREAKOUT_ATR)
      {
         // Implementation would compare price movement to ATR
         // For now, return true
      }
   }
   
   // Check Bollinger Bands filter
   if(UseBBFilter && BreakoutType == BREAKOUT_BOLLINGER)
   {
      double bbUpper = iBands(m_symbol, ExecTF, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_UPPER, 0);
      double bbLower = iBands(m_symbol, ExecTF, BBPeriod, BBDeviation, 0, PRICE_CLOSE, MODE_LOWER, 0);
      double bbWidthPips = (bbUpper - bbLower) / m_point;
      
      if(bbWidthPips < Min_Width_Pips || bbWidthPips > Max_Width_Pips) return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CTradeExecution::CalculateStopLoss(const ENUM_ORDER_TYPE type, const double entryPrice)
{
   // Implementation would calculate SL based on strategy rules
   // For now, return 0 (no stop loss)
   return 0.0;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+
double CTradeExecution::CalculateTakeProfit(const ENUM_ORDER_TYPE type, const double entryPrice)
{
   // Implementation would calculate TP based on strategy rules
   // For now, return 0 (no take profit)
   return 0.0;
}

//+------------------------------------------------------------------+
//| Execute trade with retries                                       |
//+------------------------------------------------------------------+
bool CTradeExecution::ExecuteTrade(const ENUM_ORDER_TYPE type, const double volume, const double price = 0.0)
{
   // Check if trading is allowed
   if(!AllowLong && type == ORDER_TYPE_BUY) return false;
   if(!AllowShort && type == ORDER_TYPE_SELL) return false;
   
   // Check news filter
   if(!CheckNewsFilter()) return false;
   
   // Check indicator filters
   if(!CheckIndicatorFilters(type)) return false;
   
   // Prepare trade request
   m_request.type = type;
   m_request.volume = volume;
   
   if(price > 0.0)
   {
      m_request.type_filling = ORDER_FILLING_RETURN;
      m_request.price = NormalizeDouble(price, m_digits);
   }
   else
   {
      m_request.type_filling = ORDER_FILLING_IOC;
      if(type == ORDER_TYPE_BUY)
         m_request.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
      else
         m.request.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }
   
   // Calculate SL and TP
   m_request.sl = CalculateStopLoss(type, m_request.price);
   m_request.tp = CalculateTakeProfit(type, m_request.price);
   
   // Execute trade with retries
   for(int i = 0; i < MaxRetries; i++)
   {
      ZeroMemory(m_result);
      
      if(OrderSend(m_request, m_result))
      {
         if(m_result.retcode == TRADE_RETCODE_DONE)
            return true;
      }
      
      // Wait before retry
      Sleep(RetryDelayMs);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions                                              |
//+------------------------------------------------------------------+
bool CTradeExecution::CloseAllPositions()
{
   bool result = true;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         ulong ticket = PositionGetInteger(POSITION_TICKET);
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            if(!ClosePosition(ticket))
               result = false;
         }
      }
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| Close specific position                                          |
//+------------------------------------------------------------------+
bool CTradeExecution::ClosePosition(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket)) return false;
   
   // Prepare close request
   MqlTradeRequest closeRequest;
   MqlTradeResult closeResult;
   ZeroMemory(closeRequest);
   ZeroMemory(closeResult);
   
   closeRequest.action = TRADE_ACTION_DEAL;
   closeRequest.position = ticket;
   closeRequest.symbol = m_symbol;
   closeRequest.volume = PositionGetDouble(POSITION_VOLUME);
   closeRequest.deviation = (ulong)MaxSlippage;
   closeRequest.magic = MagicNumber;
   closeRequest.comment = "Close position";
   
   ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   
   if(posType == POSITION_TYPE_BUY)
   {
      closeRequest.type = ORDER_TYPE_SELL;
      closeRequest.price = SymbolInfoDouble(m_symbol, SYMBOL_BID);
   }
   else
   {
      closeRequest.type = ORDER_TYPE_BUY;
      closeRequest.price = SymbolInfoDouble(m_symbol, SYMBOL_ASK);
   }
   
   return OrderSend(closeRequest, closeResult);
}

//+------------------------------------------------------------------+
//| Get last error description                                       |
//+------------------------------------------------------------------+
string CTradeExecution::GetLastError() const
{
   if(m_result.retcode == TRADE_RETCODE_DONE)
      return "Success";
   
   return StringFormat("Error %d: %s", m_result.retcode, TradeResultRetcodeDescription(m_result.retcode));
}

//+------------------------------------------------------------------+
//| Global trade execution object                                    |
//+------------------------------------------------------------------+
CTradeExecution TradeExecutor;

//+------------------------------------------------------------------+
