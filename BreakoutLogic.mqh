//+------------------------------------------------------------------+
//|                                                      BreakoutLogic.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.               |
//|                                             https://www.mql5.com      |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for breakout detection                          |
//+------------------------------------------------------------------+
input int      BreakoutType = 0;           // 0=Range, 1=BollingerBands, 2=ATR
input bool     AllowLong = true;           // Allow long positions
input bool     AllowShort = true;          // Allow short positions
input bool     RequireVolumeConfirm = true;// Require volume confirmation
input bool     RequireRetest = false;      // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe for range calculation
input int      TrendFilterEMA = 200;       // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe for trade execution

//+------------------------------------------------------------------+
//| Input parameters for news filter                                 |
//+------------------------------------------------------------------+
input bool     UseNewsFilter = true;       // Enable economic news filter
input int      NewsMinutesBefore = 60;     // Minutes before news to suspend trading
input int      NewsMinutesAfter = 30;      // Minutes after news to resume trading
input int      NewsImpactLevel = 3;        // Minimum impact level: 1=low, 2=medium, 3=high
input bool     CloseOnHighImpact = true;   // Close positions before high impact news

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input bool     UseATRFilter = true;        // Enable ATR filter
input int      ATRPeriod = 14;             // ATR period
input double   MinATRPips = 20;            // Minimum ATR required (pips)
input double   MaxATRPips = 150;           // Maximum ATR allowed (pips)
input double   ATR_Mult_Min = 1.25;        // Minimum ATR multiplier for breakout validation
input double   ATR_Mult_Max = 3.0;         // Maximum ATR multiplier for breakout validation

input bool     UseBBFilter = true;         // Enable Bollinger Bands filter
input int      BBPeriod = 20;              // Bollinger Bands period
input double   BBDeviation = 2.0;          // Bollinger Bands standard deviation
input double   Min_Width_Pips = 30;        // Minimum BB width (pips)
input double   Max_Width_Pips = 120;       // Maximum BB width (pips)

input bool     UseEMAFilter = true;        // Enable EMA filter
input int      EMAPeriod = 200;            // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;   // EMA timeframe

input bool     UseADXFilter = true;        // Enable ADX filter
input int      ADXPeriod = 14;             // ADX period
input double   ADXThreshold = 20.0;        // Minimum ADX threshold

input bool     UseRSIFilter = false;       // Enable RSI filter
input int      RSIPeriod = 14;             // RSI period
input double   RSIOverbought = 70;         // RSI overbought level (do not buy above)
input double   RSIOversold = 30;           // RSI oversold level (do not sell below)

//+------------------------------------------------------------------+
//| Breakout detection class                                         |
//+------------------------------------------------------------------+
class CBreakoutLogic
{
private:
   // Indicator handles
   int m_atr_handle;
   int m_bb_handle;
   int m_ema_handle;
   int m_adx_handle;
   int m_rsi_handle;
   
   // News filter variables
   datetime m_last_news_check;
   
   // Helper functions
   double   PipsToPoints(double pips);
   bool     CheckNewsFilter(string symbol);
   bool     CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES tf);
   double   GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int shift);
   double   GetBBWidth(string symbol, ENUM_TIMEFRAMES tf, int shift);
   double   GetEMAValue(string symbol, ENUM_TIMEFRAMES tf, int shift);
   double   GetADXValue(string symbol, ENUM_TIMEFRAMES tf, int shift);
   double   GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int shift);
   
public:
   // Constructor and destructor
   CBreakoutLogic();
   ~CBreakoutLogic();
   
   // Main methods
   bool     CheckBreakoutLong(string symbol, ENUM_TIMEFRAMES tf, int shift);
   bool     CheckBreakoutShort(string symbol, ENUM_TIMEFRAMES tf, int shift);
   bool     CheckAllFilters(string symbol, ENUM_TIMEFRAMES tf, int shift, bool is_long);
   bool     IsTradingAllowed(string symbol);
   void     ClosePositionsBeforeNews(string symbol);
};

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CBreakoutLogic::CBreakoutLogic()
{
   m_atr_handle = INVALID_HANDLE;
   m_bb_handle = INVALID_HANDLE;
   m_ema_handle = INVALID_HANDLE;
   m_adx_handle = INVALID_HANDLE;
   m_rsi_handle = INVALID_HANDLE;
   m_last_news_check = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CBreakoutLogic::~CBreakoutLogic()
{
   if(m_atr_handle != INVALID_HANDLE) IndicatorRelease(m_atr_handle);
   if(m_bb_handle != INVALID_HANDLE) IndicatorRelease(m_bb_handle);
   if(m_ema_handle != INVALID_HANDLE) IndicatorRelease(m_ema_handle);
   if(m_adx_handle != INVALID_HANDLE) IndicatorRelease(m_adx_handle);
   if(m_rsi_handle != INVALID_HANDLE) IndicatorRelease(m_rsi_handle);
}

//+------------------------------------------------------------------+
//| Convert pips to points                                           |
//+------------------------------------------------------------------+
double CBreakoutLogic::PipsToPoints(double pips)
{
   return pips * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10;
}

//+------------------------------------------------------------------+
//| Check news filter                                                |
//+------------------------------------------------------------------+
bool CBreakoutLogic::CheckNewsFilter(string symbol)
{
   if(!UseNewsFilter) return true;
   
   // Check every minute
   if(TimeCurrent() - m_last_news_check < 60) return true;
   m_last_news_check = TimeCurrent();
   
   // Using FFCal indicator for news data
   // Note: In real implementation, you would need to integrate with FFCal
   // This is a placeholder implementation
   
   // For demonstration purposes, assume no news is present
   // In production, implement actual FFCal integration
   return true;
}

//+------------------------------------------------------------------+
//| Check volume confirmation                                        |
//+------------------------------------------------------------------+
bool CBreakoutLogic::CheckVolumeConfirmation(string symbol, ENUM_TIMEFRAMES tf)
{
   if(!RequireVolumeConfirm) return true;
   
   // Get current volume and SMA of volume
   double volume_array[];
   ArraySetAsSeries(volume_array, true);
   
   if(CopyTickVolume(symbol, tf, 0, 21, volume_array) < 21) return false;
   
   double current_volume = volume_array[0];
   double sma_volume = 0;
   
   // Calculate SMA 20 of volume
   for(int i = 1; i <= 20; i++)
   {
      sma_volume += volume_array[i];
   }
   sma_volume /= 20;
   
   // Volume must be > 1.5x SMA
   return (current_volume > sma_volume * 1.5);
}

//+------------------------------------------------------------------+
//| Get ATR value                                                    |
//+------------------------------------------------------------------+
double CBreakoutLogic::GetATRValue(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(m_atr_handle == INVALID_HANDLE)
   {
      m_atr_handle = iATR(symbol, tf, ATRPeriod);
   }
   
   double atr_array[];
   ArraySetAsSeries(atr_array, true);
   
   if(CopyBuffer(m_atr_handle, 0, shift, 1, atr_array) < 1) return 0;
   
   return atr_array[0];
}

//+------------------------------------------------------------------+
//| Get Bollinger Bands width                                        |
//+------------------------------------------------------------------+
double CBreakoutLogic::GetBBWidth(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(m_bb_handle == INVALID_HANDLE)
   {
      m_bb_handle = iBands(symbol, tf, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
   }
   
   double upper_array[], lower_array[];
   ArraySetAsSeries(upper_array, true);
   ArraySetAsSeries(lower_array, true);
   
   if(CopyBuffer(m_bb_handle, 1, shift, 1, upper_array) < 1) return 0;
   if(CopyBuffer(m_bb_handle, 2, shift, 1, lower_array) < 1) return 0;
   
   return (upper_array[0] - lower_array[0]);
}

//+------------------------------------------------------------------+
//| Get EMA value                                                    |
//+------------------------------------------------------------------+
double CBreakoutLogic::GetEMAValue(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(m_ema_handle == INVALID_HANDLE)
   {
      m_ema_handle = iMA(symbol, tf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   }
   
   double ema_array[];
   ArraySetAsSeries(ema_array, true);
   
   if(CopyBuffer(m_ema_handle, 0, shift, 1, ema_array) < 1) return 0;
   
   return ema_array[0];
}

//+------------------------------------------------------------------+
//| Get ADX value                                                    |
//+------------------------------------------------------------------+
double CBreakoutLogic::GetADXValue(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(m_adx_handle == INVALID_HANDLE)
   {
      m_adx_handle = iADX(symbol, tf, ADXPeriod);
   }
   
   double adx_array[];
   ArraySetAsSeries(adx_array, true);
   
   if(CopyBuffer(m_adx_handle, 0, shift, 1, adx_array) < 1) return 0;
   
   return adx_array[0];
}

//+------------------------------------------------------------------+
//| Get RSI value                                                    |
//+------------------------------------------------------------------+
double CBreakoutLogic::GetRSIValue(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(m_rsi_handle == INVALID_HANDLE)
   {
      m_rsi_handle = iRSI(symbol, tf, RSIPeriod, PRICE_CLOSE);
   }
   
   double rsi_array[];
   ArraySetAsSeries(rsi_array, true);
   
   if(CopyBuffer(m_rsi_handle, 0, shift, 1, rsi_array) < 1) return 50;
   
   return rsi_array[0];
}

//+------------------------------------------------------------------+
//| Check long breakout                                              |
//+------------------------------------------------------------------+
bool CBreakoutLogic::CheckBreakoutLong(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(!AllowLong) return false;
   
   // Get price data
   double high_array[], low_array[], close_array[];
   ArraySetAsSeries(high_array, true);
   ArraySetAsSeries(low_array, true);
   ArraySetAsSeries(close_array, true);
   
   if(CopyHigh(symbol, RangeTF, shift, 2, high_array) < 2) return false;
   if(CopyLow(symbol, RangeTF, shift, 2, low_array) < 2) return false;
   if(CopyClose(symbol, tf, shift, 2, close_array) < 2) return false;
   
   // Calculate range
   double range_high = high_array[1];  // Previous day high
   double range_low = low_array[1];    // Previous day low
   double current_close = close_array[0];
   double previous_close = close_array[1];
   
   // Check for breakout above range
   if(current_close > range_high && previous_close <= range_high)
   {
      // Check if retest is required
      if(RequireRetest)
      {
         // Wait for retest - check if price came back to range high
         if(current_close < range_high) return false;
      }
      
      // Check all filters
      return CheckAllFilters(symbol, tf, shift, true);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check short breakout                                             |
//+------------------------------------------------------------------+
bool CBreakoutLogic::CheckBreakoutShort(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   if(!AllowShort) return false;
   
   // Get price data
   double high_array[], low_array[], close_array[];
   ArraySetAsSeries(high_array, true);
   ArraySetAsSeries(low_array, true);
   ArraySetAsSeries(close_array, true);
   
   if(CopyHigh(symbol, RangeTF, shift, 2, high_array) < 2) return false;
   if(CopyLow(symbol, RangeTF, shift, 2, low_array) < 2) return false;
   if(CopyClose(symbol, tf, shift, 2, close_array) < 2) return false;
   
   // Calculate range
   double range_high = high_array[1];  // Previous day high
   double range_low = low_array[1];    // Previous day low
   double current_close = close_array[0];
   double previous_close = close_array[1];
   
   // Check for breakout below range
   if(current_close < range_low && previous_close >= range_low)
   {
      // Check if retest is required
      if(RequireRetest)
      {
         // Wait for retest - check if price came back to range low
         if(current_close > range_low) return false;
      }
      
      // Check all filters
      return CheckAllFilters(symbol, tf, shift, false);
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check all indicator filters                                      |
//+------------------------------------------------------------------+
bool CBreakoutLogic::CheckAllFilters(string symbol, ENUM_TIMEFRAMES tf, int shift, bool is_long)
{
   // Check volume confirmation
   if(!CheckVolumeConfirmation(symbol, tf)) return false;
   
   // Check ATR filter
   if(UseATRFilter)
   {
      double atr_value = GetATRValue(symbol, tf, shift);
      double atr_pips = atr_value / SymbolInfoDouble(symbol, SYMBOL_POINT) / 10;
      
      // Check ATR range
      if(atr_pips < MinATRPips || atr_pips > MaxATRPips) return false;
      
      // Check breakout magnitude vs ATR
      double breakout_magnitude = 0;
      
      if(is_long)
      {
         double high_array[], close_array[];
         ArraySetAsSeries(high_array, true);
         ArraySetAsSeries(close_array, true);
         
         if(CopyHigh(symbol, RangeTF, shift, 2, high_array) < 2) return false;
         if(CopyClose(symbol, tf, shift, 2, close_array) < 2) return false;
         
         breakout_magnitude = close_array[0] - high_array[1];
      }
      else
      {
         double low_array[], close_array[];
         ArraySetAsSeries(low_array, true);
         ArraySetAsSeries(close_array, true);
         
         if(CopyLow(symbol, RangeTF, shift, 2, low_array) < 2) return false;
         if(CopyClose(symbol, tf, shift, 2, close_array) < 2) return false;
         
         breakout_magnitude = low_array[1] - close_array[0];
      }
      
      double atr_multiplier = breakout_magnitude / atr_value;
      
      if(atr_multiplier < ATR_Mult_Min || atr_multiplier > ATR_Mult_Max) return false;
   }
   
   // Check Bollinger Bands filter
   if(UseBBFilter)
   {
      double bb_width = GetBBWidth(symbol, tf, shift);
      double bb_width_pips = bb_width / SymbolInfoDouble(symbol, SYMBOL_POINT) / 10;
      
      if(bb_width_pips < Min_Width_Pips || bb_width_pips > Max_Width_Pips) return false;
   }
   
   // Check EMA filter
   if(UseEMAFilter && TrendFilterEMA > 0)
   {
      double ema_value = GetEMAValue(symbol, EMATf, shift);
      double current_price = SymbolInfoDouble(symbol, SYMBOL_BID);
      
      if(is_long)
      {
         if(current_price <= ema_value) return false;
      }
      else
      {
         if(current_price >= ema_value) return false;
      }
   }
   
   // Check ADX filter
   if(UseADXFilter)
   {
      double adx_value = GetADXValue(symbol, tf, shift);
      
      if(adx_value < ADXThreshold) return false;
   }
   
   // Check RSI filter
   if(UseRSIFilter)
   {
      double rsi_value = GetRSIValue(symbol, tf, shift);
      
      if(is_long)
      {
         if(rsi_value >= RSIOverbought) return false;
      }
      else
      {
         if(rsi_value <= RSIOversold) return false;
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Check if trading is allowed                                      |
//+------------------------------------------------------------------+
bool CBreakoutLogic::IsTradingAllowed(string symbol)
{
   // Check news filter
   if(!CheckNewsFilter(symbol)) return false;
   
   // Additional checks can be added here
   return true;
}

//+------------------------------------------------------------------+
//| Close positions before high impact news                          |
//+------------------------------------------------------------------+
void CBreakoutLogic::ClosePositionsBeforeNews(string symbol)
{
   if(!CloseOnHighImpact || !UseNewsFilter) return;
   
   // This method should be called when high impact news is detected
   // Implementation would close all open positions for the symbol
   // Placeholder for actual position closing logic
}
//+------------------------------------------------------------------+