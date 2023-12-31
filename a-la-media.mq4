//+------------------------------------------------------------------+
//|                                                   a-la-media.mq4 |
//|                                                     Ignasi Farre |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property version   "3.00"
#property strict


#define MAGIC  300


//--- input parameters
input int       apt_media=120;// Media
input double    apt_lotes_buy=0.1;// Lotes para buys
input double    apt_lotes_sell=0.1;// Lotes para sells
input int       apt_intervalo_aumento=24;// Intervalo de aumento
input int       apt_limite_para_entrada_buy=0; // Punto donde se puede comprar
input int       apt_limite_para_entrada_sell=0; // Punto donde se puede vender
input bool      apt_subidas_multiplicadas=true; // Subidas multiplicadas
input bool      apt_parar_en_ultimo_toque_media=false; // Parar programa en ultimo toque de media

input bool      apt_ventas=true; // Incluir ventas
input bool      apt_compras=true; // Incluir compras

// Varaibles staticas
static bool se_ha_operado_en_barra_actual=false;
static double media = 0;// Precio de media actual
static bool ventas=true; // Incluir ventas
static bool compras=true; // Incluir compras
static int tipo_grupo_entradas=0;// 1=compras, 2=ventas
static int num_entradas_consecutivas=0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    // Si se ha reiniciado el programa tenemos que checkear las entradas
    get_numero_entradas_consecutivas();
    get_tipo_entradas();
    ventas=apt_ventas;
    compras=apt_compras;

    // Creación de lineas
    ObjectCreate("LimiteCompras", OBJ_HLINE, 0, Time[0], apt_limite_para_entrada_buy, 0, 0); 
    ObjectSetInteger(0,"LimiteCompras",OBJPROP_COLOR,clrGreen);
    ObjectSetInteger(0,"LimiteCompras",OBJPROP_WIDTH,3);
    ObjectCreate("LimiteVentas", OBJ_HLINE, 0, Time[0], apt_limite_para_entrada_sell, 0, 0);
    ObjectSetInteger(0,"LimiteVentas",OBJPROP_WIDTH,3);

  return(INIT_SUCCEEDED);
 }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
 }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    if(Bars<apt_media+1)
        return;

    if(IsNewBarOnChart()) {
        se_ha_operado_en_barra_actual = false;
    }

    // Analizamos todos los parametros que necesitamos
    media=nor1(iMA(NULL,0,apt_media,0,MODE_EMA,PRICE_CLOSE,0));

    // Grupo de compras
    if(tipo_grupo_entradas==1 && nor0(Bid)>=nor0(media)) {
        cerrar_operaciones_compra();
    }
    // Grupo de ventas
    if(tipo_grupo_entradas==2 && nor0(Ask)<=nor0(media)) {
        cerrar_operaciones_venta();
    }

    // Vamos a coger las cordenadas de las lineas para ver si podemos meter entradas.
    double limite_para_entrada_buy =  ObjectGetDouble(0, "LimiteCompras", OBJPROP_PRICE );
    double limite_para_entrada_sell =  ObjectGetDouble(0, "LimiteVentas", OBJPROP_PRICE );

    if(!se_ha_operado_en_barra_actual) {
        // Compras
        if(limite_para_entrada_buy != 0) {
            if(compras && nor0(Open[0])<nor0(media) && limite_para_entrada_buy > Bid) {
                compra();
            }
        } else {
            if(compras && nor0(Open[0])<nor0(media)) {
                compra();
            }
        }
        // Ventas
        if(limite_para_entrada_sell != 0) {
            if(ventas && nor0(Open[0])>nor0(media) && limite_para_entrada_sell < Ask) {
                venta();
            }
        } else {
            if(ventas && nor0(Open[0])>nor0(media)) {
                venta();
            }
        }
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de compra
//+------------------------------------------------------------------+
void get_tipo_entradas() {
    if(OrdersTotal()>0) {
        for(int i = OrdersTotal()-1; i >= 0; i--) {
            // Compras m1
            if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC) {
                if(OrderType() == OP_BUY) {
                    tipo_grupo_entradas=1;// Compras
                }else if(OrderType() == OP_SELL) {
                    tipo_grupo_entradas=2;// Ventas
                }
            }
        }
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de compra
//+------------------------------------------------------------------+
void get_numero_entradas_consecutivas() {
// TODO: esto no va bien, hay que contar el tiempo que hace que toco la media y sacar los calculos de barras que llevamos desde que toco la media
    num_entradas_consecutivas = OrdersTotal();
 }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de compra
//+------------------------------------------------------------------+
bool compra() {
    bool check_order = false;
    int order_id = 0;
    double lots = get_lots("buy");
    if(check_podemos_operar(lots)) {
        order_id = OrderSend(Symbol(),OP_BUY,lots,Ask,5,0,0,"Diferencia",MAGIC,0,Green);
        if(!order_id) {
            Print("Order send error ",GetLastError());
        } else {
            se_ha_operado_en_barra_actual=true;
            check_order=true;
            tipo_grupo_entradas=1;// Compras
            num_entradas_consecutivas++;
        }
    }
    return check_order;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion de venta
//+------------------------------------------------------------------+
bool venta() {
    bool check_order = false;
    int order_id = 0;
    double lots = get_lots("sell");
    if(check_podemos_operar(lots)) {
        order_id = OrderSend(Symbol(),OP_SELL,lots,Bid,5,0,0,"Diferencia",MAGIC,0,Green);
        if(!order_id) {
            Print("Order send error ",GetLastError());
        } else {
            se_ha_operado_en_barra_actual=true;
            check_order=true;
            tipo_grupo_entradas=2;// Ventas
            num_entradas_consecutivas++;
        }
    }
    return check_order;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que chequea las operaciones abiertas
//+------------------------------------------------------------------+
double get_lots(string type) {
    double initial_lots=apt_lotes_buy;
    if(type == "sell") {
        initial_lots=apt_lotes_sell;
    }

    double lots=initial_lots;
    if(apt_subidas_multiplicadas) {
        if(num_entradas_consecutivas>apt_intervalo_aumento*1) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*2) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*3) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*4) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*5) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*6) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*7) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*8) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*9) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*10) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*11) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*12) {
            lots=lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*13) {
            lots=lots*2;
        }
    } else {
        if(num_entradas_consecutivas>apt_intervalo_aumento*1) {
            lots=initial_lots*2;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*2) {
            lots=initial_lots*3;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*3) {
            lots=initial_lots*4;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*4) {
            lots=initial_lots*5;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*5) {
            lots=initial_lots*6;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*6) {
            lots=initial_lots*7;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*7) {
            lots=initial_lots*8;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*8) {
            lots=initial_lots*9;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*9) {
            lots=initial_lots*10;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*10) {
            lots=initial_lots*11;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*11) {
            lots=initial_lots*12;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*12) {
            lots=initial_lots*13;
        }
        if(num_entradas_consecutivas>apt_intervalo_aumento*13) {
            lots=initial_lots*14;
        }
    }
  return lots;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que chequea las operaciones abiertas
//+------------------------------------------------------------------+
void cerrar_operaciones_venta() {
	// Vamos a cerrar las ventas
    if(OrdersTotal()>0) {
        for(int i = OrdersTotal()-1; i >= 0; i--) {
            if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC) {
                bool check_close = OrderClose(OrderTicket(),OrderLots(),Ask,5);
                if(check_close==false) {
                    Alert("OrderClose failed");
                } else {
                    // Todo correcto....
                    if(apt_parar_en_ultimo_toque_media) {
                        compras=false;
                        ventas=false;
                    }
                }
            }
        }
    }
    // Se se han cerrado todas las entradas ponemos el grupo de entradas a 0
    if(OrdersTotal() == 0) {
        tipo_grupo_entradas=0;
	    num_entradas_consecutivas=0;
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que chequea las operaciones abiertas
//+------------------------------------------------------------------+
void cerrar_operaciones_compra() {
	// Vamos a cerrar las compras
    if(OrdersTotal()>0) {
        for(int i = OrdersTotal()-1; i >= 0; i--) {
            if(OrderSelect(i, SELECT_BY_POS) && OrderMagicNumber() == MAGIC) {
                bool check_close = OrderClose(OrderTicket(),OrderLots(),Bid,5);
                if(check_close==false) {
                    Alert("OrderClose failed");
                } else {
                    // Todo correcto....
                    if(apt_parar_en_ultimo_toque_media) {
                        compras=false;
                        ventas=false;
                    }
                }
            }
        }
    }
    // Se se han cerrado todas las entradas ponemos el grupo de entradas a 0
    if(OrdersTotal() == 0) {
        tipo_grupo_entradas=0;
	    num_entradas_consecutivas=0;
    }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que devuelve true si hay una nueva barra
//+------------------------------------------------------------------+
bool IsNewBarOnChart() {
    bool new_candle = false;
    static datetime lastbar;
    datetime curbar = (datetime)SeriesInfoInteger(_Symbol,_Period,SERIES_LASTBAR_DATE);

    if(lastbar != curbar) {
        lastbar = curbar;
        new_candle = true;
    }
    return new_candle;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funcion que checkea si hay operaciones abieras
//+------------------------------------------------------------------+
bool check_podemos_operar(double lots) {
  bool result = true;
  //double availableMarginCall = AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL);
  //double lots_to_call = (AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL))/MarketInfo(Symbol(),MODE_MARGINREQUIRED);

  if((AccountFreeMargin()-AccountInfoDouble(ACCOUNT_MARGIN_SO_CALL))/MarketInfo(Symbol(),MODE_MARGINREQUIRED) < lots) {
  	result = false;
  }
  return result;
 }
//+------------------------------------------------------------------+

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



