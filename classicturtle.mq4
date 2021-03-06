//+------------------------------------------------------------------+
//|                                                classicturtle.mq4 |
//|                              Copyright 2015, Hard Software Corp. |
//|                                        https://www.localhost.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2015, Hard Software Corp."
#property link      "https://www.localhost.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
#define INFOLOG     0
#define WARNINGLOG  1
#define ERRORLOG    2

#define NOTREND     0
#define LONGTREND   1
#define SHORTTREND  2

#define EMPTYPOSI   0
#define TRADINGPOSI 1
#define MAXPOSI     2

#define RECOMMEND_NONE  0
#define RECOMMEND_BUY   1
#define RECOMMEND_SELL  2 

#define LASTTRADEUNKNOWN 0
#define LASTTRADEPROFIT  1
#define LASTTRADELOSS    2

#define ALLORDERTYPES  -1

//+------------------------------------------------------------------+
input int i_maxposinum      = 4;

extern int i_starttradedays = 20;
extern int i_stoptradedays  = 10;

extern int i_maxslip        = 0;
extern int i_magicnumber    = 9527;
extern int i_maxretrytimes  = 5;

extern int i_hl_open_period1  = 20;
extern int i_hl_close_period1 = 10;

extern int i_hl_open_period2  = 55;
extern int i_hl_close_period2 = 20;


//+------------------------------------------------------------------+
double g_unitvolume = 0;
double g_atr = 0;
double g_lot = 0;

double g_nextposiprice = 0;

int g_posinum = 0;
int g_posistatus = 0;

int g_trend_dir = NOTREND;

int g_last_trade_result = LASTTRADEUNKNOWN;
bool g_tracking_ignored = false;
int  g_tracking_posinum = 0;
double g_tracking_stoploss[];  // TODO: use a dynamic index range
int g_tracking_dir = NOTREND;
double g_tracking_atr = 0;
double g_tracking_nextposiprice = 0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//---
   g_unitvolume = MarketInfo(Symbol(), MODE_TICKVALUE)/MarketInfo(Symbol(), MODE_TICKSIZE);
   ArrayResize(g_tracking_stoploss,i_maxposinum);
   ArrayInitialize(g_tracking_stoploss,0.0);
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
int deinit()
  {
//---
   return(0);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
int start()
  {
  CheckPosiStatus();
   switch(g_posistatus){
   case EMPTYPOSI:
      CalcBasicInfo();
      TrackIgnoreBreak();
      TryTrendTrade();
      break;
   case TRADINGPOSI:
      TrendTradeCloseCheck();
      TrendTradeAddPosiCheck();
      break;
   case MAXPOSI:
      TrendTradeCloseCheck();
      break;
   }
   
   return(0);
  }
  

//+------------------------------------------------------------------+
//| 1. Trend Trade                                                   |
//+------------------------------------------------------------------+


void TryTrendTrade(){
   int order_type;
   int order_send_result = 0;
   int order_type_biggerindicator;
   
   order_type = CheckTrendIndicators();
   if(order_type != RECOMMEND_NONE){
      if(g_last_trade_result == LASTTRADEPROFIT){
         Print("ignored!");
         order_type_biggerindicator = CheckTrendIndicators(true); // check for 55 days
         if(order_type_biggerindicator == RECOMMEND_NONE && g_tracking_ignored == false){
            //if not tracking, this breakthrough(20days) will be tracked from now on
            Print("Start Tracking!");
            g_last_trade_result = LASTTRADEUNKNOWN;
            g_tracking_posinum = 1;
            g_tracking_ignored = true;
            g_tracking_atr = g_atr;
            
            if(order_type == RECOMMEND_BUY){
               g_tracking_dir = LONGTREND;
               g_tracking_stoploss[0] = Bid - 2*g_tracking_atr;
               g_tracking_nextposiprice = Ask + g_tracking_atr/2;
            }
            else if(order_type == RECOMMEND_SELL){
               g_tracking_dir = SHORTTREND;
               g_tracking_stoploss[0] = Ask + 2*g_tracking_atr;
               g_tracking_nextposiprice = Bid + g_tracking_atr/2;
            }
         }else if(order_type_biggerindicator != RECOMMEND_NONE){
            Print("Prepare to buy(bigger indicator)");
            order_type = order_type_biggerindicator;
         }
      }
   }else{  //recommend == none
      return;
   }
   
   if(g_tracking_ignored == true){
      return ;
   }
   
   if(order_type == RECOMMEND_BUY){
      order_send_result = BuyIt();
      if(order_send_result > 0){
         g_trend_dir = LONGTREND;
         g_posistatus = TRADINGPOSI;
         g_nextposiprice = Ask + g_atr/2;
      }
   }
   else if(order_type == RECOMMEND_SELL){
      order_send_result = SellIt();
      if(order_send_result > 0){
         g_trend_dir = SHORTTREND;
         g_posistatus = TRADINGPOSI;
         g_nextposiprice = Bid - g_atr/2;
      }
   }
   g_last_trade_result = LASTTRADEUNKNOWN;
   
   g_tracking_ignored = false;
   g_tracking_posinum = 0;
   ArrayInitialize(g_tracking_stoploss,0.0);
   g_tracking_dir = NOTREND;
   g_tracking_atr = 0;
   g_tracking_nextposiprice = 0;
}

void TrackIgnoreBreak(){
   int index;
   if(g_tracking_ignored==false)
      return;
   
   //Add posi check
   if(g_tracking_posinum<i_maxposinum){
      if(g_tracking_dir == LONGTREND){
         if(Ask > g_tracking_nextposiprice){
            //update
            for(index=0;index<g_tracking_posinum;index++){
               g_tracking_stoploss[index] += g_tracking_atr/2;
            }
            //add posi
            g_tracking_stoploss[g_tracking_posinum] = Ask - 2*g_tracking_atr;
            g_tracking_posinum++;
         }
      }
      else if(g_tracking_dir == SHORTTREND){
         if(Bid < g_tracking_nextposiprice){
            //update
            for(index=0;index<g_tracking_posinum;index++){
               g_tracking_stoploss[index] -= g_tracking_atr/2;
            }
            //add posi
            g_tracking_stoploss[g_tracking_posinum] = Bid + 2*g_tracking_atr;
            g_tracking_posinum++;
         }
      }
   }
   
   //stop loss check
   if((g_tracking_dir == LONGTREND && Bid < g_tracking_stoploss[g_tracking_posinum-1])
        || (g_tracking_dir == SHORTTREND && Ask > g_tracking_stoploss[g_tracking_posinum-1]) ){
       
      g_tracking_ignored = false;
      g_tracking_posinum = 0;
      ArrayInitialize(g_tracking_stoploss,0.0);
      g_tracking_dir = NOTREND;
      g_tracking_atr = 0;
      g_tracking_nextposiprice = 0;
      
      g_last_trade_result = LASTTRADELOSS;
      
      Print("[Tracking]stop loss");
      return ;
   }
   
   //close check
   if(CheckTrendIndicatorsForClose()){
      g_tracking_ignored = false;
      g_tracking_posinum = 0;
      ArrayInitialize(g_tracking_stoploss,0.0);
      g_tracking_dir = NOTREND;
      g_tracking_atr = 0;
      g_tracking_nextposiprice = 0;
      
      g_last_trade_result = LASTTRADEPROFIT;
      Print("[Tracking]close!(profit)");
   }
}

bool TrendTradeCloseCheck(){
   bool close_flag = false;
   close_flag = CheckTrendIndicatorsForClose();
   
   if(close_flag){
      CloseAllOrder();
      ClearBasicInfo();
      g_last_trade_result = LASTTRADEPROFIT;
      Print("[CLOSECHECK]last profit");
   }
   return(close_flag);
}

void TrendTradeAddPosiCheck(){
   int order_send_result = 0;
   
   if(g_trend_dir == LONGTREND){
      if(Ask > g_nextposiprice){
         UpdateTrendTradeStoploss();
         order_send_result = BuyIt();
         if(order_send_result>0){
            g_nextposiprice = Ask + g_atr/2;
         }
      }
   }
   else if(g_trend_dir == SHORTTREND){
      if(Bid < g_nextposiprice){
         UpdateTrendTradeStoploss();
         order_send_result = SellIt();
         if(order_send_result>0){
            g_nextposiprice = Bid - g_atr/2;
         }
      }
   }
}

void UpdateTrendTradeStoploss(){
   Alert("<FixTkSLL>");
	for(int index=OrdersTotal()-1;index>=0;index--)
	{
		if(!OrderSelect(index,SELECT_BY_POS,MODE_TRADES)) continue;
		if(OrderSymbol()==Symbol() && OrderMagicNumber()==i_magicnumber)
		{   
		   if(OrderType() == OP_BUY){
		      while(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss() + g_atr/2,OrderTakeProfit(),0,Blue));
		   }
		   if(OrderType() == OP_SELL){
		      while(!OrderModify(OrderTicket(),OrderOpenPrice(),OrderStopLoss() - g_atr/2,OrderTakeProfit(),0,Blue));
		   }
		   
		}
   }   
}

//| end of Trend Trade                                                
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Indicators

int CheckTrendIndicators(bool bigger_param=false){
   int recommend_order_type = RECOMMEND_NONE;
   //recommend_order_type = CheckMovingAverage(); 
   //recommend_order_type = CheckHighLow(); 
   recommend_order_type = CheckHighLow(bigger_param);
   
   return(recommend_order_type);
}
bool CheckTrendIndicatorsForClose(){
   bool checkresult = false;
   //checkresult = CheckMovingAverageForClose();
   checkresult = CheckHighLowForClose();
   //checkresult = CheckSARForClose();
   
   return(checkresult);
}

int CheckHighLow(bool bigger_param=false){
   int     highest_day,lowest_day;
   double  highest,lowest;
   
   if(bigger_param == false){  // 22,10
      highest_day = iHighest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period1,1);
      lowest_day  = iLowest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period1,1);
   }else{  // 55,20
      highest_day = iHighest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period2,1);
      lowest_day  = iLowest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period2,1);
   }
   highest        = iHigh(NULL,PERIOD_D1,highest_day);
   lowest         = iLow(NULL,PERIOD_D1,lowest_day);
   
   if(Ask>highest)
      return(RECOMMEND_BUY);
   if(Bid<lowest)
      return(RECOMMEND_SELL);
      
   return(RECOMMEND_NONE);
}
bool CheckHighLowForClose(){
   bool close_flag = false;
   if(g_trend_dir == LONGTREND){
      int lowest_day  = iLowest(NULL,PERIOD_D1,MODE_HIGH,i_hl_close_period1,1);
      double  lowest  = iLow(NULL,PERIOD_D1,lowest_day);
      if(Bid<lowest)
         close_flag = true;
   }
   else if(g_trend_dir == SHORTTREND){
      int highest_day  = iHighest(NULL,PERIOD_D1,MODE_HIGH,i_hl_close_period1,1);
      double  highest  = iHigh(NULL,PERIOD_D1,highest_day);
      if(Ask>highest)
         close_flag = true;
   }
   return(close_flag);
}

//| end of Indicators                                                
//+------------------------------------------------------------------+


void CloseAllOrder(int order_type=ALLORDERTYPES){
   Alert("<CloseAllTks>");
	for(int index=OrdersTotal()-1;index>=0;index--)
	{
		if(!OrderSelect(index,SELECT_BY_POS,MODE_TRADES)) continue;
		if(OrderSymbol()==Symbol() && OrderMagicNumber()==i_magicnumber)
		{   
		   if(order_type == ALLORDERTYPES || order_type == OP_BUY){
   		   if(OrderType() == OP_BUY){
   		      while(!OrderClose(OrderTicket(),OrderLots(),Bid,i_maxslip));
   		   }
   		}
   		if(order_type == ALLORDERTYPES || order_type == OP_SELL){
   		   if(OrderType() == OP_SELL){
   		      while(!OrderClose(OrderTicket(),OrderLots(),Ask,i_maxslip));
   		   }
		   }
		}
   }
}


//+------------------------------------------------------------------+
void CheckPosiStatus()
{
   int ordernumbers  = 0;
   double orderprice = 0;
   
   for(int orderIndex=0;orderIndex<OrdersTotal();orderIndex++){
      if(!OrderSelect(orderIndex,SELECT_BY_POS,MODE_TRADES)){
         Print("select order error. order index=",orderIndex);
         continue;
      }
      
      if(OrderSymbol() == Symbol() && OrderMagicNumber() == i_magicnumber){
         ordernumbers++;
         if(g_posinum>0)
            continue;
         
         //recover info from orders
         if(OrderType() == OP_BUY){
            g_trend_dir = LONGTREND;
            if(ordernumbers == 1 || OrderOpenPrice()>orderprice){ //if it is the first order; or it's price is more favorable
               orderprice = OrderOpenPrice();
               g_atr = (orderprice - OrderStopLoss())/2;
               g_nextposiprice = orderprice + g_atr/2;
               g_lot = OrderLots();
            }
         }
         else if(OrderType() == OP_SELL){
            g_trend_dir = SHORTTREND;
            if(ordernumbers == 1 || OrderOpenPrice()<orderprice){
               orderprice = OrderOpenPrice();
               g_atr = (OrderStopLoss() - orderprice)/2;
               g_nextposiprice = orderprice - g_atr/2;
               g_lot = OrderLots();
            }
         }
      }
   }
   
   if(ordernumbers == 0){
      ClearBasicInfo();
   }else if(ordernumbers == i_maxposinum){
      g_posistatus = MAXPOSI;
   }else{
      g_posistatus = TRADINGPOSI;
   }
   g_posinum = ordernumbers;
}

void CalcBasicInfo()
{
   g_atr = iATR(NULL,PERIOD_D1,20,0);
   //Alert("ATR: "+DoubleToStr(g_atr)+"; unitvolume: "+g_unitvolume+";");
  
   g_lot = (AccountFreeMargin()/100)/(g_atr*g_unitvolume);
   g_lot = NormalizeDouble(g_lot,2);
   
   if(g_lot < MarketInfo(Symbol(),MODE_MINLOT)){
      g_lot = MarketInfo(Symbol(),MODE_MINLOT);
   }else if(g_lot > MarketInfo(Symbol(),MODE_MAXLOT)){
      g_lot = MarketInfo(Symbol(),MODE_MAXLOT);
   }
   
   g_lot = NormalizeDouble(g_lot,2);
   
   //check last trade result
   if(g_last_trade_result == LASTTRADEUNKNOWN && OrdersHistoryTotal()>0){
   //TODO add one condition: if(g_ignore>0 && calc_ignore_trade == true){ if(price +- g_tempatr < stoploss) then tradeloss elseif(SAR reverted) tradeprofit  calc_ignore =false;
      if(OrderSelect(OrdersHistoryTotal()-1,SELECT_BY_POS,MODE_HISTORY)){
         double stoploss = OrderStopLoss();
         Print("[CALC]stoploss:",stoploss);
         if(OrderType()==OP_BUY && Bid < stoploss){
            Print("[CALC]Bid:",Bid);
            g_last_trade_result = LASTTRADELOSS;
            Print("[CALC]last loss");
         }else if(OrderType()==OP_SELL && Ask > stoploss){
            Print("[CALC]Ask:",Ask);
            g_last_trade_result = LASTTRADELOSS;
            Print("[CALC]last loss");
         }else{
            g_last_trade_result = LASTTRADEPROFIT;
            Print("[CALC]last profit");
         }
      }else{
         Print("select history order error. order index=",OrdersHistoryTotal()-1);
      }
   }
}

void ClearBasicInfo()
{
   g_lot = 0;
   g_atr = 0;
   g_nextposiprice = 0;
   
   g_posinum = 0;
   g_posistatus = EMPTYPOSI;
   
   g_trend_dir = NOTREND;
   
   //g_last_trade_result = LASTTRADEUNKNOWN;
}

int BuyIt(){
   int tid = 0;
   int retryleft = i_maxretrytimes;
   double stoploss_price = Bid - 2*g_atr;
   while(true){
      tid = UserOrderSend(Symbol(),OP_BUY,g_lot,Ask,i_maxslip,stoploss_price, 0, "comment",i_magicnumber,0,Red);
      if(tid > 0){
         g_posinum++;
         break;
      }
      
      retryleft--;
      if(retryleft<=0)
         break;
   }
   return(tid);
}

int SellIt(){
   int tid = 0;
   int retryleft = i_maxretrytimes;
   double stoploss_price = Ask + 2*g_atr;
   while(true){
      tid = UserOrderSend(Symbol(),OP_SELL,g_lot,Bid,i_maxslip,stoploss_price, 0, "comment",i_magicnumber,0,Blue);
      if(tid > 0){
         g_posinum++;
         break;
      }
      
      retryleft--;
      if(retryleft<=0)
         break;
   }
   return(tid);
}

int UserOrderSend(string symbol,int cmd,double volume,double price,int slippage,double stoploss,double takeprofit,string comment,int magic,datetime expiration,color arrow_color){
   int tid = 0;
   Alert("下单："+symbol+DoubleToStr(price)+ "|Lot:" + DoubleToStr(volume,2) + "|SL:"+DoubleToStr(stoploss)+"|TP:"+DoubleToStr(takeprofit));
   Print("[ATR]:",g_atr);
   while(true){
      tid=OrderSend(symbol,cmd,volume,price,slippage,stoploss,takeprofit,comment,magic,expiration,arrow_color);  
		
		if(tid>0)
		{
			Alert("下单成功..");
			break;
		}
		
		int Error=GetLastError();                 // 失败
		switch(Error)                             // Overcomable errors
		{
			case 135:Alert("报价已经改变，请重试..");
			RefreshRates();                     // Update data
			continue;                           // At the next iteration
			case 136:Alert("没有报价，请等待更新..");
			while(RefreshRates()==false)        // Up to a new tick
			Sleep(1);                        // Cycle delay
			continue;                           // At the next iteration
			case 146:Alert("交易系统繁忙，请重试..");
			Sleep(500);                         // Simple solution
			RefreshRates();                     // Update data
			continue;                           // At the next iteration
		}

		switch(Error) // Critical errors
		{
			case 2 : Alert("通用错误.");
			break;                              // Exit 'switch'
			case 5 : Alert("客户端版本过低.");
			break;                              // Exit 'switch'
			case 64: Alert("账号被屏蔽.");
			break;                              // Exit 'switch'
			case 133:Alert("禁止交易");
			break;                              // Exit 'switch'
			default:
			Alert("发生错误",Error);// Other alternatives   
			break;
		}
		break;
   }
   return(tid);
}