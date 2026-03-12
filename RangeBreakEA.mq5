//+------------------------------------------------------------------+
//|                                                      RangeBreakEA.mq5 |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Range Breakout EA with multiple filters"

//--- Include standard libraries
#include <Trade/Trade.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Indicators/Trend.mqh>
#include <Indicators/Oscilators.mqh>
#include <Indicators/BillWilliams.mqh>
#include <Indicators/Volumes.mqh>
#include <Arrays/ArrayObj.mqh>

//--- Input parameters for Breakout
input group "Breakout Parameters"
input int BreakoutType = 0;               // 0=Range, 1=BollingerBands, 2=ATR
input bool AllowLong = true;              // Allow long positions
input bool AllowShort = true;             // Allow short positions
input bool RequireVolumeConfirm = true;   // Require volume confirmation
input bool RequireRetest = false;         // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1; // Timeframe for range calculation
input int TrendFilterEMA = 200;           // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15; // Timeframe for trade execution

//--- Input parameters for News Filter
input group "News Filter"
input bool UseNewsFilter = true;          // Enable economic news filter
input int NewsMinutesBefore = 60;         // Minutes before news to suspend trading
input int NewsMinutesAfter = 30;          // Minutes after news to resume trading
input int NewsImpactLevel = 3;            // Minimum impact level: 1=low, 2=medium, 3=high
input bool CloseOnHighImpact = true;      // Close positions before high impact news

//--- Input parameters for Indicator Filters
input group "ATR Filter"
input bool UseATRFilter = true;           // Enable ATR filter
input int ATRPeriod = 14;                 // ATR period
input double MinATRPips = 20.0;           // Minimum ATR required (pips)
input double MaxATRPips = 150.0;          // Maximum ATR allowed (pips)
input double ATR_Mult_Min = 1.25;         // Minimum ATR multiplier for breakout validation
input double ATR_Mult_Max = 3.0;          // Maximum ATR multiplier for breakout validation

input group "Bollinger Bands Filter"
input bool UseBBFilter = true;            // Enable Bollinger Bands filter
input int BBPeriod = 20;                  // Bollinger Bands period
input double BBDeviation = 2.0;           // BB standard deviation
input double Min_Width_Pips = 30.0;       // Minimum BB width (pips)
input double Max_Width_Pips = 120.0;      // Maximum BB width (pips)

input group "EMA Filter"
input bool UseEMAFilter = true;           // Enable EMA filter
input int EMAPeriod = 200;                // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;  // EMA timeframe

input group "ADX Filter"
input bool UseADXFilter = true;           // Enable ADX filter
input int ADXPeriod = 14;                 // ADX period
input double ADXThreshold = 20.0;         // Minimum ADX threshold

input group "RSI Filter"
input bool UseRSIFilter = false;          // Enable RSI filter
input int RSIPeriod = 14;                 // RSI period
input double RSIOverbought = 70.0;        // RSI overbought level (do not buy above)
input double RSIOversold = 30.0;          // RSI oversold level (do not sell below)

input group "Volume Filter"
input bool UseVolumeFilter = true;        // Enable volume filter
input int VolumePeriod = 20;              // Volume moving average period
input double VolumeMultiplier = 1.5;      // Minimum volume multiplier
input int Vol_Confirm_Type = 1;           // 0=Tick, 1=Real

//--- Input parameters for Position Management
input group "Position Management"
input ulong MagicNumber = 123456;         // Unique EA order identifier
input string OrderComment = "RangeBreakEA"; // Order comment
input int MaxSlippage = 3;                // Maximum allowed slippage (points)
input int MaxOrderRetries = 3;            // Maximum order sending attempts
input bool UsePartialClose = false;       // Enable partial closing
input double PartialCloseRR = 1.0;        // R:R for partial close

//--- Global variables
CTrade Trade;
CSymbolInfo SymbolInfo;
CiATR ATR;
CiBands BB;
CiMA EMA;
CiADX ADX;
CiRSI RSI;
CiVolumes Volume;
CiMA VolumeMA;

MqlRates rates[];
MqlDateTime currentTime;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize trade object
   Trade.SetExpertMagicNumber(MagicNumber);
   Trade.SetDeviationInPoints(MaxSlippage);
   Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   //--- Initialize symbol info
   if(!SymbolInfo.Name(_Symbol))
      return INIT_FAILED;
   
   //--- Initialize indicators
   if(UseATRFilter && !ATR.Create(_Symbol, ExecTF, ATRPeriod))
      return INIT_FAILED;
   
   if(UseBBFilter && !BB.Create(_Symbol, ExecTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseEMAFilter && !EMA.Create(_Symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseADXFilter && !ADX.Create(_Symbol, ExecTF, ADXPeriod))
      return INIT_FAILED;
   
   if(UseRSIFilter && !RSI.Create(_Symbol, ExecTF, RSIPeriod, PRICE_CLOSE))
      return INIT_FAILED;
   
   if(UseVolumeFilter)
   {
      if(!Volume.Create(_Symbol, ExecTF, VOLUME_TICK))
         return INIT_FAILED;
      if(!VolumeMA.Create(_Symbol, ExecTF, VolumePeriod, 0, MODE_SMA, VOLUME_TICK))
         return INIT_FAILED;
   }
   
   //--- Set up chart
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, 0);
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for new bar
   if(!IsNewBar())
      return;
   
   //--- Check news filter
   if(UseNewsFilter && IsNewsTime())
   {
      if(CloseOnHighImpact && NewsImpactLevel >= 3)
         CloseAllPositions();
      return;
   }
   
   //--- Update indicators
   UpdateIndicators();
   
   //--- Check for trading signals
   CheckForSignals();
   
   //--- Manage existing positions
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Check if it's a new bar                                          |
//+------------------------------------------------------------------+
bool IsNewBar()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, ExecTF, 0);
   
   if(lastBarTime != currentBarTime)
   {
      lastBarTime = currentBarTime;
      return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check if current time is during news blackout                    |
//+------------------------------------------------------------------+
bool IsNewsTime()
{
   // This is a placeholder - in real implementation, integrate with FFCal indicator
   // For now, return false to allow trading
   return false;
}

//+------------------------------------------------------------------+
//| Close all positions opened by this EA                            |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber)
         {
            Trade.PositionClose(ticket);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update all indicators                                            |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
   if(UseATRFilter)
      ATR.Refresh(ExecTF);
   
   if(UseBBFilter)
      BB.Refresh(ExecTF);
   
   if(UseEMAFilter)
      EMA.Refresh(EMATf);
   
   if(UseADXFilter)
      ADX.Refresh(ExecTF);
   
   if(UseRSIFilter)
      RSI.Refresh(ExecTF);
   
   if(UseVolumeFilter)
   {
      Volume.Refresh(ExecTF);
      VolumeMA.Refresh(ExecTF);
   }
}

//+------------------------------------------------------------------+
//| Check for trading signals                                        |
//+------------------------------------------------------------------+
void CheckForSignals()
{
   //--- Get range data
   double rangeHigh = iHigh(_Symbol, RangeTF, 1);
   double rangeLow = iLow(_Symbol, RangeTF, 1);
   double currentPrice = SymbolInfo.Last();
   
   //--- Check long signal
   if(AllowLong && currentPrice > rangeHigh)
   {
      if(CheckAllFilters(true))
      {
         PlaceBuyStopOrder(rangeHigh);
      }
   }
   
   //--- Check short signal
   if(AllowShort && currentPrice < rangeLow)
   {
      if(CheckAllFilters(false))
      {
         PlaceSellStopOrder(rangeLow);
      }
   }
}

//+------------------------------------------------------------------+
//| Check all filters for trade validity                             |
//+------------------------------------------------------------------+
bool CheckAllFilters(bool isLong)
{
   //--- ATR filter
   if(UseATRFilter && !CheckATRFilter(isLong))
      return false;
   
   //--- Bollinger Bands filter
   if(UseBBFilter && !CheckBBFilter())
      return false;
   
   //--- EMA filter
   if(UseEMAFilter && !CheckEMAFilter(isLong))
      return false;
   
   //--- ADX filter
   if(UseADXFilter && !CheckADXFilter())
      return false;
   
   //--- RSI filter
   if(UseRSIFilter && !CheckRSIFilter(isLong))
      return false;
   
   //--- Volume filter
   if(UseVolumeFilter && !CheckVolumeFilter())
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check ATR filter conditions                                      |
//+------------------------------------------------------------------+
bool CheckATRFilter(bool isLong)
{
   double atrValue = ATR.Main(0);
   double atrInPips = atrValue / SymbolInfo.Point() * 10; // Convert to pips
   
   // Check ATR range
   if(atrInPips < MinATRPips || atrInPips > MaxATRPips)
      return false;
   
   // Check breakout magnitude
   double rangeHigh = iHigh(_Symbol, RangeTF, 1);
   double rangeLow = iLow(_Symbol, RangeTF, 1);
   double rangeSize = rangeHigh - rangeLow;
   double atrMultiplier = rangeSize / atrValue;
   
   if(atrMultiplier < ATR_Mult_Min || atrMultiplier > ATR_Mult_Max)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Check Bollinger Bands filter conditions                          |
//+------------------------------------------------------------------+
bool CheckBBFilter()
{
   double upperBand = BB.Upper(0);
   double lowerBand = BB.Lower(0);
   double bbWidth = upperBand - lowerBand;
   double bbWidthPips = bbWidth / SymbolInfo.Point() * 10;
   
   return (bbWidthPips >= Min_Width_Pips && bbWidthPips <= Max_Width_Pips);
}

//+------------------------------------------------------------------+
//| Check EMA filter conditions                                      |
//+------------------------------------------------------------------+
bool CheckEMAFilter(bool isLong)
{
   double emaValue = EMA.Main(0);
   double currentPrice = SymbolInfo.Last();
   
   if(isLong)
      return currentPrice > emaValue;
   else
      return currentPrice < emaValue;
}

//+------------------------------------------------------------------+
//| Check ADX filter conditions                                      |
//+------------------------------------------------------------------+
bool CheckADXFilter()
{
   double adxValue = ADX.Main(0);
   return adxValue > ADXThreshold;
}

//+------------------------------------------------------------------+
//| Check RSI filter conditions                                      |
//+------------------------------------------------------------------+
bool CheckRSIFilter(bool isLong)
{
   double rsiValue = RSI.Main(0);
   
   if(isLong)
      return rsiValue < RSIOverbought;
   else
      return rsiValue > RSIOversold;
}

//+------------------------------------------------------------------+
//| Check volume filter conditions                                   |
//+------------------------------------------------------------------+
bool CheckVolumeFilter()
{
   double currentVolume = Volume.Main(0);
   double volumeMA = VolumeMA.Main(0);
   
   return currentVolume > (volumeMA * VolumeMultiplier);
}

//+------------------------------------------------------------------+
//| Place buy stop order                                             |
//+------------------------------------------------------------------+
void PlaceBuyStopOrder(double entryPrice)
{
   double sl = CalculateStopLoss(true, entryPrice);
   double tp = CalculateTakeProfit(true, entryPrice);
   
   for(int attempt = 0; attempt < MaxOrderRetries; attempt++)
   {
      if(Trade.BuyStop(SymbolInfo.Lots(), entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, OrderComment))
         break;
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Place sell stop order                                            |
//+------------------------------------------------------------------+
void PlaceSellStopOrder(double entryPrice)
{
   double sl = CalculateStopLoss(false, entryPrice);
   double tp = CalculateTakeProfit(false, entryPrice);
   
   for(int attempt = 0; attempt < MaxOrderRetries; attempt++)
   {
      if(Trade.SellStop(SymbolInfo.Lots(), entryPrice, _Symbol, sl, tp, ORDER_TIME_GTC, 0, OrderComment))
         break;
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Calculate stop loss                                              |
//+------------------------------------------------------------------+
double CalculateStopLoss(bool isLong, double entryPrice)
{
   double rangeHigh = iHigh(_Symbol, RangeTF, 1);
   double rangeLow = iLow(_Symbol, RangeTF, 1);
   
   if(isLong)
      return rangeLow;
   else
      return rangeHigh;
}

//+------------------------------------------------------------------+
//| Calculate take profit                                            |
//+------------------------------------------------------------------+
double CalculateTakeProfit(bool isLong, double entryPrice)
{
   double rangeSize = iHigh(_Symbol, RangeTF, 1) - iLow(_Symbol, RangeTF, 1);
   
   if(isLong)
      return entryPrice + rangeSize;
   else
      return entryPrice - rangeSize;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                        |
//+------------------------------------------------------------------+
void ManagePositions()
{
   if(UsePartialClose)
   {
      // Implement partial closing logic based on R:R
      // This is a placeholder for the partial close functionality
   }
}

//+------------------------------------------------------------------+
