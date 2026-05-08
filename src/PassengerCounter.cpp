#include "PassengerCounter.h"

#define IR1 34
#define IR2 32

volatile int passengerCount = 0;
volatile int state = 0;
volatile unsigned long lastTrigger = 0;
const unsigned long debounce = 250;
const unsigned long timeout = 7000;
volatile bool updateFlag = false;

void IRAM_ATTR IR1_ISR(){
    unsigned long now = millis();
    if(now - lastTrigger < debounce) return;
    lastTrigger = now;

    if(state==0) state=1;
    else if(state==2){ passengerCount--; updateFlag=true; state=3; }
}

void IRAM_ATTR IR2_ISR(){
    unsigned long now = millis();
    if(now - lastTrigger < debounce) return;
    lastTrigger = now;

    if(state==0) state=2;
    else if(state==1){ passengerCount++; updateFlag=true; state=3; }
}

void setupPassengerCounter(){
    pinMode(IR1, INPUT_PULLUP);
    pinMode(IR2, INPUT_PULLUP);
    attachInterrupt(digitalPinToInterrupt(IR1), IR1_ISR, FALLING);
    attachInterrupt(digitalPinToInterrupt(IR2), IR2_ISR, FALLING);
}

void loopPassengerCounter(){
    unsigned long now = millis();
    if((state==1 || state==2) && now - lastTrigger > timeout) state=0;
    if(state==3 && digitalRead(IR1)==HIGH && digitalRead(IR2)==HIGH) state=0;
}

int getPassengerCount(){ return passengerCount; }
bool isCountUpdated(){ return updateFlag; }
void resetUpdateFlag(){ updateFlag=false; }