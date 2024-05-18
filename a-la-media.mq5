//+------------------------------------------------------------------+
//|                                              Moving Averages.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
#include <MT4Orders.mqh>

input double MaximumRisk        = 0.8;    // Maximum Risk in percentage
input double DecreaseFactor     = 3;       // Descrease factor
input int    MovingPeriod       = 80;      // Moving Average period
input int    MovingShift        = 6;       // Moving Average shift

// Custom
input int    apt_media                =80;// Media
input int    apt_intervalo_aumento    =24; // Intervalo de aumento
input double    apt_lotes_buy         =0.1;// Lotes para buys
input double    apt_lotes_sell        =0.1;// Lotes para sells
//---
int    ExtHandle=0;
int    rsi_handle;
bool   ExtHedging=false;
CTrade ExtTrade;

// Custom
datetime last_bar_time = 0;
double current_bid_price;
double current_ask_price;
int    tipo_trades_abiertos=10;
double   ma[1];
MqlRates rt[2];

#define MA_MAGIC 1234502


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void) {
  // Iniciamos parametros para que no esten vacios

   current_bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   current_ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   // Inicializar last_bar_time con el tiempo de la última barra al inicio
   last_bar_time = iTime(_Symbol, _Period, 0);

//--- prepare trade class to control positions if hedging mode is active
   ExtHedging=((ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE)==ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
   ExtTrade.SetExpertMagicNumber(MA_MAGIC);
   ExtTrade.SetMarginMode();
   ExtTrade.SetTypeFillingBySymbol(Symbol());
//--- Moving Average indicator
   ExtHandle=iMA(_Symbol,_Period,MovingPeriod,MovingShift,MODE_SMA,PRICE_CLOSE);
   if(ExtHandle==INVALID_HANDLE)
     {
      printf("Error creating MA indicator");
      return(INIT_FAILED);
     }
//--- ok
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void) {


   // Actualizamos todos los datos en cada tick, luego veremos si es en cada barra mejor.
   actualizamosDatos();

   if(IsNewBar()) {
      Print("-------------------------------------------------------------------Nueva barra detectada: ", TimeToString(last_bar_time));
      // Abrimos posiciones
      abrimosTrades();
     }


   // Cerramos posiciones
   cerramosTrades();


}



void abrimosTrades(void) {
   Print("-----------------------------------------rt[0].open", rt[0].open);
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)){
      ENUM_ORDER_TYPE signal=WRONG_VALUE;

      if(rt[0].open<ma[0] && rt[0].close<ma[0]) {
        signal=ORDER_TYPE_BUY;  // buy conditions
      } else if(rt[0].open>ma[0] && rt[0].close>ma[0]) {
        signal=ORDER_TYPE_SELL;    // sell conditions
      }
   Print("-----------------------------------------signal = ", signal);

   //--- Compramos
      if(signal!=WRONG_VALUE) {
         ExtTrade.PositionOpen(_Symbol,signal,TradeSizeOptimized(), SymbolInfoDouble(_Symbol,signal==ORDER_TYPE_SELL ? SYMBOL_BID:SYMBOL_ASK), 0,0);
         tipo_trades_abiertos = signal;
      }

   }
}

void cerramosTrades(void) {
//--- positions already selected before
   uint total=PositionsTotal();
   if(total>0 && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      //Compras
      if(tipo_trades_abiertos == ORDER_TYPE_BUY && current_bid_price>ma[0]) {
         for (uint i = total; i > 0; i--) {
         Print("--------------------------------------------------------------------------------------------------------- total = ", total);
         Print("--------------------------------------------------------------------------------------------------------- i = ", i);
            if(tipo_trades_abiertos==OrderGetInteger(ORDER_TYPE)){
               bool result = ExtTrade.PositionClose(_Symbol,3);
               tipo_trades_abiertos=10;
            }
         }
      } else if(tipo_trades_abiertos == POSITION_TYPE_SELL && current_bid_price<ma[0]) {
         for (uint i = total; i > 0; i--) {
            if(tipo_trades_abiertos==OrderGetInteger(ORDER_TYPE)){
               bool result = ExtTrade.PositionClose(_Symbol,3);
               tipo_trades_abiertos=10;
            }
         }
      }
   }


}


void actualizamosDatos(void) {
   current_bid_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   current_ask_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);


   //--- go trading only for first ticks of new bar
   if(CopyRates(_Symbol,_Period,0,2,rt)!=2) {
      Print("CopyRates of ",_Symbol," failed, no history");
      return;
   }
   // Si no hay tick_volume o no tenemos suficientes datos en el grafico
   // para hacer nuestra Media, esperamos a que hay mas bars en el grafico
   if(rt[1].tick_volume>1)
      return;

   Print("-----------------------------------------ma[0]", ma[0]);
   //--- get current Moving Average
   if(CopyBuffer(ExtHandle,0,0,1,ma)!=1) {
      Print("CopyBuffer from iMA failed, no data");
      return;
   }
   Print("-----------------------------------------ma[0]", ma[0]);

}

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 2 decimales
//+------------------------------------------------------------------+
double nor2(double value_to_normalize) {
  return NormalizeDouble(value_to_normalize,2);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 1 decimales
//+------------------------------------------------------------------+
double nor1(double value_to_normalize) {
  return NormalizeDouble(value_to_normalize,1);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que normalñiza doubles con 0 decimales
//+------------------------------------------------------------------+
double nor0(double value_to_normalize) {
  return NormalizeDouble(value_to_normalize,0);
}
//+------------------------------------------------------------------+


double GetCurrentProfit() {
  double Res = 0;

  for (int i = OrdersTotal() - 1; i >= 0; i--)
    if (OrderSelect(i, SELECT_BY_POS))
      Res += OrderProfit() + OrderSwap() + OrderCommission();

  return(Res);
}


//+------------------------------------------------------------------+
//| Function to check if a new bar is formed                         |
//+------------------------------------------------------------------+
bool IsNewBar() {
   // Obtener el tiempo de la barra actual
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   // Verificar si el tiempo de la barra actual es diferente al tiempo almacenado
   if(current_bar_time != last_bar_time)
     {
      // Actualizar last_bar_time con el tiempo de la nueva barra
      last_bar_time = current_bar_time;
      return true;
     }
   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Chequeamos que esteamos trabajando con trades abiertos por el script y en este symbol              |
//+------------------------------------------------------------------+
bool checkIsValidTrade(uint i) {
   bool result = false;
   string position_symbol=PositionGetSymbol(i);
   if(_Symbol==position_symbol && MA_MAGIC==PositionGetInteger(POSITION_MAGIC)) {
      result=true;
   }
   return(result);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//| No se usa, a ver que hacemos con esta funcion al final                                  |
//+------------------------------------------------------------------+
double TradeSizeOptimized(void)
  {
   double price=0.0;
   double margin=0.0;
//--- select lot size
   if(!SymbolInfoDouble(_Symbol,SYMBOL_ASK,price))
      return(0.0);
   if(!OrderCalcMargin(ORDER_TYPE_BUY,_Symbol,1.0,price,margin))
      return(0.0);
   if(margin<=0.0)
      return(0.0);

   double lot=NormalizeDouble(AccountInfoDouble(ACCOUNT_MARGIN_FREE)*MaximumRisk/margin,2);
//--- calculate number of losses orders without a break
   if(DecreaseFactor>0)
     {
      //--- select history for access
      HistorySelect(0,TimeCurrent());
      //---
      int    orders=HistoryDealsTotal();  // total history deals
      int    losses=0;                    // number of losses orders without a break

      for(int i=orders-1;i>=0;i--)
        {
         ulong ticket=HistoryDealGetTicket(i);
         if(ticket==0)
           {
            Print("HistoryDealGetTicket failed, no trade history");
            break;
           }
         //--- check symbol
         if(HistoryDealGetString(ticket,DEAL_SYMBOL)!=_Symbol)
            continue;
         //--- check Expert Magic number
         if(HistoryDealGetInteger(ticket,DEAL_MAGIC)!=MA_MAGIC)
            continue;
         //--- check profit
         double profit=HistoryDealGetDouble(ticket,DEAL_PROFIT);
         if(profit>0.0)
            break;
         if(profit<0.0)
            losses++;
        }
      //---
      if(losses>1)
         lot=NormalizeDouble(lot-lot*losses/DecreaseFactor,1);
     }
//--- normalize and check limits
   double stepvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   lot=stepvol*NormalizeDouble(lot/stepvol,0);

   double minvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   if(lot<minvol)
      lot=minvol;

   double maxvol=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   if(lot>maxvol)
      lot=maxvol;
//--- return trading volume
   return(lot);
  }

