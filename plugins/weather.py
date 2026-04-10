#!/usr/bin/python3
"""
weather.py — ambient particle overlay (snow / rain)
GTK4 + Cairo, fully input-transparent, Dracula Pro palette.

Usage:  python3 weather.py [snow|rain]   (default: snow)
Toggle: run again to kill the running instance.
"""

import fcntl
import math
import os
import random
import sys
import time

import gi
gi.require_version('Gdk', '4.0')
gi.require_version('Gtk', '4.0')
from gi.repository import Gdk, GLib, Gtk

try:
    import cairo
except ImportError:
    import cairocffi as cairo

MODE = sys.argv[1] if len(sys.argv) > 1 else 'snow'

# ── Single-instance toggle lock ──────────────────────────────────
LOCK_FILE = f'/tmp/kitty_weather_{MODE}.lock'
_lock_fd   = open(LOCK_FILE, 'w')
try:
    fcntl.flock(_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    # Already running — kill it (toggle off)
    import subprocess
    subprocess.run(['pkill', '-f', f'weather.py {MODE}'], check=False)
    sys.exit(0)


# ── Dracula Pro palette (pre-normalised to 0-1) ──────────────────
def _c(h):
    return tuple(int(h[i:i+2], 16) / 255 for i in (0, 2, 4))

WHITE  = _c('F8F8F2')
CYAN   = _c('8BE9FD')
PURPLE = _c('BD93F9')
BLUE   = _c('6272A4')
GREEN  = _c('50FA7B')


# ── Screen geometry ───────────────────────────────────────────────
def _screen_size():
    display  = Gdk.Display.get_default()
    monitors = display.get_monitors()
    monitor  = monitors.get_item(0)
    geo      = monitor.get_geometry()
    return geo.width, geo.height

SW, SH = _screen_size()


# ── Particles ─────────────────────────────────────────────────────
class Snowflake:
    _COLORS = [WHITE, WHITE, WHITE, CYAN, PURPLE]

    def __init__(self, initial=False):
        self._init(initial)

    def _init(self, initial=False):
        self.x     = random.uniform(0, SW)
        self.y     = random.uniform(0, SH) if initial else random.uniform(-60, -4)
        self.r     = random.uniform(1.5, 4.5)
        self.vy    = random.uniform(45, 130)        # px/s downward
        self.drift = random.uniform(-25, 25)        # horizontal sway speed
        self.phase = random.uniform(0, math.tau)    # sway phase offset
        self.alpha = random.uniform(0.45, 0.85)
        self.color = random.choice(self._COLORS)

    def update(self, dt):
        self.y += self.vy * dt
        # Gentle sinusoidal horizontal drift
        self.x += self.drift * math.sin(self.phase + self.y * 0.012) * dt
        if self.y > SH + 10:
            self._init()

    def draw(self, ctx):
        ctx.set_source_rgba(*self.color, self.alpha)
        ctx.arc(self.x, self.y, self.r, 0, math.tau)
        ctx.fill()


class Raindrop:
    _TILT  = math.radians(12)
    _COLORS = [(*CYAN, 0.70), (*BLUE, 0.55), (*GREEN, 0.45), (*CYAN, 0.80)]

    def __init__(self, initial=False):
        self._init(initial)

    def _init(self, initial=False):
        self.x      = random.uniform(-80, SW + 80)
        self.y      = random.uniform(0, SH) if initial else random.uniform(-300, -5)
        self.speed  = random.uniform(380, 680)      # px/s
        self.length = random.uniform(8, 22)
        c           = random.choice(self._COLORS)
        self.r, self.g, self.b, self.alpha = c

    def update(self, dt):
        dx = self.speed * math.tan(self._TILT) * dt
        dy = self.speed * dt
        self.x += dx
        self.y += dy
        if self.y > SH + 20:
            self._init()

    def draw(self, ctx):
        dx = self.length * math.sin(self._TILT)
        dy = self.length * math.cos(self._TILT)
        ctx.set_source_rgba(self.r, self.g, self.b, self.alpha)
        ctx.set_line_width(1.3)
        ctx.move_to(self.x, self.y)
        ctx.line_to(self.x - dx, self.y - dy)
        ctx.stroke()


# ── GTK overlay window ────────────────────────────────────────────
_N = {'snow': 200, 'rain': 280}

class WeatherWindow(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.set_title('kitty_weather_overlay')
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_default_size(SW, SH)
        self.fullscreen()

        canvas = Gtk.DrawingArea()
        canvas.set_draw_func(self._draw)
        self.set_child(canvas)

        self.connect('realize', self._on_realize)

        n = _N.get(MODE, 200)
        if MODE == 'snow':
            self._particles = [Snowflake(initial=True) for _ in range(n)]
        else:
            self._particles = [Raindrop(initial=True) for _ in range(n)]

        self._last = time.monotonic()
        GLib.timeout_add(14, self._tick)   # ~70 fps

    def _on_realize(self, *_):
        surface = self.get_surface()
        try:
            surface.set_input_region(cairo.Region())   # fully click-through
        except Exception:
            pass

    def _tick(self):
        now = time.monotonic()
        dt  = min(now - self._last, 0.05)
        self._last = now
        for p in self._particles:
            p.update(dt)
        self.queue_draw()
        return GLib.SOURCE_CONTINUE

    def _draw(self, _area, ctx, _w, _h):
        ctx.set_operator(cairo.OPERATOR_SOURCE)
        ctx.set_source_rgba(0, 0, 0, 0)
        ctx.paint()
        ctx.set_operator(cairo.OPERATOR_OVER)
        for p in self._particles:
            p.draw(ctx)


class WeatherApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=f'dev.neon.weather.{MODE}')

    def do_activate(self):
        WeatherWindow(self).present()


if __name__ == '__main__':
    WeatherApp().run([])
