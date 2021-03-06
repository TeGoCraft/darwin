#ifndef THERMISTOR_TABLE
#define THERMISTOR_TABLE
#define THERMISTOR

// Thermistor lookup table for RepRap Temperature Sensor Boards (http://make.rrrf.org/ts)
// Made with createTemperatureLookup.py (http://svn.reprap.org/trunk/reprap/firmware/Arduino/utilities/createTemperatureLookup.py)
// ./createTemperatureLookup.py --r0=100000 --t0=25 --r1=0 --r2=4700 --beta=3977 --max-adc=1023
// r0: 100000
// t0: 25
// r1: 0
// r2: 4700
// beta: 3977
// max adc: 1023
#define NUMTEMPS 20
short temptable[NUMTEMPS][2] = {
   {1, 913},
   {54, 264},
   {107, 215},
   {160, 189},
   {213, 171},
   {266, 157},
   {319, 145},
   {372, 135},
   {425, 127},
   {478, 118},
   {531, 110},
   {584, 103},
   {637, 95},
   {690, 88},
   {743, 80},
   {796, 71},
   {849, 62},
   {902, 50},
   {955, 34},
   {1008, 2}
   };
#endif
