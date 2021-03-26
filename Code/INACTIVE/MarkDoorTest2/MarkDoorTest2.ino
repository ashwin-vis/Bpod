/* Sweep
 by BARRAGAN <http://barraganstudio.com>
 This example code is in the public domain.

 modified 8 Nov 2013
 by Scott Fitzgerald
 http://www.arduino.cc/en/Tutorial/Sweep

modified Mark Sullivan fall-winter 2020

TUNING PROCEDURE
send motor to ~60deg position
attach link 1 close to upper stops & tighten screws screws
adjust open/close angles in code (~50deg travel b/n)
monitor motor noise, may occur at certain angles (oscillating b/n)
*/

#include <Servo.h>

Servo myservo[3];
int motor_pin[3] = {2, 3, 4};
//int button_pin[3] = {2, 4, 7};
int open_angle[3] = {15, 10, 10};
int close_angle[3] = {55, 55, 60};
bool doorOpenState[3] = {true, true, true};

int loop_delay = 30; //speed toggle (delay between angle steps)

void setup() {

  for(int i = 0; i < 3; i++){
    myservo[i].write(open_angle[i]);
    myservo[i].attach(motor_pin[i]);
//    pinMode(button_pin[i], INPUT);
    delay(1000);
  }
   
}

void loop() {

//BUTTON MODE

//for(int i = 0; i < 3; i++){
//  if (digitalRead(button_pin[i])){
//    if(doorOpenState[i]){
//      closeDoor(i);
//    }
//    else{
//      openDoor(i);
//    }
//  }
//}

//LIFE TEST MODE

for(int i = 0; i < 3; i++){
  openDoor(i);
  delay(500);
  closeDoor(i);
  delay(500);
  }

}

void openDoor(int i){
  myservo[i].attach(motor_pin[i]);
  for (int j = close_angle[i]; j >= open_angle[i]; j--) { 
    myservo[i].write(j);  
    delay(loop_delay);                      
  }
  doorOpenState[i] = true; 
  myservo[i].detach();
}

void closeDoor(int i){
  myservo[i].attach(motor_pin[i]);
  for (int j = open_angle[i]; j <= close_angle[i]; j++) { 
    myservo[i].write(j);  
    delay(loop_delay);                      
  } 
  doorOpenState[i] = false; 
  myservo[i].detach();
}
