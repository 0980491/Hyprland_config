#!/usr/bin/env python3
"""Render the spinning-torus ASCII animation into frame files for fastfetch.

fastfetch cannot animate, so banner.sh plays these frames itself. This script
just writes them.

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
WIDTH, HEIGHT = 48, 20  # in terminal cells
SS = 3                  # supersampling factor per axis

# Dark to bright. No "$": fastfetch's "file" logo type reads it as the start of
# a colour placeholder and it wrecks the layout.
RAMP = ".:-=+*#%@"
MAXL = 1.30             # luminance mapped to the brightest glyph
FLOOR = 0.06            # below this a cell stays blank

# Both axes turn, at different rates, like the original donut.c — that tumble is
# what reads as "spinning". A frame or two per revolution comes out edge-on, and
# that is correct: it is the donut turning through the viewer.
#
# donut.c steps A by 0.04 and B by 0.02 per frame. Matching that ratio (A twice
# B) and keeping both a whole number of turns over FRAMES is what makes the loop
# seamless — with 32 frames the step was 0.196 rad, five times coarser than the
# original, and the tumble read as juddering rather than turning.
A_TURNS, B_TURNS = 2, 1

R1, R2 = 1.0, 2.0       # tube radius, ring radius
K2 = 6.5                # distance from viewer (higher = less perspective drift)
K1 = WIDTH * K2 * 3 / (8 * (R1 + R2))

THETA_STEP = 0.035      # around the tube
PHI_STEP = 0.010        # around the ring


def frame(a, b):
    """One frame: rotations `a` about X and `b` about Z, as HEIGHT lines."""
    bw, bh = WIDTH * SS, HEIGHT * SS
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
            xs = int(bw / 2 + SS * K1 * ooz * x)
            ys = int(bh / 2 - SS * K1 * ooz * y / 2)
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
    for cy in range(HEIGHT):
        row = []
        for cx in range(WIDTH):
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
    # NOTE: no trimming of blank rows — every frame must be HEIGHT lines tall
    # or the donut jumps around while it spins.
    return lines


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    os.makedirs(OUT, exist_ok=True)
    for i in range(FRAMES):
        t = i * (2 * math.pi / FRAMES)
        lines = frame(t * A_TURNS, t * B_TURNS)
        with open(os.path.join(OUT, "%03d.txt" % i), "w") as fh:
            fh.write("\n".join(lines) + "\n")
        if i % 20 == 0:
            print("  %d/%d" % (i, FRAMES), flush=True)
    print("wrote %d frames of %dx%d to %s" % (FRAMES, WIDTH, HEIGHT, OUT))


if __name__ == "__main__":
    main()
