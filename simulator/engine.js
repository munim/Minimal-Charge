function pad2(n) {
  const v = Math.max(0, Math.trunc(n));
  return v < 10 ? `0${v}` : String(v);
}

export function formatTimeDigits(hour24, minute, is24Hour = true) {
  let displayHour = hour24;
  if (!is24Hour) {
    displayHour = hour24 % 12;
    if (displayHour === 0) {
      displayHour = 12;
    }
  }
  return {
    hour: pad2(displayHour),
    minute: pad2(minute),
  };
}

export function shouldRecomputeTime(prevState, nextState) {
  if (!prevState) return true;
  return (
    prevState.hour !== nextState.hour ||
    prevState.min !== nextState.min ||
    prevState.is24Hour !== nextState.is24Hour ||
    prevState.isAwake !== nextState.isAwake
  );
}

export function computeTimeStackGeometry(width, height, shape = 'round') {
  const isRound = shape === 'round';
  const fontSizePct = isRound ? 34 : 40;
  const lineHeightRatio = 0.8;
  const lineBoxPct = fontSizePct * lineHeightRatio;
  const totalHeightPct = lineBoxPct * 2;
  const topPct = isRound ? 50 - totalHeightPct / 2 : 8;
  const bottomPct = topPct + totalHeightPct;
  const leftPct = isRound ? 50 : 8;
  const fontSizePx = Math.round((width * fontSizePct) / 100);
  const lineBoxPx = Math.round((width * lineBoxPct) / 100);
  const topPx = Math.round((height * topPct) / 100);
  const xPx = Math.round((width * leftPct) / 100);

  return {
    shape: isRound ? 'round' : 'square',
    align: isRound ? 'center' : 'left',
    fontSizePct,
    lineHeightRatio,
    leftPct,
    topPct,
    bottomPct,
    fontSizePx,
    lineBoxPx,
    xPx,
    hourYPx: topPx,
    minuteYPx: topPx + lineBoxPx,
  };
}

const BURN_CYCLE = [
  [0, 0],
  [0.6, 0],
  [0.6, 0.6],
  [0, 0.6],
];

export function computeBurnInOffset(width, height, minute, requiresBurnInProtection = true, isAwake = true) {
  if (!requiresBurnInProtection || isAwake) {
    return { dxPct: 0, dyPct: 0, dxPx: 0, dyPx: 0 };
  }
  const idx = ((minute % 4) + 4) % 4;
  const [dxPct, dyPct] = BURN_CYCLE[idx];
  return {
    dxPct,
    dyPct,
    dxPx: Math.round((width * dxPct) / 100),
    dyPx: Math.round((height * dyPct) / 100),
  };
}

export function isLowPowerShedding(battery, autoBatterySaver = true) {
  return Boolean(autoBatterySaver && battery !== null && battery !== undefined && Number(battery) < 20);
}

export function resolvePalette({
  requiresBurnInProtection = true,
  isAwake = true,
  battery = 100,
  autoBatterySaver = false,
} = {}) {
  const lowPowerShedding = isLowPowerShedding(battery, autoBatterySaver);

  if (!requiresBurnInProtection) {
    if (lowPowerShedding && isAwake) {
      return {
        bg: '#000000',
        fg: '#AAAAAA',
        dim: '#AAAAAA',
        track: '#555555',
        accent: '#AAAAAA',
        warn: '#FFAA00',
      };
    }
    return {
      bg: '#000000',
      fg: '#FFFFFF',
      dim: '#AAAAAA',
      track: '#555555',
      accent: '#00AAFF',
      warn: '#FFAA00',
    };
  }

  if (!isAwake) {
    return {
      bg: '#000000',
      fg: '#BFC2C7',
      dim: '#8E9299',
      track: '#22262C',
      accent: '#BFC2C7',
      warn: '#BFC2C7',
    };
  }

  if (lowPowerShedding) {
    return {
      bg: '#000000',
      fg: '#BFC2C7',
      dim: '#8E9299',
      track: '#22262C',
      accent: '#BFC2C7',
      warn: '#F5A623',
    };
  }

  return {
    bg: '#000000',
    fg: '#F5F7FA',
    dim: '#8E9299',
    track: '#22262C',
    accent: '#3B9EFF',
    warn: '#F5A623',
  };
}

const WEATHER_CONDITION_LABELS = [
  'CLEAR',   // 0: CONDITION_CLEAR
  'CLOUDY',  // 1: CONDITION_PARTLY_CLOUDY
  'CLOUDY',  // 2: CONDITION_MOSTLY_CLOUDY
  'RAIN',    // 3: CONDITION_RAIN
  'SNOW',    // 4: CONDITION_SNOW
  'WIND',    // 5: CONDITION_WINDY
  'STORM',   // 6: CONDITION_THUNDERSTORMS
  'MIX',     // 7: CONDITION_WINTRY_MIX
  'FOG',     // 8: CONDITION_FOG
  'HAZE',    // 9: CONDITION_HAZY
  'HAIL',    // 10: CONDITION_HAIL
  'SHOWERS', // 11: CONDITION_SCATTERED_SHOWERS
  'STORM',   // 12: CONDITION_SCATTERED_THUNDERSTORMS
  'MIX',     // 13: CONDITION_UNKNOWN_PRECIPITATION
  'RAIN',    // 14: CONDITION_LIGHT_RAIN
  'RAIN',    // 15: CONDITION_HEAVY_RAIN
  'SNOW',    // 16: CONDITION_LIGHT_SNOW
  'SNOW',    // 17: CONDITION_HEAVY_SNOW
  'MIX',     // 18: CONDITION_LIGHT_RAIN_SNOW
  'MIX',     // 19: CONDITION_HEAVY_RAIN_SNOW
  'CLOUDY',  // 20: CONDITION_CLOUDY
  'MIX',     // 21: CONDITION_RAIN_SNOW
  'CLEAR',   // 22: CONDITION_PARTLY_CLEAR
  'CLEAR',   // 23: CONDITION_MOSTLY_CLEAR
  'SHOWERS', // 24: CONDITION_LIGHT_SHOWERS
  'SHOWERS', // 25: CONDITION_SHOWERS
  'SHOWERS', // 26: CONDITION_HEAVY_SHOWERS
  'SHOWERS', // 27: CONDITION_CHANCE_OF_SHOWERS
  'STORM',   // 28: CONDITION_CHANCE_OF_THUNDERSTORMS
  'FOG',     // 29: CONDITION_MIST
  'HAZE',    // 30: CONDITION_DUST
  'RAIN',    // 31: CONDITION_DRIZZLE
  'STORM',   // 32: CONDITION_TORNADO
  'HAZE',    // 33: CONDITION_SMOKE
  'MIX',     // 34: CONDITION_ICE
  'HAZE',    // 35: CONDITION_SAND
  'WIND',    // 36: CONDITION_SQUALL
  'HAZE',    // 37: CONDITION_SANDSTORM
  'HAZE',    // 38: CONDITION_VOLCANIC_ASH
  'HAZE',    // 39: CONDITION_HAZE
  'CLEAR',   // 40: CONDITION_FAIR
  'STORM',   // 41: CONDITION_HURRICANE
  'STORM',   // 42: CONDITION_TROPICAL_STORM
  'SNOW',    // 43: CONDITION_CHANCE_OF_SNOW
  'MIX',     // 44: CONDITION_CHANCE_OF_RAIN_SNOW
  'RAIN',    // 45: CONDITION_CLOUDY_CHANCE_OF_RAIN
  'SNOW',    // 46: CONDITION_CLOUDY_CHANCE_OF_SNOW
  'MIX',     // 47: CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW
  'SNOW',    // 48: CONDITION_FLURRIES
  'RAIN',    // 49: CONDITION_FREEZING_RAIN
  'MIX',     // 50: CONDITION_SLEET
  'MIX',     // 51: CONDITION_ICE_SNOW
  'CLOUDY',  // 52: CONDITION_THIN_CLOUDS
  'WEATHER', // 53: CONDITION_UNKNOWN
];

export function mapWeatherCondition(conditionCode) {
  if (conditionCode === null || conditionCode === undefined || Number.isNaN(Number(conditionCode))) {
    return 'WEATHER';
  }
  const idx = Math.trunc(Number(conditionCode));
  if (idx < 0 || idx >= WEATHER_CONDITION_LABELS.length) {
    return 'WEATHER';
  }
  return WEATHER_CONDITION_LABELS[idx];
}

export function formatTemperature(tempC, unit = 'C') {
  if (tempC === null || tempC === undefined || Number.isNaN(Number(tempC))) {
    return '—';
  }
  const c = Number(tempC);
  const isF = String(unit).toUpperCase() === 'F' || unit === 1;
  const val = isF ? Math.round((c * 9) / 5 + 32) : Math.round(c);
  return `${val}°`;
}

export function shouldQueryHeartRate(slots = [], isAwake = true, { battery = 100, autoBatterySaver = false } = {}) {
  if (!isAwake || isLowPowerShedding(battery, autoBatterySaver)) return false;
  return slots.some((s) => {
    const v = String(s || '').toLowerCase();
    return v === 'hr' || v === 'heart_rate' || v === '4';
  });
}

export function shouldRenderSlots({
  isAwake = true,
  timeOnlyAmbient = false,
  battery = 100,
  autoBatterySaver = true,
} = {}) {
  if (isAwake) return true;
  if (timeOnlyAmbient || isLowPowerShedding(battery, autoBatterySaver)) return false;
  return true;
}

export function evaluateRefreshPolicy({
  profile = 'balanced',
  isAwake = true,
  justWoke = false,
  minuteChanged = false,
  slots = ['date', 'steps', 'battery'],
  battery = 100,
  autoBatterySaver = true,
  elapsedSec = { steps: Infinity, battery: Infinity, weather: Infinity },
} = {}) {
  const normProfile = String(profile || 'balanced').toLowerCase();
  const isSaverProfile = normProfile === 'saver' || normProfile === '1';
  const isLiveProfile = normProfile === 'live' || normProfile === '2';
  const lowPowerShedding = isLowPowerShedding(battery, autoBatterySaver);

  const hasSlot = (target) =>
    slots.some((s) => {
      const v = String(s || '').toLowerCase();
      if (target === 'hr') return v === 'hr' || v === 'heart_rate' || v === '4';
      if (target === 'steps') return v === 'steps' || v === '2';
      if (target === 'battery') return v === 'battery' || v === '3';
      if (target === 'weather') return v === 'weather' || v === '5';
      return false;
    });

  // In sleep mode under Max Battery Saver (Wake-Only), zero sensor/stat/weather queries occur
  if (!isAwake && isSaverProfile) {
    return {
      pollHr: false,
      pollSteps: false,
      pollBattery: false,
      pollWeather: false,
      lowPowerShedding,
    };
  }

  // Heart rate:
  // - Never in sleep mode or when lowPowerShedding is active
  // - Live Active: every 1s in Active mode
  // - Balanced / Max Battery Saver: only on wrist raise (justWoke) or minute rollover while awake
  const canPollHr = shouldQueryHeartRate(slots, isAwake, { battery, autoBatterySaver });
  const pollHr = canPollHr && (isLiveProfile ? true : Boolean(justWoke || minuteChanged));

  // Steps & Battery:
  // - Active mode: on wrist raise or at 60s (minuteChanged / elapsed >= 60)
  // - Ambient sleep mode (Balanced & Live Active): every 5 minutes (300s)
  const stepsThreshold = isAwake ? 60 : 300;
  const batteryThreshold = isAwake ? 60 : 300;
  const canTickStat = isAwake ? Boolean(justWoke || minuteChanged || elapsedSec.steps >= stepsThreshold) : Boolean(minuteChanged && elapsedSec.steps >= stepsThreshold);
  const canTickBat = isAwake ? Boolean(justWoke || minuteChanged || elapsedSec.battery >= batteryThreshold) : Boolean(minuteChanged && elapsedSec.battery >= batteryThreshold);

  const pollSteps = hasSlot('steps') && (justWoke || (elapsedSec.steps ?? Infinity) >= stepsThreshold) && canTickStat;
  const pollBattery = hasSlot('battery') && (justWoke || (elapsedSec.battery ?? Infinity) >= batteryThreshold) && canTickBat;

  // Weather:
  // - Suspended when lowPowerShedding is active
  // - Balanced / Saver (when awake): 15 minutes (900s)
  // - Live Active: 5 minutes (300s) in sleep or active
  const weatherThreshold = isLiveProfile ? 300 : 900;
  const canTickWeather = isAwake
    ? Boolean(justWoke || (minuteChanged && (elapsedSec.weather ?? Infinity) >= weatherThreshold) || (elapsedSec.weather ?? Infinity) >= weatherThreshold)
    : Boolean(minuteChanged && (elapsedSec.weather ?? Infinity) >= weatherThreshold);
  const pollWeather =
    !lowPowerShedding &&
    hasSlot('weather') &&
    (elapsedSec.weather ?? Infinity) >= weatherThreshold &&
    canTickWeather;

  return {
    pollHr,
    pollSteps,
    pollBattery,
    pollWeather,
    lowPowerShedding,
  };
}

export function buildWatchRenderModel(state = {}) {
  const width = state.width || 454;
  const height = state.height || 454;
  const shape = state.shape === 'square' ? 'square' : 'round';
  const requiresBurnInProtection = state.displayType !== 'mip' && state.requiresBurnInProtection !== false;
  const isAwake = state.isAwake !== false;
  const battery = state.battery ?? 76;
  const autoBatterySaver = state.autoBatterySaver !== false;
  const timeOnlyAmbient = Boolean(state.timeOnlyAmbient);
  const lowPowerShedding = isLowPowerShedding(battery, autoBatterySaver);

  const time = formatTimeDigits(state.hour ?? 10, state.minute ?? 9, state.is24Hour !== false);
  const timeGeometry = computeTimeStackGeometry(width, height, shape);
  const burnIn = computeBurnInOffset(width, height, state.minute ?? 0, requiresBurnInProtection, isAwake);
  const palette = resolvePalette({
    requiresBurnInProtection,
    isAwake,
    battery,
    autoBatterySaver,
  });
  const slotsVisible = shouldRenderSlots({
    isAwake,
    timeOnlyAmbient,
    battery,
    autoBatterySaver,
  });
  const slotLayout = computeSlotLayout(width, height, shape, state.slots || ['date', 'steps', 'battery']);
  const refreshPolicy = evaluateRefreshPolicy({
    profile: state.profile || 'balanced',
    isAwake,
    justWoke: Boolean(state.justWoke),
    minuteChanged: Boolean(state.minuteChanged),
    slots: state.slots || ['date', 'steps', 'battery'],
    battery,
    autoBatterySaver,
    elapsedSec: state.elapsedSec,
  });

  const metricData = {
    weekday: state.weekday ?? 'WED',
    day: state.day ?? 14,
    month: state.month ?? 'May',
    steps: state.steps,
    stepGoal: state.stepGoal ?? 10000,
    battery,
    heartRate: lowPowerShedding ? null : state.heartRate,
    weatherCondition: lowPowerShedding ? null : state.weatherCondition,
    temperatureC: lowPowerShedding ? null : state.temperatureC,
    tempUnit: state.tempUnit || 'C',
  };

  const slots = slotLayout.map((slotGeo) => {
    const metric = formatSlotMetric(slotGeo.type, metricData);
    const valueColor = metric.valueColorRole === 'warn' ? palette.warn : palette.fg;
    const barColor =
      metric.barColorRole === 'warn'
        ? palette.warn
        : metric.barColorRole === 'accent'
          ? palette.accent
          : palette.fg;
    return {
      ...slotGeo,
      visible: slotsVisible && slotGeo.visible,
      metric,
      labelColor: palette.dim,
      valueColor,
      barColor,
      trackColor: palette.track,
    };
  });

  return {
    width,
    height,
    shape,
    requiresBurnInProtection,
    isAwake,
    lowPowerShedding,
    time,
    timeGeometry,
    burnIn,
    palette,
    slotsVisible,
    slots,
    refreshPolicy,
  };
}



export function formatSteps(n) {
  if (n === null || n === undefined || Number.isNaN(Number(n))) {
    return '—';
  }
  const v = Math.max(0, Math.trunc(Number(n)));
  return v < 1000 ? String(v) : `${Math.round(v / 100) / 10}K`;
}

export function formatSlotMetric(slotType, data = {}) {
  const type = String(slotType || 'off').toLowerCase();
  if (type === 'off' || type === '0') {
    return {
      type: 'off',
      label: '',
      value: '',
      hasBar: false,
      barRatio: 0,
      barColorRole: null,
      valueColorRole: 'fg',
    };
  }

  if (type === 'date' || type === '1') {
    const weekday = data.weekday ? String(data.weekday).toUpperCase() : 'DATE';
    const hasDate = data.day !== null && data.day !== undefined && data.month;
    return {
      type: 'date',
      label: weekday,
      value: hasDate ? `${data.day} ${data.month}` : '—',
      hasBar: false,
      barRatio: 0,
      barColorRole: null,
      valueColorRole: 'fg',
    };
  }

  if (type === 'steps' || type === '2') {
    const steps = data.steps;
    const goal = data.stepGoal && data.stepGoal > 0 ? data.stepGoal : 10000;
    const hasSteps = steps !== null && steps !== undefined && !Number.isNaN(Number(steps));
    const ratio = hasSteps ? Math.min(1, Math.max(0, Number(steps) / goal)) : 0;
    return {
      type: 'steps',
      label: 'STEPS',
      value: hasSteps ? formatSteps(steps) : '—',
      hasBar: true,
      barRatio: ratio,
      barColorRole: 'accent',
      valueColorRole: 'fg',
    };
  }

  if (type === 'battery' || type === '3') {
    const battery = data.battery;
    const hasBattery = battery !== null && battery !== undefined && !Number.isNaN(Number(battery));
    const pct = hasBattery ? Math.min(100, Math.max(0, Math.round(Number(battery)))) : 0;
    const isLow = hasBattery && Number(battery) < 20;
    return {
      type: 'battery',
      label: 'BATTERY',
      value: hasBattery ? `${pct}%` : '—',
      hasBar: true,
      barRatio: hasBattery ? pct / 100 : 0,
      barColorRole: isLow ? 'warn' : 'fg',
      valueColorRole: isLow ? 'warn' : 'fg',
    };
  }

  if (type === 'hr' || type === 'heart_rate' || type === '4') {
    const hr = data.heartRate;
    const hasHr = hr !== null && hr !== undefined && !Number.isNaN(Number(hr)) && Number(hr) > 0;
    return {
      type: 'hr',
      label: 'HR',
      value: hasHr ? `${Math.round(Number(hr))} bpm` : '—',
      hasBar: false,
      barRatio: 0,
      barColorRole: null,
      valueColorRole: 'fg',
    };
  }

  if (type === 'weather' || type === '5') {
    const hasTemp = data.temperatureC !== null && data.temperatureC !== undefined && !Number.isNaN(Number(data.temperatureC));
    const label = hasTemp || (data.weatherCondition !== null && data.weatherCondition !== undefined)
      ? mapWeatherCondition(data.weatherCondition)
      : 'WEATHER';
    return {
      type: 'weather',
      label,
      value: formatTemperature(data.temperatureC, data.tempUnit || 'C'),
      hasBar: false,
      barRatio: 0,
      barColorRole: null,
      valueColorRole: 'fg',
    };
  }

  return {
    type,
    label: type.toUpperCase(),
    value: '—',
    hasBar: false,
    barRatio: 0,
    barColorRole: null,
    valueColorRole: 'fg',
  };
}

export function computeSlotLayout(width, height, shape = 'round', slots = ['date', 'steps', 'battery']) {
  const normalized = slots.map((s) => {
    const v = String(s || 'off').toLowerCase();
    return v === '0' ? 'off' : v;
  });
  const active = normalized.map((s) => s !== 'off');
  const isRound = shape === 'round';

  if (isRound) {
    const slot2Active = active[1];
    const slot3Active = active[2];
    const soloBottom = (slot2Active && !slot3Active) || (!slot2Active && slot3Active);

    const slot1 = {
      slotIndex: 0,
      type: normalized[0],
      visible: active[0],
      align: 'center',
      topPct: 5,
      bottomPct: null,
      leftPct: 28,
      rightPct: 72,
      centerXPct: 50,
      widthPct: 44,
      barWidthPct: 22,
      barHeightPx: 3,
      xPx: Math.round(width * 0.5),
      yPx: Math.round(height * 0.05),
      widthPx: Math.round(width * 0.44),
      barWidthPx: Math.round(width * 0.22),
    };

    const slot2LeftPct = soloBottom && slot2Active ? 39 : 26;
    const slot2RightPct = slot2LeftPct + 22;
    const slot2CenterPct = slot2LeftPct + 11;
    const slot2 = {
      slotIndex: 1,
      type: normalized[1],
      visible: slot2Active,
      align: 'center',
      topPct: null,
      bottomPct: 8,
      leftPct: slot2LeftPct,
      rightPct: slot2RightPct,
      centerXPct: slot2CenterPct,
      widthPct: 22,
      barWidthPct: 22,
      barHeightPx: 3,
      xPx: Math.round((width * slot2CenterPct) / 100),
      yPx: Math.round(height * (1 - 0.08)),
      widthPx: Math.round(width * 0.22),
      barWidthPx: Math.round(width * 0.22),
    };

    const slot3LeftPct = soloBottom && slot3Active ? 39 : 52;
    const slot3RightPct = slot3LeftPct + 22;
    const slot3CenterPct = slot3LeftPct + 11;
    const slot3 = {
      slotIndex: 2,
      type: normalized[2],
      visible: slot3Active,
      align: 'center',
      topPct: null,
      bottomPct: 8,
      leftPct: slot3LeftPct,
      rightPct: slot3RightPct,
      centerXPct: slot3CenterPct,
      widthPct: 22,
      barWidthPct: 22,
      barHeightPx: 3,
      xPx: Math.round((width * slot3CenterPct) / 100),
      yPx: Math.round(height * (1 - 0.08)),
      widthPx: Math.round(width * 0.22),
      barWidthPx: Math.round(width * 0.22),
    };

    return [slot1, slot2, slot3];
  }

  // Square / Rectangular dial:
  // Data column at left: 62%, top: 12%, width: 30%, stacked in 3 fixed 14%-tall rows with 5% vertical gap.
  // Turning a slot Off leaves its row blank without collapsing unless only one of Slot 2/Slot 3 is active and Slot 1 is empty.
  const soloSquareBottom = !active[0] && ((active[1] && !active[2]) || (!active[1] && active[2]));
  const rowTops = [12, 31, 50];

  return [0, 1, 2].map((idx) => {
    const topPct = soloSquareBottom && active[idx] ? 12 : rowTops[idx];
    return {
      slotIndex: idx,
      type: normalized[idx],
      visible: active[idx],
      align: 'left',
      topPct,
      bottomPct: null,
      leftPct: 62,
      rightPct: 92,
      centerXPct: 77,
      widthPct: 30,
      heightPct: 14,
      barWidthPct: 30,
      barHeightPx: 3,
      xPx: Math.round(width * 0.62),
      yPx: Math.round((height * topPct) / 100),
      widthPx: Math.round(width * 0.30),
      barWidthPx: Math.round(width * 0.30),
    };
  });
}


