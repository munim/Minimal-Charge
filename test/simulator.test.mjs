import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import path from 'node:path';
import {
  formatTimeDigits,
  shouldRecomputeTime,
  computeTimeStackGeometry,
  computeBurnInOffset,
  resolvePalette,
  formatSteps,
  formatSlotMetric,
  computeSlotLayout,
  mapWeatherCondition,
  formatTemperature,
  shouldQueryHeartRate,
  shouldFallbackHeartRateHistory,
  shouldUseOutlineTimeFont,
  canUseMipMinuteClip,
  computeMinuteClipRect,
  evaluateRefreshPolicy,
  shouldRenderSlots,
  buildWatchRenderModel,
} from '../simulator/engine.js';

test('Seam 1 (Ticket #1): formatTimeDigits zero-pads 24h and 12h hours with no AM/PM', () => {
  assert.deepEqual(formatTimeDigits(0, 5, true), { hour: '00', minute: '05' });
  assert.deepEqual(formatTimeDigits(8, 5, true), { hour: '08', minute: '05' });
  assert.deepEqual(formatTimeDigits(13, 58, true), { hour: '13', minute: '58' });

  // 12-hour mode: 0 -> 12, 8 -> 08, 12 -> 12, 13 -> 01, 23 -> 11
  assert.deepEqual(formatTimeDigits(0, 5, false), { hour: '12', minute: '05' });
  assert.deepEqual(formatTimeDigits(8, 5, false), { hour: '08', minute: '05' });
  assert.deepEqual(formatTimeDigits(12, 30, false), { hour: '12', minute: '30' });
  assert.deepEqual(formatTimeDigits(13, 58, false), { hour: '01', minute: '58' });
  assert.deepEqual(formatTimeDigits(23, 9, false), { hour: '11', minute: '09' });
});

test('Seam 1 (Ticket #1): shouldRecomputeTime skips recomputation when active minute has not changed', () => {
  assert.equal(shouldRecomputeTime({ hour: 11, min: 58, is24Hour: true, isAwake: true }, { hour: 11, min: 58, is24Hour: true, isAwake: true }), false);
  assert.equal(shouldRecomputeTime({ hour: 11, min: 58, is24Hour: true, isAwake: true }, { hour: 11, min: 59, is24Hour: true, isAwake: true }), true);
  assert.equal(shouldRecomputeTime({ hour: 11, min: 58, is24Hour: true, isAwake: true }, { hour: 11, min: 58, is24Hour: false, isAwake: true }), true);
  assert.equal(shouldRecomputeTime(null, { hour: 11, min: 58, is24Hour: true, isAwake: true }), true);
});

test('Seam 1 (Ticket #1): computeTimeStackGeometry matches Round (34%, centered, y: 22.8%-77.2%) and Square (40%, top-left 8%/8%, y: 8%-72%)', () => {
  const round = computeTimeStackGeometry(454, 454, 'round');
  assert.equal(round.fontSizePct, 34);
  assert.equal(round.lineHeightRatio, 0.8);
  assert.equal(round.align, 'center');
  assert.equal(Math.round(round.topPct * 10) / 10, 22.8);
  assert.equal(Math.round(round.bottomPct * 10) / 10, 77.2);
  assert.equal(round.xPx, 227);
  assert.equal(round.fontSizePx, Math.round(454 * 0.34));

  const square = computeTimeStackGeometry(390, 390, 'square');
  assert.equal(square.fontSizePct, 40);
  assert.equal(square.lineHeightRatio, 0.8);
  assert.equal(square.align, 'left');
  assert.equal(square.leftPct, 8);
  assert.equal(square.topPct, 8);
  assert.equal(square.bottomPct, 72);
  assert.equal(square.xPx, Math.round(390 * 0.08));
  assert.equal(square.fontSizePx, Math.round(390 * 0.40));
});

test('Seam 2 (Ticket #2): computeBurnInOffset shifts 0.6% in 4-step cycle only on AMOLED in Ambient sleep mode', () => {
  // AMOLED active -> [0, 0]
  assert.deepEqual(computeBurnInOffset(454, 454, 1, true, true), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });
  // AMOLED ambient -> 4-step cycle indexed by minute % 4
  assert.deepEqual(computeBurnInOffset(454, 454, 0, true, false), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });
  assert.deepEqual(computeBurnInOffset(454, 454, 1, true, false), { dxPct: 0.6, dyPct: 0, dxPx: Math.round(454 * 0.006), dyPx: 0 });
  assert.deepEqual(computeBurnInOffset(454, 454, 2, true, false), { dxPct: 0.6, dyPct: 0.6, dxPx: Math.round(454 * 0.006), dyPx: Math.round(454 * 0.006) });
  assert.deepEqual(computeBurnInOffset(454, 454, 3, true, false), { dxPct: 0, dyPct: 0.6, dxPx: 0, dyPx: Math.round(454 * 0.006) });
  assert.deepEqual(computeBurnInOffset(454, 454, 4, true, false), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });

  // MIP active & ambient -> always [0, 0]
  assert.deepEqual(computeBurnInOffset(260, 260, 1, false, true), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });
  assert.deepEqual(computeBurnInOffset(260, 260, 1, false, false), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });
  assert.deepEqual(computeBurnInOffset(260, 260, 2, false, false), { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 });
});

test('Seam 2 (Ticket #2): resolvePalette switches AMOLED Ambient to dimmed greys and keeps MIP 64-color palette steady', () => {
  const amoledActive = resolvePalette({ requiresBurnInProtection: true, isAwake: true });
  assert.equal(amoledActive.fg, '#F5F7FA');
  assert.equal(amoledActive.dim, '#8E9299');
  assert.equal(amoledActive.track, '#22262C');
  assert.equal(amoledActive.accent, '#3B9EFF');
  assert.equal(amoledActive.warn, '#F5A623');

  const amoledAmbient = resolvePalette({ requiresBurnInProtection: true, isAwake: false });
  assert.equal(amoledAmbient.fg, '#BFC2C7');
  assert.equal(amoledAmbient.dim, '#8E9299');
  assert.equal(amoledAmbient.track, '#22262C');
  assert.equal(amoledAmbient.accent, '#BFC2C7');
  assert.equal(amoledAmbient.warn, '#BFC2C7');

  const mipActive = resolvePalette({ requiresBurnInProtection: false, isAwake: true });
  const mipAmbient = resolvePalette({ requiresBurnInProtection: false, isAwake: false });
  assert.deepEqual(mipActive, {
    bg: '#000000',
    fg: '#FFFFFF',
    dim: '#AAAAAA',
    track: '#555555',
    accent: '#00AAFF',
    warn: '#FFAA00',
  });
  assert.deepEqual(mipAmbient, mipActive);
});

test('Seam 3 (Ticket #3): formatSteps and formatSlotMetric format Date, Steps, Battery, and null fallbacks', () => {
  assert.equal(formatSteps(0), '0');
  assert.equal(formatSteps(999), '999');
  assert.equal(formatSteps(1000), '1K');
  assert.equal(formatSteps(8420), '8.4K');
  assert.equal(formatSteps(12560), '12.6K');

  const dateSlot = formatSlotMetric('date', { weekday: 'Wed', day: 14, month: 'May' });
  assert.deepEqual(dateSlot, {
    type: 'date',
    label: 'WED',
    value: '14 May',
    hasBar: false,
    barRatio: 0,
    barColorRole: null,
    valueColorRole: 'fg',
  });

  const stepsSlot = formatSlotMetric('steps', { steps: 8420, stepGoal: 10000 });
  assert.equal(stepsSlot.label, 'STEPS');
  assert.equal(stepsSlot.value, '8.4K');
  assert.equal(stepsSlot.hasBar, true);
  assert.equal(Math.round(stepsSlot.barRatio * 100), 84);
  assert.equal(stepsSlot.barColorRole, 'accent');

  // Capped at 100%
  const cappedSteps = formatSlotMetric('steps', { steps: 14000, stepGoal: 10000 });
  assert.equal(cappedSteps.barRatio, 1);

  const batterySlot = formatSlotMetric('battery', { battery: 76 });
  assert.equal(batterySlot.label, 'BATTERY');
  assert.equal(batterySlot.value, '76%');
  assert.equal(batterySlot.hasBar, true);
  assert.equal(batterySlot.barRatio, 0.76);
  assert.equal(batterySlot.barColorRole, 'fg');
  assert.equal(batterySlot.valueColorRole, 'fg');

  // Null sensor values preserve label and render '—'
  const nullSteps = formatSlotMetric('steps', { steps: null, stepGoal: 10000 });
  assert.equal(nullSteps.label, 'STEPS');
  assert.equal(nullSteps.value, '—');
  assert.equal(nullSteps.hasBar, true);
  assert.equal(nullSteps.barRatio, 0);

  const nullBattery = formatSlotMetric('battery', { battery: null });
  assert.equal(nullBattery.label, 'BATTERY');
  assert.equal(nullBattery.value, '—');
});

test('Seam 1 (Ticket #3): computeSlotLayout handles Round (top 5%, bottom 8%, solo-bottom centering, 22% bar width cap) and Square (right column 62%/12%/30%)', () => {
  // Round with all 3 slots active
  const roundAll = computeSlotLayout(454, 454, 'round', ['date', 'steps', 'battery']);
  assert.equal(roundAll.length, 3);
  assert.equal(roundAll[0].topPct, 5);
  assert.equal(roundAll[0].centerXPct, 50);
  assert.equal(roundAll[0].widthPct, 44);
  assert.equal(roundAll[0].barWidthPct, 22);
  assert.equal(roundAll[0].barHeightPx, 3);

  // Slot 2: bottom 8%, 22% wide, right edge at 48% (left 26%, center 37%)
  assert.equal(roundAll[1].bottomPct, 8);
  assert.equal(roundAll[1].widthPct, 22);
  assert.equal(roundAll[1].rightPct, 48);
  assert.equal(roundAll[1].leftPct, 26);
  assert.equal(roundAll[1].centerXPct, 37);

  // Slot 3: bottom 8%, 22% wide, left edge at 52% (right 74%, center 63%)
  assert.equal(roundAll[2].bottomPct, 8);
  assert.equal(roundAll[2].widthPct, 22);
  assert.equal(roundAll[2].leftPct, 52);
  assert.equal(roundAll[2].centerXPct, 63);

  // Round solo bottom rule: only Slot 2 active -> centers horizontally at 50%
  const roundSolo2 = computeSlotLayout(454, 454, 'round', ['date', 'steps', 'off']);
  assert.equal(roundSolo2[1].visible, true);
  assert.equal(roundSolo2[1].centerXPct, 50);
  assert.equal(roundSolo2[1].leftPct, 39);
  assert.equal(roundSolo2[1].widthPct, 22);
  assert.equal(roundSolo2[2].visible, false);

  // Round solo bottom rule: only Slot 3 active -> centers horizontally at 50%
  const roundSolo3 = computeSlotLayout(454, 454, 'round', ['date', 'off', 'battery']);
  assert.equal(roundSolo3[1].visible, false);
  assert.equal(roundSolo3[2].visible, true);
  assert.equal(roundSolo3[2].centerXPct, 50);
  assert.equal(roundSolo3[2].leftPct, 39);
  assert.equal(roundSolo3[2].widthPct, 22);

  // Square layout: column at left 62%, top 12%, width 30%, 3 fixed 14%-tall rows with 5% gap
  const squareAll = computeSlotLayout(390, 390, 'square', ['date', 'off', 'battery']);
  assert.equal(squareAll[0].leftPct, 62);
  assert.equal(squareAll[0].topPct, 12);
  assert.equal(squareAll[0].widthPct, 30);
  assert.equal(squareAll[0].heightPct, 14);
  // Slot 2 is off, Slot 3 stays at its fixed 3rd row (12 + 14 + 5 + 14 + 5 = 50%) without collapsing
  assert.equal(squareAll[1].visible, false);
  assert.equal(squareAll[2].visible, true);
  assert.equal(squareAll[2].topPct, 50);
});

test('Seam 3 (Ticket #4): Heart Rate & Weather slot formatting, °C/°F conversion, and all 53+1 Garmin CONDITION_* codes <= 7 chars', () => {
  // All 54 Garmin CONDITION_* codes (0..53) map to single-word uppercase labels <= 7 chars
  for (let code = 0; code <= 53; code++) {
    const label = mapWeatherCondition(code);
    assert.equal(typeof label, 'string');
    assert.ok(label.length >= 3 && label.length <= 7, `Code ${code} mapped to "${label}" (>7 chars)`);
    assert.ok(!label.includes(' '), `Code ${code} mapped to multi-word "${label}"`);
    assert.equal(label, label.toUpperCase());
  }
  assert.equal(mapWeatherCondition(0), 'CLEAR');
  assert.equal(mapWeatherCondition(1), 'CLOUDY');
  assert.equal(mapWeatherCondition(3), 'RAIN');
  assert.equal(mapWeatherCondition(4), 'SNOW');
  assert.equal(mapWeatherCondition(5), 'WIND');
  assert.equal(mapWeatherCondition(6), 'STORM');
  assert.equal(mapWeatherCondition(7), 'MIX');
  assert.equal(mapWeatherCondition(8), 'FOG');
  assert.equal(mapWeatherCondition(9), 'HAZE');
  assert.equal(mapWeatherCondition(10), 'HAIL');
  assert.equal(mapWeatherCondition(11), 'SHOWERS');
  assert.equal(mapWeatherCondition(53), 'WEATHER');
  assert.equal(mapWeatherCondition(null), 'WEATHER');

  // Temperature conversion
  assert.equal(formatTemperature(18, 'C'), '18°');
  assert.equal(formatTemperature(18, 'F'), '64°');
  assert.equal(formatTemperature(0, 'F'), '32°');
  assert.equal(formatTemperature(null, 'C'), '—');

  // Heart rate slot
  const hrSlot = formatSlotMetric('hr', { heartRate: 72 });
  assert.deepEqual(hrSlot, {
    type: 'hr',
    label: 'HR',
    value: '72 bpm',
    hasBar: false,
    barRatio: 0,
    barColorRole: null,
    valueColorRole: 'fg',
  });
  const nullHrSlot = formatSlotMetric('hr', { heartRate: null });
  assert.equal(nullHrSlot.label, 'HR');
  assert.equal(nullHrSlot.value, '—');

  // Weather slot
  const weatherSlotC = formatSlotMetric('weather', { weatherCondition: 0, temperatureC: 18, tempUnit: 'C' });
  assert.equal(weatherSlotC.label, 'CLEAR');
  assert.equal(weatherSlotC.value, '18°');
  assert.equal(weatherSlotC.hasBar, false);

  const weatherSlotF = formatSlotMetric('weather', { weatherCondition: 3, temperatureC: 18, tempUnit: 'F' });
  assert.equal(weatherSlotF.label, 'RAIN');
  assert.equal(weatherSlotF.value, '64°');

  const nullWeather = formatSlotMetric('weather', { weatherCondition: null, temperatureC: null, tempUnit: 'C' });
  assert.equal(nullWeather.label, 'WEATHER');
  assert.equal(nullWeather.value, '—');

  // HR sensor query guard: only when at least one slot is 'hr' AND watch is in Active mode
  assert.equal(shouldQueryHeartRate(['date', 'steps', 'battery'], true), false);
  assert.equal(shouldQueryHeartRate(['date', 'hr', 'battery'], false), false);
  assert.equal(shouldQueryHeartRate(['date', 'hr', 'battery'], true), true);
});

test('Seam 2 (Ticket #5): evaluateRefreshPolicy enforces Balanced, Max Battery Saver (Wake-Only), and Live Active throttling', () => {
  const allSlots = ['hr', 'steps', 'weather'];

  // Balanced on wrist raise (justWoke = true): polls HR, Steps/Battery, Weather if stale
  const balancedWake = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: true,
    justWoke: true,
    minuteChanged: false,
    slots: allSlots,
    elapsedSec: { steps: 10, battery: 10, weather: 10 },
  });
  assert.equal(balancedWake.pollHr, true);

  // Balanced during 1Hz active tick (justWoke = false, minuteChanged = false): never re-polls HR or fresh caches
  const balanced1Hz = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: true,
    justWoke: false,
    minuteChanged: false,
    slots: allSlots,
    elapsedSec: { steps: 15, battery: 15, weather: 120 },
  });
  assert.equal(balanced1Hz.pollHr, false);
  assert.equal(balanced1Hz.pollSteps, false);
  assert.equal(balanced1Hz.pollBattery, false);
  assert.equal(balanced1Hz.pollWeather, false);

  // Balanced in Ambient sleep: Steps/Battery refresh at 5 min (300s), Weather at 15 min (900s), HR never
  const balancedSleep4m = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['hr', 'steps', 'weather'],
    elapsedSec: { steps: 240, battery: 240, weather: 600 },
  });
  assert.equal(balancedSleep4m.pollHr, false);
  assert.equal(balancedSleep4m.pollSteps, false);
  assert.equal(balancedSleep4m.pollWeather, false);

  const balancedSleep15m = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['hr', 'steps', 'weather'],
    elapsedSec: { steps: 300, battery: 300, weather: 900 },
  });
  assert.equal(balancedSleep15m.pollHr, false);
  assert.equal(balancedSleep15m.pollSteps, true);
  assert.equal(balancedSleep15m.pollWeather, true);

  // Max Battery Saver (Wake-Only): zero sensor/stat/weather queries in sleep mode regardless of elapsed time
  const saverSleep = evaluateRefreshPolicy({
    profile: 'saver',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['hr', 'steps', 'weather'],
    elapsedSec: { steps: 9999, battery: 9999, weather: 9999 },
  });
  assert.equal(saverSleep.pollHr, false);
  assert.equal(saverSleep.pollSteps, false);
  assert.equal(saverSleep.pollBattery, false);
  assert.equal(saverSleep.pollWeather, false);

  // Live Active: polls HR every 1s in Active mode, refreshes Steps/Battery/Weather every 5 min (300s) in sleep
  const liveActive1Hz = evaluateRefreshPolicy({
    profile: 'live',
    isAwake: true,
    justWoke: false,
    minuteChanged: false,
    slots: ['hr', 'steps', 'weather'],
    elapsedSec: { steps: 10, battery: 10, weather: 10 },
  });
  assert.equal(liveActive1Hz.pollHr, true);

  const liveSleep5m = evaluateRefreshPolicy({
    profile: 'live',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['hr', 'steps', 'weather'],
    elapsedSec: { steps: 300, battery: 300, weather: 300 },
  });
  assert.equal(liveSleep5m.pollHr, false);
  assert.equal(liveSleep5m.pollSteps, true);
  assert.equal(liveSleep5m.pollWeather, true);
});

test('Seam 2 (Ticket #5 & #6): Time-Only in Ambient Mode and Auto Battery Saver <20% power-shedding & amber warning', () => {
  // Time-Only in Ambient Mode hides slots only when asleep
  assert.equal(shouldRenderSlots({ isAwake: true, timeOnlyAmbient: true, battery: 76, autoBatterySaver: true }), true);
  assert.equal(shouldRenderSlots({ isAwake: false, timeOnlyAmbient: true, battery: 76, autoBatterySaver: true }), false);
  assert.equal(shouldRenderSlots({ isAwake: false, timeOnlyAmbient: false, battery: 76, autoBatterySaver: true }), true);

  // Auto Battery Saver <20% forces Time-Only in Ambient sleep even when timeOnlyAmbient setting is false
  assert.equal(shouldRenderSlots({ isAwake: false, timeOnlyAmbient: false, battery: 14, autoBatterySaver: true }), false);
  // When Auto Battery Saver <20% is Off, Ambient sleep still renders slots if timeOnlyAmbient is false
  assert.equal(shouldRenderSlots({ isAwake: false, timeOnlyAmbient: false, battery: 14, autoBatterySaver: false }), true);

  // Below 20% battery colours Battery slot with 'warn' role
  const lowBatSlot = formatSlotMetric('battery', { battery: 14 });
  assert.equal(lowBatSlot.value, '14%');
  assert.equal(lowBatSlot.valueColorRole, 'warn');
  assert.equal(lowBatSlot.barColorRole, 'warn');

  // Auto Battery Saver <20% dims Active palette to Ambient grey while keeping warn amber (#F5A623 on AMOLED, #FFAA00 on MIP)
  const shedAmoledActive = resolvePalette({
    requiresBurnInProtection: true,
    isAwake: true,
    battery: 14,
    autoBatterySaver: true,
  });
  assert.equal(shedAmoledActive.fg, '#BFC2C7');
  assert.equal(shedAmoledActive.accent, '#BFC2C7');
  assert.equal(shedAmoledActive.warn, '#F5A623');

  // In AMOLED Ambient mode, warn is grey (#BFC2C7), not bright amber
  const shedAmoledAmbient = resolvePalette({
    requiresBurnInProtection: true,
    isAwake: false,
    battery: 14,
    autoBatterySaver: false,
  });
  assert.equal(shedAmoledAmbient.warn, '#BFC2C7');

  // Auto Battery Saver <20% suspends HR and Weather polling
  const shedPolicy = evaluateRefreshPolicy({
    profile: 'live',
    isAwake: true,
    justWoke: true,
    minuteChanged: true,
    slots: ['hr', 'weather', 'battery'],
    battery: 14,
    autoBatterySaver: true,
    elapsedSec: { steps: 999, battery: 999, weather: 999 },
  });
  assert.equal(shedPolicy.pollHr, false);
  assert.equal(shedPolicy.pollWeather, false);
  assert.equal(shedPolicy.pollBattery, true);

  // Charging back to >= 20% resumes normal polling and full Active contrast
  const rechargedPolicy = evaluateRefreshPolicy({
    profile: 'live',
    isAwake: true,
    justWoke: true,
    minuteChanged: true,
    slots: ['hr', 'weather', 'battery'],
    battery: 20,
    autoBatterySaver: true,
    elapsedSec: { steps: 999, battery: 999, weather: 999 },
  });
  assert.equal(rechargedPolicy.pollHr, true);
  assert.equal(rechargedPolicy.pollWeather, true);

  const rechargedPalette = resolvePalette({
    requiresBurnInProtection: true,
    isAwake: true,
    battery: 20,
    autoBatterySaver: true,
  });
  assert.equal(rechargedPalette.fg, '#F5F7FA');
  assert.equal(rechargedPalette.accent, '#3B9EFF');
});

test('buildWatchRenderModel produces complete watch state across Round/Square, AMOLED/MIP, and low-battery power-shedding', () => {
  const activeRound = buildWatchRenderModel({
    width: 454,
    height: 454,
    shape: 'round',
    displayType: 'amoled',
    isAwake: true,
    hour: 8,
    minute: 5,
    is24Hour: false,
    slots: ['date', 'steps', 'battery'],
    profile: 'balanced',
    timeOnlyAmbient: false,
    autoBatterySaver: true,
    weekday: 'Wed',
    day: 14,
    month: 'May',
    steps: 8420,
    stepGoal: 10000,
    battery: 76,
    heartRate: 72,
    weatherCondition: 0,
    temperatureC: 18,
    tempUnit: 'C',
  });
  assert.equal(activeRound.time.hour, '08');
  assert.equal(activeRound.time.minute, '05');
  assert.equal(activeRound.palette.fg, '#F5F7FA');
  assert.equal(activeRound.burnIn.dxPx, 0);
  assert.equal(activeRound.slotsVisible, true);
  assert.equal(activeRound.slots[0].metric.label, 'WED');
  assert.equal(activeRound.slots[1].metric.value, '8.4K');
  assert.equal(activeRound.slots[2].metric.value, '76%');

  // Low battery (<20%) with Auto Battery Saver On in Active mode suspends HR/Weather and highlights Battery in warn color
  const lowBatModel = buildWatchRenderModel({
    width: 454,
    height: 454,
    shape: 'round',
    displayType: 'amoled',
    isAwake: true,
    hour: 11,
    minute: 58,
    is24Hour: true,
    slots: ['hr', 'weather', 'battery'],
    profile: 'balanced',
    timeOnlyAmbient: false,
    autoBatterySaver: true,
    battery: 14,
    heartRate: 72,
    weatherCondition: 0,
    temperatureC: 18,
    tempUnit: 'C',
  });
  assert.equal(lowBatModel.palette.fg, '#BFC2C7');
  assert.equal(lowBatModel.slots[0].metric.value, '—');
  assert.equal(lowBatModel.slots[1].metric.value, '—');
  assert.equal(lowBatModel.slots[2].metric.value, '14%');
  assert.equal(lowBatModel.slots[2].valueColor, '#F5A623');
});

test('HTML Simulator (Tickets #1-#6): simulator/index.html exposes Round/Square, AMOLED/MIP, Active/Ambient, 3 Slot Dropdowns, Refresh Profile, Time-Only Ambient, Auto Battery Saver <20%, and Battery slider', () => {
  const htmlPath = path.resolve('simulator/index.html');
  assert.ok(fs.existsSync(htmlPath), 'simulator/index.html must exist');
  const html = fs.readFileSync(htmlPath, 'utf8');
  assert.match(html, /JetBrains Mono/);
  assert.match(html, /id="slot1"/);
  assert.match(html, /id="slot2"/);
  assert.match(html, /id="slot3"/);
  assert.match(html, /id="refreshProfile"/);
  assert.match(html, /id="timeOnlyAmbient"/);
  assert.match(html, /id="autoBatterySaver"/);
  assert.match(html, /id="ambientBrightness"/);
  assert.match(html, /id="batteryLevel"/);
  assert.match(html, /id="tempUnit"/);
});

test('Power Optimizations (#4, #5, #6, #7, #8): HR wake-only history fallback, 30m sleep battery throttle, Bold Outline ambient font, Ambient Brightness presets, and MIP dirty-rect clipping', () => {
  // #4: HR history fallback only on wrist wake (justWoke)
  assert.equal(shouldFallbackHeartRateHistory(true), true);
  assert.equal(shouldFallbackHeartRateHistory(false), false);
  const wakeHr = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: true,
    justWoke: true,
    minuteChanged: false,
    slots: ['hr'],
  });
  const minuteHr = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: true,
    justWoke: false,
    minuteChanged: true,
    slots: ['hr'],
  });
  assert.equal(wakeHr.pollHr, true);
  assert.equal(wakeHr.pollHrHistoryFallback, true);
  assert.equal(minuteHr.pollHr, true);
  assert.equal(minuteHr.pollHrHistoryFallback, false);

  // #5: Sleep battery polling throttled to 30m (1800s) when battery > 30% or no battery slot, 5m (300s) when <= 30% with battery slot
  const sleepHighBat5m = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['battery'],
    battery: 76,
    elapsedSec: { steps: 300, battery: 300, weather: 300 },
  });
  assert.equal(sleepHighBat5m.pollBattery, false);

  const sleepHighBat30m = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['battery'],
    battery: 76,
    elapsedSec: { steps: 1800, battery: 1800, weather: 1800 },
  });
  assert.equal(sleepHighBat30m.pollBattery, true);

  const sleepLowBat5m = evaluateRefreshPolicy({
    profile: 'balanced',
    isAwake: false,
    justWoke: false,
    minuteChanged: true,
    slots: ['battery'],
    battery: 25,
    elapsedSec: { steps: 300, battery: 300, weather: 300 },
  });
  assert.equal(sleepLowBat5m.pollBattery, true);

  // #6: JetBrains Mono Bold outline font active only in AMOLED Ambient mode
  assert.equal(shouldUseOutlineTimeFont(true, false), true);
  assert.equal(shouldUseOutlineTimeFont(true, true), false);
  assert.equal(shouldUseOutlineTimeFont(false, false), false);
  const ambientAmoledModel = buildWatchRenderModel({ displayType: 'amoled', isAwake: false, ambientBrightness: 1 });
  assert.equal(ambientAmoledModel.useOutlineTimeFont, true);
  assert.equal(ambientAmoledModel.palette.fg, '#808080');

  // #7: AMOLED Ambient Brightness presets (0 = #BFC2C7, 1 = #808080, 2 = #4D4F54)
  assert.equal(resolvePalette({ requiresBurnInProtection: true, isAwake: false, ambientBrightness: 0 }).fg, '#BFC2C7');
  assert.equal(resolvePalette({ requiresBurnInProtection: true, isAwake: false, ambientBrightness: 1 }).fg, '#808080');
  assert.equal(resolvePalette({ requiresBurnInProtection: true, isAwake: false, ambientBrightness: 2 }).fg, '#4D4F54');

  // #8: MIP Dirty-Rect Clipping policy and minute clip rect
  assert.equal(canUseMipMinuteClip({ requiresBurnInProtection: false, hasFullDraw: true, justWoke: false, minuteChanged: true, hourChanged: false, anySlotRefreshed: false, sheddingChanged: false }), true);
  assert.equal(canUseMipMinuteClip({ requiresBurnInProtection: true, hasFullDraw: true, justWoke: false, minuteChanged: true, hourChanged: false, anySlotRefreshed: false, sheddingChanged: false }), false);
  assert.equal(canUseMipMinuteClip({ requiresBurnInProtection: false, hasFullDraw: true, justWoke: false, minuteChanged: true, hourChanged: true, anySlotRefreshed: false, sheddingChanged: false }), false);
  const mipRoundClip = computeMinuteClipRect(260, 260, 'round');
  assert.equal(mipRoundClip.y, 130);
  const mipSquareClip = computeMinuteClipRect(240, 240, 'square');
  assert.equal(mipSquareClip.y, 96);
});






