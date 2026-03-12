//+------------------------------------------------------------------+
//|                                                      NewsFilter.mqh |
//|                        Manages economic news filtering using FFCal |
//|               Suspends trading around high-impact events          |
//+------------------------------------------------------------------+
#property copyright ""
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input double   InpATRMinVolatility      = 10.0;     // Minimum ATR volatility filter (pips)
input double   InpATRMaxVolatility      = 50.0;     // Maximum ATR volatility filter (pips)
input double   InpATRBreakoutMultiplier = 1.25;     // Breakout confirmation multiplier (>1.25x ATR)
input double   InpBBMinWidth            = 30.0;     // Minimum Bollinger Bands width (pips)
input double   InpBBMaxWidth            = 120.0;    // Maximum Bollinger Bands width (pips)
input int      InpEMAPeriod             = 200;      // EMA period for trend filter (H1)
input double   InpADXMinStrength        = 20.0;     // Minimum ADX trend strength
input int      InpRSIOverbought         = 70;       // RSI overbought level to exclude
input int      InpRSIOversold           = 30;       // RSI oversold level to exclude
input int      InpVolumeSMAPeriod       = 20;       // Volume SMA period
input double   InpVolumeMultiplier      = 1.5;      // Volume confirmation multiplier (>1.5x SMA)

//+------------------------------------------------------------------+
//| Input parameters for time filters                                |
//+------------------------------------------------------------------+
input int      InpTradingStartHour      = 8;        // Trading start hour (GMT)
input int      InpTradingEndHour        = 21;       // Trading end hour (GMT)
input bool     InpCloseBeforeWeekend    = true;     // Close positions before weekend (Friday 21h GMT)
input int      InpAsianSessionStart     = 0;        // Asian session start hour (GMT)
input int      InpAsianSessionEnd       = 6;        // Asian session end hour (GMT)

//+------------------------------------------------------------------+
//| Input parameters for news filter                                 |
//+------------------------------------------------------------------+
input int      InpNewsPreEventMinutes   = 30;       // Minutes before high-impact event to suspend trading
input int      InpNewsPostEventMinutes  = 30;       // Minutes after high-impact event to suspend trading
input string   InpHighImpactEvents      = "NFP,CPI,Interest Rate,GDP"; // Comma-separated high-impact events

//+------------------------------------------------------------------+
//| Global variables and handles                                     |
//+------------------------------------------------------------------+
int            atrHandle;                           // ATR indicator handle
int            bbHandle;                            // Bollinger Bands handle
int            emaHandle;                           // EMA handle
int            adxHandle;                           // ADX handle
int            rsiHandle;                           // RSI handle
int            volumeHandle;                        // Volume indicator handle
int            volumeSMAHandle;                     // Volume SMA handle
datetime       lastNewsCheckTime;                   // Last time news was checked
string         highImpactEvents[];                  // Array of high-impact events

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
bool NewsFilterInit()
{
   // Initialize indicator handles
   atrHandle = iATR(_Symbol, PERIOD_CURRENT, 14);
   bbHandle = iBands(_Symbol, PERIOD_CURRENT, 20, 2, 0, PRICE_CLOSE);
   emaHandle = iMA(_Symbol, PERIOD_H1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   adxHandle = iADX(_Symbol, PERIOD_CURRENT, 14);
   rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE);
   volumeHandle = iVolumes(_Symbol, PERIOD_CURRENT, VOLUME_TICK);
   volumeSMAHandle = iMAOnArray(volumeHandle, 0, InpVolumeSMAPeriod, 0, MODE_SMA, 0);
   
   // Check if all handles are valid
   if(atrHandle == INVALID_HANDLE || bbHandle == INVALID_HANDLE || emaHandle == INVALID_HANDLE || 
      adxHandle == INVALID_HANDLE || rsiHandle == INVALID_HANDLE || volumeHandle == INVALID_HANDLE || 
      volumeSMAHandle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return false;
   }
   
   // Parse high-impact events string into array
   StringSplit(InpHighImpactEvents, ',', highImpactEvents);
   
   // Initialize last news check time
   lastNewsCheckTime = TimeCurrent();
   
   return true;
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void NewsFilterDeinit()
{
   // Release indicator handles
   if(atrHandle != INVALID_HANDLE) IndicatorRelease(atrHandle);
   if(bbHandle != INVALID_HANDLE) IndicatorRelease(bbHandle);
   if(emaHandle != INVALID_HANDLE) IndicatorRelease(emaHandle);
   if(adxHandle != INVALID_HANDLE) IndicatorRelease(adxHandle);
   if(rsiHandle != INVALID_HANDLE) IndicatorRelease(rsiHandle);
   if(volumeHandle != INVALID_HANDLE) IndicatorRelease(volumeHandle);
   if(volumeSMAHandle != INVALID_HANDLE) IndicatorRelease(volumeSMAHandle);
}

//+------------------------------------------------------------------+
//| Check if current time is within trading hours                    |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentHour = timeStruct.hour;
   int dayOfWeek = timeStruct.day_of_week;
   
   // Check if it's Friday after trading end hour (for weekend closing)
   if(InpCloseBeforeWeekend && dayOfWeek == 5 && currentHour >= InpTradingEndHour)
      return false;
   
   // Check if within trading hours (8h GMT to 21h GMT)
   if(currentHour >= InpTradingStartHour && currentHour < InpTradingEndHour)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is within Asian session                    |
//+------------------------------------------------------------------+
bool IsAsianSession()
{
   MqlDateTime timeStruct;
   TimeToStruct(TimeCurrent(), timeStruct);
   
   int currentHour = timeStruct.hour;
   
   // Check if within Asian session hours (0h GMT to 6h GMT)
   if(currentHour >= InpAsianSessionStart && currentHour < InpAsianSessionEnd)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check ATR volatility filter                                      |
//+------------------------------------------------------------------+
bool CheckATRFilter()
{
   double atrValue[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) <= 0)
      return false;
   
   // Convert ATR to pips
   double atrPips = atrValue[0] / _Point;
   
   // Check if ATR is within min/max range
   if(atrPips >= InpATRMinVolatility && atrPips <= InpATRMaxVolatility)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands width filter                               |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   double upperBand[1], lowerBand[1];
   if(CopyBuffer(bbHandle, 1, 0, 1, upperBand) <= 0 || CopyBuffer(bbHandle, 2, 0, 1, lowerBand) <= 0)
      return false;
   
   // Calculate band width in pips
   double bandWidthPips = (upperBand[0] - lowerBand[0]) / _Point;
   
   // Check if band width is within range
   if(bandWidthPips >= InpBBMinWidth && bandWidthPips <= InpBBMaxWidth)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check EMA trend filter                                           |
//| Returns: 1 for buy, -1 for sell, 0 for no trend                 |
//+------------------------------------------------------------------+
int CheckEMAFilter()
{
   double emaValue[1], closePrice[1];
   if(CopyBuffer(emaHandle, 0, 0, 1, emaValue) <= 0 || CopyClose(_Symbol, PERIOD_H1, 0, 1, closePrice) <= 0)
      return 0;
   
   // Check trend direction
   if(closePrice[0] > emaValue[0])
      return 1;   // Buy signal
   else if(closePrice[0] < emaValue[0])
      return -1;  // Sell signal
   
   return 0;      // No clear trend
}

//+------------------------------------------------------------------+
//| Check ADX trend strength filter                                  |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   double adxValue[1];
   if(CopyBuffer(adxHandle, 0, 0, 1, adxValue) <= 0)
      return false;
   
   // Check if ADX is above minimum strength
   if(adxValue[0] >= InpADXMinStrength)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check RSI overbought/oversold filter                             |
//+------------------------------------------------------------------+
bool CheckRSIFilter()
{
   double rsiValue[1];
   if(CopyBuffer(rsiHandle, 0, 0, 1, rsiValue) <= 0)
      return false;
   
   // Check if RSI is not in overbought or oversold zone
   if(rsiValue[0] < InpRSIOverbought && rsiValue[0] > InpRSIOversold)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check volume confirmation filter                                 |
//+------------------------------------------------------------------+
bool CheckVolumeFilter()
{
   double volumeValue[1], volumeSMAValue[1];
   if(CopyBuffer(volumeHandle, 0, 0, 1, volumeValue) <= 0 || CopyBuffer(volumeSMAHandle, 0, 0, 1, volumeSMAValue) <= 0)
      return false;
   
   // Check if current volume is above SMA multiplier
   if(volumeValue[0] > volumeSMAValue[0] * InpVolumeMultiplier)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check breakout confirmation using ATR                            |
//+------------------------------------------------------------------+
bool CheckBreakoutConfirmation(double entryPrice, double currentPrice, ENUM_ORDER_TYPE orderType)
{
   double atrValue[1];
   if(CopyBuffer(atrHandle, 0, 0, 1, atrValue) <= 0)
      return false;
   
   double priceDifference = MathAbs(currentPrice - entryPrice);
   double requiredBreakout = atrValue[0] * InpATRBreakoutMultiplier;
   
   // Check if price has moved more than required breakout distance
   if(priceDifference >= requiredBreakout)
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Check for high-impact news events                                |
//| Note: This is a placeholder. In real implementation, you would  |
//|       integrate with FFCal API or use a news feed service        |
//+------------------------------------------------------------------+
bool IsHighImpactNewsScheduled()
{
   // This function should be implemented to check FFCal or news API
   // For now, it returns false as a placeholder
   
   // Check if enough time has passed since last news check
   if(TimeCurrent() - lastNewsCheckTime < 300)  // Check every 5 minutes
      return false;
   
   // Update last check time
   lastNewsCheckTime = TimeCurrent();
   
   // Placeholder logic - in real implementation, check news calendar
   // and return true if high-impact event is scheduled within
   // InpNewsPreEventMinutes to InpNewsPostEventMinutes
   
   return false;
}

//+------------------------------------------------------------------+
//| Main filter function - checks all conditions                    |
//| Returns: 1 for buy, -1 for sell, 0 for no trade                 |
//+------------------------------------------------------------------+
int CheckAllFilters()
{
   // Check time filters
   if(!IsTradingTime())
      return 0;
   
   // Check news filter
   if(IsHighImpactNewsScheduled())
      return 0;
   
   // Check indicator filters
   if(!CheckATRFilter())
      return 0;
   
   if(!CheckBBFilter())
      return 0;
   
   int trendDirection = CheckEMAFilter();
   if(trendDirection == 0)
      return 0;
   
   if(!CheckADXFilter())
      return 0;
   
   if(!CheckRSIFilter())
      return 0;
   
   if(!CheckVolumeFilter())
      return 0;
   
   // All filters passed, return trend direction
   return trendDirection;
}

//+------------------------------------------------------------------+
//| Function to check if position should be closed                   |
//+------------------------------------------------------------------+
bool ShouldClosePosition()
{
   // Check if it's Friday and time to close before weekend
   if(InpCloseBeforeWeekend)
   {
      MqlDateTime timeStruct;
      TimeToStruct(TimeCurrent(), timeStruct);
      
      if(timeStruct.day_of_week == 5 && timeStruct.hour >= InpTradingEndHour)
         return true;
   }
   
   // Check if high-impact news is scheduled
   if(IsHighImpactNewsScheduled())
      return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| Function to get filter status for debugging                      |
//+------------------------------------------------------------------+
string GetFilterStatus()
{
   string status = "Filter Status:\n";
   
   status += "Trading Time: " + (IsTradingTime() ? "Yes" : "No") + "\n";
   status += "Asian Session: " + (IsAsianSession() ? "Yes" : "No") + "\n";
   status += "ATR Filter: " + (CheckATRFilter() ? "Pass" : "Fail") + "\n";
   status += "BB Filter: " + (CheckBBFilter() ? "Pass" : "Fail") + "\n";
   status += "EMA Filter: " + IntegerToString(CheckEMAFilter()) + "\n";
   status += "ADX Filter: " + (CheckADXFilter() ? "Pass" : "Fail") + "\n";
   status += "RSI Filter: " + (CheckRSIFilter() ? "Pass" : "Fail") + "\n";
   status += "Volume Filter: " + (CheckVolumeFilter() ? "Pass" : "Fail") + "\n";
   status += "News Filter: " + (IsHighImpactNewsScheduled() ? "Active" : "Inactive") + "\n";
   
   return status;
}

//+------------------------------------------------------------------+
