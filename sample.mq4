#property copyright "Codinal Systems"
#property link      "https://codinal-systems.com/"
#property version   "1.00"
#property strict

//--------------------------------------------------------------------------------------------//

//口座番号
#define ACCOUNT_NUMBER 13026156

//制限期間
#define EXPIRY_DATE "2022.12.31 23:59" 

//--------------------------------------------------------------------------------------------//

input string               orderSetting = "---------------注文設定---------------"; //▼注文
input int                  magicNum = 123;               //マジックナンバー
input int                  slippagePips = 20;            //スリッページ
input double               lots = 0.01;                  //Lotサイズ
input double               slPips = 10;                  //SL(Pips)
input double               tpPips = 10;                  //TP(Pips)
input double               maxSpreadPips = 10;           //許容スプレッド(Pips)
input int                  maxPosition = 5;              //最大ポジション数

input string               otherMargin = "";             //　
input string               otherSetting = "---------------その他設定---------------"; //▼その他
input int                  retry = 3;                    //注文失敗時のリトライ回数
input int                  interval = 3000;              //インターバル秒数(ms)

input string               closeMargin = "";             //　
input string               closeSetting = "---------------決済設定---------------"; //▼決済
input double               exitProfit = 1000;            //決済収益(円)

input string               rsiMargin = "";               //　
input string               rsiSetting = "---------------RSI設定---------------"; //▼RSI
input int                  rsiPeriod = 14;               //期間
input ENUM_APPLIED_PRICE   rsiPrice = PRICE_CLOSE;       //適用価格
input double               rsiHighLevel = 70.0;          //上レベル
input double               rsiLowLevel = 30.0;           //下レベル

//--------------------------------------------------------------------------------------------//

int slippage;
datetime lastTime;


// EAの挿入時に行う処理を記述する
int OnInit(){
   
   if (TimeCurrent() > StrToTime(EXPIRY_DATE) && EXPIRY_DATE != "0"){
      Alert("It has expired.\n有効期限が切れています。");
      return INIT_FAILED;
   }
   
   slippage = int(slippagePips * Pips() / Point);
   CreateButtonObject("BUTTON OBJECT", 5, 45, 100, 40, "強制全決済", clrWhite, 12, clrSalmon, clrNONE);
   
   EventSetMillisecondTimer(3000);
   
   
   return INIT_SUCCEEDED;
}


// EAの削除時に行う処理を記述する
void OnDeinit(const int reason){
   
}

void OnTick(){
   
   if (!IsTradeAllowed()) return;
   
   // 毎tickごとに処理を行う
   OrderExit();
   
   if (lastTime == iTime(Symbol(), Period(), 0)) return;
   lastTime = iTime(Symbol(), Period(), 0);
   
   // 新しい足形成時に一度だけ処理を行う
   OrderOpen();
}

// 注文処理を記述する
void OrderOpen(){
   
   double rsi = iRSI(Symbol(), Period(), rsiPeriod, rsiPrice, 1);
   double lastRsi = iRSI(Symbol(), Period(), rsiPeriod, rsiPrice, 2);

   if (OrdersCount(OP_BUY) < maxPosition && lastRsi < rsiHighLevel && rsi >= rsiHighLevel){
      int ticket = OrderSendBuy();
      if (ticket == -1) Sleep(interval);
   }
   if (OrdersCount(OP_SELL) < maxPosition && lastRsi > rsiLowLevel && rsi <= rsiLowLevel){
      int ticket = OrderSendSell();
      if (ticket == -1) Sleep(interval);
   }
}

// 決済処理を記述する
void OrderExit(){
   
   if (OrdersCount(OP_BUY) > 0 && OrdersProfitTotal(OP_BUY) > exitProfit){
      OrdersCloseAll(OP_BUY);
   }

   if (OrdersCount(OP_SELL) > 0 && OrdersProfitTotal(OP_SELL) > exitProfit){
      OrdersCloseAll(OP_SELL);
   }
}

// 〇秒毎に行う処理を記述する
void OnTimer(){

   if(AccountNumber() != ACCOUNT_NUMBER && ACCOUNT_NUMBER != 0){
      Alert("Auth falied.\n許可されていない口座番号です。");
      ExpertRemove();
   }
   EventKillTimer();
}

// イベント処理を記述する
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam){  

   if (id == CHARTEVENT_OBJECT_CLICK){
      if (sparam == "BUTTON OBJECT"){
         OrdersCloseAll(OP_BUY);
         OrdersCloseAll(OP_SELL);
         Sleep(200);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
   }
}

// 成行買い注文
int OrderSendBuy(){
   
   if (maxSpreadPips < MarketInfo(Symbol(), MODE_SPREAD) / 10) return -1;
   
   int ticket = -1;
   double sl = 0, tp = 0;
   if (slPips != 0) sl = Ask - slPips * Pips();
   if (tpPips != 0) tp = Ask + tpPips * Pips();
   
   for (int retryCnt = 0; retryCnt < retry; retryCnt++){
      ticket = OrderSend(Symbol(), OP_BUY, lots, Ask, slippage, sl, tp, "", magicNum);
      if (ticket != -1) {
         break;
      }else {
         Print("buy order send error " + (string)GetLastError());
         Sleep(interval);
         RefreshRates();
      }
   }
   return ticket;
}

// 成行売り注文
int OrderSendSell(){
   
   if (maxSpreadPips < MarketInfo(Symbol(), MODE_SPREAD) / 10) return -1;
   
   int ticket = 0;
   double sl = 0, tp = 0;
   if (slPips != 0) sl = Bid + slPips * Pips();
   if (tpPips != 0) tp = Bid - tpPips * Pips();
   
   for (int retryCnt = 0; retryCnt < retry; retryCnt++){
      ticket = OrderSend(Symbol(), OP_SELL, lots, Bid, slippage, sl, tp, "", magicNum);
      if (ticket != -1) {
         break;
      }else {
         Print("sell order send error " + (string)GetLastError());
         Sleep(interval);
         RefreshRates();
      }
   }
   return ticket;
}

// 合計収支を取得する
double OrdersProfitTotal(int orderType){
   
   double profit = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--){
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != magicNum || OrderType() != orderType) continue;
      profit += (OrderProfit() + OrderSwap() + OrderCommission());
   } 
   return profit;
}

// 保有しているポジション数を返す
int OrdersCount(int orderType){
   
   int cnt = 0;
   for (int i = OrdersTotal() - 1; i >= 0; i--){
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != magicNum || OrderType() != orderType) continue;
      cnt++;
   }
   return cnt;
}

// 全決済
void OrdersCloseAll(int orderType){
   
   for(int i = OrdersTotal() - 1; i >= 0; i--){
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderSymbol() != Symbol() || OrderMagicNumber() != magicNum || OrderType() != orderType) continue;
      for (int retryCnt = 0; retryCnt < retry; retryCnt++){
         bool closed = OrderClose(OrderTicket(), OrderLots(), OrderClosePrice(), 0);
         if (closed){
            break;
         }else{
            Print("order close error " + (string)GetLastError());
            Sleep(interval);
            RefreshRates();    
         }
      }
   }
}

// 1Pips辺りの価格を返す関数
double Pips(){

   int digits = (int)MarketInfo(Symbol(), MODE_DIGITS);
   
   if (StringFind(Symbol(), "XAUUSD", 0) != -1 || StringFind(Symbol(), "GOLD", -1) != -1){
      return NormalizeDouble(Point * 10, digits - 1); 
   }
   
   if(digits == 3 || digits == 5){
     return NormalizeDouble(Point * 10, digits - 1);
   }

   if(digits == 4 || digits == 2){
     return Point;
   }
   return 0;
}

// ボタンを作成
void CreateButtonObject(string objName, int posX, int posY, int sizeX, int sizeY, string text, color fontColor, int fontSize, color bgColor, color borderColor){

   ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
   
   ObjectSetString(0, objName, OBJPROP_TEXT, text);
   ObjectSetString (0, objName, OBJPROP_FONT, "Meiryo UI");
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize); 
   ObjectSetInteger(0, objName, OBJPROP_COLOR, fontColor);

   ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, borderColor);
  
   ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, posX); 
   ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, posY);
   ObjectSetInteger(0, objName, OBJPROP_XSIZE, sizeX); 
   ObjectSetInteger(0, objName, OBJPROP_YSIZE, sizeY); 
   ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_LOWER);  
     
   ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
 } 
