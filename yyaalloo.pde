/******************************************************************************
* This is an Arduino Sketch designed to run some LED's for my Reef Aquarum.
* It should provide timing and power controls for the LED lights while
* providing temperature feedback from various points on the LED heatsink.
* It should also control the fans mounted on the LED heatsink.  It's in my
* living room so it's nice to have the fans off whenever possible.
* 07/2011
* Neil Williams <neildotwilliams at gmail.com>
*******************************************************************************/

/****** Updates here ******
* I lost control of the versions at version 0.0025 :-(
* 06/08/2011 Temperature reading and print to serial working ok.
* 06/08/2011 RTC complete.  Time can be retrieved and printer to serial ok.
* 06/08/2011 Added Moon Phase.  Should print 1-7.  Doesnt do anything yet though ;-)
* 06/08/2011 Started adding PWM LED control.  Fades in half hour before full on.
* 07/08/2011 Fade out fixed.
* 07/08/2011 Implemented anti_shock
* 11/08/2011 Moonlight fades in ok
* 14/08/2011 Added analogwrite on last else statement in main loop.
* 14/08/2011 Added antishock type statement to decreasing lights.
* 17/08/2011 Fixed lights staying on - 30 mins before off time and dim starting.
* 19/08/2011 Added multiple thermometers
* 10/09/2011 Fixed moon phase calc, needed to add float and put the year in 4 digits.
* Make a checklist and perform and log all checks
****** Updates here ******/

/******************************************************************************
* ToDo :-(
* Temperature stuff - Does the temp just do the fans or dim the lights?!?!
* Display
* Fan Control - with PWM speed control & monitor (i.e. not just vary the voltage)?!?!
*******************************************************************************/

/* DS18B20 Temp Sensor code assimilated from:
* http://www.hacktronics.com/Tutorials/arduino-1-wire-address-finder.html
* http://www.hacktronics.com/Tutorials/arduino-1-wire-tutorial.html
*
* RTC DS1307 code assimilated from:
* Detailed example: http://www.ermicro.com/blog/?p=950
* http://www.glacialwanderer.com/hobbyrobotics/?p=12
* http://tronixstuff.wordpress.com/2010/05/20/getting-started-with-arduino-%E2%80%93-chapter-seven/
* The RTC is set using a different sketch to avoid resetting it by accident.
*
* Moon phase code assimilated from:
* http://technology-flow.com/articles/aquarium-lights/
*/

// Libraries be here ;-)
#include <OneWire.h>                   // Used for the 1-Wire comms
#include <DallasTemperature.h>         // Used to communicate with the temperature sensor (DS18B20)
#include <Wire.h>                      // Used for the RTC 2-wire comms
#define DS1307_I2C_ADDRESS 0x68        // Address used for the RTC chip

// Setup a 1-Wire bus to communicate with any OneWire devices on Digital pin 2
OneWire OneWireBus(2);

// Pass our oneWire reference to Dallas Temperature. 
DallasTemperature sensors(&OneWireBus);

// Assign the addresses of temperature sensors.  Add addresses as needed.
DeviceAddress Therm1 = { 0x28, 0x5F, 0xDA, 0x5F, 0x03, 0x00, 0x00, 0x51 };  // Give more descriptive names later
DeviceAddress Therm2 = { 0x28, 0x91, 0xFA, 0x5F, 0x03, 0x00, 0x00, 0x25 };
DeviceAddress Therm3 = { 0x28, 0x00, 0xF3, 0x5F, 0x03, 0x00, 0x00, 0x50 };
// Variables used by the DS1307 RTC.
byte second, minute, hour, dayOfWeek, dayOfMonth, month, year;

// Define the initial LED intensity values to zero
int RB_LED_intensity = 0;
int RB_LED_intensity_desired = 0;
int V_LED_intensity = 0;
int V_LED_intensity_desired = 0;
int NW_LED_intensity = 0;
int NW_LED_intensity_desired = 0;
int MOON_LED_intensity = 0;
int MOON_LED_intensity_desired = 0;

// Define the LED max intensities - up to 255
int RB_LED_MAX = 150;
int V_LED_MAX = 150;
int NW_LED_MAX = 150;
int MOON_LED_MAX = 150;

// Define the LED Pins
int RB_LED_PIN = 11;                   // Royal Blue (420nm) LED Pin
int V_LED_PIN = 10;                    // Violet (410nm) LED Pin
int NW_LED_PIN = 9;                    // Neutral White (4100k) LED PIN
int MOON_LED_PIN = 6;                  // Low power blue moon lights

// Define the LED times - in hours only!!
int RB_LED_ON = 9;
int RB_LED_OFF = 20;
int V_LED_ON = 9;
int V_LED_OFF = 20;
int NW_LED_ON = 9;
int NW_LED_OFF = 20;
int MOON_LED_ON = 20;
int MOON_LED_OFF = 9;

/****** Some conversions for the RTC ******/
// Convert binary coded decimal to normal decimal numbers
byte bcdToDec(byte val)
{
  return ( (val/16*10) + (val%16) );
}

// Get the date and time from the ds1307
void getDateDs1307(
byte *second,
byte *minute,
byte *hour,
byte *dayOfWeek,
byte *dayOfMonth,
byte *month,
byte *year)
{
  // Reset the register pointer to zero
  Wire.beginTransmission(DS1307_I2C_ADDRESS);
  Wire.send(0);
  Wire.endTransmission();

  // Read 7 bytes of data from the DS1307 device.
  Wire.requestFrom(DS1307_I2C_ADDRESS, 7);

  // A few of these need masks because certain bits are control bits
  *second     = bcdToDec(Wire.receive() & 0x7f);  //  Mask off the Clock Halt bit.
  *minute     = bcdToDec(Wire.receive());
  *hour       = bcdToDec(Wire.receive() & 0x3f);  // Mask for 24 hour format.
  *dayOfWeek  = bcdToDec(Wire.receive());
  *dayOfMonth = bcdToDec(Wire.receive());
  *month      = bcdToDec(Wire.receive());
  *year       = bcdToDec(Wire.receive());
 
}

// Print temperature function
void printTemperature(DeviceAddress deviceAddress)
{
  float tempC = sensors.getTempC(deviceAddress);
  if (tempC == -127.00) {
    Serial.print("Error getting temperature");
  }
  else {
       Serial.print("C: ");
       Serial.print(tempC);
  }
}

// Define the moon phase as an integer
// http://www.amsat.org/amsat/articles/g3ruh/100.html - Julian Date calc
// http://pmyers.pcug.org.au/General/JulianDates.htm
int moonPhase(int moonYear, int moonMonth, int moonDay)
{
    
    float dayFromYear, dayFromMonth;
    double julianDay;
    int phase;
    moonYear = 2000 + moonYear;                                                // Make the moon year 4 digits.  ds1307 only stores 2 digits!
    if (moonMonth < 3)                                                         // Use March as start of year
    {
        moonYear--;                                                            // take away a year
        moonMonth += 12;                                                       // add an extra 12 months (the year taken away from before)
    }
    ++moonMonth;
    dayFromYear = 365.25 * moonYear;                                           // get total days since year 0
    dayFromMonth = 30.6 * moonMonth;                                           // work out days from beginning of year to now using average month
    /* julianDay - January 1, 4713 BC Greenwich noon. */
    julianDay = dayFromYear + dayFromMonth + moonDay - 694039.09;              // Work out the julian date
    Serial.println("");
    Serial.println("Julian day number for 11/09/2011 is 2455816");
    Serial.print("The Julian day is:");
    Serial.println(julianDay);
    julianDay /= 29.53;                                                        // divide by the moon cycle (29.53 days)
    phase = julianDay;                                                         // grab the integer part of julianDay
    /* subtract integer part to leave fractional part of original julianDay */
    julianDay -= phase;
    phase = julianDay * 8 + 0.5;                                               // scale fraction from 0-8 and round by adding 0.5
    phase = phase & 7;                                                         // 0 and 8 are the same so turn 8 into 0
    return phase;                                                              // Return our result
}

// Anti_shock routine - not to scare the fishes on reset
int anti_shock(int led_intensity, int led_desired)
{
  if (led_intensity < (led_desired - 5))     // Run until we reach desired level
  {
    int result;
    result = led_intensity + 5;        // Increment at each pass
    return result;
  }
  else if (led_intensity >= (led_desired - 5))
    {
      int result;
      result = led_intensity + 1;        // Increment by 1 so we dont overshoot, 256 is dumb :-)
      return result;
    }
}

/****** Setup Loop - runs once ******/
void setup()
{
  Serial.begin(115200);                 // Start USB serial port
  sensors.begin();                    // Start the OneWire library
  sensors.setResolution(Therm1, 11);  // Set the temperature resolution to 11 bit (0.125c - plenty good enough!)
  sensors.setResolution(Therm2, 11);
  sensors.setResolution(Therm3, 11);
                                      // (bits)       9,   10,   11,    12
                                      // (Centigrade) 0.5, 0.25, 0.125, 0.0625
  Wire.begin();                       // Start the 2-wire comms
  pinMode(RB_LED_PIN, OUTPUT);        // Set the digital pins to output for PWM
  pinMode(V_LED_PIN, OUTPUT);         // Set the digital pins to output for PWM
  pinMode(NW_LED_PIN, OUTPUT);        // Set the digital pins to output for PWM
  pinMode(MOON_LED_PIN, OUTPUT);      // Set the digital pins to output for PWM

// Define the initial LED intensity values
int RB_LED_intensity = 0;
int V_LED_intensity = 0;
int NW_LED_intensity = 0;
int MOON_LED_intensity = 0;
}
/****** Finish setup loop ******/

/****** Main Program Loop ******/
void loop(void)
{
// Print out some stuff for debuggering
Serial.println("****************************************");
Serial.println("****************************************");

// Print the time
getDateDs1307(&second, &minute, &hour, &dayOfWeek, &dayOfMonth, &month, &year);
  Serial.print(hour, DEC);
  Serial.print(":");
  Serial.print(minute, DEC);
  Serial.print(":");
  Serial.print(second, DEC);
  Serial.print("  ");
  Serial.print(dayOfMonth, DEC);
  Serial.print("/");
  Serial.print(month, DEC);
  Serial.print("/");
  Serial.print(year, DEC);
  Serial.print("  Day of week:");
  Serial.print(dayOfWeek, DEC);

// Print the moon phase
int lunarCycle = moonPhase(year, month, dayOfMonth); //get a value for the lunar cycle
  Serial.print("Moon phase: ");
  Serial.println(lunarCycle);

// Print the temperature
  Serial.print("Thermometer 1 temperature is ");
  sensors.requestTemperatures();
  printTemperature(Therm1);
  Serial.println("");
  Serial.print("Thermometer 2 temperature is ");
  sensors.requestTemperatures();
  printTemperature(Therm2);
  Serial.println("");
  Serial.print("Thermometer 3 temperature is ");
  sensors.requestTemperatures();
  printTemperature(Therm3);
  Serial.println("");

// RB LED Times
Serial.println("");
Serial.println("LED Times:");
Serial.print("RB LED ----> On Time=");
Serial.print(RB_LED_ON);
Serial.print(",  Off Time=");
Serial.println(RB_LED_OFF);
// V LED Times
Serial.print("V LED -----> On Time=");
Serial.print(V_LED_ON);
Serial.print(",  Off Time=");
Serial.println(V_LED_OFF);
// NW LED Times
Serial.print("NW LED ----> On Time=");
Serial.print(NW_LED_ON);
Serial.print(",  Off Time=");
Serial.println(NW_LED_OFF);
// Moon LED Times
Serial.print("Moon LED --> On Time=");
Serial.print(MOON_LED_ON);
Serial.print(", Off Time=");
Serial.println(MOON_LED_OFF);

Serial.println("");
Serial.println("LED Status:");

//****** Royal Blue LED's control ******//
// Modify these times to work through the logic mentally.
// RB on at 9
// RB off at 21
// time = 17:55
if ((hour == (RB_LED_ON - 1)) && (minute >= 30) )                              // Start on with dimming
{
    Serial.println("RB Increasing");
    RB_LED_intensity_desired=map(minute,30,59,0,RB_LED_MAX);         
    if ( RB_LED_intensity < RB_LED_intensity_desired )
    {
    RB_LED_intensity = anti_shock(RB_LED_intensity, RB_LED_intensity_desired); // Increase the intensity with anti_shock(tm)
    analogWrite(RB_LED_PIN,RB_LED_intensity);
    }
}
else if ((hour >= RB_LED_ON) && ((hour < RB_LED_OFF && (minute <=30)) || (hour < RB_LED_OFF-1) )) // Should be full on
{
  Serial.println("RB on max");
    RB_LED_intensity_desired = RB_LED_MAX ;                         
    if ( RB_LED_intensity < RB_LED_intensity_desired )
    {
    RB_LED_intensity = anti_shock(RB_LED_intensity, RB_LED_intensity_desired); // Increase the intensity with anti_shock(tm)
    analogWrite(RB_LED_PIN,RB_LED_intensity);
    }
}
else if ( (hour == (RB_LED_OFF - 1)) && (minute >= 31) )                       // Should be dimming
{
  Serial.println("RB Decreasing");
  RB_LED_intensity_desired=map(minute,59,31,0,RB_LED_MAX);                   // Decrease LED intensity
    if (RB_LED_intensity_desired < RB_LED_intensity)                           // Check we're going down (so to speak) not up!
    {
      RB_LED_intensity=RB_LED_intensity_desired;
      analogWrite(RB_LED_PIN,RB_LED_intensity);
      Serial.println("We are getting dimmer");
    }
    else if (RB_LED_intensity_desired > RB_LED_intensity)
    {
      Serial.println("We should be dimming but we are below desired level already");
    }
}
else
{
   Serial.println("RB Off");
   RB_LED_intensity = 0;
   analogWrite(RB_LED_PIN,RB_LED_intensity);
}

//****** Violet LED's control ******//
if ((hour == (V_LED_ON - 1)) && (minute >= 30))
{
  Serial.println("V Increasing");
    V_LED_intensity_desired=map(minute,30,59,0,V_LED_MAX);                     // Increase the intensity
    if ( V_LED_intensity < V_LED_intensity_desired )
    {
    V_LED_intensity = anti_shock(V_LED_intensity, V_LED_intensity_desired);
    analogWrite(V_LED_PIN, V_LED_intensity);
    }
}
else if ((hour >= V_LED_ON) && ((hour < V_LED_OFF && (minute <=30)) || (hour < V_LED_OFF-1) ))                      // Should be full on
{
  Serial.println("V on max");
  V_LED_intensity_desired = V_LED_MAX ;                                        // Insert anti_shock here
  if ( V_LED_intensity < V_LED_intensity_desired )
  {
  V_LED_intensity = anti_shock(V_LED_intensity, V_LED_intensity_desired);
  analogWrite(V_LED_PIN, V_LED_intensity);
  }
}
else if ((hour == (V_LED_OFF - 1)) && (minute >= 31))                          // Should be dimming
{
  Serial.println("V Decreasing");
    V_LED_intensity_desired=map(minute,59,31,0,V_LED_MAX);                     // Decrease LED intensity
    if (V_LED_intensity_desired < V_LED_intensity)                             // Check we're going down not up!
    {
    V_LED_intensity=V_LED_intensity_desired;
    analogWrite(V_LED_PIN,V_LED_intensity);
    }
        else if (V_LED_intensity_desired > V_LED_intensity)
    {
      Serial.println("We should be dimming but we are below desired level already");
    }
}
else
{
   Serial.println("V off");
   V_LED_intensity = 0;
   analogWrite(V_LED_PIN,V_LED_intensity);
}

//****** Neutral White LED's control ******//
if ((hour == (NW_LED_ON - 1)) && (minute >= 30))
{
    Serial.println("NW Increasing");
    NW_LED_intensity_desired=map(minute,30,59,0,NW_LED_MAX);                   // Increase the intensity
    if ( NW_LED_intensity < NW_LED_intensity_desired )
    {
    NW_LED_intensity = anti_shock(NW_LED_intensity, NW_LED_intensity_desired);
    analogWrite(NW_LED_PIN,NW_LED_intensity);
    }
}
else if ((hour >= NW_LED_ON) && ((hour < NW_LED_OFF && (minute <=30)) || (hour < NW_LED_OFF-1) ))                   // Should be full on
{
    Serial.println("NW on max");
    NW_LED_intensity_desired = NW_LED_MAX ;
    if ( NW_LED_intensity < NW_LED_intensity_desired )
    {
    NW_LED_intensity = anti_shock(NW_LED_intensity, NW_LED_intensity_desired); // Insert antishock here!
    analogWrite(NW_LED_PIN,NW_LED_intensity);
    }
}
else if ((hour == (NW_LED_OFF - 1)) && (minute >= 31))                         // Should be dimming
{
    Serial.println("NW Decreasing");
    NW_LED_intensity_desired=map(minute,59,31,0,NW_LED_MAX);                   // Decrease LED intensity
    if (NW_LED_intensity_desired < NW_LED_intensity)                           // Check we're going down not up!
    {
    NW_LED_intensity=NW_LED_intensity_desired;
    analogWrite(NW_LED_PIN,NW_LED_intensity);
    }
        else if (NW_LED_intensity_desired > NW_LED_intensity)
    {
      Serial.println("We should be dimming but we are below desired level already");
    }
}
else
{
   Serial.println("NW off");
   NW_LED_intensity = 0;
   analogWrite(NW_LED_PIN,NW_LED_intensity);
}

//****** Moonlight LED's control ******//
// Things work a bit different with moonlight
if ((hour == (MOON_LED_ON - 1)) && (minute >= 30))
{
    Serial.println("Moon Increasing");
    MOON_LED_intensity_desired=map(minute,30,59,0,MOON_LED_MAX);                         // Increase the intensity
    if ( MOON_LED_intensity < MOON_LED_intensity_desired )
    {
    MOON_LED_intensity = anti_shock(MOON_LED_intensity, MOON_LED_intensity_desired);
    analogWrite(MOON_LED_PIN,MOON_LED_intensity);
    }
}
else if ((hour >= MOON_LED_ON) || (hour <= MOON_LED_OFF - 1))                            // Should be full on
{
    Serial.println("Moon on max");
    MOON_LED_intensity_desired = MOON_LED_MAX ;
    if ( MOON_LED_intensity < MOON_LED_intensity_desired )
    {
    MOON_LED_intensity = anti_shock(MOON_LED_intensity, MOON_LED_intensity_desired);     // Insert antishock here!!
    analogWrite(MOON_LED_PIN,MOON_LED_intensity);
    }
}
else if ((hour == (MOON_LED_OFF - 1)) && (minute >= 30))                       // Should be dimming
{
    Serial.println("Moon Decreasing");
    MOON_LED_intensity_desired=map(minute,59,30,0,MOON_LED_MAX);                         // Decrease LED intensity
    if (MOON_LED_intensity_desired < MOON_LED_intensity)                                 // Check we're going down not up!
    {
    MOON_LED_intensity=MOON_LED_intensity_desired;
    analogWrite(MOON_LED_PIN,MOON_LED_intensity);
    }
        else if (MOON_LED_intensity_desired > MOON_LED_intensity)
    {
      Serial.println("We should be dimming but we are below desired level already");
    }
}
else
{
   Serial.println("Moon off");
   MOON_LED_intensity = 0;
   analogWrite(MOON_LED_PIN,MOON_LED_intensity);
}

// Print the LED intensity
Serial.println();
Serial.print("Royal Blue LED intensity:          ");
Serial.println(RB_LED_intensity);
Serial.print("Violet LED intensity:              ");
Serial.println(V_LED_intensity);
Serial.print("Neutral White LED intensity:       ");
Serial.println(NW_LED_intensity);
Serial.print("Moonlight LED intensity:           ");
Serial.println(MOON_LED_intensity);

// Pause the loop - in milliseconds - 1000 = 1sec
// Set to 60 seconds for testing while logging
delay(5000);
}
/****** Finish Main Program Loop ******/
