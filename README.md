# YYAALLOO

Arduino sketch for a reef aquarium LED lighting controller. Manages 4 PWM LED channels with time-based schedules and smooth fade transitions, reads 3x DS18B20 temperature sensors over 1-Wire, and syncs time via a DS1307 RTC over I2C.

Originally written in August 2011 by Neil Williams.

## Features

- **4 LED channels** with independent on/off schedules
  - Royal Blue (420nm) — Pin 11
  - Violet (410nm) — Pin 10
  - Neutral White (4100K) — Pin 9
  - Moonlight — Pin 6
- **Smooth fade transitions** — 30-minute fade-in before on-time and fade-out after off-time, via `anti_shock()` to avoid startling fish on power-on
- **Moon phase calculation** — Julian date algorithm, returns phase 0–7
- **3x temperature sensors** — DS18B20 over 1-Wire on Pin 2
- **RTC sync** — DS1307 over I2C (address 0x68)
- **Serial diagnostics** — outputs time, moon phase, temperatures, and LED intensities every 5 seconds at 115200 baud

## Hardware

| Component | Pin | Notes |
|-----------|-----|-------|
| Royal Blue LED | 11 (PWM) | 420nm |
| Violet LED | 10 (PWM) | 410nm |
| Neutral White LED | 9 (PWM) | 4100K |
| Moon LED | 6 (PWM) | Night light |
| Temp sensors (3x) | 2 (1-Wire) | DS18B20 |
| RTC DS1307 | SDA/SCL | I2C addr 0x68 |

## Build & Flash

No build system — use Arduino IDE or PlatformIO.

**Required libraries** (install via Arduino IDE Library Manager):
- `OneWire`
- `DallasTemperature`
- `Wire` (built-in)

### Arduino IDE

File → Open → `yyaalloo.pde` → Upload

### Arduino CLI

```bash
arduino-cli compile --fqbn arduino:avr:uno yyaalloo.pde
arduino-cli upload --fqbn arduino:avr:uno --port /dev/ttyUSB0 yyaalloo.pde
```

### Serial Monitor

Connect at **115200 baud**. Output is printed every 5 seconds showing current time, moon phase, all three temperatures, LED schedule state, and current intensities.

## Known Compatibility Issue

The sketch uses deprecated Wire library calls that must be updated for Arduino IDE 1.0+ and modern boards:

| Old (pre-1.0) | New |
|---------------|-----|
| `Wire.send()` | `Wire.write()` |
| `Wire.receive()` | `Wire.read()` |

## LED Scheduling

Each channel has configurable on/off hours (whole hours only). The scheduling logic:

- **Fade-in**: starts at minute 30 of the hour before `ON` time, ramps from 0 to max by `ON` hour
- **Full on**: between `ON` and `OFF` hours
- **Fade-out**: starts at minute 31 of the hour before `OFF` time, ramps from max to 0
- **Off**: all other times, intensity set to 0

The moonlight channel operates on an inverted schedule (on at night, off during the day).

To change schedules, edit the constants near the top of `yyaalloo.pde`:

```cpp
int RB_LED_ON  = 9;   // Royal Blue on at 09:00
int RB_LED_OFF = 20;  // Royal Blue off at 20:00
```

Max intensity (0–255) per channel:

```cpp
int RB_LED_MAX   = 150;
int V_LED_MAX    = 150;
int NW_LED_MAX   = 150;
int MOON_LED_MAX = 150;
```

## Credits

Code assimilated from:
- DS18B20: [Hacktronics 1-Wire tutorial](http://www.hacktronics.com/Tutorials/arduino-1-wire-tutorial.html)
- DS1307 RTC: [ermicro.com](http://www.ermicro.com/blog/?p=950), [glacialwanderer.com](http://www.glacialwanderer.com/hobbyrobotics/?p=12)
- Moon phase algorithm: [technology-flow.com](http://technology-flow.com/articles/aquarium-lights/)

## License

MIT
