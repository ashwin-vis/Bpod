/*


*/
// DIO Module interfaces the Bpod state machine with TTL signals on Arduino digital pins.
// Pin 2 is a multi-electrode lick sensor, pin 20 is a buzzer, pins 3-17 are configured as output channels.
// A 2-byte serial message from the state machine sets the state of the output lines: [Channel (3-17), State(0 or 1)].

// OLD
// A 3-byte serial message from the state machine enables or disables input lines: ['E' Channel (2-7), State (0 = disabled, 1 = enabled)]

#include "ArCOM.h" // Import serial communication wrapper
#include <Wire.h>
#include "Adafruit_MPR121.h"

#ifndef _BV
#define _BV(bit) (1 << (bit)) 
#endif

byte out = 15;
int buzzer = 20;
int irqpin = 2;
int houseLight = 21;

Adafruit_MPR121 cap = Adafruit_MPR121();
// Keeps track of the last pins touched
// so we know when buttons are 'released'
uint16_t lasttouched = 0;
uint16_t currtouched = 0;

uint8_t touchChannels[] = {1,4,7}; // left, center, and right lick sensor pins
uint8_t touchPin;
int ntouchChannels = (sizeof(touchChannels)/sizeof(uint8_t));

// Module setup
ArCOM Serial1COM(Serial1); // Wrap Serial1 (UART on Arduino M0, Due + Teensy 3.X)
char moduleName[] = "DIOLicks"; // Name of module for manual override UI and state machine assembler
//char* eventNames[] = {"2_Hi", "2_Lo", "3_Hi", "3_Lo", "4_Hi", "4_Lo", "5_Hi", "5_Lo", "6_Hi", "6_Lo"};
char* eventNames[] = {"Lick_Left", "Lick_Right", "Lick_Center"};
#define FirmwareVersion 1
#define InputOffset 2
#define OutputOffset 3
#define nInputChannels 3
#define nOutputChannels 15
//uint32_t refractoryPeriod = 300; // Minimum amount of time (in microseconds) after a logic transition on a line, before its level is checked again.
//                                  // This puts a hard limit on how fast each channel on the board can spam the state machine with events.

// Constants
//#define InputChRangeHigh InputOffset+nInputChannels
#define OutputChRangeHigh OutputOffset+nOutputChannels

byte nEventNames = (sizeof(eventNames)/sizeof(char *));


// Variables
byte opCode = 0;
byte channel = 0;
byte state = 0;
//byte thisEvent = 0;
//boolean readThisChannel = false; // For implementing refractory period (see variable above)
//byte inputChState[nInputChannels] = {0}; // Current state of each input channel
//byte lastInputChState[nInputChannels] = {0}; // Last known state of each input channel
//byte inputsEnabled[nInputChannels] = {0}; // For each input channel, enabled or disabled
//uint32_t inputChSwitchTime[nInputChannels] = {0}; // Time of last detected logic transition
//byte events[nInputChannels*2] = {0}; // List of high or low events captured this cycle
//byte nEvents = 0; // Number of events captured in the current cycle
uint32_t currentTime = 0; // Current time in microseconds

void setup()
{
  Serial1.begin(1312500);
  currentTime = micros();
//  for (int i = 0; i < nInputChannels; i++) {
//    pinMode(i+InputOffset, INPUT_PULLUP);
//    inputsEnabled[i] = 1;
//    inputChState[i] = 1;
//    lastInputChState[i] = 1;
//  }
  for (int i = OutputOffset; i < OutputChRangeHigh; i++) {
    pinMode(i, OUTPUT);
  }

  pinMode(houseLight, OUTPUT);

  pinMode(irqpin,INPUT);
  digitalWrite(irqpin, HIGH); //enable pullup resistor
  
  if (!cap.begin(0x5A)) {
    while (1);
  }  
}

void loop()
{
  currentTime = micros();

  // this doesn't work because bytes only go up to 255-->need many bytes to read
//  if (Serial1COM.available()) {
//    opCode = Serial1COM.readByte();
//    if (opCode == 255) {
//      returnModuleInfo();
//    } else if (opCode == 'B') {
//      channel = Serial1COM.readByte(); 
//      state = Serial1COM.readByte();
//      tone(buzzer,channel,state);
//    } else if ((opCode >= OutputOffset) && (opCode < OutputChRangeHigh)) {
//        state = Serial1COM.readByte(); 
//        digitalWrite(opCode,state); 
//    } 
//  }

    
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    if (opCode == 255) {
      returnModuleInfo();
    }else if (opCode == 254){
      tone(buzzer,4000,200);
      state = Serial1COM.readByte();
    }else if (opCode == 253){
      tone(buzzer,4500,50);
      state = Serial1COM.readByte();
    }else if (opCode == houseLight){
      state = Serial1COM.readByte(); 
      digitalWrite(opCode,state); 
    }else if ((opCode >= OutputOffset) && (opCode < OutputChRangeHigh)) {
        state = Serial1COM.readByte(); 
        digitalWrite(opCode,state); 
    }
//    else if (opCode == 'E') {
//      channel = Serial1COM.readByte(); 
//      state = Serial1COM.readByte();
//      if ((channel >= InputOffset) && (channel < InputChRangeHigh)) {
//        inputsEnabled[channel-InputOffset] = state;
//      }
//    }
  }


  if (!checkInterrupt()) {  
  // Get the currently touched pads
  currtouched = cap.touched();
  
  for (uint8_t i=0; i<ntouchChannels; i++) {
    touchPin = touchChannels[i];
    if ((currtouched & _BV(touchPin)) && !(lasttouched & _BV(touchPin)) ) {
//      Serial.print(i); Serial.println(" touched");
        Serial1COM.writeByte(byte(i));
    }
  }

  // reset our state
  lasttouched = currtouched;
  }

  
//  thisEvent = 1;
//  for (int i = 0; i < nInputChannels; i++) {
//    if (inputsEnabled[i] == 1) {
//      inputChState[i] = digitalRead(i+InputOffset);
//      readThisChannel = false;
//      if (currentTime > inputChSwitchTime[i]) {
//        if ((currentTime - inputChSwitchTime[i]) > refractoryPeriod) {
//          readThisChannel = true;
//        }
//      } else if ((currentTime + 4294967296-inputChSwitchTime[i]) > refractoryPeriod) {
//        readThisChannel = true;
//      }
//      if (readThisChannel) {
//        if ((inputChState[i] == 1) && (lastInputChState[i] == 0)) {
//          events[nEvents] = thisEvent; nEvents++;
//          inputChSwitchTime[i] = currentTime;
//          lastInputChState[i] = inputChState[i];
//        }
//        if ((inputChState[i] == 0) && (lastInputChState[i] == 1)) {
//          events[nEvents] = thisEvent+1; nEvents++;
//          inputChSwitchTime[i] = currentTime;
//          lastInputChState[i] = inputChState[i];
//        }
//      }
//    }
//    thisEvent += 2;
//  }
//  if (nEvents > 0) {
//    Serial1COM.writeByteArray(events, nEvents);
//    nEvents = 0;
//  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1);
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  Serial1COM.writeByte(nInputChannels); // 2 states for each input channel
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('E'); // Op code for: Behavior event names
  Serial1COM.writeByte(nEventNames);
  for (int i = 0; i < nEventNames; i++) { // Once for each event name
    Serial1COM.writeByte(strlen(eventNames[i])); // Send event name length
    for (int j = 0; j < strlen(eventNames[i]); j++) { // Once for each character in this event name
      Serial1COM.writeByte(*(eventNames[i]+j)); // Send the character
    }
  }
  Serial1COM.writeByte(0); // 1 if more info follows, 0 if not
}

boolean checkInterrupt(void){
  return digitalRead(irqpin);
}
