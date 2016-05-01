//
// Airspeed - based on RBL SimpleControls app
//

// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
// associated documentation files (the "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// - The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
// OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
// CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

//"services.h/spi.h/boards.h" is needed in every new project
#include <SPI.h>
#include <boards.h>
#include <ble_shield.h>
#include <TimerOne.h>

// project-specific BLE service definition
#include <services.h>
#include <lib_aci.h>
static hal_aci_data_t g_setup_msgs[NB_SETUP_MESSAGES] PROGMEM = SETUP_MESSAGES_CONTENT;
static services_pipe_type_mapping_t g_services_pipe_type_mapping[NUMBER_OF_PIPES] = SERVICES_PIPE_TYPE_MAPPING_CONTENT;

union long_hex {
    uint32_t lunsign;
    struct {
        uint8_t b0;
        uint8_t b1;
        uint8_t b2;
        uint8_t b3;
    } lbytes;
};

float kAirspeedRatio = 1.5191;
float kConvertMeterPerSecToKMH = 3.6;

float g_reference_pressure;
float g_air_pressure;
float g_airspeed_kmh = 0;

// fwd declare
void timerCallback();

void setup()
{
  // Enable serial debug
  Serial.begin(57600);
  Serial.print("\n*** Airspeed starting\n");

  // Init. and start BLE library.
  ble_begin(g_setup_msgs, NB_SETUP_MESSAGES,
     g_services_pipe_type_mapping, NUMBER_OF_PIPES,
     PIPE_UART_OVER_BTLE_UART_TX_TX, PIPE_UART_OVER_BTLE_UART_RX_RX,
     PIPE_DEVICE_INFORMATION_HARDWARE_REVISION_STRING_SET);

  int seed = analogRead(0);
  randomSeed(seed);
  
  Serial.println("getting reference pressure");
  g_reference_pressure = analogRead(0);  
  for (int i=1;i<=100;i++)
  {
    g_reference_pressure = (analogRead(0))*0.25 + g_reference_pressure*0.75;
    
    delay(20);
  }
  
  g_air_pressure = g_reference_pressure;
  
  Serial.println("starting timer");
  Timer1.initialize(500000);             // initialize timer1, and set a 1/2 second period
  Timer1.attachInterrupt(timerCallback); // attaches callback() as a timer interrupt  
}

void timerCallback()
{
  g_air_pressure = analogRead(0)*0.25 + g_air_pressure*0.75;
  float pressure_diff = (g_air_pressure >= g_reference_pressure) ? (g_air_pressure - g_reference_pressure) : 0.0;  
  float airspeed = sqrt(pressure_diff*kAirspeedRatio);
  g_airspeed_kmh = airspeed * kConvertMeterPerSecToKMH;
}

void loop()
{    
  // If data is ready
  while (ble_available())
  {
    byte command = ble_read();

    Serial.print("Receiving <--- cmd: ");    
    Serial.print(command, HEX);
    Serial.print("\n");    
          
    switch (command) {
      case 0x01: {
        Serial.print("cmd: 0x01\n");    
        union long_hex value;
        
        // don't interrupt us while we're reading the airspeed
        noInterrupts();
        float kmh = g_airspeed_kmh;
        interrupts();
        
        value.lunsign = *((uint32_t *)&kmh);
        
        Serial.print("returning air speed: ");
        Serial.print(kmh);
        Serial.println(" km/h");
        
        // little endian
        ble_write(value.lbytes.b0);         
        ble_write(value.lbytes.b1);
        ble_write(value.lbytes.b2);
        ble_write(value.lbytes.b3);        
        break;
      }
            
      default:
        Serial.print("Invalid command - ignoring: ");
        Serial.print(command);
        Serial.print("\n");
        break;      
    }
  }
    
  // Allow BLE Shield to send/receive data
  ble_do_events();  
}



