#!/usr/bin/env python3
"""
✨ Magic Dust — Kitty terminal particle effects
GTK4 + Cairo transparent overlay. Press Ctrl+F9 to cycle modes.

Modes (cycle with repeated Ctrl+F9):
  sand      — glowing grains fall from text cursor
  fireworks — burst + arc explosion on each keypress
  matrix    — green digital rain from cursor position

Requirements (all from pacman):
  python-gobject   gtk4
  gtk4-layer-shell        ← install: sudo pacman -S gtk4-layer-shell
                            (without it the overlay still works but may sit behind Kitty)
  python-evdev            ← install: sudo pip install evdev  (system pip)
  OR user in 'input' group: sudo usermod -aG input $USER  (re-login required)
"""

import sys, os, math, random, threading, time, fcntl, subprocess, json

# ── single-instance / mode cycling ─────────────────────────────────
MODE_FILE  = "/tmp/magic_dust_mode"
LOCK_FILE  = "/tmp/magic_dust.lock"
MODES      = ["sand", "fireworks", "matrix"]

_lock_fd = open(LOCK_FILE, "w")
try:
    fcntl.flock(_lock_fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
except BlockingIOError:
    # Already running — advance mode file and kill it (toggle/cycle)
    try:
        cur = open(MODE_FILE).read().strip() if os.path.exists(MODE_FILE) else "sand"
        nxt = MODES[(MODES.index(cur) + 1) % len(MODES)] if cur in MODES else "sand"
        open(MODE_FILE, "w").write(nxt)
    except Exception:
        pass
    subprocess.run(["pkill", "-f", "magic_dust.py"], check=False)
    sys.exit(0)

# Determine mode from file or argv
if len(sys.argv) > 1 and sys.argv[1] in MODES:
    MODE = sys.argv[1]
elif os.path.exists(MODE_FILE):
    raw = open(MODE_FILE).read().strip()
    MODE = raw if raw in MODES else "sand"
else:
    MODE = "sand"
open(MODE_FILE, "w").write(MODE)

# ── GTK4 + Cairo ────────────────────────────────────────────────────
import gi
gi.require_version("Gtk", "4.0")
gi.require_version("Gdk", "4.0")
from gi.repository import Gtk, Gdk, GLib
import cairo

# ── gtk4-layer-shell (optional) ─────────────────────────────────────
_LAYER_SHELL = False
try:
    gi.require_version("Gtk4LayerShell", "1.0")
    from gi.repository import Gtk4LayerShell
    _LAYER_SHELL = True
except (ValueError, ImportError):
    pass

# ═══════════════════════════════════════════════════════════════════
#  GLOBAL CONFIG
# ═══════════════════════════════════════════════════════════════════

FPS             = 60
MAX_PARTICLES   = 1200

# Dracula palette (r, g, b) 0-1
COLORS = [
    (0.741, 0.576, 0.976),   # #BD93F9  purple
    (1.000, 0.475, 0.776),   # #FF79C6  pink
    (0.545, 0.914, 0.992),   # #8BE9FD  cyan
    (0.314, 0.980, 0.482),   # #50FA7B  green
    (0.945, 0.980, 0.549),   # #F1FA8C  yellow
    (1.000, 1.000, 1.000),   # #FFFFFF  white
    (0.000, 1.000, 1.000),   # #00FFFF  electric cyan
    (1.000, 0.722, 0.424),   # #FFB86C  orange
]

SANDY_COLORS = [
    (1.000, 0.722, 0.424),   # orange-gold
    (0.945, 0.980, 0.549),   # yellow
    (1.000, 0.475, 0.776),   # pink sparkle
    (0.741, 0.576, 0.976),   # purple sparkle
    (0.545, 0.914, 0.992),   # cyan
    (1.000, 0.900, 0.600),   # warm white-gold
    (1.000, 1.000, 1.000),   # white
]

MATRIX_CHARS = list("ｦｧｨｩｪｫｬｭｮｯｰｱｲｳｴｵｶｷｸｹｺｻｼｽｾｿﾀﾁﾂﾃﾄﾅﾆﾇﾈﾉﾊﾋﾌﾍﾎﾏ"
                    "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ")


# ═══════════════════════════════════════════════════════════════════
#  PARTICLE BASE
# ═══════════════════════════════════════════════════════════════════

class Particle:
    __slots__ = ("x", "y", "vx", "vy", "r", "g", "b",
                 "size", "life", "max_life", "rot", "rot_speed")

    def update(self, dt: float) -> bool:
        self.x   += self.vx
        self.y   += self.vy
        self.rot += self.rot_speed
        self.life -= dt
        return self.life > 0

    @property
    def alpha(self) -> float:
        return max(0.0, min(1.0, self.life / self.max_life))


# ═══════════════════════════════════════════════════════════════════
#  SAND MODE
# ═══════════════════════════════════════════════════════════════════

class SandParticle(Particle):
    """Tiny glowing grain that falls steeply downward from cursor."""
    GRAVITY = 0.38
    __slots__ = ("shape", "trail", "vx_orig")

    def __init__(self, x: float, y: float):
        self.r, self.g, self.b = random.choice(SANDY_COLORS)
        self.size = random.uniform(1.5, 4.5)

        # Downward cone: 60°–120° below horizontal (mostly straight down)
        angle  = random.uniform(math.pi * 0.33, math.pi * 0.67)
        speed  = random.uniform(2.0, 7.0)
        spread = random.uniform(-14, 14)          # small horizontal jitter

        self.x = x + spread
        self.y = y
        self.vx = math.cos(angle) * speed * random.choice([-1, 1])
        self.vy = math.sin(angle) * speed         # positive = down

        lifespan      = random.uniform(0.8, 1.6)
        self.life     = lifespan
        self.max_life = lifespan
        self.rot      = random.uniform(0, math.pi * 2)
        self.rot_speed = random.uniform(-0.15, 0.15)
        self.trail    = random.random() < 0.30
        self.vx_orig  = self.vx
        self.shape    = random.choice(("dust", "dust", "dust", "diamond", "sparkle"))

    def update(self, dt: float) -> bool:
        self.vy  += self.GRAVITY
        self.vx  *= 0.985           # slight horizontal drag
        self.x   += self.vx
        self.y   += self.vy
        self.rot += self.rot_speed
        self.life -= dt
        return self.life > 0

    def draw(self, ctx: cairo.Context):
        a = self.alpha
        s = max(0.3, self.size * a ** 0.5)
        x, y = self.x, self.y

        # glow halo
        ctx.set_source_rgba(self.r, self.g, self.b, a * 0.18)
        ctx.arc(x, y, s * 2.8, 0, math.pi * 2)
        ctx.fill()

        ctx.set_source_rgba(self.r, self.g, self.b, a)
        if self.shape == "dust":
            ctx.arc(x, y, s * 0.85, 0, math.pi * 2)
            ctx.fill()
        elif self.shape == "diamond":
            ctx.move_to(x,           y - s * 2.2)
            ctx.line_to(x + s * 1.1, y)
            ctx.line_to(x,           y + s * 2.2)
            ctx.line_to(x - s * 1.1, y)
            ctx.close_path()
            ctx.fill()
        elif self.shape == "sparkle":
            arm = s * 1.8
            ctx.set_line_width(max(0.6, s * 0.4))
            ctx.move_to(x - arm, y);   ctx.line_to(x + arm, y);   ctx.stroke()
            ctx.move_to(x, y - arm);   ctx.line_to(x, y + arm);   ctx.stroke()

        # falling trail
        if self.trail and a > 0.25 and abs(self.vy) > 0.5:
            tx = x - self.vx * 2.5
            ty = y - self.vy * 2.5
            ctx.set_source_rgba(self.r, self.g, self.b, a * 0.4)
            ctx.set_line_width(max(0.3, s * 0.35))
            ctx.move_to(tx, ty)
            ctx.line_to(x, y)
            ctx.stroke()


# ═══════════════════════════════════════════════════════════════════
#  FIREWORKS MODE
# ═══════════════════════════════════════════════════════════════════

class FireworkParticle(Particle):
    GRAVITY = 0.12
    __slots__ = ("shape",)

    def __init__(self, x: float, y: float, burst_phase: int = 0):
        self.r, self.g, self.b = random.choice(COLORS)
        self.size = random.uniform(2.5, 6.5)
        self.shape = random.choice(("star", "circle", "sparkle"))

        # Phase 0: upward burst; phase 1: secondary radial explosion
        if burst_phase == 0:
            angle = random.uniform(-math.pi * 0.85, -math.pi * 0.15)
            speed = random.uniform(5.0, 14.0)
        else:
            angle = random.uniform(0, math.pi * 2)
            speed = random.uniform(2.0, 9.0)

        self.x = x + random.uniform(-8, 8)
        self.y = y + random.uniform(-4, 4)
        self.vx = math.cos(angle) * speed
        self.vy = math.sin(angle) * speed

        ls = random.uniform(1.0, 2.2)
        self.life = ls; self.max_life = ls
        self.rot = random.uniform(0, math.pi * 2)
        self.rot_speed = random.uniform(-0.2, 0.2)

    def update(self, dt: float) -> bool:
        self.vy += self.GRAVITY
        self.vx *= 0.978
        self.x  += self.vx
        self.y  += self.vy
        self.rot += self.rot_speed
        self.life -= dt
        return self.life > 0

    def draw(self, ctx: cairo.Context):
        a = self.alpha
        s = max(0.5, self.size * a)
        x, y = self.x, self.y

        ctx.set_source_rgba(self.r, self.g, self.b, a * 0.22)
        ctx.arc(x, y, s * 2.8, 0, math.pi * 2); ctx.fill()

        ctx.set_source_rgba(self.r, self.g, self.b, a * 0.60)
        ctx.arc(x, y, s * 1.5, 0, math.pi * 2); ctx.fill()

        ctx.set_source_rgba(self.r, self.g, self.b, a)
        if self.shape == "circle":
            ctx.arc(x, y, s, 0, math.pi * 2); ctx.fill()
        elif self.shape == "star":
            for i in range(5):
                ao = self.rot + i * (math.pi * 2 / 5)
                ai = ao + math.pi / 5
                if i == 0:
                    ctx.move_to(x + math.cos(ao)*s*2.2, y + math.sin(ao)*s*2.2)
                else:
                    ctx.line_to(x + math.cos(ao)*s*2.2, y + math.sin(ao)*s*2.2)
                ctx.line_to(x + math.cos(ai)*s*0.9, y + math.sin(ai)*s*0.9)
            ctx.close_path(); ctx.fill()
        elif self.shape == "sparkle":
            arm = s * 2.1
            ctx.set_line_width(max(0.7, s*0.45))
            ctx.move_to(x-arm, y); ctx.line_to(x+arm, y); ctx.stroke()
            ctx.move_to(x, y-arm); ctx.line_to(x, y+arm); ctx.stroke()
            d = arm * 0.65
            ctx.set_line_width(max(0.4, s*0.3))
            ctx.move_to(x-d,y-d); ctx.line_to(x+d,y+d); ctx.stroke()
            ctx.move_to(x+d,y-d); ctx.line_to(x-d,y+d); ctx.stroke()


def spawn_fireworks(x: float, y: float) -> list:
    out = []
    for _ in range(18):
        out.append(FireworkParticle(x, y, burst_phase=0))
    for _ in range(14):
        out.append(FireworkParticle(x, y, burst_phase=1))
    return out


# ═══════════════════════════════════════════════════════════════════
#  MATRIX MODE
# ═══════════════════════════════════════════════════════════════════

class MatrixDrop:
    __slots__ = ("x", "y", "vy", "chars", "life", "max_life")

    def __init__(self, x: float, y: float):
        self.x = x + random.uniform(-40, 40)
        self.y = y
        self.vy = random.uniform(80, 200)         # px/s downward
        n = random.randint(4, 16)
        self.chars   = [random.choice(MATRIX_CHARS) for _ in range(n)]
        ls = random.uniform(1.5, 3.5)
        self.life = ls; self.max_life = ls

    def update(self, dt: float) -> bool:
        self.y += self.vy * dt
        # randomly mutate head character
        if random.random() < 0.15:
            self.chars[0] = random.choice(MATRIX_CHARS)
        self.life -= dt
        return self.life > 0

    def draw(self, ctx: cairo.Context, font_size: float = 13.0):
        a   = max(0.0, min(1.0, self.life / self.max_life))
        n   = len(self.chars)
        ctx.select_font_face("monospace",
                             cairo.FONT_SLANT_NORMAL,
                             cairo.FONT_WEIGHT_BOLD)
        ctx.set_font_size(font_size)
        for i, ch in enumerate(self.chars):
            frac  = 1.0 - i / n
            alpha = a * frac
            if i == 0:
                # bright white head
                ctx.set_source_rgba(0.9, 1.0, 0.9, alpha)
            else:
                # green body, dimming with distance
                g = 0.4 + 0.6 * frac
                ctx.set_source_rgba(0.0, g, 0.1, alpha * 0.85)
            cy = self.y - i * (font_size + 2)
            ctx.move_to(self.x, cy)
            ctx.show_text(ch)


def spawn_matrix(x: float, y: float) -> list:
    return [MatrixDrop(x, y) for _ in range(random.randint(4, 8))]


# ═══════════════════════════════════════════════════════════════════
#  CURSOR POSITION (async cached)
# ═══════════════════════════════════════════════════════════════════

class CursorTracker:
    """Polls kitty @ ls every 150 ms in a background thread."""

    def __init__(self):
        self._x = 960.0
        self._y = 540.0
        self._lock = threading.Lock()
        t = threading.Thread(target=self._loop, daemon=True)
        t.start()

    def get(self) -> tuple[float, float]:
        with self._lock:
            return self._x, self._y

    def _loop(self):
        while True:
            self._poll()
            time.sleep(0.15)

    def _poll(self):
        try:
            r = subprocess.run(
                ["kitty", "@", "ls"],
                capture_output=True, text=True, timeout=0.3,
            )
            data = json.loads(r.stdout)
            for os_win in data:
                for tab in os_win.get("tabs", []):
                    for win in tab.get("windows", []):
                        if not win.get("is_focused"):
                            continue
                        geom   = win.get("geometry", {})
                        cursor = win.get("cursor_state", {})
                        cols   = win.get("columns", 80)
                        rows   = win.get("lines", 24)
                        if not geom or "x" not in cursor:
                            return
                        cell_w = (geom["right"]  - geom["left"]) / max(cols, 1)
                        cell_h = (geom["bottom"] - geom["top"])  / max(rows, 1)
                        x = geom["left"] + (cursor["x"] + 0.5) * cell_w
                        y = geom["top"]  + (cursor["y"] + 0.5) * cell_h
                        with self._lock:
                            self._x, self._y = x, y
                        return
        except Exception:
            pass


# ═══════════════════════════════════════════════════════════════════
#  OVERLAY WINDOW
# ═══════════════════════════════════════════════════════════════════

class MagicDustOverlay(Gtk.ApplicationWindow):

    def __init__(self, app):
        super().__init__(application=app, title="magic_dust")

        self.mode      = MODE
        self.particles = []          # Particle | MatrixDrop
        self.glow_rings: list[tuple[float, float, int]] = []
        self.lock      = threading.Lock()
        self._last_ts  = time.monotonic()
        self.cursor    = CursorTracker()

        self._setup_window()
        self._setup_drawing()
        self._start_keyboard_listener()
        self.connect("realize", self._on_realize)
        GLib.timeout_add(int(1000 / FPS), self._tick)

    # ── window ─────────────────────────────────────────────────────
    def _setup_window(self):
        display  = Gdk.Display.get_default()
        monitors = display.get_monitors()
        monitor  = monitors.get_item(0)
        geom     = monitor.get_geometry()
        W, H     = geom.width, geom.height

        self.set_default_size(W, H)
        self.set_decorated(False)
        self.set_resizable(False)
        self.set_can_focus(False)
        self.set_focusable(False)

        # transparent CSS
        css = b"window { background-color: transparent; }"
        prov = Gtk.CssProvider()
        prov.load_from_data(css)
        Gtk.StyleContext.add_provider_for_display(
            display, prov, Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )

        if _LAYER_SHELL:
            Gtk4LayerShell.init_for_window(self)
            Gtk4LayerShell.set_layer(self, Gtk4LayerShell.Layer.OVERLAY)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.TOP, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.LEFT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.RIGHT, True)
            Gtk4LayerShell.set_anchor(self, Gtk4LayerShell.Edge.BOTTOM, True)
            Gtk4LayerShell.set_exclusive_zone(self, -1)
            Gtk4LayerShell.set_keyboard_mode(self, Gtk4LayerShell.KeyboardMode.NONE)
            print("✨ Magic Dust: gtk4-layer-shell overlay active")
        else:
            print("⚠  gtk4-layer-shell not found. Install: sudo pacman -S gtk4-layer-shell")
            print("   Overlay may appear behind Kitty without it.")

    def _setup_drawing(self):
        self.da = Gtk.DrawingArea()
        self.da.set_draw_func(self._draw)
        self.set_child(self.da)

    def _on_realize(self, _widget):
        surface = self.get_surface()
        if surface:
            surface.set_input_region(cairo.Region())

    # ── keyboard listener (evdev) ───────────────────────────────────
    def _start_keyboard_listener(self):
        try:
            import evdev, select

            devs = []
            for p in evdev.list_devices():
                try:
                    d = evdev.InputDevice(p)
                    if evdev.ecodes.EV_KEY in d.capabilities():
                        devs.append(d)
                except Exception:
                    pass

            if not devs:
                raise RuntimeError("no keyboard devices (add user to 'input' group)")

            SKIP = {
                evdev.ecodes.KEY_LEFTSHIFT,  evdev.ecodes.KEY_RIGHTSHIFT,
                evdev.ecodes.KEY_LEFTCTRL,   evdev.ecodes.KEY_RIGHTCTRL,
                evdev.ecodes.KEY_LEFTALT,    evdev.ecodes.KEY_RIGHTALT,
                evdev.ecodes.KEY_LEFTMETA,   evdev.ecodes.KEY_RIGHTMETA,
                evdev.ecodes.KEY_CAPSLOCK,   evdev.ecodes.KEY_NUMLOCK,
                evdev.ecodes.KEY_SCROLLLOCK,
            }

            def _run():
                while True:
                    try:
                        r, _, _ = select.select(devs, [], [], 1.0)
                        for dev in r:
                            for ev in dev.read():
                                if (ev.type  == evdev.ecodes.EV_KEY
                                        and ev.value == 1
                                        and ev.code  not in SKIP):
                                    GLib.idle_add(self._spawn_burst)
                    except Exception:
                        time.sleep(0.1)

            threading.Thread(target=_run, daemon=True).start()
            print(f"✨ Magic Dust [{MODE}]: evdev listener active ({len(devs)} device(s))")

        except Exception as exc:
            print(f"⚠  evdev failed ({exc})")
            print("   Fix: sudo usermod -aG input $USER  (re-login)")
            print("   Fallback: demo auto-burst every 0.3s")

            def _demo():
                while True:
                    time.sleep(0.3)
                    GLib.idle_add(self._spawn_burst)
            threading.Thread(target=_demo, daemon=True).start()

    # ── spawn ───────────────────────────────────────────────────────
    def _spawn_burst(self):
        x, y = self.cursor.get()
        with self.lock:
            if self.mode == "sand":
                new = [SandParticle(x, y) for _ in range(28)]
                self.glow_rings.append((x, y, 8))
            elif self.mode == "fireworks":
                new = spawn_fireworks(x, y)
                self.glow_rings.append((x, y, 12))
            else:  # matrix
                new = spawn_matrix(x, y)

            self.particles.extend(new)
            if len(self.particles) > MAX_PARTICLES:
                self.particles = self.particles[-MAX_PARTICLES:]
        self.da.queue_draw()

    # ── tick ────────────────────────────────────────────────────────
    def _tick(self) -> bool:
        now = time.monotonic()
        dt  = min(now - self._last_ts, 0.05)
        self._last_ts = now
        with self.lock:
            if self.particles or self.glow_rings:
                self.particles = [p for p in self.particles if p.update(dt)]
                self.da.queue_draw()
        return GLib.SOURCE_CONTINUE

    # ── draw ────────────────────────────────────────────────────────
    def _draw(self, _area, ctx: cairo.Context, _w: int, _h: int):
        ctx.set_operator(cairo.OPERATOR_SOURCE)
        ctx.set_source_rgba(0, 0, 0, 0)
        ctx.paint()
        ctx.set_operator(cairo.OPERATOR_OVER)

        with self.lock:
            # glow rings
            new_rings = []
            for gx, gy, frames in self.glow_rings:
                if frames > 0:
                    frac   = frames / 12
                    radius = (13 - frames) * 6 + 8
                    ctx.set_source_rgba(0.741, 0.576, 0.976, frac * 0.85)
                    ctx.set_line_width(2.0)
                    ctx.arc(gx, gy, radius, 0, math.pi * 2)
                    ctx.stroke()
                    if frames > 6:
                        ctx.set_source_rgba(0.0, 1.0, 1.0, frac * 0.5)
                        ctx.set_line_width(1.0)
                        ctx.arc(gx, gy, radius * 0.45, 0, math.pi * 2)
                        ctx.stroke()
                    new_rings.append((gx, gy, frames - 1))
            self.glow_rings = new_rings

            # particles
            if self.mode == "matrix":
                for p in self.particles:
                    p.draw(ctx)
            else:
                for p in sorted(self.particles, key=lambda p: p.alpha):
                    p.draw(ctx)


# ═══════════════════════════════════════════════════════════════════
#  APP
# ═══════════════════════════════════════════════════════════════════

class MagicDustApp(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=f"com.kitty.magic_dust.{MODE}")

    def do_activate(self):
        win = MagicDustOverlay(self)
        win.present()
        print(f"✨ Magic Dust [{MODE}] running — Ctrl+F9 cycles modes, Ctrl+F10 stops")


if __name__ == "__main__":
    MagicDustApp().run(sys.argv[:1])
