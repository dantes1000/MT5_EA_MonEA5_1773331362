//+------------------------------------------------------------------+
//|                                                      Utilities.mqh |
//|                        Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Utility functions for timeframe conversion, pip calculations,    |
//| and error logging                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Timeframe conversion functions                                   |
//+------------------------------------------------------------------+

//--- Convert timeframe enum to minutes
int TimeframeToMinutes(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return 1;
      case PERIOD_M2:  return 2;
      case PERIOD_M3:  return 3;
      case PERIOD_M4:  return 4;
      case PERIOD_M5:  return 5;
      case PERIOD_M6:  return 6;
      case PERIOD_M10: return 10;
      case PERIOD_M12: return 12;
      case PERIOD_M15: return 15;
      case PERIOD_M20: return 20;
      case PERIOD_M30: return 30;
      case PERIOD_H1:  return 60;
      case PERIOD_H2:  return 120;
      case PERIOD_H3:  return 180;
      case PERIOD_H4:  return 240;
      case PERIOD_H6:  return 360;
      case PERIOD_H8:  return 480;
      case PERIOD_H12: return 720;
      case PERIOD_D1:  return 1440;
      case PERIOD_W1:  return 10080;
      case PERIOD_MN1: return 43200;
      default:         return 0;
   }
}

//--- Convert minutes to timeframe enum
ENUM_TIMEFRAMES MinutesToTimeframe(int minutes)
{
   switch(minutes)
   {
      case 1:     return PERIOD_M1;
      case 2:     return PERIOD_M2;
      case 3:     return PERIOD_M3;
      case 4:     return PERIOD_M4;
      case 5:     return PERIOD_M5;
      case 6:     return PERIOD_M6;
      case 10:    return PERIOD_M10;
      case 12:    return PERIOD_M12;
      case 15:    return PERIOD_M15;
      case 20:    return PERIOD_M20;
      case 30:    return PERIOD_M30;
      case 60:    return PERIOD_H1;
      case 120:   return PERIOD_H2;
      case 180:   return PERIOD_H3;
      case 240:   return PERIOD_H4;
      case 360:   return PERIOD_H6;
      case 480:   return PERIOD_H8;
      case 720:   return PERIOD_H12;
      case 1440:  return PERIOD_D1;
      case 10080: return PERIOD_W1;
      case 43200: return PERIOD_MN1;
      default:    return PERIOD_CURRENT;
   }
}

//--- Get higher timeframe from current
ENUM_TIMEFRAMES GetHigherTimeframe(ENUM_TIMEFRAMES tf)
{
   int minutes = TimeframeToMinutes(tf);
   
   if(minutes >= 43200) return PERIOD_MN1; // Monthly is highest
   if(minutes >= 10080) return PERIOD_MN1;
   if(minutes >= 1440)  return PERIOD_W1;
   if(minutes >= 720)   return PERIOD_D1;
   if(minutes >= 480)   return PERIOD_H12;
   if(minutes >= 360)   return PERIOD_H8;
   if(minutes >= 240)   return PERIOD_H6;
   if(minutes >= 180)   return PERIOD_H4;
   if(minutes >= 120)   return PERIOD_H3;
   if(minutes >= 60)    return PERIOD_H2;
   if(minutes >= 30)    return PERIOD_H1;
   if(minutes >= 20)    return PERIOD_M30;
   if(minutes >= 15)    return PERIOD_M20;
   if(minutes >= 10)    return PERIOD_M15;
   if(minutes >= 6)     return PERIOD_M12;
   if(minutes >= 5)     return PERIOD_M10;
   if(minutes >= 4)     return PERIOD_M6;
   if(minutes >= 3)     return PERIOD_M5;
   if(minutes >= 2)     return PERIOD_M4;
   if(minutes >= 1)     return PERIOD_M3;
   
   return PERIOD_M2;
}

//--- Get lower timeframe from current
ENUM_TIMEFRAMES GetLowerTimeframe(ENUM_TIMEFRAMES tf)
{
   int minutes = TimeframeToMinutes(tf);
   
   if(minutes <= 1)     return PERIOD_M1;  // M1 is lowest
   if(minutes <= 2)     return PERIOD_M1;
   if(minutes <= 3)     return PERIOD_M2;
   if(minutes <= 4)     return PERIOD_M3;
   if(minutes <= 5)     return PERIOD_M4;
   if(minutes <= 6)     return PERIOD_M5;
   if(minutes <= 10)    return PERIOD_M6;
   if(minutes <= 12)    return PERIOD_M10;
   if(minutes <= 15)    return PERIOD_M12;
   if(minutes <= 20)    return PERIOD_M15;
   if(minutes <= 30)    return PERIOD_M20;
   if(minutes <= 60)    return PERIOD_M30;
   if(minutes <= 120)   return PERIOD_H1;
   if(minutes <= 180)   return PERIOD_H2;
   if(minutes <= 240)   return PERIOD_H3;
   if(minutes <= 360)   return PERIOD_H4;
   if(minutes <= 480)   return PERIOD_H6;
   if(minutes <= 720)   return PERIOD_H8;
   if(minutes <= 1440)  return PERIOD_H12;
   if(minutes <= 10080) return PERIOD_D1;
   if(minutes <= 43200) return PERIOD_W1;
   
   return PERIOD_MN1;
}

//+------------------------------------------------------------------+
//| Pip calculation functions                                        |
//+------------------------------------------------------------------+

//--- Get pip value for current symbol
double GetPipValue()
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0 || tickSize == 0) return 0;
   
   // Calculate pip value based on tick size
   double pipValue = (tickValue / tickSize) * point * 10;
   
   // For JPY pairs, adjust for 2 decimal places instead of 4
   if(StringFind(_Symbol, "JPY") != -1)
   {
      pipValue = (tickValue / tickSize) * point * 100;
   }
   
   return pipValue;
}

//--- Convert pips to price points
int PipsToPoints(double pips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0) return 0;
   
   // For JPY pairs
   if(StringFind(_Symbol, "JPY") != -1)
   {
      return (int)MathRound(pips * 100);
   }
   
   return (int)MathRound(pips * 10000);
}

//--- Convert price points to pips
double PointsToPips(int points)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0) return 0;
   
   // For JPY pairs
   if(StringFind(_Symbol, "JPY") != -1)
   {
      return points / 100.0;
   }
   
   return points / 10000.0;
}

//--- Calculate distance in pips between two prices
double PriceDistanceInPips(double price1, double price2)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0) return 0;
   
   double distance = MathAbs(price1 - price2);
   
   // For JPY pairs
   if(StringFind(_Symbol, "JPY") != -1)
   {
      return distance / (point * 100);
   }
   
   return distance / (point * 10000);
}

//--- Calculate ATR value in pips
double ATRInPips(int period, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double atrValue = iATR(_Symbol, tf, period, 0);
   
   if(atrValue == 0) return 0;
   
   return PriceDistanceInPips(0, atrValue);
}

//--- Calculate Bollinger Bands width in pips
double BBWidthInPips(int period, double deviation, ENUM_TIMEFRAMES tf = PERIOD_CURRENT)
{
   double upperBand = iBands(_Symbol, tf, period, 0, deviation, PRICE_CLOSE, MODE_UPPER, 0);
   double lowerBand = iBands(_Symbol, tf, period, 0, deviation, PRICE_CLOSE, MODE_LOWER, 0);
   
   if(upperBand == 0 || lowerBand == 0) return 0;
   
   return PriceDistanceInPips(lowerBand, upperBand);
}

//+------------------------------------------------------------------+
//| Error logging functions                                          |
//+------------------------------------------------------------------+

//--- Log error with timestamp
void LogError(string functionName, string errorMessage, int errorCode = 0)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMessage;
   
   if(errorCode != 0)
   {
      logMessage = StringFormat("%s | ERROR in %s: %s (Code: %d)", 
                                timestamp, functionName, errorMessage, errorCode);
   }
   else
   {
      logMessage = StringFormat("%s | ERROR in %s: %s", 
                                timestamp, functionName, errorMessage);
   }
   
   Print(logMessage);
}

//--- Log warning with timestamp
void LogWarning(string functionName, string warningMessage)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMessage = StringFormat("%s | WARNING in %s: %s", 
                                    timestamp, functionName, warningMessage);
   
   Print(logMessage);
}

//--- Log information with timestamp
void LogInfo(string functionName, string infoMessage)
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMessage = StringFormat("%s | INFO in %s: %s", 
                                    timestamp, functionName, infoMessage);
   
   Print(logMessage);
}

//--- Log trade operation with timestamp
void LogTrade(string operation, double price, double volume, string comment = "")
{
   string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS);
   string logMessage;
   
   if(comment != "")
   {
      logMessage = StringFormat("%s | TRADE %s: Price=%.5f, Volume=%.2f, Comment=%s", 
                                timestamp, operation, price, volume, comment);
   }
   else
   {
      logMessage = StringFormat("%s | TRADE %s: Price=%.5f, Volume=%.2f", 
                                timestamp, operation, price, volume);
   }
   
   Print(logMessage);
}

//--- Check and log last error
bool CheckLastError(string functionName)
{
   int lastError = GetLastError();
   
   if(lastError != 0)
   {
      LogError(functionName, "Last error occurred", lastError);
      ResetLastError();
      return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Additional utility functions                                     |
//+------------------------------------------------------------------+

//--- Normalize price to tick size
double NormalizePrice(double price)
{
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0) return price;
   
   return MathRound(price / tickSize) * tickSize;
}

//--- Normalize volume to lot step
double NormalizeVolume(double volume)
{
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(lotStep == 0) return volume;
   
   // Round to nearest lot step
   volume = MathRound(volume / lotStep) * lotStep;
   
   // Ensure within min/max limits
   volume = MathMax(volume, minLot);
   volume = MathMin(volume, maxLot);
   
   return volume;
}

//--- Calculate stop loss price based on pips
double CalculateStopLossPrice(bool isBuy, double entryPrice, double stopLossPips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0) return 0;
   
   double stopLossPoints = PipsToPoints(stopLossPips);
   
   if(isBuy)
   {
      return entryPrice - (stopLossPoints * point);
   }
   else
   {
      return entryPrice + (stopLossPoints * point);
   }
}

//--- Calculate take profit price based on pips
double CalculateTakeProfitPrice(bool isBuy, double entryPrice, double takeProfitPips)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(point == 0) return 0;
   
   double takeProfitPoints = PipsToPoints(takeProfitPips);
   
   if(isBuy)
   {
      return entryPrice + (takeProfitPoints * point);
   }
   else
   {
      return entryPrice - (takeProfitPoints * point);
   }
}

//--- Check if current time is within trading session
bool IsTradingSession(int startHour, int startMinute, int endHour, int endMinute)
{
   MqlDateTime currentTime;
   TimeToStruct(TimeCurrent(), currentTime);
   
   int currentMinutes = currentTime.hour * 60 + currentTime.min;
   int startMinutes = startHour * 60 + startMinute;
   int endMinutes = endHour * 60 + endMinute;
   
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   }
   else
   {
      // Session crosses midnight
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
   }
}

//--- Calculate risk percentage based on stop loss and position size
double CalculateRiskPercentage(double entryPrice, double stopLossPrice, double volume, double accountBalance)
{
   if(accountBalance == 0) return 0;
   
   double riskAmount = MathAbs(entryPrice - stopLossPrice) * volume;
   double pipValue = GetPipValue();
   
   if(pipValue != 0)
   {
      riskAmount *= pipValue;
   }
   
   return (riskAmount / accountBalance) * 100;
}

//+------------------------------------------------------------------+
