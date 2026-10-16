import Toybox.Activity;
import Toybox.ActivityMonitor;
import Toybox.Application;
import Toybox.Application.Properties;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Weather;

class MinimalChargeView extends WatchUi.WatchFace {
    private var _timeFont as FontResource?;
    private var _labelFont as FontDefinition or VectorFont = Graphics.FONT_XTINY;
    private var _valueFont as FontDefinition or VectorFont = Graphics.FONT_XTINY;
    private var _isAwake as Boolean = true;
    private var _justWoke as Boolean = true;
    private var _requiresBurnIn as Boolean = false;
    private var _isRound as Boolean = true;

    // Settings
    private var _slot1 as Number = 1;
    private var _slot2 as Number = 2;
    private var _slot3 as Number = 3;
    private var _refreshProfile as Number = 0;
    private var _timeOnlyAmbient as Boolean = false;
    private var _autoBatterySaver as Boolean = true;

    // Cached time state to avoid recomputing when minute has not changed
    private var _cachedHour as Number = -1;
    private var _cachedMin as Number = -1;
    private var _cachedIs24Hour as Boolean = true;
    private var _hourStr as String = "00";
    private var _minStr as String = "00";
    private var _timeCoords as Array<Number> = [0, 0, 0];

    // Cached sensor & firmware readings + pre-formatted slot strings
    private var _cachedBattery as Number? = null;
    private var _cachedBatteryStr as String = "—";
    private var _cachedBatteryRatio as Float = 0.0f;
    private var _cachedStepGoal as Number = 10000;
    private var _cachedStepsStr as String = "—";
    private var _cachedStepsRatio as Float = 0.0f;
    private var _cachedHrStr as String = "—";
    private var _cachedWeatherCond as Number? = null;
    private var _cachedWeatherTempC as Numeric? = null;
    private var _cachedWeatherLabel as String = "WEATHER";
    private var _cachedWeatherTempStr as String = "—";
    private var _cachedWeekday as String = "DATE";
    private var _cachedDateVal as String = "—";

    // Elapsed minutes since last refresh
    private var _stepsElapsedMins as Number = 999;
    private var _batteryElapsedMins as Number = 999;
    private var _weatherElapsedMins as Number = 999;

    public function initialize() {
        WatchFace.initialize();
        var devSettings = System.getDeviceSettings();
        if (devSettings has :requiresBurnInProtection) {
            _requiresBurnIn = devSettings.requiresBurnInProtection;
        }
        _isRound = (devSettings.screenShape == System.SCREEN_SHAPE_ROUND);
        loadSettings();
    }

    public function loadSettings() as Void {
        _slot1 = getPropValue("Slot1", 1) as Number;
        _slot2 = getPropValue("Slot2", 2) as Number;
        _slot3 = getPropValue("Slot3", 3) as Number;
        _refreshProfile = getPropValue("DataRefreshProfile", 0) as Number;
        _timeOnlyAmbient = getPropValue("TimeOnlyAmbient", false) as Boolean;
        _autoBatterySaver = getPropValue("AutoBatterySaver", true) as Boolean;
        _cachedHour = -1;
        _stepsElapsedMins = 999;
        _batteryElapsedMins = 999;
        _weatherElapsedMins = 999;
        _justWoke = true;
    }

    private function getPropValue(key as String, fallback as Number or Boolean) as Number or Boolean {
        try {
            if (Application has :Properties) {
                var val = Properties.getValue(key);
                if ((fallback instanceof Boolean) && (val instanceof Boolean)) {
                    return val;
                }
                if ((fallback instanceof Number) && (val instanceof Number)) {
                    return val;
                }
            }
        } catch (e) {
        }
        return fallback;
    }

    public function onLayout(dc as Dc) as Void {
        _timeFont = WatchUi.loadResource($.Rez.Fonts.TimeFont) as FontResource;
        var width = dc.getWidth();
        var height = dc.getHeight();
        _labelFont = Graphics.FONT_XTINY;
        _valueFont = Graphics.FONT_XTINY;

        if (Graphics has :getVectorFont) {
            var labelSize = ((width * 36) + 500) / 1000;
            var valueSize = ((width * 50) + 500) / 1000;
            var vfLabel = Graphics.getVectorFont({
                :face => ["RobotoRegular", "RobotoCondensedRegular", "BionicMedium"],
                :size => labelSize
            });
            var vfValue = Graphics.getVectorFont({
                :face => ["RobotoRegular", "RobotoCondensedRegular", "BionicMedium"],
                :size => valueSize
            });
            if (vfLabel != null) {
                _labelFont = vfLabel;
            }
            if (vfValue != null) {
                _valueFont = vfValue;
            }
        } else {
            var tinyAscent = Graphics.getFontAscent(Graphics.FONT_TINY);
            if (tinyAscent <= ((height * 65) / 1000)) {
                _valueFont = Graphics.FONT_TINY;
            }
        }
        _cachedHour = -1;
    }

    public function onEnterSleep() as Void {
        _isAwake = false;
        _justWoke = false;
        _cachedHour = -1;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _isAwake = true;
        _justWoke = true;
        _cachedHour = -1;
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var devSettings = System.getDeviceSettings();
        var is24Hour = devSettings.is24Hour;
        var clockTime = System.getClockTime();

        var minuteChanged = MinimalChargeState.shouldRecomputeTime(
            _cachedHour,
            _cachedMin,
            _cachedIs24Hour,
            clockTime.hour,
            clockTime.min,
            is24Hour
        );

        if (minuteChanged) {
            _hourStr = MinimalChargeFormatter.formatHour(clockTime.hour, is24Hour);
            _minStr = MinimalChargeFormatter.formatTwoDigits(clockTime.min);
            _cachedHour = clockTime.hour;
            _cachedMin = clockTime.min;
            _cachedIs24Hour = is24Hour;
            _stepsElapsedMins += 1;
            _batteryElapsedMins += 1;
            _weatherElapsedMins += 1;
            updateDateCache();
        }

        var burnIn = MinimalChargeState.computeBurnInOffset(width, height, clockTime.min, _requiresBurnIn, _isAwake);
        var dx = burnIn[0];
        var dy = burnIn[1];

        if (minuteChanged || !_isAwake || _justWoke) {
            _timeCoords = MinimalChargeLayout.computeTimeCoords(width, height, _isRound, dx, dy);
        }

        var useF = (devSettings.temperatureUnits == System.UNIT_STATUTE);
        refreshDataCaches(minuteChanged, useF);
        _justWoke = false;

        var palette = MinimalChargeState.resolvePalette(_requiresBurnIn, _isAwake, _cachedBattery, _autoBatterySaver);
        var fgColor = palette[0];

        // Pure black (#000000) ground
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Draw stacked hour over minute in pre-baked JetBrains Mono Light 300 bitmap font
        var loadedFont = _timeFont;
        if (loadedFont != null) {
            var justify = _isRound ? Graphics.TEXT_JUSTIFY_CENTER : Graphics.TEXT_JUSTIFY_LEFT;
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_timeCoords[0], _timeCoords[1], loadedFont, _hourStr, justify);
            dc.drawText(_timeCoords[0], _timeCoords[2], loadedFont, _minStr, justify);
        }

        // Draw 3 data slots unless Time-Only Ambient or <20% Auto Battery Saver sleep hides them
        if (MinimalChargeState.shouldRenderSlots(_isAwake, _timeOnlyAmbient, _cachedBattery, _autoBatterySaver)) {
            drawAllSlots(dc, width, height, dx, dy, palette);
        }
    }

    private function updateDateCache() as Void {
        if (!MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_DATE)) {
            return;
        }
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        _cachedWeekday = info.day_of_week.toString().toUpper();
        _cachedDateVal = info.day.toString() + " " + info.month.toString();
    }

    private function refreshDataCaches(minuteChanged as Boolean, useFahrenheit as Boolean) as Void {
        var hasBatterySlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_BATTERY);
        var hasStepsSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_STEPS);
        var hasHrSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_HEART_RATE);
        var hasWeatherSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_WEATHER);

        // Battery polling respects shouldPollStepsOrBattery (zero calls in sleep under Max Battery Saver)
        var needBatteryCheck = hasBatterySlot || _autoBatterySaver;
        if (MinimalChargeState.shouldPollStepsOrBattery(
            needBatteryCheck, _isAwake, _justWoke, minuteChanged, _refreshProfile, _batteryElapsedMins
        )) {
            var stats = System.getSystemStats();
            if (stats != null) {
                var batFloat = stats.battery;
                if (batFloat != null) {
                    var batInt = (batFloat + 0.5f).toNumber();
                    _cachedBattery = batInt;
                    _cachedBatteryStr = MinimalChargeFormatter.formatBattery(batInt);
                    _cachedBatteryRatio = MinimalChargeState.clampBarRatio(batInt, 100);
                    _batteryElapsedMins = 0;
                }
            }
        }

        if (MinimalChargeState.shouldPollStepsOrBattery(
            hasStepsSlot, _isAwake, _justWoke, minuteChanged, _refreshProfile, _stepsElapsedMins
        )) {
            if (Toybox has :ActivityMonitor) {
                var monInfo = ActivityMonitor.getInfo();
                if (monInfo != null) {
                    var steps = monInfo.steps;
                    var goal = monInfo.stepGoal;
                    if (goal != null && goal > 0) {
                        _cachedStepGoal = goal;
                    }
                    _cachedStepsStr = MinimalChargeFormatter.formatSteps(steps);
                    _cachedStepsRatio = MinimalChargeState.clampBarRatio(steps, _cachedStepGoal);
                    _stepsElapsedMins = 0;
                }
            }
        }

        if (MinimalChargeState.shouldPollHeartRate(
            hasHrSlot, _isAwake, _justWoke, minuteChanged, _refreshProfile, _cachedBattery, _autoBatterySaver
        )) {
            var hr = null;
            var actInfo = Activity.getActivityInfo();
            if (actInfo != null && actInfo.currentHeartRate != null) {
                hr = actInfo.currentHeartRate;
            } else if ((Toybox has :ActivityMonitor) && (ActivityMonitor has :getHeartRateHistory)) {
                var iter = ActivityMonitor.getHeartRateHistory(1, true);
                if (iter != null) {
                    var sample = iter.next();
                    if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        hr = sample.heartRate;
                    }
                }
            }
            _cachedHrStr = MinimalChargeFormatter.formatHeartRate(hr);
        }

        if (MinimalChargeState.shouldPollWeather(
            hasWeatherSlot, _isAwake, _justWoke, minuteChanged, _refreshProfile, _weatherElapsedMins, _cachedBattery, _autoBatterySaver
        )) {
            if (Toybox has :Weather) {
                var cond = Weather.getCurrentConditions();
                if (cond != null) {
                    _cachedWeatherCond = cond.condition;
                    _cachedWeatherTempC = cond.temperature;
                } else {
                    _cachedWeatherCond = null;
                    _cachedWeatherTempC = null;
                }
                if (_cachedWeatherCond == null && _cachedWeatherTempC == null) {
                    _cachedWeatherLabel = "WEATHER";
                    _cachedWeatherTempStr = "—";
                } else {
                    _cachedWeatherLabel = MinimalChargeFormatter.mapWeatherCondition(_cachedWeatherCond);
                    _cachedWeatherTempStr = MinimalChargeFormatter.formatTemperature(_cachedWeatherTempC, useFahrenheit);
                }
                _weatherElapsedMins = 0;
            }
        }
    }

    private function drawAllSlots(
        dc as Dc,
        width as Number,
        height as Number,
        dx as Number,
        dy as Number,
        palette as Array<Number>
    ) as Void {
        var slot1Active = (_slot1 != MinimalChargeState.SLOT_OFF);
        var slot2Active = (_slot2 != MinimalChargeState.SLOT_OFF);
        var slot3Active = (_slot3 != MinimalChargeState.SLOT_OFF);

        if (_isRound) {
            if (slot1Active) {
                var topY = ((height * 5) + 50) / 100 + dy;
                drawSingleSlot(dc, width, (width / 2) + dx, topY, false, Graphics.TEXT_JUSTIFY_CENTER, _slot1, palette);
            }
            // Round Slots 2 & 3 are bottom-anchored at bottom: 8% (92% of dial height)
            var bottomAnchorY = height - (((height * 8) + 50) / 100) + dy;
            if (slot2Active) {
                var x2 = MinimalChargeLayout.computeRoundBottomSlotX(width, 2, slot2Active, slot3Active) + dx;
                drawSingleSlot(dc, width, x2, bottomAnchorY, true, Graphics.TEXT_JUSTIFY_CENTER, _slot2, palette);
            }
            if (slot3Active) {
                var x3 = MinimalChargeLayout.computeRoundBottomSlotX(width, 3, slot2Active, slot3Active) + dx;
                drawSingleSlot(dc, width, x3, bottomAnchorY, true, Graphics.TEXT_JUSTIFY_CENTER, _slot3, palette);
            }
        } else {
            var leftX = ((width * 62) + 50) / 100 + dx;
            if (slot1Active) {
                var y1 = MinimalChargeLayout.computeSquareSlotY(height, 0, slot1Active, slot2Active, slot3Active) + dy;
                drawSingleSlot(dc, width, leftX, y1, false, Graphics.TEXT_JUSTIFY_LEFT, _slot1, palette);
            }
            if (slot2Active) {
                var y2 = MinimalChargeLayout.computeSquareSlotY(height, 1, slot1Active, slot2Active, slot3Active) + dy;
                drawSingleSlot(dc, width, leftX, y2, false, Graphics.TEXT_JUSTIFY_LEFT, _slot2, palette);
            }
            if (slot3Active) {
                var y3 = MinimalChargeLayout.computeSquareSlotY(height, 2, slot1Active, slot2Active, slot3Active) + dy;
                drawSingleSlot(dc, width, leftX, y3, false, Graphics.TEXT_JUSTIFY_LEFT, _slot3, palette);
            }
        }
    }

    private function drawSingleSlot(
        dc as Dc,
        width as Number,
        x as Number,
        anchorY as Number,
        alignBottom as Boolean,
        justify as TextJustification,
        slotType as Number,
        palette as Array<Number>
    ) as Void {
        var fgColor = palette[0];
        var dimColor = palette[1];
        var trackColor = palette[2];
        var accentColor = palette[3];
        var warnColor = palette[4];
        var label = "";
        var value = "—";
        var hasBar = false;
        var barRatio = 0.0f;
        var valueColor = fgColor;
        var barColor = fgColor;
        var bat = _cachedBattery;
        var lowPowerShedding = MinimalChargeState.isLowPowerShedding(bat, _autoBatterySaver);

        if (slotType == MinimalChargeState.SLOT_DATE) {
            label = _cachedWeekday;
            value = _cachedDateVal;
        } else if (slotType == MinimalChargeState.SLOT_STEPS) {
            label = "STEPS";
            value = _cachedStepsStr;
            hasBar = true;
            barRatio = _cachedStepsRatio;
            barColor = accentColor;
        } else if (slotType == MinimalChargeState.SLOT_BATTERY) {
            label = "BATTERY";
            value = _cachedBatteryStr;
            hasBar = true;
            barRatio = _cachedBatteryRatio;
            if (bat != null && bat < 20) {
                valueColor = warnColor;
                barColor = warnColor;
            }
        } else if (slotType == MinimalChargeState.SLOT_HEART_RATE) {
            label = "HR";
            value = lowPowerShedding ? "—" : _cachedHrStr;
        } else if (slotType == MinimalChargeState.SLOT_WEATHER) {
            label = lowPowerShedding ? "WEATHER" : _cachedWeatherLabel;
            value = lowPowerShedding ? "—" : _cachedWeatherTempStr;
        } else {
            return;
        }

        var labelFont = _labelFont;
        var valueFont = _valueFont;
        var labelAscent = Graphics.getFontAscent(labelFont);
        var valueAscent = Graphics.getFontAscent(valueFont);
        var labelCapH = ((labelAscent * 72) + 50) / 100;
        var valueCapH = ((valueAscent * 72) + 50) / 100;
        var labelTopPad = labelAscent - labelCapH;
        var valueTopPad = valueAscent - valueCapH;

        var gapLabelVal = (width >= 320) ? 4 : 2;
        var gapValBar = (width >= 320) ? 5 : 3;
        var visTotalH = labelCapH + gapLabelVal + valueCapH + (hasBar ? (gapValBar + 3) : 0);
        var visTopY = alignBottom ? (anchorY - visTotalH) : anchorY;

        var labelDrawY = visTopY - labelTopPad;
        dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, labelDrawY, labelFont, label, justify);

        var visValTopY = visTopY + labelCapH + gapLabelVal;
        var valDrawY = visValTopY - valueTopPad;
        dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, valDrawY, valueFont, value, justify);

        if (hasBar) {
            var barW = MinimalChargeLayout.computeBarWidth(width, _isRound);
            var barX = (justify == Graphics.TEXT_JUSTIFY_CENTER) ? (x - (barW / 2)) : x;
            var barY = visValTopY + valueCapH + gapValBar;

            dc.setColor(trackColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(barX, barY, barW, 3);

            var fillW = (barW.toFloat() * barRatio + 0.5f).toNumber();
            if (fillW > 0) {
                dc.setColor(barColor, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(barX, barY, fillW, 3);
            }
        }
    }
}
