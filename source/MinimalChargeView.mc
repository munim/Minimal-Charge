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
    private var _timeOutlineFont as FontResource?;
    private var _labelFont as FontDefinition or VectorFont = Graphics.FONT_XTINY;
    private var _valueFont as FontDefinition or VectorFont = Graphics.FONT_XTINY;
    private var _isAwake as Boolean = true;
    private var _justWoke as Boolean = true;
    private var _requiresBurnIn as Boolean = false;
    private var _isRound as Boolean = true;
    private var _hasFullDraw as Boolean = false;
    private var _prevLowPowerShedding as Boolean = false;

    // Settings
    private var _slot1 as Number = 1;
    private var _slot2 as Number = 2;
    private var _slot3 as Number = 3;
    private var _refreshProfile as Number = 0;
    private var _timeOnlyAmbient as Boolean = false;
    private var _autoBatterySaver as Boolean = true;
    private var _ambientBrightness as Number = 0;

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
        _ambientBrightness = getPropValue("AmbientBrightness", 0) as Number;
        _cachedHour = -1;
        _stepsElapsedMins = 999;
        _batteryElapsedMins = 999;
        _weatherElapsedMins = 999;
        _justWoke = true;
        _hasFullDraw = false;
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
        if (_requiresBurnIn) {
            _timeOutlineFont = WatchUi.loadResource($.Rez.Fonts.TimeOutlineFont) as FontResource;
        }
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
        _hasFullDraw = false;
    }

    public function onEnterSleep() as Void {
        _isAwake = false;
        _justWoke = false;
        _cachedHour = -1;
        _hasFullDraw = false;
        WatchUi.requestUpdate();
    }

    public function onExitSleep() as Void {
        _isAwake = true;
        _justWoke = true;
        _cachedHour = -1;
        _hasFullDraw = false;
        WatchUi.requestUpdate();
    }

    public function onUpdate(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var devSettings = System.getDeviceSettings();
        var is24Hour = devSettings.is24Hour;
        var clockTime = System.getClockTime();

        var hourChanged = (_cachedHour < 0) || (_cachedHour != clockTime.hour) || (_cachedIs24Hour != is24Hour);
        var minuteChanged = MinimalChargeState.shouldRecomputeTime(
            _cachedHour,
            _cachedMin,
            _cachedIs24Hour,
            clockTime.hour,
            clockTime.min,
            is24Hour
        );

        var dateRefreshed = false;
        if (minuteChanged) {
            _hourStr = MinimalChargeFormatter.formatHour(clockTime.hour, is24Hour);
            _minStr = MinimalChargeFormatter.formatTwoDigits(clockTime.min);
            _cachedHour = clockTime.hour;
            _cachedMin = clockTime.min;
            _cachedIs24Hour = is24Hour;
            _stepsElapsedMins += 1;
            _batteryElapsedMins += 1;
            _weatherElapsedMins += 1;
            dateRefreshed = updateDateCache();
        }

        var burnIn = MinimalChargeState.computeBurnInOffset(width, height, clockTime.min, _requiresBurnIn, _isAwake);
        var dx = burnIn[0];
        var dy = burnIn[1];

        if (minuteChanged || !_isAwake || _justWoke) {
            _timeCoords = MinimalChargeLayout.computeTimeCoords(width, height, _isRound, dx, dy);
        }

        var useF = (devSettings.temperatureUnits == System.UNIT_STATUTE);
        var dataRefreshed = refreshDataCaches(minuteChanged, useF);
        var anySlotRefreshed = dateRefreshed || dataRefreshed;

        var nowShedding = MinimalChargeState.isLowPowerShedding(_cachedBattery, _autoBatterySaver);
        var sheddingChanged = (nowShedding != _prevLowPowerShedding);
        _prevLowPowerShedding = nowShedding;

        var mipMinuteClip = MinimalChargeState.canUseMipMinuteClip(
            _requiresBurnIn,
            _hasFullDraw,
            _justWoke,
            minuteChanged,
            hourChanged,
            anySlotRefreshed,
            sheddingChanged
        );
        _justWoke = false;

        var palette = MinimalChargeState.resolvePaletteWithBrightness(
            _requiresBurnIn,
            _isAwake,
            _cachedBattery,
            _autoBatterySaver,
            _ambientBrightness
        );
        var fgColor = palette[0];
        var justify = _isRound ? Graphics.TEXT_JUSTIFY_CENTER : Graphics.TEXT_JUSTIFY_LEFT;
        var useOutline = MinimalChargeState.shouldUseOutlineTimeFont(_requiresBurnIn, _isAwake);
        var activeTimeFont = (useOutline && _timeOutlineFont != null) ? _timeOutlineFont : _timeFont;

        if (mipMinuteClip && (dc has :setClip)) {
            var clipRect = MinimalChargeLayout.computeMinuteClipRect(width, height, _isRound);
            dc.setClip(clipRect[0], clipRect[1], clipRect[2], clipRect[3]);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
            dc.clear();
            if (activeTimeFont != null) {
                dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
                dc.drawText(_timeCoords[0], _timeCoords[2], activeTimeFont, _minStr, justify);
            }
            return;
        }

        if (dc has :clearClip) {
            dc.clearClip();
        }

        // Pure black (#000000) ground
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        // Draw stacked hour over minute in pre-baked JetBrains Mono (Light 300 awake/MIP, Bold Outline AMOLED sleep)
        if (activeTimeFont != null) {
            dc.setColor(fgColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(_timeCoords[0], _timeCoords[1], activeTimeFont, _hourStr, justify);
            dc.drawText(_timeCoords[0], _timeCoords[2], activeTimeFont, _minStr, justify);
        }

        // Draw 3 data slots unless Time-Only Ambient or <20% Auto Battery Saver sleep hides them
        if (MinimalChargeState.shouldRenderSlots(_isAwake, _timeOnlyAmbient, _cachedBattery, _autoBatterySaver)) {
            drawAllSlots(dc, width, height, dx, dy, palette);
        }
        _hasFullDraw = true;
    }

    private function updateDateCache() as Boolean {
        if (!MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_DATE)) {
            return false;
        }
        var info = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var nextWeekday = info.day_of_week.toString().toUpper();
        var nextDateVal = info.day.toString() + " " + info.month.toString();
        var changed = !nextWeekday.equals(_cachedWeekday) || !nextDateVal.equals(_cachedDateVal);
        _cachedWeekday = nextWeekday;
        _cachedDateVal = nextDateVal;
        return changed;
    }

    private function refreshDataCaches(minuteChanged as Boolean, useFahrenheit as Boolean) as Boolean {
        var hasBatterySlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_BATTERY);
        var hasStepsSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_STEPS);
        var hasHrSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_HEART_RATE);
        var hasWeatherSlot = MinimalChargeState.hasSlotType(_slot1, _slot2, _slot3, MinimalChargeState.SLOT_WEATHER);
        var refreshedSlot = false;

        // Battery polling throttles to 30m in sleep when >30% or when no battery slot is visible
        if (MinimalChargeState.shouldPollBattery(
            hasBatterySlot, _autoBatterySaver, _isAwake, _justWoke, minuteChanged, _refreshProfile, _batteryElapsedMins, _cachedBattery
        )) {
            var stats = System.getSystemStats();
            if (stats != null) {
                var batFloat = stats.battery;
                if (batFloat != null) {
                    var batInt = (batFloat + 0.5f).toNumber();
                    if (hasBatterySlot && (_cachedBattery == null || _cachedBattery != batInt)) {
                        refreshedSlot = true;
                    }
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
                    var nextStepsStr = MinimalChargeFormatter.formatSteps(steps);
                    if (!nextStepsStr.equals(_cachedStepsStr)) {
                        refreshedSlot = true;
                    }
                    _cachedStepsStr = nextStepsStr;
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
            } else if (
                MinimalChargeState.shouldFallbackHeartRateHistory(_justWoke) &&
                (Toybox has :ActivityMonitor) &&
                (ActivityMonitor has :getHeartRateHistory)
            ) {
                var iter = ActivityMonitor.getHeartRateHistory(1, true);
                if (iter != null) {
                    var sample = iter.next();
                    if (sample != null && sample.heartRate != ActivityMonitor.INVALID_HR_SAMPLE) {
                        hr = sample.heartRate;
                    }
                }
            }
            var nextHrStr = MinimalChargeFormatter.formatHeartRate(hr);
            if (!nextHrStr.equals(_cachedHrStr)) {
                refreshedSlot = true;
            }
            _cachedHrStr = nextHrStr;
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
                var nextWeatherLabel = "WEATHER";
                var nextWeatherTemp = "—";
                if (_cachedWeatherCond != null || _cachedWeatherTempC != null) {
                    nextWeatherLabel = MinimalChargeFormatter.mapWeatherCondition(_cachedWeatherCond);
                    nextWeatherTemp = MinimalChargeFormatter.formatTemperature(_cachedWeatherTempC, useFahrenheit);
                }
                if (!nextWeatherLabel.equals(_cachedWeatherLabel) || !nextWeatherTemp.equals(_cachedWeatherTempStr)) {
                    refreshedSlot = true;
                }
                _cachedWeatherLabel = nextWeatherLabel;
                _cachedWeatherTempStr = nextWeatherTemp;
                _weatherElapsedMins = 0;
            }
        }
        return refreshedSlot;
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
        var iconType = 0; // 0 = none, 1 = steps, 2 = battery
        var hasBar = false;
        var barRatio = 0.0f;
        var valueColor = fgColor;
        var barColor = fgColor;
        var iconColor = dimColor;
        var bat = _cachedBattery;
        var lowPowerShedding = MinimalChargeState.isLowPowerShedding(bat, _autoBatterySaver);

        if (slotType == MinimalChargeState.SLOT_DATE) {
            label = _cachedWeekday;
            value = _cachedDateVal;
        } else if (slotType == MinimalChargeState.SLOT_STEPS) {
            iconType = 1;
            value = _cachedStepsStr;
            hasBar = true;
            barRatio = _cachedStepsRatio;
            barColor = accentColor;
        } else if (slotType == MinimalChargeState.SLOT_BATTERY) {
            iconType = 2;
            value = _cachedBatteryStr;
            hasBar = true;
            barRatio = _cachedBatteryRatio;
            if (bat != null && bat < 20) {
                valueColor = warnColor;
                barColor = warnColor;
                iconColor = warnColor;
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

        var gapLabelVal = ((width * 22) + 500) / 1000;
        if (gapLabelVal < 6) {
            gapLabelVal = 6;
        }
        var gapValBar = ((width * 24) + 500) / 1000;
        if (gapValBar < 6) {
            gapValBar = 6;
        }

        var hasIcon = (iconType != 0);
        var visTotalH = (hasIcon ? valueCapH : (labelCapH + gapLabelVal + valueCapH)) + (hasBar ? (gapValBar + 3) : 0);
        var visTopY = alignBottom ? (anchorY - visTotalH) : anchorY;

        var visValTopY = visTopY;
        if (!hasIcon) {
            var labelDrawY = visTopY - labelTopPad;
            dc.setColor(dimColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, labelDrawY, labelFont, label, justify);
            visValTopY = visTopY + labelCapH + gapLabelVal;
        }

        var valDrawY = visValTopY - valueTopPad;
        if (hasIcon) {
            var iconW = getSlotIconWidth(width, valueCapH, iconType);
            var iconGap = ((width * 14) + 500) / 1000;
            if (iconGap < 4) {
                iconGap = 4;
            }
            var textW = dc.getTextWidthInPixels(value, valueFont);
            var totalRowW = iconW + iconGap + textW;
            var rowStartX = (justify == Graphics.TEXT_JUSTIFY_CENTER) ? (x - (totalRowW / 2)) : x;

            drawSlotIcon(dc, width, rowStartX, visValTopY, valueCapH, iconType, iconColor, barRatio);
            dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(rowStartX + iconW + iconGap, valDrawY, valueFont, value, Graphics.TEXT_JUSTIFY_LEFT);
        } else {
            dc.setColor(valueColor, Graphics.COLOR_TRANSPARENT);
            dc.drawText(x, valDrawY, valueFont, value, justify);
        }

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

    private function getSlotIconWidth(width as Number, valueCapH as Number, iconType as Number) as Number {
        if (iconType == 1) {
            var footW = ((width * 13) + 500) / 1000;
            if (footW < 4) {
                footW = 4;
            }
            var footGap = (width >= 320) ? 3 : 2;
            return (footW * 2) + footGap;
        }
        var batH = ((valueCapH * 68) + 50) / 100;
        if (batH < 7) {
            batH = 7;
        }
        var bodyW = ((batH * 155) + 50) / 100;
        var nubW = (width >= 320) ? 2 : 1;
        return bodyW + nubW;
    }

    private function drawSlotIcon(
        dc as Dc,
        width as Number,
        iconX as Number,
        valTopY as Number,
        valueCapH as Number,
        iconType as Number,
        iconColor as Number,
        barRatio as Float
    ) as Void {
        if (iconType == 1) {
            var footW = ((width * 13) + 500) / 1000;
            if (footW < 4) {
                footW = 4;
            }
            var footGap = (width >= 320) ? 3 : 2;
            var footH = ((valueCapH * 78) + 50) / 100;
            if (footH < 8) {
                footH = 8;
            }
            var stagger = valueCapH - footH;
            if (stagger < 2) {
                stagger = 2;
            }
            var radius = footW / 2;
            var archGap = (width >= 320) ? 2 : 1;
            var leftY = valTopY + stagger;
            var rightY = valTopY;
            var rightX = iconX + footW + footGap;

            dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRoundedRectangle(iconX, leftY, footW, footH, radius);
            dc.fillRoundedRectangle(rightX, rightY, footW, footH, radius);

            var archOffset = ((footH * 58) + 50) / 100;
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(iconX, leftY + archOffset, footW, archGap);
            dc.fillRectangle(rightX, rightY + archOffset, footW, archGap);
            return;
        }

        // Battery icon
        var batH = ((valueCapH * 68) + 50) / 100;
        if (batH < 7) {
            batH = 7;
        }
        var bodyW = ((batH * 155) + 50) / 100;
        var nubW = (width >= 320) ? 2 : 1;
        var nubH = ((batH * 46) + 50) / 100;
        if (nubH < 3) {
            nubH = 3;
        }
        var stroke = (width >= 360) ? 2 : 1;
        var batY = valTopY + ((valueCapH - batH) / 2);

        dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(iconX, batY, bodyW, batH);
        dc.fillRectangle(iconX + bodyW, batY + ((batH - nubH) / 2), nubW, nubH);

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(iconX + stroke, batY + stroke, bodyW - (stroke * 2), batH - (stroke * 2));

        var innerPad = stroke + 1;
        var maxFillW = bodyW - (innerPad * 2);
        var innerH = batH - (innerPad * 2);
        var fillW = (maxFillW.toFloat() * barRatio + 0.5f).toNumber();
        if (fillW > 0 && innerH > 0) {
            dc.setColor(iconColor, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(iconX + innerPad, batY + innerPad, fillW, innerH);
        }
    }
}
