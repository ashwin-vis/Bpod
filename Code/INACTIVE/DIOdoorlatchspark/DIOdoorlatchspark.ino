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

// Module setup
ArCOM Serial1COM(Serial1); // Wrap Serial1 (UART on Arduino M0, Due + Teensy 3.X)
char moduleName[] = "DIODOORLATCHLICKS"; // Name of module for manual override UI and state machine assembler
char* eventNames[] = {"LeftLick_Hi", "LeftLick_Lo", "CenterLick_Hi", "CenterLick_Lo", "RightLick_Hi", "RightLick_Lo"};
#define FirmwareVersion 1
#define OutputOffset 2
#define nOutputChannels 22
#define nInputChannels 3
uint32_t refractoryPeriod = 300; // Minimum amount of time (in microseconds) after a logic transition on a line, before its level is checked again.
                                  // This puts a hard limit on how fast each channel on the board can spam the state machine with events.

// Constants
#define OutputChRangeHigh OutputOffset+nOutputChannels

byte nEventNames = (sizeof(eventNames)/sizeof(char *));

// Variables
byte opCode = 0;
byte channel = 0;
byte state = 0;
uint32_t currentTime = 0; // Current time in microseconds

int buzzer = 5;
int door = 0;

Servo myservo;

int motorPins[]= {2,3,4};
int speed_delay = 30;

void setup()
{
  Serial1.begin(1312500);
  currentTime = micros();
  
  for (int i = OutputOffset; i < OutputChRangeHigh; i++) {
    pinMode(i, OUTPUT);
  }
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
  int open_angle = 15;
  int close_angle = 55;
  switch (door){
    case 1:
      open_angle = 15;
      close_angle = 55;
      break;
    case 2:
      open_angle = 10;
      close_angle = 55;    
      break;
    case 3:
      open_angle = 10;
      close_angle = 60;    
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
  int open_angle = 15;
  int close_angle = 55;  
  switch (door){
    case 1:
      open_angle = 15;
      close_angle = 55;
      break;
    case 2:
      open_angle = 10;
      close_angle = 55;    
      break;
    case 3:
      open_angle = 10;
      close_angle = 60;    
      break;
  }  
  for (int i = open_angle; i <= close_angle; i++) { 
    myservo.write(i);  
    delay(speed_delay);                   
  }
  myservo.detach();
}
