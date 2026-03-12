//+------------------------------------------------------------------+
//| RiskManagement.mqh                                              |
//| Handles position sizing, stop loss, take profit, and partial close logic |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Input parameters for breakout settings                           |
//+------------------------------------------------------------------+
enum ENUM_BREAKOUT_TYPE
{
   BREAKOUT_RANGE = 0,      // Range
   BREAKOUT_BOLLINGER = 1,  // Bollinger Bands
   BREAKOUT_ATR = 2         // ATR
};

input ENUM_BREAKOUT_TYPE BreakoutType = BREAKOUT_RANGE; // Breakout type
input bool AllowLong = true;                            // Allow long positions
input bool AllowShort = true;                           // Allow short positions
input bool RequireVolumeConfirm = true;                 // Require volume confirmation
input bool RequireRetest = false;                       // Wait for retest before entry
input ENUM_TIMEFRAMES RangeTF = PERIOD_D1;              // Timeframe for range calculation
input int TrendFilterEMA = 200;                         // EMA period for trend filter (0=disabled)
input ENUM_TIMEFRAMES ExecTF = PERIOD_M15;              // Timeframe for trade execution

//+------------------------------------------------------------------+
//| Input parameters for news filter                                 |
//+------------------------------------------------------------------+
input bool UseNewsFilter = true;                        // Enable economic news filter
input int NewsMinutesBefore = 60;                       // Minutes before news to suspend trading
input int NewsMinutesAfter = 30;                        // Minutes after news to resume trading
input int NewsImpactLevel = 3;                          // Minimum impact level: 1=low, 2=medium, 3=high
input bool CloseOnHighImpact = true;                    // Close positions before high-impact news

//+------------------------------------------------------------------+
//| Input parameters for indicator filters                           |
//+------------------------------------------------------------------+
input bool UseATRFilter = true;                         // Enable ATR filter
input int ATRPeriod = 14;                               // ATR period
input double MinATRPips = 20.0;                         // Minimum ATR required (pips)
input double MaxATRPips = 150.0;                        // Maximum ATR allowed (pips)
input double ATR_Mult_Min = 1.25;                       // Minimum ATR multiplier for breakout validation
input double ATR_Mult_Max = 3.0;                        // Maximum ATR multiplier for breakout validation

input bool UseBBFilter = true;                          // Enable Bollinger Bands filter
input int BBPeriod = 20;                                // Bollinger Bands period
input double BBDeviation = 2.0;                         // Bollinger Bands standard deviation
input double Min_Width_Pips = 30.0;                     // Minimum BB width (pips)
input double Max_Width_Pips = 120.0;                    // Maximum BB width (pips)

input bool UseEMAFilter = true;                         // Enable EMA filter
input int EMAPeriod = 200;                              // EMA period for trend filter
input ENUM_TIMEFRAMES EMATf = PERIOD_H1;                // EMA timeframe

input bool UseADXFilter = true;                         // Enable ADX filter
input int ADXPeriod = 14;                               // ADX period
input double ADXThreshold = 20.0;                       // Minimum ADX threshold

input bool UseRSIFilter = false;                        // Enable RSI filter
input int RSIPeriod = 14;                               // RSI period
input double RSIOverbought = 70.0;                      // RSI overbought level (do not buy above)
input double RSIOversold = 30.0;                        // RSI oversold level (do not sell below)

//+------------------------------------------------------------------+
//| Input parameters for risk management                             |
//+------------------------------------------------------------------+
input double RiskPerTrade = 1.0;                        // Risk per trade (% of account)
input double MaxRiskPerDay = 5.0;                       // Maximum risk per day (% of account)
input int MaxPositions = 5;                             // Maximum number of open positions
input bool UseTrailingStop = true;                      // Enable trailing stop
input double TrailingStopPips = 50.0;                   // Trailing stop distance (pips)
input double TrailingStepPips = 10.0;                   // Trailing step (pips)
input bool UsePartialClose = true;                      // Enable partial close
input double PartialClosePct = 50.0;                    // Percentage to close on partial close
input double PartialCloseProfitPips = 100.0;            // Profit in pips to trigger partial close
input double StopLossPips = 100.0;                      // Stop loss distance (pips)
input double TakeProfitPips = 200.0;                    // Take profit distance (pips)
input double MinLotSize = 0.01;                         // Minimum lot size
input double MaxLotSize = 10.0;                         // Maximum lot size
input double LotStep = 0.01;                            // Lot step

//+------------------------------------------------------------------+
//| Global variables                                                 |
//+------------------------------------------------------------------+
double DailyRiskUsed = 0.0;
datetime LastTradeDate = 0;
int ATRHandle = INVALID_HANDLE;
int BBHandle = INVALID_HANDLE;
int EMAHandle = INVALID_HANDLE;
int ADXHandle = INVALID_HANDLE;
int RSIHandle = INVALID_HANDLE;
int VolumeHandle = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Class for managing risk                                          |
//+------------------------------------------------------------------+
class CRiskManager
{
private:
   double AccountBalance() { return AccountInfoDouble(ACCOUNT_BALANCE); }
   double AccountEquity() { return AccountInfoDouble(ACCOUNT_EQUITY); }
   double TickSize(const string symbol) { return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE); }
   double TickValue(const string symbol) { return SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE); }
   double PointSize(const string symbol) { return SymbolInfoDouble(symbol, SYMBOL_POINT); }
   
   // Convert pips to points
   double PipsToPoints(const string symbol, double pips)
   {
      double point = PointSize(symbol);
      double tickSize = TickSize(symbol);
      return (pips * point) / tickSize;
   }
   
   // Calculate lot size based on risk
   double CalculateLotSize(const string symbol, double stopLossPips)
   {
      double balance = AccountBalance();
      double riskAmount = balance * (RiskPerTrade / 100.0);
      double stopLossPoints = PipsToPoints(symbol, stopLossPips);
      double tickValue = TickValue(symbol);
      
      if(stopLossPoints <= 0 || tickValue <= 0) return MinLotSize;
      
      double lotSize = riskAmount / (stopLossPoints * tickValue);
      lotSize = NormalizeDouble(lotSize, 2);
      
      // Apply lot size constraints
      if(lotSize < MinLotSize) lotSize = MinLotSize;
      if(lotSize > MaxLotSize) lotSize = MaxLotSize;
      lotSize = MathFloor(lotSize / LotStep) * LotStep;
      
      return lotSize;
   }
   
   // Check daily risk limit
   bool CheckDailyRisk(double riskAmount)
   {
      datetime currentDate = TimeCurrent();
      MqlDateTime dateStruct;
      TimeToStruct(currentDate, dateStruct);
      dateStruct.hour = 0;
      dateStruct.min = 0;
      dateStruct.sec = 0;
      datetime todayStart = StructToTime(dateStruct);
      
      if(LastTradeDate < todayStart)
      {
         DailyRiskUsed = 0.0;
         LastTradeDate = currentDate;
      }
      
      double dailyRiskLimit = AccountBalance() * (MaxRiskPerDay / 100.0);
      if(DailyRiskUsed + riskAmount > dailyRiskLimit) return false;
      
      DailyRiskUsed += riskAmount;
      return true;
   }
   
   // Check maximum positions
   bool CheckMaxPositions()
   {
      int positions = PositionsTotal();
      return positions < MaxPositions;
   }
   
public:
   // Initialize indicator handles
   bool InitIndicators()
   {
      if(UseATRFilter)
         ATRHandle = iATR(_Symbol, ExecTF, ATRPeriod);
      if(UseBBFilter)
         BBHandle = iBands(_Symbol, ExecTF, BBPeriod, 0, BBDeviation, PRICE_CLOSE);
      if(UseEMAFilter)
         EMAHandle = iMA(_Symbol, EMATf, EMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
      if(UseADXFilter)
         ADXHandle = iADX(_Symbol, ExecTF, ADXPeriod);
      if(UseRSIFilter)
         RSIHandle = iRSI(_Symbol, ExecTF, RSIPeriod, PRICE_CLOSE);
      if(RequireVolumeConfirm)
         VolumeHandle = iVolumes(_Symbol, ExecTF, VOLUME_TICK);
      
      return true;
   }
   
   // Deinitialize indicators
   void DeinitIndicators()
   {
      if(ATRHandle != INVALID_HANDLE) IndicatorRelease(ATRHandle);
      if(BBHandle != INVALID_HANDLE) IndicatorRelease(BBHandle);
      if(EMAHandle != INVALID_HANDLE) IndicatorRelease(EMAHandle);
      if(ADXHandle != INVALID_HANDLE) IndicatorRelease(ADXHandle);
      if(RSIHandle != INVALID_HANDLE) IndicatorRelease(RSIHandle);
      if(VolumeHandle != INVALID_HANDLE) IndicatorRelease(VolumeHandle);
   }
   
   // Check if trading is allowed based on news filter
   bool IsTradingAllowed()
   {
      if(!UseNewsFilter) return true;
      
      // Check economic calendar using FFCal indicator
      // This is a placeholder - actual implementation would use FFCal indicator
      // For now, assume trading is allowed
      return true;
   }
   
   // Check if position should be closed due to high-impact news
   bool ShouldCloseForNews()
   {
      if(!UseNewsFilter || !CloseOnHighImpact) return false;
      
      // Check if high-impact news is imminent using FFCal indicator
      // This is a placeholder - actual implementation would use FFCal indicator
      return false;
   }
   
   // Validate breakout based on indicator filters
   bool ValidateBreakout(int direction) // direction: 1 for long, -1 for short
   {
      // Check ATR filter
      if(UseATRFilter)
      {
         double atrValues[1];
         if(CopyBuffer(ATRHandle, 0, 0, 1, atrValues) <= 0) return false;
         double atrPips = atrValues[0] / PointSize(_Symbol) * 10; // Convert to pips
         
         if(atrPips < MinATRPips || atrPips > MaxATRPips) return false;
         
         // Check breakout magnitude vs ATR
         double breakoutSize = 0; // This should be calculated based on actual breakout
         if(breakoutSize < atrPips * ATR_Mult_Min || breakoutSize > atrPips * ATR_Mult_Max)
            return false;
      }
      
      // Check Bollinger Bands filter
      if(UseBBFilter)
      {
         double upperBand[1], lowerBand[1];
         if(CopyBuffer(BBHandle, 1, 0, 1, upperBand) <= 0) return false;
         if(CopyBuffer(BBHandle, 2, 0, 1, lowerBand) <= 0) return false;
         
         double bbWidthPips = (upperBand[0] - lowerBand[0]) / PointSize(_Symbol) * 10;
         if(bbWidthPips < Min_Width_Pips || bbWidthPips > Max_Width_Pips) return false;
      }
      
      // Check EMA filter for trend
      if(UseEMAFilter && TrendFilterEMA > 0)
      {
         double emaValues[1];
         if(CopyBuffer(EMAHandle, 0, 0, 1, emaValues) <= 0) return false;
         
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(direction == 1 && currentPrice <= emaValues[0]) return false;
         if(direction == -1 && currentPrice >= emaValues[0]) return false;
      }
      
      // Check ADX filter for trend strength
      if(UseADXFilter)
      {
         double adxValues[1];
         if(CopyBuffer(ADXHandle, 0, 0, 1, adxValues) <= 0) return false;
         if(adxValues[0] < ADXThreshold) return false;
      }
      
      // Check RSI filter for overbought/oversold
      if(UseRSIFilter)
      {
         double rsiValues[1];
         if(CopyBuffer(RSIHandle, 0, 0, 1, rsiValues) <= 0) return false;
         if(direction == 1 && rsiValues[0] >= RSIOverbought) return false;
         if(direction == -1 && rsiValues[0] <= RSIOversold) return false;
      }
      
      // Check volume confirmation
      if(RequireVolumeConfirm)
      {
         double volumeValues[1];
         if(CopyBuffer(VolumeHandle, 0, 0, 1, volumeValues) <= 0) return false;
         
         // Calculate SMA of volume (simplified)
         double volumeSMA = 0;
         for(int i = 1; i <= 20; i++)
         {
            double vol[1];
            if(CopyBuffer(VolumeHandle, 0, i, 1, vol) > 0)
               volumeSMA += vol[0];
         }
         volumeSMA /= 20;
         
         if(volumeValues[0] < volumeSMA * 1.5) return false;
      }
      
      return true;
   }
   
   // Calculate position parameters
   bool CalculatePositionParams(const string symbol, int direction, 
                                double &lotSize, double &slPrice, double &tpPrice)
   {
      if(!CheckMaxPositions()) return false;
      
      // Calculate lot size
      lotSize = CalculateLotSize(symbol, StopLossPips);
      if(lotSize <= 0) return false;
      
      // Calculate risk amount for daily limit check
      double riskAmount = AccountBalance() * (RiskPerTrade / 100.0);
      if(!CheckDailyRisk(riskAmount)) return false;
      
      // Calculate stop loss and take profit prices
      double currentPrice = (direction == 1) ? SymbolInfoDouble(symbol, SYMBOL_ASK) 
                                             : SymbolInfoDouble(symbol, SYMBOL_BID);
      double point = PointSize(symbol);
      
      if(direction == 1) // Long
      {
         slPrice = currentPrice - (StopLossPips * point * 10);
         tpPrice = currentPrice + (TakeProfitPips * point * 10);
      }
      else // Short
      {
         slPrice = currentPrice + (StopLossPips * point * 10);
         tpPrice = currentPrice - (TakeProfitPips * point * 10);
      }
      
      return true;
   }
   
   // Manage trailing stop
   void ManageTrailingStop()
   {
      if(!UseTrailingStop) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            long type = PositionGetInteger(POSITION_TYPE);
            double currentPrice = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(symbol, SYMBOL_BID) 
                                                              : SymbolInfoDouble(symbol, SYMBOL_ASK);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentSL = PositionGetDouble(POSITION_SL);
            double point = PointSize(symbol);
            
            double newSL = currentSL;
            
            if(type == POSITION_TYPE_BUY)
            {
               double trailLevel = currentPrice - (TrailingStopPips * point * 10);
               if(trailLevel > currentSL && trailLevel > openPrice)
               {
                  newSL = trailLevel;
                  // Apply trailing step
                  if(newSL - currentSL >= TrailingStepPips * point * 10)
                  {
                     ModifyPositionSL(symbol, ticket, newSL);
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL)
            {
               double trailLevel = currentPrice + (TrailingStopPips * point * 10);
               if(trailLevel < currentSL && trailLevel < openPrice)
               {
                  newSL = trailLevel;
                  // Apply trailing step
                  if(currentSL - newSL >= TrailingStepPips * point * 10)
                  {
                     ModifyPositionSL(symbol, ticket, newSL);
                  }
               }
            }
         }
      }
   }
   
   // Check for partial close conditions
   void CheckPartialClose()
   {
      if(!UsePartialClose) return;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double profit = PositionGetDouble(POSITION_PROFIT);
            double volume = PositionGetDouble(POSITION_VOLUME);
            double point = PointSize(symbol);
            
            // Convert profit to pips
            double profitPips = MathAbs(profit) / (volume * TickValue(symbol) * point * 10);
            
            if(profitPips >= PartialCloseProfitPips)
            {
               double closeVolume = volume * (PartialClosePct / 100.0);
               ClosePartialPosition(symbol, ticket, closeVolume);
            }
         }
      }
   }
   
   // Modify position stop loss
   bool ModifyPositionSL(const string symbol, ulong ticket, double newSL)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_SLTP;
      request.position = ticket;
      request.symbol = symbol;
      request.sl = newSL;
      
      return OrderSend(request, result);
   }
   
   // Close partial position
   bool ClosePartialPosition(const string symbol, ulong ticket, double volume)
   {
      MqlTradeRequest request = {};
      MqlTradeResult result = {};
      
      request.action = TRADE_ACTION_DEAL;
      request.position = ticket;
      request.symbol = symbol;
      request.volume = volume;
      request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
      request.price = SymbolInfoDouble(symbol, (request.type == ORDER_TYPE_SELL) ? SYMBOL_BID : SYMBOL_ASK);
      request.deviation = 10;
      
      return OrderSend(request, result);
   }
   
   // Close all positions (for news filter)
   void CloseAllPositions()
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(PositionSelectByTicket(ticket))
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            double volume = PositionGetDouble(POSITION_VOLUME);
            
            MqlTradeRequest request = {};
            MqlTradeResult result = {};
            
            request.action = TRADE_ACTION_DEAL;
            request.position = ticket;
            request.symbol = symbol;
            request.volume = volume;
            request.type = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
            request.price = SymbolInfoDouble(symbol, (request.type == ORDER_TYPE_SELL) ? SYMBOL_BID : SYMBOL_ASK);
            request.deviation = 10;
            
            OrderSend(request, result);
         }
      }
   }
};

//+------------------------------------------------------------------+
//| Global risk manager instance                                     |
//+------------------------------------------------------------------+
CRiskManager RiskManager;

//+------------------------------------------------------------------+
//| Initialization function                                          |
//+------------------------------------------------------------------+
bool RiskManagementInit()
{
   return RiskManager.InitIndicators();
}

//+------------------------------------------------------------------+
//| Deinitialization function                                        |
//+------------------------------------------------------------------+
void RiskManagementDeinit()
{
   RiskManager.DeinitIndicators();
}

//+------------------------------------------------------------------+
//| Main risk management function                                    |
//+------------------------------------------------------------------+
bool ManageRisk(const string symbol, int direction, 
                double &lotSize, double &slPrice, double &tpPrice)
{
   // Check if trading is allowed
   if(!RiskManager.IsTradingAllowed()) return false;
   
   // Check if positions should be closed due to news
   if(RiskManager.ShouldCloseForNews())
   {
      RiskManager.CloseAllPositions();
      return false;
   }
   
   // Validate breakout with indicator filters
   if(!RiskManager.ValidateBreakout(direction)) return false;
   
   // Calculate position parameters
   if(!RiskManager.CalculatePositionParams(symbol, direction, lotSize, slPrice, tpPrice))
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Function to manage open positions                                |
//+------------------------------------------------------------------+
void ManageOpenPositions()
{
   RiskManager.ManageTrailingStop();
   RiskManager.CheckPartialClose();
   
   // Check if positions should be closed due to news
   if(RiskManager.ShouldCloseForNews())
   {
      RiskManager.CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Function to reset daily risk counter                             |
//+------------------------------------------------------------------+
void ResetDailyRisk()
{
   DailyRiskUsed = 0.0;
   LastTradeDate = TimeCurrent();
}

//+------------------------------------------------------------------+