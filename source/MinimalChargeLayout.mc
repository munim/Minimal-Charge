import Toybox.Lang;

module MinimalChargeLayout {

    // Returns [xPx, hourYPx, minuteYPx]
    // Round dial: centered at 50%, numeral height 34%, line-height 0.8 -> y: 22.8%-77.2% (hour top 22.8%, minute top 50.0%)
    // Square/Rectangular dial: top-left at 8%, 8%, numeral height 40%, line-height 0.8 -> y: 8%-72% (hour top 8%, minute top 40%)
    public function computeTimeCoords(width as Number, height as Number, isRound as Boolean, dx as Number, dy as Number) as Array<Number> {
        if (isRound) {
            var x = (width / 2) + dx;
            var hourY = ((height * 228) + 500) / 1000 + dy;
            var minuteY = (height / 2) + dy;
            return [x, hourY, minuteY];
        } else {
            var x = ((width * 8) + 50) / 100 + dx;
            var hourY = ((height * 8) + 50) / 100 + dy;
            var minuteY = ((height * 40) + 50) / 100 + dy;
            return [x, hourY, minuteY];
        }
    }

    // Round bottom slot horizontal center:
    // Slot 2 (bottom-left): width 22%, right edge at 48% -> center at 37%
    // Slot 3 (bottom-right): width 22%, left edge at 52% -> center at 63%
    // Solo bottom rule: when only one of Slot 2 or Slot 3 is enabled, centers horizontally at 50%
    public function computeRoundBottomSlotX(width as Number, slotNumber as Number, slot2Active as Boolean, slot3Active as Boolean) as Number {
        var soloBottom = (slot2Active && !slot3Active) || (!slot2Active && slot3Active);
        if (soloBottom) {
            return width / 2;
        }
        if (slotNumber == 2) {
            return ((width * 37) + 50) / 100;
        }
        return ((width * 63) + 50) / 100;
    }

    // Progress bar width:
    // Round: 22% of dial width (even in Slot 1 so it stays inside the upper bezel arc)
    // Square: 30% of dial width (matches the right-hand data column width)
    public function computeBarWidth(width as Number, isRound as Boolean) as Number {
        if (isRound) {
            return ((width * 22) + 50) / 100;
        }
        return ((width * 30) + 50) / 100;
    }

    // Square slot row top Y coordinate:
    // Data column at left: 62%, top: 12%, width: 30%, 3 fixed 14%-tall rows with 5% vertical gap (12%, 31%, 50%)
    public function computeSquareSlotY(height as Number, slotIndex as Number, slot1Active as Boolean, slot2Active as Boolean, slot3Active as Boolean) as Number {
        var soloBottom = !slot1Active && ((slot2Active && !slot3Active) || (!slot2Active && slot3Active));
        if (soloBottom) {
            return ((height * 12) + 50) / 100;
        }
        var pct = 12;
        if (slotIndex == 1) {
            pct = 31;
        } else if (slotIndex == 2) {
            pct = 50;
        }
        return ((height * pct) + 50) / 100;
    }

    // MIP dirty-rect bounding box [clipX, clipY, clipW, clipH] for minute-only updates:
    // Round: minute occupies y: 50%..77.2%, centered horizontally within 48% width
    // Square: minute occupies x: 6%..60%, y: 40%..73% (left of the 62% slot column)
    public function computeMinuteClipRect(width as Number, height as Number, isRound as Boolean) as Array<Number> {
        if (isRound) {
            var clipW = ((width * 480) + 500) / 1000;
            var clipX = (width - clipW) / 2;
            var clipY = height / 2;
            var clipH = ((height * 280) + 500) / 1000;
            return [clipX, clipY, clipW, clipH];
        } else {
            var clipX = ((width * 6) + 50) / 100;
            var clipY = ((height * 40) + 50) / 100;
            var clipW = ((width * 54) + 50) / 100;
            var clipH = ((height * 33) + 50) / 100;
            return [clipX, clipY, clipW, clipH];
        }
    }
}
