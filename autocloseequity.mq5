//+------------------------------------------------------------------+
//|                                              EquityTargetEA.mq5 |
//|                                                                  |
//|                                   EA untuk Close by Target Equity |
//+------------------------------------------------------------------+
#property copyright "Equity Target EA"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input Parameters
input group "=== Target Settings ==="
input double TargetEquity = 30000.0;          // Target Equity

input group "=== Display Settings ==="
input bool   ShowPanel = true;              // Tampilkan Info Panel
input ENUM_BASE_CORNER PanelCorner = CORNER_LEFT_UPPER; // Posisi Panel
input int    PanelX = 300;                  // Panel X Position
input int    PanelY = 30;                   // Panel Y Position
input color  PanelColor = clrBlack;         // Warna Panel
input color  TextColor = clrWhite;          // Warna Text
input color  EquityColor = clrAqua;         // Warna Equity
input color  TargetColor = clrYellow;       // Warna Target
input color  ProfitColor = clrLime;         // Warna Profit
input color  LossColor = clrRed;            // Warna Loss

//--- Global Variables
bool targetReached = false;
CTrade trade;

//--- Forward Declarations
void CloseAllPositions();
void DeleteAllPendingOrders();

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Reset flag setiap reload
   targetReached = false;
   
   // Setup trade object for fast execution
   trade.SetAsyncMode(true);  // Async mode for speed
   trade.SetDeviationInPoints(500);
   trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Check if trading is allowed
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED))
   {
      Alert("ERROR: Autotrading is disabled in terminal!");
      Print("ERROR: Please enable AutoTrading button (Ctrl+E)");
      return(INIT_FAILED);
   }
   
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Alert("ERROR: EA trading is not allowed!");
      Print("ERROR: Check 'Allow Algo Trading' in Tools > Options > Expert Advisors");
      return(INIT_FAILED);
   }
   
   Print("=== Equity Target EA Initialized ===");
   Print("Current Equity: ", currentEquity);
   Print("Target Equity: ", TargetEquity);
   Print("Remaining: ", TargetEquity - currentEquity);
   Print("AutoTrading: ENABLED");
   Print("Async Mode: ENABLED");
   Print("Status: RESET - Ready to monitor");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Hapus objek panel jika ada
   ObjectsDeleteAll(0, "EqPanel_");
   Print("=== Equity Target EA Stopped ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check target equity
   if(!targetReached)
      CheckTargetReached();
   
   // Update display panel
   if(ShowPanel)
      UpdateInfoPanel();
}

//+------------------------------------------------------------------+
//| Check if target reached                                          |
//+------------------------------------------------------------------+
void CheckTargetReached()
{
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(currentEquity >= TargetEquity)
   {
      string message = StringFormat("TARGET TERCAPAI! Equity: %.2f / Target: %.2f", 
                                   currentEquity, TargetEquity);
      Print(message);
      
      // Close all positions first
      CloseAllPositions();
      DeleteAllPendingOrders();
      
      // Set flag after closing
      targetReached = true;
      
      // Show alert after execution completed
      Alert(message);
      Print("Semua posisi dan pending order telah ditutup.");
   }
}



//+------------------------------------------------------------------+
//| Close all positions using CTrade async mode                      |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   int totalPositions = PositionsTotal();
   int closed = 0;
   
   Print("Fast closing ", totalPositions, " positions using CTrade async...");
   
   // Close all positions using CTrade async mode
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0)
      {
         if(trade.PositionClose(ticket))
            closed++;
      }
   }
   
   Print("Close requests sent: ", closed, "/", totalPositions);
}

//+------------------------------------------------------------------+
//| Get retcode description                                          |
//+------------------------------------------------------------------+
string GetRetcodeDescription(uint retcode)
{
   switch(retcode)
   {
      case TRADE_RETCODE_DONE: return "Request completed";
      case TRADE_RETCODE_PLACED: return "Order placed";
      case TRADE_RETCODE_REJECT: return "Request rejected";
      case TRADE_RETCODE_CANCEL: return "Request canceled";
      case TRADE_RETCODE_ERROR: return "Request processing error";
      case TRADE_RETCODE_TIMEOUT: return "Request timeout";
      case TRADE_RETCODE_INVALID: return "Invalid request";
      case TRADE_RETCODE_INVALID_VOLUME: return "Invalid volume";
      case TRADE_RETCODE_INVALID_PRICE: return "Invalid price";
      case TRADE_RETCODE_INVALID_STOPS: return "Invalid stops";
      case TRADE_RETCODE_TRADE_DISABLED: return "Trade disabled";
      case TRADE_RETCODE_MARKET_CLOSED: return "Market closed";
      case TRADE_RETCODE_NO_MONEY: return "Not enough money";
      case TRADE_RETCODE_PRICE_CHANGED: return "Price changed";
      case TRADE_RETCODE_PRICE_OFF: return "No quotes";
      case TRADE_RETCODE_INVALID_EXPIRATION: return "Invalid expiration";
      case TRADE_RETCODE_ORDER_CHANGED: return "Order changed";
      case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Too many requests";
      case TRADE_RETCODE_NO_CHANGES: return "No changes";
      case TRADE_RETCODE_SERVER_DISABLES_AT: return "Autotrading disabled by server";
      case TRADE_RETCODE_CLIENT_DISABLES_AT: return "Autotrading disabled by client";
      case TRADE_RETCODE_LOCKED: return "Request locked";
      case TRADE_RETCODE_FROZEN: return "Order or position frozen";
      case TRADE_RETCODE_INVALID_FILL: return "Invalid fill type";
      default: return "Unknown error";
   }
}

//+------------------------------------------------------------------+
//| Delete all pending orders (limit, stop, dll)                     |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   int totalDeleted = 0;
   int totalOrders = OrdersTotal();
   
   // Collect all orders first
   ulong tickets[];
   ArrayResize(tickets, totalOrders);
   
   for(int i = 0; i < totalOrders; i++)
   {
      tickets[i] = OrderGetTicket(i);
   }
   
   // Delete all orders rapidly
   for(int i = 0; i < ArraySize(tickets); i++)
   {
      ulong ticket = tickets[i];
      if(ticket <= 0) continue;
      
      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      
      request.action = TRADE_ACTION_REMOVE;
      request.order = ticket;
      
      if(OrderSend(request, result))
      {
         if(result.retcode == TRADE_RETCODE_DONE)
         {
            totalDeleted++;
         }
      }
   }
   
   if(totalOrders > 0)
      Print("Pending orders deleted: ", totalDeleted, " of ", totalOrders);
}

//+------------------------------------------------------------------+
//| Update info panel                                                |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
   int x = PanelX;
   int y = PanelY;
   int lineHeight = 18;
   int panelWidth = 240;
   int panelHeight = 183;
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double currentProfit = currentEquity - currentBalance;
   double remaining = TargetEquity - currentEquity;
   
   // Calculate total lots
   double totalLots = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetTicket(i) > 0)
      {
         totalLots += PositionGetDouble(POSITION_VOLUME);
      }
   }
   
   // Background panel - solid rectangle
   string bgName = "EqPanel_BG";
   if(ObjectFind(0, bgName) < 0)
   {
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, bgName, OBJPROP_CORNER, PanelCorner);
      ObjectSetInteger(0, bgName, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x-5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y-5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, PanelColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, bgName, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, true);
   
   // Title
   CreateLabel("EqPanel_Title", x, y, "=== EQUITY TARGET EA ===", 0, clrYellow);
   y += lineHeight + 5;
   
   // Current Equity
   color equityColor = currentEquity >= TargetEquity ? clrLime : EquityColor;
   CreateLabel("EqPanel_Equity", x, y, 
               StringFormat("Equity    : %.2f", currentEquity), 0, equityColor);
   y += lineHeight;
   
   // Target
   CreateLabel("EqPanel_Target", x, y, 
               StringFormat("Target    : %.2f", TargetEquity), 0, TargetColor);
   y += lineHeight;
   
   // Remaining
   color remainColor = remaining > 0 ? clrOrange : clrLime;
   CreateLabel("EqPanel_Remain", x, y, 
               StringFormat("Remaining : %.2f", remaining), 0, remainColor);
   y += lineHeight + 3;
   
   // Current Balance
   CreateLabel("EqPanel_Balance", x, y, 
               StringFormat("Balance   : %.2f", currentBalance), 0, clrLightGray);
   y += lineHeight;
   
   // Current Profit/Loss
   color profitColor = currentProfit >= 0 ? ProfitColor : LossColor;
   CreateLabel("EqPanel_Profit", x, y, 
               StringFormat("Float P/L : %.2f", currentProfit), 0, profitColor);
   y += lineHeight + 3;
   
   // Total Lots
   CreateLabel("EqPanel_TotalLots", x, y, 
               StringFormat("Total Lots: %.2f", totalLots), 0, clrCyan);
   y += lineHeight;
   
   // Open Positions
   int totalPos = PositionsTotal();
   int totalOrders = OrdersTotal();
   CreateLabel("EqPanel_Positions", x, y, 
               StringFormat("Pos: %d | Orders: %d", totalPos, totalOrders), 0, clrWhite);
   y += lineHeight + 3;
   
   // Status
   string status = targetReached ? "TARGET REACHED!" : "MONITORING...";
   color statusColor = targetReached ? clrRed : clrLime;
   CreateLabel("EqPanel_Status", x, y, status, 0, statusColor);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create label object                                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, int width, color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, PanelCorner);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   }
   
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_BACK, false); // Text di depan
}

//+------------------------------------------------------------------+
