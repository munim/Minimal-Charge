import Toybox.Lang;
import Toybox.Test;

(:test)
function testSeam1TimeFormattingAndCacheGuard(logger as Test.Logger) as Boolean {
    // 24h zero-padded
    Test.assertEqual("00", MinimalChargeFormatter.formatHour(0, true));
    Test.assertEqual("08", MinimalChargeFormatter.formatHour(8, true));
    Test.assertEqual("13", MinimalChargeFormatter.formatHour(13, true));
    Test.assertEqual("05", MinimalChargeFormatter.formatTwoDigits(5));

    // 12h zero-padded (01..12, no AM/PM)
    Test.assertEqual("12", MinimalChargeFormatter.formatHour(0, false));
    Test.assertEqual("08", MinimalChargeFormatter.formatHour(8, false));
    Test.assertEqual("12", MinimalChargeFormatter.formatHour(12, false));
    Test.assertEqual("01", MinimalChargeFormatter.formatHour(13, false));
    Test.assertEqual("11", MinimalChargeFormatter.formatHour(23, false));

    // Minute-change cache guard
    Test.assertEqual(false, MinimalChargeState.shouldRecomputeTime(11, 58, true, 11, 58, true));
    Test.assertEqual(true, MinimalChargeState.shouldRecomputeTime(11, 58, true, 11, 59, true));
    Test.assertEqual(true, MinimalChargeState.shouldRecomputeTime(-1, -1, true, 11, 58, true));
    return true;
}

(:test)
function testSeam1TimeAndSlotGeometry(logger as Test.Logger) as Boolean {
    // Round 454x454 time stack: 34% height, line-height 0.8, centered at 50%, y: 22.8%-77.2%
    var roundTime = MinimalChargeLayout.computeTimeCoords(454, 454, true, 0, 0);
    Test.assertEqual(227, roundTime[0]); // x = 50%
    Test.assertEqual(104, roundTime[1]); // hourY = round(454 * 0.228) = 104
    Test.assertEqual(227, roundTime[2]); // minuteY = round(454 * 0.50) = 227

    // Square 390x390 time stack: 40% height, line-height 0.8, top-left at 8%, 8%
    var squareTime = MinimalChargeLayout.computeTimeCoords(390, 390, false, 0, 0);
    Test.assertEqual(31, squareTime[0]); // x = round(390 * 0.08) = 31
    Test.assertEqual(31, squareTime[1]); // hourY = round(390 * 0.08) = 31
    Test.assertEqual(156, squareTime[2]); // minuteY = round(390 * 0.40) = 156

    // Round solo-bottom rule: when only Slot 2 is active, its X centers at 50% (227px on 454w)
    var roundDualBottom = MinimalChargeLayout.computeRoundBottomSlotX(454, 2, true, true);
    var roundSoloBottom2 = MinimalChargeLayout.computeRoundBottomSlotX(454, 2, true, false);
    var roundSoloBottom3 = MinimalChargeLayout.computeRoundBottomSlotX(454, 3, false, true);
    Test.assertEqual(168, roundDualBottom); // 37% of 454
    Test.assertEqual(227, roundSoloBottom2); // 50% of 454
    Test.assertEqual(227, roundSoloBottom3); // 50% of 454

    // Round Slot 1 bar width capped at 22% of dial width
    Test.assertEqual(100, MinimalChargeLayout.computeBarWidth(454, true));
    return true;
}

(:test)
function testSeam2BurnInPaletteAndRefreshPolicy(logger as Test.Logger) as Boolean {
    // AMOLED Ambient 4-step 0.6% burn-in pixel shift
    var shift0 = MinimalChargeState.computeBurnInOffset(454, 454, 0, true, false);
    var shift1 = MinimalChargeState.computeBurnInOffset(454, 454, 1, true, false);
    var shift2 = MinimalChargeState.computeBurnInOffset(454, 454, 2, true, false);
    var shift3 = MinimalChargeState.computeBurnInOffset(454, 454, 3, true, false);
    Test.assertEqual(0, shift0[0]);
    Test.assertEqual(0, shift0[1]);
    Test.assertEqual(3, shift1[0]);
    Test.assertEqual(0, shift1[1]);
    Test.assertEqual(3, shift2[0]);
    Test.assertEqual(3, shift2[1]);
    Test.assertEqual(0, shift3[0]);
    Test.assertEqual(3, shift3[1]);

    // MIP sleep mode skips pixel shift ([0, 0])
    var mipShift = MinimalChargeState.computeBurnInOffset(260, 260, 2, false, false);
    Test.assertEqual(0, mipShift[0]);
    Test.assertEqual(0, mipShift[1]);

    // Active mode on AMOLED restores [0, 0]
    var activeShift = MinimalChargeState.computeBurnInOffset(454, 454, 2, true, true);
    Test.assertEqual(0, activeShift[0]);
    Test.assertEqual(0, activeShift[1]);

    // Palette resolution (AMOLED vs MIP vs <20% low battery power shedding)
    var amoledActive = MinimalChargeState.resolvePalette(true, true, 76, true);
    Test.assertEqual(0xF5F7FA, amoledActive[0]); // fg
    Test.assertEqual(0x3B9EFF, amoledActive[3]); // accent
    Test.assertEqual(0xF5A623, amoledActive[4]); // warn

    var amoledAmbient = MinimalChargeState.resolvePalette(true, false, 76, true);
    Test.assertEqual(0xBFC2C7, amoledAmbient[0]); // dimmed grey fg
    Test.assertEqual(0xBFC2C7, amoledAmbient[3]); // no accent in ambient
    Test.assertEqual(0xBFC2C7, amoledAmbient[4]); // no amber in ambient

    var mipActive = MinimalChargeState.resolvePalette(false, true, 76, false);
    var mipAmbient = MinimalChargeState.resolvePalette(false, false, 76, false);
    Test.assertEqual(0xFFFFFF, mipActive[0]);
    Test.assertEqual(mipActive[0], mipAmbient[0]);
    Test.assertEqual(mipActive[3], mipAmbient[3]);

    // <20% with Auto Battery Saver On dims active fg to 0xBFC2C7 while keeping warn 0xF5A623
    var shedPalette = MinimalChargeState.resolvePalette(true, true, 14, true);
    Test.assertEqual(0xBFC2C7, shedPalette[0]);
    Test.assertEqual(0xF5A623, shedPalette[4]);

    // Time-Only Ambient & Auto Battery Saver <20% ambient slot hiding
    Test.assertEqual(true, MinimalChargeState.shouldRenderSlots(true, true, 14, true));
    Test.assertEqual(false, MinimalChargeState.shouldRenderSlots(false, true, 76, true));
    Test.assertEqual(false, MinimalChargeState.shouldRenderSlots(false, false, 14, true));
    Test.assertEqual(true, MinimalChargeState.shouldRenderSlots(false, false, 14, false));

    // Data Refresh Profiles for Steps/Battery and Weather
    // Max Battery Saver (1): zero queries in sleep mode
    Test.assertEqual(false, MinimalChargeState.shouldPollStepsOrBattery(true, false, false, true, 1, 999));
    Test.assertEqual(false, MinimalChargeState.shouldPollWeather(true, false, false, true, 1, 999, 76, true));
    // Balanced (0): Steps/Battery refresh at 5 min in sleep, 1 min in active; Weather at 15 min
    Test.assertEqual(false, MinimalChargeState.shouldPollStepsOrBattery(true, false, false, true, 0, 4));
    Test.assertEqual(true, MinimalChargeState.shouldPollStepsOrBattery(true, false, false, true, 0, 5));
    Test.assertEqual(false, MinimalChargeState.shouldPollWeather(true, false, false, true, 0, 14, 76, true));
    Test.assertEqual(true, MinimalChargeState.shouldPollWeather(true, false, false, true, 0, 15, 76, true));
    // Auto Battery Saver <20% suspends Weather polling
    Test.assertEqual(false, MinimalChargeState.shouldPollWeather(true, true, true, true, 2, 999, 14, true));
    return true;
}

(:test)
function testSeam3StepsWeatherAndSensors(logger as Test.Logger) as Boolean {
    // Steps formatting
    Test.assertEqual("0", MinimalChargeFormatter.formatSteps(0));
    Test.assertEqual("999", MinimalChargeFormatter.formatSteps(999));
    Test.assertEqual("1K", MinimalChargeFormatter.formatSteps(1000));
    Test.assertEqual("8.4K", MinimalChargeFormatter.formatSteps(8420));
    Test.assertEqual("—", MinimalChargeFormatter.formatSteps(null));

    // Weather 53+1 condition codes all <= 7 chars and single word
    for (var code = 0; code <= 53; code++) {
        var label = MinimalChargeFormatter.mapWeatherCondition(code);
        Test.assert(label.length() >= 3 && label.length() <= 7);
    }
    Test.assertEqual("CLEAR", MinimalChargeFormatter.mapWeatherCondition(0));
    Test.assertEqual("CLOUDY", MinimalChargeFormatter.mapWeatherCondition(1));
    Test.assertEqual("RAIN", MinimalChargeFormatter.mapWeatherCondition(3));
    Test.assertEqual("SHOWERS", MinimalChargeFormatter.mapWeatherCondition(25));
    Test.assertEqual("WEATHER", MinimalChargeFormatter.mapWeatherCondition(53));

    // Temperature C/F formatting
    Test.assertEqual("18°", MinimalChargeFormatter.formatTemperature(18, false));
    Test.assertEqual("64°", MinimalChargeFormatter.formatTemperature(18, true));
    Test.assertEqual("—", MinimalChargeFormatter.formatTemperature(null, false));

    // Battery & HR formatting
    Test.assertEqual("76%", MinimalChargeFormatter.formatBattery(76));
    Test.assertEqual("—", MinimalChargeFormatter.formatBattery(null));
    Test.assertEqual("72 bpm", MinimalChargeFormatter.formatHeartRate(72));
    Test.assertEqual("—", MinimalChargeFormatter.formatHeartRate(null));

    // HR query guard: never in sleep, never when no HR slot, never when <20% Auto Battery Saver active
    Test.assertEqual(false, MinimalChargeState.shouldPollHeartRate(false, true, true, false, 0, 76, true));
    Test.assertEqual(false, MinimalChargeState.shouldPollHeartRate(true, false, false, true, 0, 76, true));
    Test.assertEqual(true, MinimalChargeState.shouldPollHeartRate(true, true, true, false, 0, 76, true));
    Test.assertEqual(false, MinimalChargeState.shouldPollHeartRate(true, true, false, false, 0, 76, true)); // Balanced 1Hz tick
    Test.assertEqual(true, MinimalChargeState.shouldPollHeartRate(true, true, false, false, 2, 76, true));  // Live Active 1Hz tick
    Test.assertEqual(false, MinimalChargeState.shouldPollHeartRate(true, true, true, true, 2, 14, true));  // Suspended <20%
    return true;
}
