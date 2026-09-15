// Main Unit: receive measured data from satellite devices, central node point
// consists of: microcontroller (M5stack), LoRa Radio card (RFM96), RealTime Clock (DS1307)
// The M5stack contains: LiPo battery charging, microSD Card slot, WiFi interface, TFT display and 3 buttons
// function: 2 buttons for entering identifier; one button for measurement (2nd press stores data on SD card)
//           pressing the measurement button will trigger radio signal "measure" being sent; data will then be collected
//           from every satellite device individually
// The M5stack opens up a webserver at startup; when connecting via WiFi, data can be sent both way via the websocket; simply open IP in browser.
// Code Structure:  <libraries/definitions>  <setup>  <code loop>

//----------- Libraries -------------------------------------
#include <SPI.h>
//#include <RHGenericSPI.h>
//#include <RH_RF95.h>
#include <M5LoRa.h>
#include <Wire.h>
#include <SD.h>  //not needed with M5?
#include <M5Stack.h>
#include <WiFi.h>
#include <ESPAsyncWebServer.h>
#include <SPIFFS.h>
#include "RTClib.h"
//--------END Libraries -------------------------------------

//-----------PIN definitions---------------------------------
#define RFM95_CS 5       // LoRa Chip Select
#define RFM95_RST 35     // LoRa Reset pin   //36 on first M5!!!
#define RFM95_INT 26     // LoRa Interrupt pin
//-------END PIN definitions---------------------------------

//-------Global variables, drivers and definitions -----------
#define RF95_FREQ 433E6  //LoRa frequency
#define NUM_SATELLITES 13   // number of satellite devices, followed by the keywords for each one
String satellites[NUM_SATELLITES] = {"clamp_1", "clamp_2", "clamp_3", "clamp_4", "clamp_5","clamp_6", "clamp_7", "clamp_8", "clamp_9", "clamp_0", "irr_1", "volt_1","irr_2"};
//String satellites[NUM_SATELLITES] = {"clamp_1", "clamp_2", "clamp_3", "clamp_4", "irr_1", "volt_1","irr_2"};
String answers[NUM_SATELLITES]; // the answer strings with the measurement variables will be stored here
uint8_t Cursor = 0;             // cursor position
uint8_t NumClamps = 5;             // Number of Clamps 
uint64_t TriggerTime = 0;
String StringList = "-0123456789ABCDEFGHI";  // allowed characters for button character cycling
String StringID = "A-B-C-10-2";  //global var for string identifier
bool Saved = false;         // prevents from saving the same result multiple times   
bool FirstTime = true;   // writing the header to the SD card is only done once at the first SAVE operation
bool TftReset = true;       // TFT is cleared after measurement, not when changing string characters
bool ClampsOnly = false;
const char* SSID = "MAIN"; 
const char* PASSWORD = "testpass";
bool TriggerMeasure = false;      // measurement triggered from WLAN interface instead of button press
bool TriggerSave = false;        // save to file triggered from WLAN interface instead of button press
bool SaveToFile = false;       // choose to actually save to file
DateTime Now;          // time object
RTC_DS1307 rtc;        // real time clock
File MyFile;                // SD card file name
//---END Global variables, drivers and definitions -----------


//-------- Webserver and Websocket --------------------------
AsyncWebServer server(80);       // async web server on port 80
AsyncWebSocket ws("/ws");        // web socket is attached to server
AsyncWebSocketClient * GlobalClient = NULL;   // global client variable
// interrupt definitions for the websocket: gets activated by client
void onWsEvent(AsyncWebSocket * server, AsyncWebSocketClient * client, AwsEventType type, void * arg, uint8_t *data, size_t len){
  if(type == WS_EVT_CONNECT) GlobalClient = client; 
  else if(type == WS_EVT_DISCONNECT) GlobalClient = NULL;
  else if(type == WS_EVT_DATA)   // if a message from the client is received (MEASURE, CLAMPS, SAVE, TIME, or DATA)
  {
    String message = "";
    for(int i=0; i < len; i++)  message += char(data[i]);  // convert input characters to message-string
    if ((message.indexOf("MEASURE_") > -1) or (message.indexOf("CLAMPS_") > -1))    // used for starting the measurement
    {  TriggerMeasure = true;  SaveToFile = false;   // also aborts the data before saving
       if (message.indexOf("CLAMPS_") > -1) ClampsOnly  = true;
       else ClampsOnly = false;
       NumClamps = message[message.indexOf("_") + 1] - '0';  // simple convert character to integer
       if (NumClamps == 0) NumClamps = 10;   //  0 stands for 10
       StringID = message.substring(message.indexOf(';')+1,message.length());}   // read out string ID after ';'     
    else if (message.indexOf("SAVE") > -1) {  TriggerSave = true; SaveToFile = true; // save data to SD card
       StringID = message.substring(message.indexOf(';')+1,message.length());}
       
    else if (message.indexOf("TIME") > -1) {    // receive time string from websocket client
      message = message.substring(message.indexOf(';')+1,message.length());  
      M5.Lcd.println();M5.Lcd.println("time set");
      uint8_t dtDay, dtMonth, dtYear, dtHour, dtMinute;
      dtDay = message.substring(0,3).toInt();   
      dtMonth = message.substring(3,5).toInt(); 
      dtYear = message.substring(6,8).toInt();
      dtHour = message.substring(9,11).toInt();
      dtMinute = message.substring(12,14).toInt();
      rtc.adjust(DateTime(dtYear, dtMonth, dtDay, dtHour, dtMinute, 0));
      delay(500); 
      TftReset=true; 
    }
    else if (message.indexOf("DATA") > -1) {     // triggers all saved data from SD card being transferred back
      if (SD.exists("/AA_log.txt")) {
        MyFile = SD.open("/AA_log.txt", FILE_READ);
        String textLine = "DATA";
        if(GlobalClient != NULL && GlobalClient->status() == WS_CONNECTED)   //send file content via websocket
        {     
          while (MyFile.available())
          {
            char c = MyFile.read();
            textLine += c;
            if (c == '\n') {
              if (GlobalClient != NULL && GlobalClient->status() == WS_CONNECTED) GlobalClient->text(textLine);
              textLine = "DATA";
            }
          }
        }
        MyFile.close();
      }
    }
  }
}
//-------- END Webserver and Websocket --------------------------



void setup()    // initialize components, startup screen with logo
{
  //start M5stack without SD-Card and Serial;  SD-card is initialized further below
  M5.begin(true,false,false,true);   // LCD and I2C enable
  M5.Power.begin();  //start power management with charging
  //*****STARTUP SCREEN TEST, tests all components; halts if LoRa is not working
  M5.Lcd.fillScreen(TFT_BLACK);
  M5.Lcd.setRotation(1);
  M5.Lcd.setCursor(0, 0);
  M5.Lcd.setTextColor(TFT_WHITE);
  M5.Lcd.setTextSize(2);
  M5.Lcd.println("TFT:    OK");  // "if you see this, it works"
  
  M5.Lcd.print("Time: ");
  if (! rtc.begin())  M5.Lcd.println("failed");
  if (! rtc.isrunning())  rtc.adjust(DateTime(F(__DATE__), F(__TIME__)));   // adjust time when compiling code
  if (rtc.begin()) 
  { 
    Now = rtc.now();
    char tempString[20];
    sprintf(tempString, "%02d.%02d.%04d %02d:%02d", Now.day(), Now.month(), Now.year(), Now.hour(), Now.minute());
    M5.Lcd.println(tempString);
  } 
  //LoRa radio initialization
  LoRa.setPins(RFM95_CS, RFM95_RST, RFM95_INT);
  LoRa.setSpreadingFactor(9);
  LoRa.setSignalBandwidth(625E2);
  LoRa.setCodingRate4(8);
  LoRa.enableCrc();
  LoRa.setSPIFrequency(1E6);
  LoRa.setPreambleLength(8);
  //LoRa.setSyncWord(0x12);
  LoRa.setTxPower(23);
  //digitalWrite(RFM95_RST, LOW); delay(100); digitalWrite(RFM95_RST, HIGH); delay(5); // manual reset of LoRa chip
  M5.Lcd.print("Radio: ");
  if (!LoRa.begin(RF95_FREQ)) { M5.Lcd.println("failed"); while (1);  }  // HALTS if LoRa fails
  M5.Lcd.println("OK");
  LoRa.setSpreadingFactor(9);
  LoRa.setSignalBandwidth(625E2);
  LoRa.setCodingRate4(8);
  LoRa.enableCrc();
  LoRa.setSPIFrequency(1E6);
  LoRa.setPreambleLength(8);
  LoRa.setSyncWord(0x12);
  LoRa.setTxPower(23);
  M5.Lcd.print("frequ. ");
  M5.Lcd.print(RF95_FREQ/1000000,0);M5.Lcd.println("MHz");
  // SPIFFS initialization
  M5.Lcd.print("SPIFFS: ");
  if (!SPIFFS.begin(true)) M5.Lcd.println(" failed");
  else M5.Lcd.println("OK");
  // WiFi server initialization; async web server with web socket for two-way communication
  WiFi.softAP(SSID, PASSWORD);
  M5.Lcd.print("IP Adresse: ");
  M5.Lcd.println(WiFi.softAPIP());
  ws.onEvent(onWsEvent);
  server.addHandler(&ws);
  server.on("/", HTTP_GET, [](AsyncWebServerRequest* request) { request->send(SPIFFS, "/index.html");  } );
  server.begin();
  /*
  rf95.setTxPower(23, false);  //setIP LoRa radio boost to 23dB / 20dB(M5)
  rf95.setSignalBandwidth(125000);
  rf95.setCodingRate4(8);
  rf95.setPayloadCRC(true);
  */
  //begin SD card 
  M5.Lcd.print("SD card:  ");
  if (!SD.begin(4)) M5.Lcd.println("failed");
  else M5.Lcd.println("OK");
  delay(2000);
  //*****end startup screen
  //Startup Logo
  if (SD.exists("/logoTFT.png")) {M5.Lcd.drawPngFile(SD, "/logoTFT.png");
  delay(1500);}    // logo shown for 1.5 second
  //if possible get string name from TXT file  
  if (SD.exists("/string.txt"))
  {
    MyFile = SD.open("/string.txt");
    if (MyFile)
    {
      StringID = "";
      while (MyFile.available())
      {
        char x = MyFile.read();
        if (isGraph(x)) StringID.concat(x);  //only valid characters which make sense
      }
      MyFile.close();
    }
  }
  M5.update();
  delay(1000);
}


void loop()
{
  //********* BUTTON A AND B: CHANGE STRING IDENTIFIER
  if (TftReset == true)  // usually only renew characters without screen clearance
  {
    M5.Lcd.fillScreen(TFT_BLACK);M5.update();
    TftReset = false;
  }
  if (M5.BtnA.isPressed()) {
    if (Cursor == StringID.length() - 1) Cursor = 0;
    else Cursor += 1;
  }
  if (M5.BtnB.isPressed()) {
    uint16_t charIndex = StringList.indexOf(StringID.charAt(Cursor));
    if (charIndex == StringList.length() - 1) charIndex = 0;
    else charIndex += 1;
    StringID.setCharAt(Cursor, StringList.charAt(charIndex));
  }
  M5.Lcd.setCursor(0, 0);
  M5.Lcd.setTextSize(3);
  for (uint16_t i = 0; i < StringID.length(); i++)
  {
    if (i == Cursor) M5.Lcd.setTextColor(TFT_BLACK, TFT_WHITE);
    else M5.Lcd.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Lcd.print(StringID.charAt(i));
  }
  if (M5.BtnA.isPressed()) delay(200);  // faster cycling for character position
  if (M5.BtnB.isPressed()) delay(130);  // faster cycling for character change
  M5.update();
  GlobalClient->status();  // test: hopefully solves idling at first connection


  //*********MEASUREMENT BUTTON or CLIENT COMMAND MEASURE VIA WEBSOCKET
  if (M5.BtnC.wasPressed() or TriggerMeasure)
  {
    TriggerMeasure = false;
    TriggerSave = false;
    //server.reset();
    M5.Lcd.fillScreen(TFT_BLACK);
    M5.Lcd.setCursor(0, 0);
    M5.Lcd.setTextSize(2);
    M5.Lcd.setTextColor(TFT_WHITE, TFT_BLACK);
    M5.Lcd.println("measure...");
    M5.update();
    Now = rtc.now();  //RTC
    //-----------LoRa sequence, getting measurement data from satellites -------------------
    String command, numClamps;  // construct measurement command: "CL" for clamps only, or "ME" for all satellites, + clamp number
    if (NumClamps == 10) numClamps = '0';
    else numClamps = String(NumClamps);
    if (ClampsOnly) command = "CL"+numClamps;
    else  command = "ME"+numClamps;
    
    uint64_t startTime;
    for (uint8_t i = 0; i < 1; i++) //send command 1 time, second time by repeater
    {
      LoRa.beginPacket();
      LoRa.write(0x00);  //destination
      LoRa.write(0x00);  //source
      LoRa.write(0x00);  //MessageCount
      LoRa.write(command.length());
      LoRa.print(command);
      LoRa.endPacket();
      //delay(10);
      if (i==0) startTime = millis();
     }
    M5.Lcd.print("received ");
    for (uint8_t i = 0; i < NUM_SATELLITES; i++)  answers[i] = "";   // clear answers, in case of reception error
    bool allReceived = false;
    uint64_t maxTime = 0;
    if (ClampsOnly) maxTime = (NumClamps+1)*800;
    else  maxTime = (NUM_SATELLITES-10+NumClamps+2)*800;
    while ( (millis() - startTime < maxTime))  // max. 0.8s reading of responses from satellites
    {                                              
      if (LoRa.parsePacket() > 0)
      {
        byte messageLength, source;
        String message = "";
        for (uint8_t k=0; k<2; k++) source = LoRa.read();  // dump destination, use source;
        for (uint8_t k=0; k<2; k++) messageLength = LoRa.read();  // dump messageCount, messageLength not used
        while (LoRa.available()) {
          message += (char)LoRa.read();
        }
        if (message.startsWith(satellites[int(source)-1]))   //message starts with keyword
        {
          if (message.startsWith("irr_2"))       //special part for repeater unit! save repeated messages
          {
            while (message.indexOf("#") > 0)    //read out all extra messages
            {
              String repeatedAnswer = message.substring(message.lastIndexOf("#")+1);
              for (uint8_t j=0; j<NUM_SATELLITES; j++)
              {
                if (repeatedAnswer.startsWith(satellites[j]) )
                {
                  answers[j] = repeatedAnswer.substring(repeatedAnswer.indexOf(";")+1,repeatedAnswer.lastIndexOf(";")+1);  //strip identifier
                  M5.Lcd.print(j + 1);
                  j=NUM_SATELLITES; // breaks loop
                }
              }
              message = message.substring(0,message.lastIndexOf("#"));  //strip extra content from original message
            }
            startTime = 0;  // last message of repeater unit, breaks reception loop
          }   // end special part for repeater unit to save extra messages
            
          if (answers[int(source)-1] == "")  // only save one result
          {
            answers[int(source)-1] = message.substring(message.indexOf(";")+1,message.lastIndexOf(";")+1);  //strip identifier from message
            M5.Lcd.print(int(source)-1 + 1);
          }
        }
      }
    }
    //-----------END LoRa sequence, getting measurement data from satellites -------------------

    //-----------print results to TFT -------------------
    M5.Lcd.fillScreen(TFT_BLACK);
    M5.Lcd.setCursor(0, 0);
    M5.Lcd.println("Results:");
    M5.Lcd.setTextSize(2);
    for (uint8_t i = 0; i < NUM_SATELLITES; i++)
    {
      if (answers[i].length() < 1) {M5.Lcd.setTextColor(TFT_RED, TFT_BLACK); M5.Lcd.println("---");M5.Lcd.setTextColor(TFT_WHITE, TFT_BLACK);}
      for (uint8_t j = 0; j < answers[i].length(); j++)
      {
        if (answers[i].charAt(j) == ';') M5.Lcd.print('|');
        else M5.Lcd.print(answers[i].charAt(j));
        if (j == answers[i].length() - 1) M5.Lcd.println();
      }
    }
    //-----------END print results to TFT -------------------

    //-----------send results to client via web socket -------------------
    //test sequence, ONLY FOR TESTING/DEBUGGING
    //answers[0] = "1.2";answers[1]="3.2";answers[2]="4.3";answers[3]="4.3";answers[4]="8.4";answers[5]="800.0;-255.0;24.5;";answers[6]="600.0";answers[7]="323.2";
    if(GlobalClient != NULL && GlobalClient->status() == WS_CONNECTED)
    {
      char tempString[20];
      sprintf(tempString, "%02d.%02d.%04d %02d:%02d", Now.day(), Now.month(), Now.year(), Now.hour(), Now.minute());      
      String htmlString = "string;" + StringID + '|';
      htmlString += "time;" + String(tempString) + '|';
      for (uint8_t i = 0; i < NUM_SATELLITES; i++)
      {
        htmlString += satellites[i] + ';';
        if (answers[i].length() < 1) { if (satellites[i]=="irr_1") htmlString += "|tmod_1;|tmod_2;|"; else htmlString += '|';}
        else
        {
          if (satellites[i] == "irr_1") 
          {
            htmlString += String(answers[i].substring(0, answers[i].indexOf(";"))) + '|';
            htmlString += String("tmod_1") + ';';
            htmlString += String(answers[i].substring(answers[i].indexOf(";")+1, answers[i].indexOf(";",answers[i].indexOf(";")+1))) + '|';
            htmlString += String("tmod_2") + ';';
            htmlString += String(answers[i].substring(answers[i].indexOf(";",answers[i].indexOf(";")+1)+1, answers[i].lastIndexOf(";"))) + '|';
          }
          else htmlString += answers[i].substring(0, answers[i].indexOf(";")) + '|';
        }
      }
      GlobalClient->text(htmlString);
    }
    //-----------END send results to client via web socket -------------------

    //-----------save string identifier, wait for command to save results ------
    TftReset = true;
    Saved = false;
    //SD.remove("/string.txt"); //not needed with M5stack
    MyFile = SD.open("/string.txt", FILE_WRITE);
    MyFile.print(StringID);
    MyFile.close();
    while (not(M5.BtnA.isPressed() or M5.BtnC.wasPressed() or TriggerSave or TriggerMeasure)) {M5.update();}  //loop forever until further command
    if (M5.BtnA.isPressed() or TriggerMeasure) SaveToFile = false;   // do not save to SD card
    else SaveToFile = true;  //save to SD card
    TriggerSave = false;
    //-----------END save string identifier, wait for command to save results ------


    //-----------handle error in transmission: no result at all-----------
    uint16_t answerSum = 0;
    for (uint8_t i=0; i< NUM_SATELLITES; i++)
      if (answers[i].length()) answerSum++;
    if (answerSum == 0) 
    {
      SaveToFile = false;
      M5.Lcd.setTextSize(2);
      M5.Lcd.setTextColor(TFT_RED, TFT_BLACK);
      M5.Lcd.println("nothing received");
      M5.Lcd.setTextColor(TFT_WHITE, TFT_BLACK);
      TftReset = true;
      delay(1500);
    }
    //-----------END handle error in transmission: no result at all-----------
    ClampsOnly = false;
  }  //end button C, measurement button


    //-----------save result to SD card-----------
  if (SaveToFile)  //something was received
  {
    if (Saved == true) 
    {
      M5.Lcd.fillScreen(TFT_BLACK);
      M5.Lcd.setCursor(0, 0);
      M5.Lcd.setTextSize(2);
      M5.Lcd.setTextColor(TFT_RED, TFT_BLACK);
      M5.Lcd.println("Error:");
      M5.Lcd.println("saved already!");
      M5.Lcd.setTextColor(TFT_WHITE, TFT_BLACK);
    }
    else
    {
      MyFile = SD.open("/AA_log.txt", FILE_APPEND);
      if (FirstTime)
      {
        MyFile.print("time stamp;string;");  //start of header line
        for (uint8_t i=0; i< NUM_SATELLITES; i++)
        {
          MyFile.print(satellites[i]); //write identifier for each result
          MyFile.print(";"); 
          if (satellites[i] == "irr_1") MyFile.print("temp_1;temp_2;");       
        }
        FirstTime = false;
        MyFile.println();  //end of header line
      }
      //print timestamp
      char tempString[20];
      sprintf(tempString, "%02d.%02d.%04d %02d:%02d", Now.day(), Now.month(), Now.year(), Now.hour(), Now.minute());
      MyFile.print(tempString); MyFile.print(";");
      MyFile.print(StringID); MyFile.print(";");
      for (uint8_t i=0; i< NUM_SATELLITES; i++)
      {
        if (answers[i].length()>1)
         {
            MyFile.print(answers[i]);
         }
        else
        {
          if (satellites[i] == "irr_1") MyFile.print(";;;"); 
          else MyFile.print(";");
        }
      }
      MyFile.println();
      Saved = true;
      M5.Lcd.setTextSize(2);
      M5.Lcd.println("saved!");
      MyFile.close();
      if(GlobalClient != NULL && GlobalClient->status() == WS_CONNECTED)   //feedback to web page client: file saved
      {
        GlobalClient->text("SAVED");
      }
    } //end else
    delay(500); //otherwise cycles too quickly
    SaveToFile = false;
    TftReset = true;
  }
  //END -----------save result to SD card-----------
} //end main loop
