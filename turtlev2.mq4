//+------------------------------------------------------------------+
//|                                                     turtlev2.mq4 |
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
extern int i_maxposinum     = 4;

extern int i_starttradedays = 20;
extern int i_stoptradedays  = 10;

extern int i_maxslip        = 0;
extern int i_magicnumber    = 9527;
extern int i_maxretrytimes  = 5;

extern int i_ma_period  = 12;
extern int i_ma_shift   = 6;

extern int i_hl_open_period  = 20;
extern int i_hl_close_period = 10;

extern double i_sar_step1  = 0.02;
extern double i_sar_max1   = 0.2;

extern double i_sar_step2  = 0.01;
extern double i_sar_max2   = 0.1;

//+------------------------------------------------------------------+
double g_unitvolume = 0;
double g_atr = 0;
double g_lot = 0;

double g_nextposiprice = 0;

int g_posinum = 0;
int g_posistatus = 0;

int g_trend_dir = NOTREND;

int g_last_trade_result = LASTTRADEUNKNOWN;
int g_ignore_times = 0;


//temporary
double g_last_sar_value=0;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int init()
  {
//---
   g_unitvolume = MarketInfo(Symbol(), MODE_TICKVALUE)/MarketInfo(Symbol(), MODE_TICKSIZE);
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
  bool close_flag = false;
  CheckPosiStatus();
   switch(g_posistatus){
   case EMPTYPOSI:
      CalcBasicInfo();
      TryTrendTrade();
      break;
   case TRADINGPOSI:
      close_flag = TrendTradeCloseCheck();
      TrendTradeAddPosiCheck();
      break;
   case MAXPOSI:
      close_flag = TrendTradeCloseCheck();
      break;
   }
   
   //if(close_flag){
   //   CheckPosiStatus();
   //   CalcBasicInfo();
   //   TryTrendTrade();
   //}
   
////---
//   int new_trend_dir = CheckTrend();
//   int old_trend_dir = g_trend_dir;
//   if(new_trend_dir != NOTREND){ //if got trend now
//      if(old_trend_dir == NOTREND){ // close all orders whose direction is not identical to the trend 
//         CloseVibrateOrder(new_trend_dir);
//      }
//      
//      TrendTrade();
//   }
//   else{ //new_trend_dir == NOTREND
//      if(old_trend_dir != NOTREND){ // close all trend orders
//         CloseAllOrder();
//      }
//      
//      VibrateTrade();
//   }
//   g_trend_dir = new_trend_dir;
   
   return(0);
  }
  

//+------------------------------------------------------------------+
//| 1. Trend Trade                                                   |
//+------------------------------------------------------------------+
void TrendTrade(){
   
}

void TryTrendTrade(){
   int order_type;
   int order_send_result = 0;
   
   order_type = CheckTrendIndicators();
   if()
   /*
   if(g_last_trade_result == LASTTRADELOSS || g_last_trade_result == LASTTRADEUNKNOWN){
      order_type = CheckTrendIndicators(); // check using normal indicator
   }else if(g_last_trade_result == LASTTRADEPROFIT && g_ignore_times > 0){
      order_type = CheckTrendIndicators(); // TODO check using a 'bigger' indicator
   }else{// g_last_trade_result == LASTTRADEPROFIT && g_ignore_times == 0
      order_type = RECOMMEND_NONE;
      g_ignore_times++;
   }
   */
   
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
}

int CheckResultAndIndicators(){ // TODO: check:1.result of last breakthrough, 2. indicators
   int order_type;
   order_type = CheckTrendIndicators();
   if(order_type != RECOMMEND_NONE){
      if(g_last_trade_result == LASTTRADELOSS){
         return 0; //TODO
      }
      
   }
   return 0; //TODO
}

bool TrendTradeCloseCheck(){
   bool close_flag = false;
   close_flag = CheckTrendIndicatorsForClose();
   
   if(close_flag){
      CloseAllOrder();
      ClearBasicInfo();
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
   //checkresult = CheckHighLowForClose();
   checkresult = CheckSARForClose();
   
   return(checkresult);
}


int CheckMAandSAR(){
   int recommend = CheckMovingAverage();
   double sar_value = iSAR(NULL,0,i_sar_step1,i_sar_max1,0);
   //double sar_value = iSAR(NULL,PERIOD_D1,i_sar_step,i_sar_max,0);
   if(sar_value < Close[0] && recommend==RECOMMEND_BUY)
      return(RECOMMEND_BUY);
   if(sar_value > Close[0] && recommend==RECOMMEND_SELL)
      return(RECOMMEND_SELL);
   return(RECOMMEND_NONE);
}
int CheckSAR(bool bigger_param=false){
   //double sar_value = iSAR(NULL,0,i_sar_step,i_sar_max,0);
   double sar_value = 0;
   
   if(bigger_param == false){
      sar_value = iSAR(NULL,0,i_sar_step1,i_sar_max1,0);
   }else{
      sar_value = iSAR(NULL,0,i_sar_step2,i_sar_max2,0);
   }
   Print("sar:"+sar_value+";last_sar:"+g_last_sar_value);
   if(sar_value < Close[0] && g_last_sar_value > Close[1]){
      g_last_sar_value = sar_value;
      return(RECOMMEND_BUY);
   }
   if(sar_value > Close[0] && g_last_sar_value < Close[1]){
      g_last_sar_value = sar_value;
      return(RECOMMEND_SELL);
   }
   g_last_sar_value = sar_value;
   return(RECOMMEND_NONE);
} 
bool CheckSARForClose(){
   //double sar_value = iSAR(NULL,0,i_sar_step,i_sar_max,0);
   double sar_value = iSAR(NULL,0,i_sar_step1,i_sar_max1,0); // TODO
   g_last_sar_value = sar_value;
   if(sar_value > Close[0] && g_trend_dir==LONGTREND)
      return(true);
   if(sar_value < Close[0] && g_trend_dir==SHORTTREND)
      return(true);
   return(false);
}


int CheckMovingAverage(){
   double ma = 0;
   ma = iMA(NULL,PERIOD_D1,i_ma_period,i_ma_shift,MODE_SMA,PRICE_CLOSE,0);
   if(Open[1] > ma && Close[1] < ma && Bid < ma){
      return(RECOMMEND_SELL);
   }
   if(Open[1] < ma && Close[1] > ma && Ask > ma){
      return(RECOMMEND_BUY);
   }
   return(RECOMMEND_NONE);
}
bool CheckMovingAverageForClose(){
   bool close_flag = false;
   if(g_trend_dir == LONGTREND && CheckMovingAverage() == RECOMMEND_SELL)
      close_flag = true;
   if(g_trend_dir == SHORTTREND && CheckMovingAverage() == RECOMMEND_BUY)
      close_flag = true;
   
   return(close_flag);
}


int CheckHighLow(bool bigger_param=false){
   int     highest_day = iHighest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period,1);
   double  highest     = iHigh(NULL,PERIOD_D1,highest_day);
   
   int     lowest_day  = iLowest(NULL,PERIOD_D1,MODE_HIGH,i_hl_open_period,1);
   double  lowest      = iLow(NULL,PERIOD_D1,lowest_day);
   
   if(Ask>highest)
      return(RECOMMEND_BUY);
   if(Bid<lowest)
      return(RECOMMEND_SELL);
      
   return(RECOMMEND_NONE);
}
bool CheckHighLowForClose(){
   bool close_flag = false;
   if(g_trend_dir == LONGTREND){
      int lowest_day  = iLowest(NULL,PERIOD_D1,MODE_HIGH,i_hl_close_period,1);
      double  lowest      = iLow(NULL,PERIOD_D1,lowest_day);
      if(Bid<lowest)
         close_flag = true;
   }
   else if(g_trend_dir == SHORTTREND){
      int highest_day = iHighest(NULL,PERIOD_D1,MODE_HIGH,i_hl_close_period,1);
      double  highest     = iHigh(NULL,PERIOD_D1,highest_day);
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
         if(OrderType()==OP_BUY && Bid < stoploss){
            g_last_trade_result = LASTTRADELOSS;
         }else if(OrderType()==OP_SELL && Ask > stoploss){
            g_last_trade_result = LASTTRADELOSS;
         }else{
            g_last_trade_result = LASTTRADEPROFIT;
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
   
   g_last_trade_result = LASTTRADEUNKNOWN;
   g_ignore_times = 0;
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