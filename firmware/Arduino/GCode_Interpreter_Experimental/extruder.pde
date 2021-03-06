//
// Start of temperature lookup table
//
// Thermistor lookup table for RepRap Temperature Sensor Boards (http://make.rrrf.org/ts)
// Made with createTemperatureLookup.py (http://svn.reprap.org/trunk/reprap/firmware/Arduino/utilities/createTemperatureLookup.py)
// ./createTemperatureLookup.py --r0=100000 --t0=25 --r1=0 --r2=4700 --beta=4066 --max-adc=1023
// r0: 100000
// t0: 25
// r1: 0
// r2: 4700
// beta: 4066
// max adc: 1023
#define NUMTEMPS 20
short temptable[NUMTEMPS][2] = {
   {1, 841},
   {54, 255},
   {107, 209},
   {160, 184},
   {213, 166},
   {266, 153},
   {319, 142},
   {372, 132},
   {425, 124},
   {478, 116},
   {531, 108},
   {584, 101},
   {637, 93},
   {690, 86},
   {743, 78},
   {796, 70},
   {849, 61},
   {902, 50},
   {955, 34},
   {1008, 3}
};
//
// End of temperature lookup table
//

#define EXTRUDER_FORWARD 1
#define EXTRUDER_REVERSE 0

//these our the default values for the extruder.
int extruder_target_celsius = 0;
int extruder_max_celsius = 0;
byte extruder_heater_low = 64;
byte extruder_heater_high = 255;

//this is for doing encoder based extruder control
int extruder_rpm = 0;
long extruder_delay = 0;

//these are for the extruder PID
volatile int extruder_error = 0;						// extruder position / error variable.
volatile int extruder_pGain = EXTRUDER_INITIAL_PGAIN;	// Proportional gain
volatile int extruder_iGain = EXTRUDER_INITIAL_IGAIN;	// Integral gain
volatile int extruder_dGain = EXTRUDER_INITIAL_DGAIN;	// Derivative gain
volatile int iMax = 500;								// Integrator max
volatile int iMin = -500;								// Integrator min
volatile int iState = 0;								// Integrator state
volatile int dState = 0;								// Last position input

#ifdef INVERT_EXTRUDER_QUADRATURE
#define EXTRUDER_QUADRATURE_INCREMENT extruder_error--;
#define EXTRUDER_QUADRATURE_DECREMENT extruder_error++;
#else
#define EXTRUDER_QUADRATURE_INCREMENT extruder_error++;
#define EXTRUDER_QUADRATURE_DECREMENT extruder_error--;
#endif

void extruder_read_quadrature()
{  
  // found a low-to-high on channel A
  if (digitalRead(EXTRUDER_ENCODER_A_PIN) == HIGH)
  {   
    // check channel B to see which way
    if (digitalRead(EXTRUDER_ENCODER_B_PIN) == LOW)
        EXTRUDER_QUADRATURE_INCREMENT
    else
        EXTRUDER_QUADRATURE_DECREMENT
  }
  // found a high-to-low on channel A
  else                                        
  {
    // check channel B to see which way
    if (digitalRead(EXTRUDER_ENCODER_B_PIN) == LOW)
        EXTRUDER_QUADRATURE_DECREMENT
    else
        EXTRUDER_QUADRATURE_INCREMENT
  }
}

void init_extruder()
{
	//default to room temp.
	extruder_set_temperature(21);
	
	//setup our motor dir pin
	pinMode(EXTRUDER_MOTOR_DIR_PIN, OUTPUT);
	digitalWrite(EXTRUDER_MOTOR_DIR_PIN, EXTRUDER_FORWARD);

	//setup our motor speed pin
	pinMode(EXTRUDER_MOTOR_SPEED_PIN, OUTPUT);
	analogWrite(EXTRUDER_MOTOR_SPEED_PIN, 0);

	//set up our header pin
	pinMode(EXTRUDER_HEATER_PIN, OUTPUT);
	analogWrite(EXTRUDER_HEATER_PIN, 0);

	//setup our fan pin
	pinMode(EXTRUDER_FAN_PIN, OUTPUT);
	analogWrite(EXTRUDER_FAN_PIN, 0);
	
	//setup our encoder interrupt stuff.
	//these pins are inputs
	pinMode(EXTRUDER_ENCODER_A_PIN, INPUT);
	pinMode(EXTRUDER_ENCODER_B_PIN, INPUT);

	//turn on internal pullups
	digitalWrite(EXTRUDER_ENCODER_A_PIN, HIGH);
	digitalWrite(EXTRUDER_ENCODER_A_PIN, HIGH);
	
	//attach our interrupt handler
	attachInterrupt(0, extruder_read_quadrature, CHANGE);

	//setup our timer interrupt stuff
	setupTimer1Interrupt();
	setupTimer2Interrupt();
	
	//our default speed for the PID is every millisecond (16000 ticks)
	setTimer2Ticks(16000);
}

void extruder_set_temperature(int temp)
{
	extruder_target_celsius = temp;
	extruder_max_celsius = (int)((float)temp * 1.1);
}

/**
*  Samples the temperature and converts it to degrees celsius.
*  Returns degrees celsius.
*/
int extruder_get_temperature()
{
	if (EXTRUDER_THERMISTOR_PIN > -1)
		return extruder_read_thermistor();
	else if (EXTRUDER_THERMOCOUPLE_PIN > -1)
		return extruder_read_thermocouple();
}

/*
* This function gives us the temperature from the thermistor in Celsius
*/
int extruder_read_thermistor()
{
	int raw = extruder_sample_temperature(EXTRUDER_THERMISTOR_PIN);

	int celsius = 0;
	byte i;

	for (i=1; i<NUMTEMPS; i++)
	{
		if (temptable[i][0] > raw)
		{
			celsius  = temptable[i-1][1] + 
				(raw - temptable[i-1][0]) * 
				(temptable[i][1] - temptable[i-1][1]) /
				(temptable[i][0] - temptable[i-1][0]);

			if (celsius > 255)
				celsius = 255; 

			break;
		}
	}

	// Overflow: We just clamp to 0 degrees celsius
	if (i == NUMTEMPS)
		celsius = 0;

	return celsius;
}

/*
* This function gives us the temperature from the thermocouple in Celsius
*/
int extruder_read_thermocouple()
{
	return ( 5.0 * extruder_sample_temperature(EXTRUDER_THERMOCOUPLE_PIN) * 100.0) / 1024.0;
}

/*
* This function gives us an averaged sample of the analog temperature pin.
*/
int extruder_sample_temperature(byte pin)
{
	int raw = 0;
	
	//read in a certain number of samples
	for (byte i=0; i<TEMPERATURE_SAMPLES; i++)
		raw += analogRead(pin);
		
	//average the samples
	raw = raw/TEMPERATURE_SAMPLES;

	//send it back.
	return raw;
}


/*!
  Manages motor and heater based on measured temperature:
  o If temp is too low, don't start the motor
  o Adjust the heater power to keep the temperature at the target
 */
void extruder_manage_temperature()
{
	//make sure we know what our temp is.
	int current_celsius = extruder_get_temperature();

	//put the heater into high mode if we're not at our target.
	if (current_celsius < extruder_target_celsius)
		analogWrite(EXTRUDER_HEATER_PIN, extruder_heater_high);
	//put the heater on low if we're at our target.
	else if (current_celsius < extruder_max_celsius)
		analogWrite(EXTRUDER_HEATER_PIN, extruder_heater_low);
	//turn the heater off if we're above our max.
	else
		analogWrite(EXTRUDER_HEATER_PIN, 0);
}
