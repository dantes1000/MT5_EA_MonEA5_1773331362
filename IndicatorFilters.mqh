//+------------------------------------------------------------------+
//|                                                      IndicatorFilters.mqh |
//|                        Copyright 2023, MetaQuotes Ltd.         |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input double   InpATR_MinVolatility      = 0.0005;   // Minimum ATR volatility filter (in price)
input double   InpATR_MaxVolatility      = 0.0020;   // Maximum ATR volatility filter (in price)
input double   InpATR_BreakoutMultiplier = 1.25;     // Breakout confirmation multiplier (>1.25x ATR)
input int      InpBB_MinWidthPips       = 30;       // Minimum Bollinger Bands width in pips
input int      InpBB_MaxWidthPips       = 120;      // Maximum Bollinger Bands width in pips
input int      InpEMA_Period            = 200;      // EMA period for trend filter (H1)
input double   InpADX_MinStrength       = 20.0;     // Minimum ADX strength
input int      InpRSI_Period            = 14;       // RSI period
input int      InpRSI_Overbought        = 70;       // RSI overbought level
input int      InpRSI_Oversold          = 30;       // RSI oversold level
input int      InpVolume_SMAPeriod      = 20;       // Volume SMA period
input double   InpVolume_Multiplier     = 1.5;      // Volume confirmation multiplier (>1.5x SMA)
input int      InpTradingStartHour      = 8;        // Trading start hour (GMT)
input int      InpTradingEndHour        = 21;       // Trading end hour (GMT) for Friday close
input bool     InpCloseBeforeWeekend    = true;     // Close positions before weekend (Friday 21h GMT)

//+------------------------------------------------------------------+
//| Class for indicator filter calculations                          |
//+------------------------------------------------------------------+
class CIndicatorFilters
{
private:
   int               m_handleATR;
   int               m_handleBB;
   int               m_handleEMA;
   int               m_handleADX;
   int               m_handleRSI;
   int               m_handleVolumeSMA;
   
   double            m_atrBuffer[];
   double            m_bbUpperBuffer[];
   double            m_bbLowerBuffer[];
   double            m_emaBuffer[];
   double            m_adxBuffer[];
   double            m_rsiBuffer[];
   double            m_volumeBuffer[];
   double            m_volumeSMABuffer[];
   
   MqlRates          m_rates[];
   
   // Helper function to get pip value
   double PipValue()
   {
      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      return (digits == 3 || digits == 5) ? point * 10 : point;
   }
   
public:
   // Constructor
   CIndicatorFilters()
   {
      m_handleATR = iATR(_Symbol, PERIOD_CURRENT, 14);
      m_handleBB = iBands(_Symbol, PERIOD_CURRENT, 20, 0, 2, PRICE_CLOSE);
      m_handleEMA = iMA(_Symbol, PERIOD_H1, InpEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
      m_handleADX = iADX(_Symbol, PERIOD_CURRENT, 14);
      m_handleRSI = iRSI(_Symbol, PERIOD_CURRENT, InpRSI_Period, PRICE_CLOSE);
      m_handleVolumeSMA = iMA(_Symbol, PERIOD_CURRENT, InpVolume_SMAPeriod, 0, MODE_SMA, VOLUME_TICK);
      
      ArraySetAsSeries(m_atrBuffer, true);
      ArraySetAsSeries(m_bbUpperBuffer, true);
      ArraySetAsSeries(m_bbLowerBuffer, true);
      ArraySetAsSeries(m_emaBuffer, true);
      ArraySetAsSeries(m_adxBuffer, true);
      ArraySetAsSeries(m_rsiBuffer, true);
      ArraySetAsSeries(m_volumeBuffer, true);
      ArraySetAsSeries(m_volumeSMABuffer, true);
      ArraySetAsSeries(m_rates, true);
   }
   
   // Destructor
   ~CIndicatorFilters()
   {
      if(m_handleATR != INVALID_HANDLE) IndicatorRelease(m_handleATR);
      if(m_handleBB != INVALID_HANDLE) IndicatorRelease(m_handleBB);
      if(m_handleEMA != INVALID_HANDLE) IndicatorRelease(m_handleEMA);
      if(m_handleADX != INVALID_HANDLE) IndicatorRelease(m_handleADX);
      if(m_handleRSI != INVALID_HANDLE) IndicatorRelease(m_handleRSI);
      if(m_handleVolumeSMA != INVALID_HANDLE) IndicatorRelease(m_handleVolumeSMA);
   }
   
   // Update indicator buffers
   bool UpdateBuffers()
   {
      if(CopyRates(_Symbol, PERIOD_CURRENT, 0, 3, m_rates) < 3) return false;
      
      if(CopyBuffer(m_handleATR, 0, 0, 3, m_atrBuffer) < 3) return false;
      if(CopyBuffer(m_handleBB, 1, 0, 3, m_bbUpperBuffer) < 3) return false;
      if(CopyBuffer(m_handleBB, 2, 0, 3, m_bbLowerBuffer) < 3) return false;
      if(CopyBuffer(m_handleEMA, 0, 0, 3, m_emaBuffer) < 3) return false;
      if(CopyBuffer(m_handleADX, 0, 0, 3, m_adxBuffer) < 3) return false;
      if(CopyBuffer(m_handleRSI, 0, 0, 3, m_rsiBuffer) < 3) return false;
      if(CopyBuffer(m_handleVolumeSMA, 0, 0, 3, m_volumeSMABuffer) < 3) return false;
      
      // Get volume data
      if(CopyTickVolume(_Symbol, PERIOD_CURRENT, 0, 3, m_volumeBuffer) < 3) return false;
      
      return true;
   }
   
   // ATR filter: check volatility range
   bool CheckATRFilter()
   {
      double currentATR = m_atrBuffer[0];
      return (currentATR >= InpATR_MinVolatility && currentATR <= InpATR_MaxVolatility);
   }
   
   // ATR breakout confirmation
   bool CheckATRBreakout(double priceChange)
   {
      double currentATR = m_atrBuffer[0];
      return (MathAbs(priceChange) > (currentATR * InpATR_BreakoutMultiplier));
   }
   
   // Bollinger Bands width filter
   bool CheckBBWidthFilter()
   {
      double bbWidth = (m_bbUpperBuffer[0] - m_bbLowerBuffer[0]) / PipValue();
      return (bbWidth >= InpBB_MinWidthPips && bbWidth <= InpBB_MaxWidthPips);
   }
   
   // EMA trend filter
   bool CheckEMATrendFilter(int tradeType) // 1 for buy, -1 for sell
   {
      double currentPrice = m_rates[0].close;
      double currentEMA = m_emaBuffer[0];
      
      if(tradeType == 1) // Buy condition
         return (currentPrice > currentEMA);
      else if(tradeType == -1) // Sell condition
         return (currentPrice < currentEMA);
      
      return false;
   }
   
   // ADX strength filter
   bool CheckADXFilter()
   {
      return (m_adxBuffer[0] >= InpADX_MinStrength);
   }
   
   // RSI overbought/oversold filter
   bool CheckRSIFilter(int tradeType) // 1 for buy, -1 for sell
   {
      double currentRSI = m_rsiBuffer[0];
      
      if(tradeType == 1) // Buy condition - avoid overbought
         return (currentRSI < InpRSI_Overbought);
      else if(tradeType == -1) // Sell condition - avoid oversold
         return (currentRSI > InpRSI_Oversold);
      
      return false;
   }
   
   // Volume confirmation filter
   bool CheckVolumeFilter()
   {
      double currentVolume = m_volumeBuffer[0];
      double currentVolumeSMA = m_volumeSMABuffer[0];
      
      if(currentVolumeSMA == 0) return false;
      
      return (currentVolume > (currentVolumeSMA * InpVolume_Multiplier));
   }
   
   // Time filter: check if within trading hours
   bool CheckTradingHours()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Check if it's Friday and after closing time
      if(InpCloseBeforeWeekend && dt.day_of_week == 5 && dt.hour >= InpTradingEndHour)
         return false;
      
      // Check if within trading hours (after 8h GMT)
      if(dt.hour < InpTradingStartHour)
         return false;
      
      return true;
   }
   
   // Check if it's Asian session (0-6h GMT) for calculations
   bool IsAsianSession()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.hour >= 0 && dt.hour < 6);
   }
   
   // Check if it's London session for entry
   bool IsLondonSession()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.hour >= 8 && dt.hour < 17); // London session typically 8-17 GMT
   }
   
   // Check if trading day is allowed (all days)
   bool IsTradingDayAllowed()
   {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      return (dt.day_of_week >= 1 && dt.day_of_week <= 5); // Monday to Friday
   }
   
   // Check if position should be closed before weekend
   bool ShouldCloseBeforeWeekend()
   {
      if(!InpCloseBeforeWeekend) return false;
      
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      
      // Check if it's Friday and after closing time
      return (dt.day_of_week == 5 && dt.hour >= InpTradingEndHour);
   }
   
   // Comprehensive filter check for buy signals
   bool CheckBuyFilters()
   {
      if(!UpdateBuffers()) return false;
      
      // Check all filters
      if(!CheckATRFilter()) return false;
      if(!CheckBBWidthFilter()) return false;
      if(!CheckEMATrendFilter(1)) return false;
      if(!CheckADXFilter()) return false;
      if(!CheckRSIFilter(1)) return false;
      if(!CheckVolumeFilter()) return false;
      if(!CheckTradingHours()) return false;
      if(!IsTradingDayAllowed()) return false;
      if(!IsLondonSession()) return false;
      
      return true;
   }
   
   // Comprehensive filter check for sell signals
   bool CheckSellFilters()
   {
      if(!UpdateBuffers()) return false;
      
      // Check all filters
      if(!CheckATRFilter()) return false;
      if(!CheckBBWidthFilter()) return false;
      if(!CheckEMATrendFilter(-1)) return false;
      if(!CheckADXFilter()) return false;
      if(!CheckRSIFilter(-1)) return false;
      if(!CheckVolumeFilter()) return false;
      if(!CheckTradingHours()) return false;
      if(!IsTradingDayAllowed()) return false;
      if(!IsLondonSession()) return false;
      
      return true;
   }
   
   // Get current ATR value
   double GetCurrentATR() { return m_atrBuffer[0]; }
   
   // Get Bollinger Bands width in pips
   double GetBBWidthPips() { return (m_bbUpperBuffer[0] - m_bbLowerBuffer[0]) / PipValue(); }
   
   // Get current EMA value
   double GetCurrentEMA() { return m_emaBuffer[0]; }
   
   // Get current ADX value
   double GetCurrentADX() { return m_adxBuffer[0]; }
   
   // Get current RSI value
   double GetCurrentRSI() { return m_rsiBuffer[0]; }
   
   // Get current volume ratio
   double GetVolumeRatio() 
   { 
      if(m_volumeSMABuffer[0] == 0) return 0;
      return m_volumeBuffer[0] / m_volumeSMABuffer[0]; 
   }
};

//+------------------------------------------------------------------+
//| Example usage in Expert Advisor                                  |
//+------------------------------------------------------------------+
/*
// In your Expert Advisor:
#include <IndicatorFilters.mqh>

CIndicatorFilters filters;

// In OnInit()
if(!filters.UpdateBuffers())
{
   Print("Failed to initialize indicator buffers");
   return(INIT_FAILED);
}

// In OnTick()
if(filters.CheckBuyFilters())
{
   // Execute buy order
}

if(filters.CheckSellFilters())
{
   // Execute sell order
}

// Check if positions should be closed before weekend
if(filters.ShouldCloseBeforeWeekend())
{
   // Close all positions
}
*/
//+------------------------------------------------------------------+