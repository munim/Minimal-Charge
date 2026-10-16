import Toybox.Lang;

module MinimalChargeState {

    // Slot types
    const SLOT_OFF = 0;
    const SLOT_DATE = 1;
    const SLOT_STEPS = 2;
    const SLOT_BATTERY = 3;
    const SLOT_HEART_RATE = 4;
    const SLOT_WEATHER = 5;

    // Refresh profiles
    const PROFILE_BALANCED = 0;
    const PROFILE_MAX_SAVER = 1;
    const PROFILE_LIVE_ACTIVE = 2;

    public function isLowPowerShedding(battery as Number?, autoBatterySaver as Boolean) as Boolean {
        return autoBatterySaver && (battery != null) && (battery < 20);
    }

    public function clampBarRatio(value as Number?, goal as Number) as Float {
        if (value == null || goal <= 0) {
            return 0.0f;
        }
        var ratio = value.toFloat() / goal.toFloat();
        if (ratio < 0.0f) {
            return 0.0f;
        }
        if (ratio > 1.0f) {
            return 1.0f;
        }
        return ratio;
    }

    public function shouldRecomputeTime(
        prevHour as Number,
        prevMin as Number,
        prevIs24Hour as Boolean,
        nextHour as Number,
        nextMin as Number,
        nextIs24Hour as Boolean
    ) as Boolean {
        if (prevHour < 0 || prevMin < 0) {
            return true;
        }
        return (prevHour != nextHour) || (prevMin != nextMin) || (prevIs24Hour != nextIs24Hour);
    }

    // 4-point burn-in cycle on AMOLED in Ambient sleep mode:
    // [0, 0] -> [0.6%, 0] -> [0.6%, 0.6%] -> [0, 0.6%] indexed by minutes % 4
    // On MIP or when Awake, returns [0, 0].
    public function computeBurnInOffset(
        width as Number,
        height as Number,
        minute as Number,
        requiresBurnInProtection as Boolean,
        isAwake as Boolean
    ) as Array<Number> {
        if (!requiresBurnInProtection || isAwake) {
            return [0, 0];
        }
        var step = minute % 4;
        if (step < 0) {
            step += 4;
        }
        var shiftX = ((width * 6) + 500) / 1000;
        var shiftY = ((height * 6) + 500) / 1000;
        if (step == 1) {
            return [shiftX, 0];
        } else if (step == 2) {
            return [shiftX, shiftY];
        } else if (step == 3) {
            return [0, shiftY];
        }
        return [0, 0];
    }

    // Returns [fgColor, dimColor, trackColor, accentColor, warnColor]
    public function resolvePalette(
        requiresBurnInProtection as Boolean,
        isAwake as Boolean,
        battery as Number?,
        autoBatterySaver as Boolean
    ) as Array<Number> {
        var lowPowerShedding = isLowPowerShedding(battery, autoBatterySaver);

        if (!requiresBurnInProtection) {
            // MIP 64-color palette stays steady between Active and Sleep modes
            // unless Auto Battery Saver <20% is active in Active mode
            if (lowPowerShedding && isAwake) {
                return [0xAAAAAA, 0xAAAAAA, 0x555555, 0xAAAAAA, 0xFFAA00];
            }
            return [0xFFFFFF, 0xAAAAAA, 0x555555, 0x00AAFF, 0xFFAA00];
        }

        // AMOLED Ambient sleep mode: dimmed greys, no bright accent or amber
        if (!isAwake) {
            return [0xBFC2C7, 0x8E9299, 0x22262C, 0xBFC2C7, 0xBFC2C7];
        }

        // AMOLED Active mode with <20% Auto Battery Saver: dimmed grey palette + warn amber
        if (lowPowerShedding) {
            return [0xBFC2C7, 0x8E9299, 0x22262C, 0xBFC2C7, 0xF5A623];
        }

        // AMOLED Active mode normal
        return [0xF5F7FA, 0x8E9299, 0x22262C, 0x3B9EFF, 0xF5A623];
    }

    public function shouldRenderSlots(
        isAwake as Boolean,
        timeOnlyAmbient as Boolean,
        battery as Number?,
        autoBatterySaver as Boolean
    ) as Boolean {
        if (isAwake) {
            return true;
        }
        if (timeOnlyAmbient || isLowPowerShedding(battery, autoBatterySaver)) {
            return false;
        }
        return true;
    }

    public function hasSlotType(slot1 as Number, slot2 as Number, slot3 as Number, targetType as Number) as Boolean {
        return (slot1 == targetType) || (slot2 == targetType) || (slot3 == targetType);
    }

    public function shouldPollHeartRate(
        hasHrSlot as Boolean,
        isAwake as Boolean,
        justWoke as Boolean,
        minuteChanged as Boolean,
        profile as Number,
        battery as Number?,
        autoBatterySaver as Boolean
    ) as Boolean {
        if (!isAwake || !hasHrSlot || isLowPowerShedding(battery, autoBatterySaver)) {
            return false;
        }
        if (profile == PROFILE_LIVE_ACTIVE) {
            return true;
        }
        return justWoke || minuteChanged;
    }

    public function shouldPollStepsOrBattery(
        hasTargetSlot as Boolean,
        isAwake as Boolean,
        justWoke as Boolean,
        minuteChanged as Boolean,
        profile as Number,
        elapsedMinutes as Number
    ) as Boolean {
        if (!hasTargetSlot) {
            return false;
        }
        if (!isAwake && (profile == PROFILE_MAX_SAVER)) {
            return false;
        }
        if (isAwake) {
            return justWoke || (minuteChanged && (elapsedMinutes >= 1));
        }
        return minuteChanged && (elapsedMinutes >= 5);
    }

    public function shouldPollWeather(
        hasWeatherSlot as Boolean,
        isAwake as Boolean,
        justWoke as Boolean,
        minuteChanged as Boolean,
        profile as Number,
        elapsedMinutes as Number,
        battery as Number?,
        autoBatterySaver as Boolean
    ) as Boolean {
        if (!hasWeatherSlot || isLowPowerShedding(battery, autoBatterySaver)) {
            return false;
        }
        if (!isAwake && (profile == PROFILE_MAX_SAVER)) {
            return false;
        }
        var thresholdMins = (profile == PROFILE_LIVE_ACTIVE) ? 5 : 15;
        if (isAwake && justWoke && (elapsedMinutes >= thresholdMins)) {
            return true;
        }
        return minuteChanged && (elapsedMinutes >= thresholdMins);
    }
}
