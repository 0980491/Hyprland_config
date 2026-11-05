#!/usr/bin/env python3
"""Render the spinning-torus ASCII animation into frame files for fastfetch.

fastfetch cannot animate, so banner.sh plays these frames itself. This script
just writes them.

Frames go into one directory per size -- donut/48x20, donut/34x14, donut/24x10.
banner.sh has to lay the donut beside the info box and falls back to a static
banner when the two do not fit side by side, so a single 48-column set meant
every terminal narrower than 89 columns silently lost the animation. With the
smaller sets it picks the widest one that fits instead.

Three things matter for it to actually read as a donut at this size:

  * every frame is exactly HEIGHT lines. Trimming blank rows per frame made
    each one a different height, and the whole shape jittered up and down
    between frames, which is what made the animation unreadable.
  * supersampling. At ~40x18 one character covers a lot of surface, and
    picking a single sample per cell speckles the shading. Each cell is
    sampled SS x SS times and averaged.
  * a ramp of visually distinct glyphs. ".,-~:;=!*#%@" has four characters
    that all read as "a small dot" at terminal size.

Re-run after editing the constants:
    python3 ~/.config/fastfetch/make-donut.py
"""
import math
import os
import shutil

OUT = os.path.expanduser("~/.config/fastfetch/donut")
FRAMES = 200            # frames in one seamless loop
WIDTHS = (48, 34, 24)   # in terminal cells; the height follows from the aspect
SS = 3                  # supersampling factor per axis

# Terminal cells are about twice as tall as wide, and the donut is as tall as
# it is wide, so a WIDTH-column donut needs about WIDTH/2 rows. A little less,
# because the tumble never puts the widest section on the vertical axis.
ASPECT = 5 / 12

# Dark to bright. No "$": fastfetch's "file" logo type reads it as the start of
# a colour placeholder and it wrecks the layout.
RAMP = ".:-=+*#%@"
MAXL = 1.30             # luminance mapped to the brightest glyph
FLOOR = 0.06            # below this a cell stays blank

# Both axes turn, at different rates, like the original donut.c -- that tumble is
# what reads as "spinning". A frame or two per revolution comes out edge-on, and
# that is correct: it is the donut turning through the viewer.
#
# donut.c steps A by 0.04 and B by 0.02 per frame. Matching that ratio (A twice
# B) and keeping both a whole number of turns over FRAMES is what makes the loop
# seamless -- with 32 frames the step was 0.196 rad, five times coarser than the
# original, and the tumble read as juddering rather than turning.
A_TURNS, B_TURNS = 2, 1

R1, R2 = 1.0, 2.0       # tube radius, ring radius
K2 = 6.5                # distance from viewer (higher = less perspective drift)

THETA_STEP = 0.035      # around the tube
PHI_STEP = 0.010        # around the ring


def frame(a, b, width, height):
    """One frame: rotations `a` about X and `b` about Z, as `height` lines."""
    k1 = width * K2 * 3 / (8 * (R1 + R2))
    bw, bh = width * SS, height * SS
    lum = [0.0] * (bw * bh)
    zbuf = [0.0] * (bw * bh)

    cos_a, sin_a = math.cos(a), math.sin(a)
    cos_b, sin_b = math.cos(b), math.sin(b)

    theta = 0.0
    while theta < 2 * math.pi:
        cos_t, sin_t = math.cos(theta), math.sin(theta)
        theta += THETA_STEP

        circle_x = R2 + R1 * cos_t
        circle_y = R1 * sin_t

        phi = 0.0
        while phi < 2 * math.pi:
            cos_p, sin_p = math.cos(phi), math.sin(phi)
            phi += PHI_STEP

            x = (circle_x * (cos_b * cos_p + sin_a * sin_b * sin_p)
                 - circle_y * cos_a * sin_b)
            y = (circle_x * (sin_b * cos_p - sin_a * cos_b * sin_p)
                 + circle_y * cos_a * cos_b)
            z = K2 + cos_a * circle_x * sin_p + circle_y * sin_a
            ooz = 1 / z

            # y is halved because terminal cells are about twice as tall as wide
            xs = int(bw / 2 + SS * k1 * ooz * x)
            ys = int(bh / 2 - SS * k1 * ooz * y / 2)
            if not (0 <= xs < bw and 0 <= ys < bh):
                continue

            # how much this point faces the light at <0, 1, -1>
            l = (cos_p * cos_t * sin_b - cos_a * cos_t * sin_p
                 - sin_a * sin_t + cos_b * (cos_a * sin_t - cos_t * sin_a * sin_p))
            if l <= 0:
                continue

            i = ys * bw + xs
            if ooz > zbuf[i]:
                zbuf[i] = ooz
                lum[i] = l

    # average each SS x SS block down to one cell
    lines = []
    top = len(RAMP) - 1
    for cy in range(height):
        row = []
        for cx in range(width):
            total = 0.0
            for sy in range(SS):
                base = (cy * SS + sy) * bw + cx * SS
                for sx in range(SS):
                    total += lum[base + sx]
            avg = total / (SS * SS)
            if avg < FLOOR:
                row.append(" ")
            else:
                row.append(RAMP[min(int(avg / MAXL * top + 0.5), top)])
        lines.append("".join(row).rstrip())
    # NOTE: no trimming of blank rows -- every frame must be `height` lines tall
    # or the donut jumps around while it spins.
    return lines


def render(width, height):
    """Write one size, into a scratch directory that is swapped in at the end.

    Rendering in place would leave the animation broken for the couple of
    minutes this takes, and permanently broken if it were interrupted.
    """
    name = "%dx%d" % (width, height)
    final = os.path.join(OUT, name)
    tmp = os.path.join(OUT, ".%s.new" % name)
    shutil.rmtree(tmp, ignore_errors=True)
    os.makedirs(tmp)

    for i in range(FRAMES):
        t = i * (2 * math.pi / FRAMES)
        lines = frame(t * A_TURNS, t * B_TURNS, width, height)
        with open(os.path.join(tmp, "%03d.txt" % i), "w") as fh:
            fh.write("\n".join(lines) + "\n")
        if i % 40 == 0:
            print("  %s  %d/%d" % (name, i, FRAMES), flush=True)

    shutil.rmtree(final, ignore_errors=True)
    os.rename(tmp, final)
    print("  %s  done" % name, flush=True)


def main():
    os.makedirs(OUT, exist_ok=True)
    for width in WIDTHS:
        render(width, int(round(width * ASPECT)))

    # Older installs kept a single set of frames loose in donut/. banner.sh
    # still reads that layout, so clear it out or it would win by accident.
    for entry in os.listdir(OUT):
        if entry.endswith(".txt"):
            os.remove(os.path.join(OUT, entry))

    print("wrote %d frames per size (%s) to %s"
          % (FRAMES, ", ".join(str(w) for w in WIDTHS), OUT))


if __name__ == "__main__":
    main()
