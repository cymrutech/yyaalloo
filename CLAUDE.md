# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**YYAALLOO** is an Arduino sketch for a reef aquarium LED lighting controller. It manages 4 PWM LED channels (Royal Blue, Violet, Neutral White, Moon), reads 3x DS18B20 temperature sensors over 1-Wire, and syncs time via a DS1307 RTC over I2C. Serial output at 115200 baud provides runtime diagnostics.

## Build & Flash

No build system — use Arduino IDE or PlatformIO:

```bash
# Arduino IDE (GUI): File → Open → yyaalloo.pde → Upload
# Arduino CLI (if installed):
arduino-cli compile --fqbn arduino:avr:uno yyaalloo.pde
arduino-cli upload --fqbn arduino:avr:uno --port /dev/ttyUSB0 yyaalloo.pde
```

**Required libraries** (install via Arduino IDE Library Manager):
- `OneWire`
- `DallasTemperature`
- `Wire` (built-in)

**Monitor:** 115200 baud — outputs time, temps, moon phase, LED intensities every 5 seconds.

## Known Compatibility Issue

The sketch uses deprecated Wire library calls:
- `Wire.send()` → now `Wire.write()`
- `Wire.receive()` → now `Wire.read()`

These must be updated for Arduino IDE 1.0+ / modern boards.

## Architecture

Single file: `yyaalloo.pde` (480 lines)

**Hardware pins:**
| Channel | Pin | Notes |
|---------|-----|-------|
| Royal Blue LED | 11 (PWM) | 420nm |
| Violet LED | 10 (PWM) | 410nm |
| Neutral White LED | 9 (PWM) | 4100K |
| Moon LED | 6 (PWM) | Night light |
| Temp sensors (3x) | 2 (1-Wire) | DS18B20 |
| RTC DS1307 | SDA/SCL | I2C addr 0x68 |

**Main loop** (5s cycle):
1. Read RTC time via I2C (`getDateDs1307()`)
2. Calculate moon phase (`moonPhase()`)
3. Read all 3 temperature sensors
4. For each LED channel: evaluate fade-in/full-on/fade-out windows, then apply `anti_shock()` to smooth intensity transitions over 30-minute ramp periods

**LED scheduling logic** (per channel):
- Fade-in: 30 min before ON hour (starting at minute 30 of the prior hour)
- Full on: between ON and OFF hours
- Fade-out: 30 min starting at minute 31 of the OFF hour

## Project Notes (from claude.md)

- Migrate to CymruTech website under a new "Electronics" top-level menu
- Open-source on GitHub under CymruTech account
- Keep original code intact
- Close old Google Site: https://sites.google.com/site/neildotwilliams/
