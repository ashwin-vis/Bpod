/*
  ----------------------------------------------------------------------------

  This file is part of the Sanworks Bpod_Gen2 repository
  Copyright (C) 2017 Sanworks LLC, Stony Brook, New York, USA

  ----------------------------------------------------------------------------

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, version 3.

  This program is distributed  WITHOUT ANY WARRANTY and without even the
  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.

*/
// DIO Module interfaces the Bpod state machine with TTL signals on Arduino digital pins.
// Pins 2-7 are configured as input channels, pins 19-23 are configured as output channels.
// A 2-byte serial message from the state machine sets the state of the output lines: [Channel (19-23), State(0 or 1)].
// A 3-byte serial message from the state machine enables or disables input lines: ['E' Channel (2-7), State (0 = disabled, 1 = enabled)]

#include "ArCOM.h" // Import serial communication wrapper
#include <Servo.h>
#include "mpr121spark.h"
#include <Wire.h>

// Module setup
ArCOM Serial1COM(Serial1); // Wrap Serial1 (UART on Arduino M0, Due + Teensy 3.X)
char moduleName[] = "DIOnewDOORLICKS"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"Lick_Left_Hi", "Lick_Left_Lo","Lick_Center_Hi", "Lick_Center_Lo","Lick_Right_Hi","Lick_Right_Lo"};
#define FirmwareVersion 1
#define InputOffset 2
#define OutputOffset 5
#define nInputChannels 3
#define nOutputChannels 15

// Constants
#define InputChRangeHigh InputOffset+nInputChannels
#define OutputChRangeHigh OutputOffset+nOutputChannels



// Variables
byte opCode = 0;
byte channel = 0;
byte state = 0;
byte thisEvent = 0;
byte nEventNames = (sizeof(eventNames)/sizeof(char *));
byte events[nInputChannels*2] = {0}; // List of high or low events captured this cycle
byte nEvents = 0; // Number of events captured in the current cycle
uint32_t currentTime = 0; // Current time in microseconds

int irqpin = 2;
boolean touchStates[12]; //to keep track of the previous touch states
int lickSensors[] = {1,4,7};
int touchPin = 0;
byte toWrite;

int buzzer = 5;
int door = 0;

Servo myservo;

int motorPins[]= {6,7,8};
int speed_delay = 30;

void setup()
{
  Serial1.begin(1312500);
  currentTime = micros();
  
  for (int i = OutputOffset; i < OutputChRangeHigh; i++) {
    pinMode(i, OUTPUT);
  }

  pinMode(irqpin, INPUT);
  digitalWrite(irqpin, HIGH); //enable pullup resistor  

  Wire.begin();

  mpr121_setup();  
}

void loop()
{
  currentTime = micros();
  if (Serial1COM.available()) {
    opCode = Serial1COM.readByte();
    if (opCode == 255) {
      returnModuleInfo();
    } else if (opCode == 254){
      tone(buzzer,4000,200);
      state = Serial1COM.readByte();
    } else if (opCode == 253){
      tone(buzzer,4500,50);
      state = Serial1COM.readByte();
    } else if (opCode == 252){
      door = 1;
      speed_delay = Serial1COM.readByte();
      closeDoor(door, speed_delay);
    } else if (opCode == 251){
      door = 1;
      speed_delay = Serial1COM.readByte();
      openDoor(door,speed_delay);
    } else if (opCode == 250){
      door = 2;
      speed_delay = Serial1COM.readByte();
      closeDoor(door, speed_delay);
    } else if (opCode == 249){
      door = 2;
      speed_delay = Serial1COM.readByte();
      openDoor(door,speed_delay);
    } else if (opCode == 248){
      door = 3;
      speed_delay = Serial1COM.readByte();
      closeDoor(door, speed_delay);
    } else if (opCode == 247){
      door = 3;
      speed_delay = Serial1COM.readByte();
      openDoor(door,speed_delay);            
    } else if ((opCode >= OutputOffset) && (opCode < OutputChRangeHigh)) {
        state = Serial1COM.readByte(); 
        digitalWrite(opCode,state); 
    }
  }

  // CHECK FOR LICKS
  if(!checkInterrupt()){
    
    //read the touch state from the MPR121
    Wire.requestFrom(0x5A,2); 
    
    byte LSB = Wire.read();
    byte MSB = Wire.read();
    
    uint16_t touched = ((MSB << 8) | LSB); //16bits that make up the touch states

    thisEvent = 1;
    //change this to be for the 3
    for (int i=0; i < 3; i++){  // Check what electrodes were pressed
      touchPin = lickSensors[i];
      if(touched & (1<<touchPin)){
      
        if(touchStates[touchPin] == 0){
          events[nEvents] = thisEvent; nEvents++;
        }else if(touchStates[touchPin] == 1){
          //pin touchpin is still being touched
        }  
      
        touchStates[touchPin] = 1;      
      }else{
        if(touchStates[touchPin] == 1){        
          events[nEvents] = thisEvent+1; nEvents++;
       }        
        touchStates[i] = 0;
      }    
    }
    thisEvent += 2;    
  }
  if (nEvents > 0) {
    Serial1COM.writeByteArray(events, nEvents);
    nEvents = 0;
  }
}

void returnModuleInfo() {
  Serial1COM.writeByte(65); // Acknowledge
  Serial1COM.writeUint32(FirmwareVersion); // 4-byte firmware version
  Serial1COM.writeByte(sizeof(moduleName)-1);
  Serial1COM.writeCharArray(moduleName, sizeof(moduleName)-1); // Module name
  Serial1COM.writeByte(1); // 1 if more info follows, 0 if not
  Serial1COM.writeByte('#'); // Op code for: Number of behavior events this module can generate
  Serial1COM.writeByte(nInputChannels*2); // 2 states for each input channel
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

void openDoor(int door,int speed_delay){
  int motorPin = motorPins[door-1];
  myservo.attach(motorPin);
  int open_angle = 30;
  int close_angle = 70;
  switch (door){
    case 1:
      open_angle = 30;
      close_angle = 80;
      break;
    case 2:
      open_angle = 35;
      close_angle = 85;    
      break;
    case 3:
      open_angle = 30;
      close_angle = 70;    
      break;
  }
  for (int i = close_angle; i >= open_angle; i--) { 
    myservo.write(i);  
    delay(speed_delay);                 
  }
  myservo.detach();
}

void closeDoor(int door, int speed_delay){
  int motorPin = motorPins[door-1];
  myservo.attach(motorPin);
  int open_angle = 30;
  int close_angle = 80;  
  switch (door){
    case 1:
      open_angle = 30;
      close_angle = 70;
      break;
    case 2:
      open_angle = 35;
      close_angle = 85;    
      break;
    case 3:
      open_angle = 30;
      close_angle = 70;    
      break;
  }  
  for (int i = open_angle; i <= close_angle; i++) { 
    myservo.write(i);  
    delay(speed_delay);                   
  }
  myservo.detach();
}

void mpr121_setup(void){

  set_register(0x5A, ELE_CFG, 0x00); 
  
  // Section A - Controls filtering when data is > baseline.
  set_register(0x5A, MHD_R, 0x01);
  set_register(0x5A, NHD_R, 0x01);
  set_register(0x5A, NCL_R, 0x00);
  set_register(0x5A, FDL_R, 0x00);

  // Section B - Controls filtering when data is < baseline.
  set_register(0x5A, MHD_F, 0x01);
  set_register(0x5A, NHD_F, 0x01);
  set_register(0x5A, NCL_F, 0xFF);
  set_register(0x5A, FDL_F, 0x02);
  
  // Section C - Sets touch and release thresholds for each electrode
  set_register(0x5A, ELE0_T, TOU_THRESH);
  set_register(0x5A, ELE0_R, REL_THRESH);
 
  set_register(0x5A, ELE1_T, TOU_THRESH);
  set_register(0x5A, ELE1_R, REL_THRESH);
  
  set_register(0x5A, ELE2_T, TOU_THRESH);
  set_register(0x5A, ELE2_R, REL_THRESH);
  
  set_register(0x5A, ELE3_T, TOU_THRESH);
  set_register(0x5A, ELE3_R, REL_THRESH);
  
  set_register(0x5A, ELE4_T, TOU_THRESH);
  set_register(0x5A, ELE4_R, REL_THRESH);
  
  set_register(0x5A, ELE5_T, TOU_THRESH);
  set_register(0x5A, ELE5_R, REL_THRESH);
  
  set_register(0x5A, ELE6_T, TOU_THRESH);
  set_register(0x5A, ELE6_R, REL_THRESH);
  
  set_register(0x5A, ELE7_T, TOU_THRESH);
  set_register(0x5A, ELE7_R, REL_THRESH);
  
  set_register(0x5A, ELE8_T, TOU_THRESH);
  set_register(0x5A, ELE8_R, REL_THRESH);
  
  set_register(0x5A, ELE9_T, TOU_THRESH);
  set_register(0x5A, ELE9_R, REL_THRESH);
  
  set_register(0x5A, ELE10_T, TOU_THRESH);
  set_register(0x5A, ELE10_R, REL_THRESH);
  
  set_register(0x5A, ELE11_T, TOU_THRESH);
  set_register(0x5A, ELE11_R, REL_THRESH);
  
  // Section D
  // Set the Filter Configuration
  // Set ESI2
  set_register(0x5A, FIL_CFG, 0x04);
  
  // Section E
  // Electrode Configuration
  // Set ELE_CFG to 0x00 to return to standby mode
  set_register(0x5A, ELE_CFG, 0x0C);  // Enables all 12 Electrodes
  
  
  // Section F
  // Enable Auto Config and auto Reconfig
  /*set_register(0x5A, ATO_CFG0, 0x0B);
  set_register(0x5A, ATO_CFGU, 0xC9);  // USL = (Vdd-0.7)/vdd*256 = 0xC9 @3.3V   set_register(0x5A, ATO_CFGL, 0x82);  // LSL = 0.65*USL = 0x82 @3.3V
  set_register(0x5A, ATO_CFGT, 0xB5);*/  // Target = 0.9*USL = 0xB5 @3.3V
  
  set_register(0x5A, ELE_CFG, 0x0C);
  
}


boolean checkInterrupt(void){
  return digitalRead(irqpin);
}


void set_register(int address, unsigned char r, unsigned char v){
    Wire.beginTransmission(address);
    Wire.write(r);
    Wire.write(v);
    Wire.endTransmission();
}
