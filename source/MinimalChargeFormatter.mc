import Toybox.Lang;
import Toybox.Math;

module MinimalChargeFormatter {

    public function formatTwoDigits(value as Number) as String {
        var v = value;
        if (v < 0) {
            v = 0;
        }
        return (v < 10) ? ("0" + v.toString()) : v.toString();
    }

    public function formatHour(hour24 as Number, is24Hour as Boolean) as String {
        var h = hour24;
        if (!is24Hour) {
            h = hour24 % 12;
            if (h == 0) {
                h = 12;
            }
        }
        return formatTwoDigits(h);
    }

    public function formatSteps(steps as Number?) as String {
        if (steps == null) {
            return "—";
        }
        if (steps < 1000) {
            return steps.toString();
        }
        var tenths = (steps + 50) / 100;
        var whole = tenths / 10;
        var rem = tenths % 10;
        if (rem == 0) {
            return whole.toString() + "K";
        }
        return whole.toString() + "." + rem.toString() + "K";
    }

    public function formatBattery(battery as Number?) as String {
        if (battery == null) {
            return "—";
        }
        var pct = battery;
        if (pct < 0) {
            pct = 0;
        } else if (pct > 100) {
            pct = 100;
        }
        return pct.toString() + "%";
    }

    public function formatHeartRate(bpm as Number?) as String {
        if (bpm == null || bpm <= 0) {
            return "—";
        }
        return bpm.toString() + " bpm";
    }

    public function formatTemperature(tempC as Numeric?, useFahrenheit as Boolean) as String {
        if (tempC == null) {
            return "—";
        }
        var val = tempC.toFloat();
        if (useFahrenheit) {
            val = (val * 9.0f / 5.0f) + 32.0f;
        }
        var rounded = (val >= 0.0f) ? (val + 0.5f).toNumber() : (val - 0.5f).toNumber();
        return rounded.toString() + "°";
    }

    // Maps all 53 Garmin Weather.CONDITION_* enum codes (plus 53 CONDITION_UNKNOWN)
    // to concise 1-word labels <= 7 characters so labels never clip inside a 22%-wide slot.
    public function mapWeatherCondition(conditionCode as Number?) as String {
        if (conditionCode == null) {
            return "WEATHER";
        }
        switch (conditionCode) {
            case 0:  // CONDITION_CLEAR
            case 22: // CONDITION_PARTLY_CLEAR
            case 23: // CONDITION_MOSTLY_CLEAR
            case 40: // CONDITION_FAIR
                return "CLEAR";

            case 1:  // CONDITION_PARTLY_CLOUDY
            case 2:  // CONDITION_MOSTLY_CLOUDY
            case 20: // CONDITION_CLOUDY
            case 52: // CONDITION_THIN_CLOUDS
                return "CLOUDY";

            case 3:  // CONDITION_RAIN
            case 14: // CONDITION_LIGHT_RAIN
            case 15: // CONDITION_HEAVY_RAIN
            case 31: // CONDITION_DRIZZLE
            case 45: // CONDITION_CLOUDY_CHANCE_OF_RAIN
            case 49: // CONDITION_FREEZING_RAIN
                return "RAIN";

            case 4:  // CONDITION_SNOW
            case 16: // CONDITION_LIGHT_SNOW
            case 17: // CONDITION_HEAVY_SNOW
            case 43: // CONDITION_CHANCE_OF_SNOW
            case 46: // CONDITION_CLOUDY_CHANCE_OF_SNOW
            case 48: // CONDITION_FLURRIES
                return "SNOW";

            case 5:  // CONDITION_WINDY
            case 36: // CONDITION_SQUALL
                return "WIND";

            case 6:  // CONDITION_THUNDERSTORMS
            case 12: // CONDITION_SCATTERED_THUNDERSTORMS
            case 28: // CONDITION_CHANCE_OF_THUNDERSTORMS
            case 32: // CONDITION_TORNADO
            case 41: // CONDITION_HURRICANE
            case 42: // CONDITION_TROPICAL_STORM
                return "STORM";

            case 7:  // CONDITION_WINTRY_MIX
            case 13: // CONDITION_UNKNOWN_PRECIPITATION
            case 18: // CONDITION_LIGHT_RAIN_SNOW
            case 19: // CONDITION_HEAVY_RAIN_SNOW
            case 21: // CONDITION_RAIN_SNOW
            case 34: // CONDITION_ICE
            case 44: // CONDITION_CHANCE_OF_RAIN_SNOW
            case 47: // CONDITION_CLOUDY_CHANCE_OF_RAIN_SNOW
            case 50: // CONDITION_SLEET
            case 51: // CONDITION_ICE_SNOW
                return "MIX";

            case 8:  // CONDITION_FOG
            case 29: // CONDITION_MIST
                return "FOG";

            case 9:  // CONDITION_HAZY
            case 30: // CONDITION_DUST
            case 33: // CONDITION_SMOKE
            case 35: // CONDITION_SAND
            case 37: // CONDITION_SANDSTORM
            case 38: // CONDITION_VOLCANIC_ASH
            case 39: // CONDITION_HAZE
                return "HAZE";

            case 10: // CONDITION_HAIL
                return "HAIL";

            case 11: // CONDITION_SCATTERED_SHOWERS
            case 24: // CONDITION_LIGHT_SHOWERS
            case 25: // CONDITION_SHOWERS
            case 26: // CONDITION_HEAVY_SHOWERS
            case 27: // CONDITION_CHANCE_OF_SHOWERS
                return "SHOWERS";

            default:
                return "WEATHER";
        }
    }
}
