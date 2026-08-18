#!/usr/bin/env python3
"""Keep a dragged window tiled when it crosses workspaces.

Hyprland floats a tiled window the moment you grab it with SUPER+drag, and
tiles it back when you drop it — but only if you never left the workspace.
Change workspace mid-drag with the scroll wheel and the window lands on the
new one stuck as floating, and you have to SUPER+W it back by hand.

Sequence recorded from the live event socket. Broken case:

    changefloatingmode>>ADDR,1     drag starts, window gets floated
    workspace>>N                   scroll wheel
    movewindow>>ADDR,N             the window follows
                                   ...and no changefloatingmode>>ADDR,0

Dropping on the same workspace ends with that missing event, and there is
nothing to fix.

So the rule is: a window that was floated moments ago and then lands on a
different workspace was being carried, and belongs back in the layout. The
freshness check is what keeps a window you floated on purpose out of it —
after FLOAT_SETTLED seconds its floating state is taken as deliberate.

An earlier version also demanded an empty `activewindow` event after the
float, on the theory that only a drag empties the focus. The log said
otherwise: real drags often keep the focus, so it fired only sometimes.
Hence no cleverness here, just the freshness window.

There is no "you let go of the button" event, so once the window has moved
this watches its position and tiles it back once it stops moving. State is
read straight off the Hyprland command socket rather than by running
hyprctl, which at four polls a second was slow enough to feel like a lag.
"""
import json
import os
import select
import socket
import struct
import threading
import time

RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/run/user/%d" % os.getuid())
SIGNATURE = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE", "")
BASE = os.path.join(RUNTIME, "hypr", SIGNATURE)
EVENT_SOCKET = os.path.join(BASE, ".socket2.sock")
CMD_SOCKET = os.path.join(BASE, ".socket.sock")

# How long a float still counts as "part of a drag". Past this it is treated
# as something you chose, and the window is left alone.
FLOAT_SETTLED = 25.0
# Fallback only, for when the mouse buttons cannot be read: the window has to
# sit still this many polls before the drag is called over.
STILL_SAMPLES = 4
POLL = 0.1
GIVE_UP = 20.0
# How often to look for input devices that appeared after startup.
RESCAN = 5.0

# Reading the button straight off the input device is what makes this land the
# instant you let go. Waiting for the window to stop moving cost half a second
# and you could feel it.
EV_KEY = 0x01
BTN_LEFT = 0x110
EVENT_STRUCT = "llHHi"                       # timeval, type, code, value
EVENT_SIZE = struct.calcsize(EVENT_STRUCT)

button_down = False
buttons_readable = False

floated_at = {}          # address -> when it was floated
lock = threading.Lock()

DEBUG = os.environ.get("KEEP_TILED_DEBUG") == "1"
LOG = os.path.join(RUNTIME, "keep-tiled.log")


def log(message):
    if not DEBUG:
        return
    with open(LOG, "a") as fh:
        fh.write("%.3f  %s\n" % (time.time(), message))
        fh.flush()


def request(command):
    """Talk to Hyprland's command socket directly. Spawning hyprctl for this
    cost tens of milliseconds a call, several times a second, per drag."""
    try:
        with socket.socket(socket.AF_UNIX, socket.SOCK_STREAM) as sock:
            sock.connect(CMD_SOCKET)
            sock.sendall(command.encode())
            chunks = []
            while True:
                chunk = sock.recv(65536)
                if not chunk:
                    break
                chunks.append(chunk)
        return b"".join(chunks).decode("utf-8", "replace")
    except OSError as error:
        log("    !! socket error: %s" % error)
        return ""


def find_window(address):
    try:
        clients = json.loads(request("j/clients"))
    except json.JSONDecodeError:
        return None
    for client in clients:
        if client.get("address", "")[2:].lower() == address.lower():
            return client
    return None


def mouse_event_devices():
    """Every /dev/input/event* that reports mouse buttons."""
    paths = []
    try:
        with open("/proc/bus/input/devices") as fh:
            blocks = fh.read().split("\n\n")
    except OSError:
        return paths

    for block in blocks:
        for line in block.splitlines():
            if not line.startswith("H: Handlers="):
                continue
            handlers = line.split("=", 1)[1].split()
            if not any(h.startswith("mouse") for h in handlers):
                continue
            for handler in handlers:
                if handler.startswith("event"):
                    paths.append("/dev/input/" + handler)
    return paths


def open_mouse_devices(fds):
    """Open every mouse device we are not already reading.

    Called again after a device disappears rather than once at startup: a USB
    hub that re-enumerates takes the mouse with it, and the replacement comes
    back under a new event number.
    """
    known = set(fds.values())
    for path in mouse_event_devices():
        if path in known:
            continue
        try:
            fds[os.open(path, os.O_RDONLY | os.O_NONBLOCK)] = path
            log("== watching buttons on %s" % path)
        except OSError as error:
            log("    !! cannot read %s: %s" % (path, error))


def watch_mouse_button():
    """Track the left button so a drop is noticed the moment it happens."""
    global button_down, buttons_readable

    fds = {}
    next_scan = 0.0

    while True:
        # Rescan on a timer, and immediately whenever we have nothing left to
        # read, so an unplugged mouse is picked back up when it returns.
        if not fds or time.time() >= next_scan:
            open_mouse_devices(fds)
            next_scan = time.time() + RESCAN
            if not fds:
                log("== no readable mouse devices, falling back to stillness")

        buttons_readable = bool(fds)

        ready, _, _ = select.select(list(fds), [], [], 1.0)
        for fd in ready:
            try:
                data = os.read(fd, EVENT_SIZE * 64)
            except OSError as error:
                log("    !! %s: %s" % (fds.get(fd), error))
                data = b""
            if not data:
                # The device is gone. A dead fd stays readable forever, so
                # leaving it in the set spins select() at 100% of a core —
                # which is exactly what the re-enumerating USB hub caused
                # (2026-08-16). Drop it; the rescan picks up its replacement.
                log("    !! dropping %s" % fds.get(fd))
                try:
                    os.close(fd)
                except OSError:
                    pass
                fds.pop(fd, None)
                next_scan = 0.0
                continue
            for offset in range(0, len(data) - EVENT_SIZE + 1, EVENT_SIZE):
                _, _, etype, code, value = struct.unpack(
                    EVENT_STRUCT, data[offset:offset + EVENT_SIZE])
                if etype == EV_KEY and code == BTN_LEFT:
                    button_down = value != 0


def retile_on_release(address):
    """Tile the window back the moment the left button comes up."""
    deadline = time.time() + GIVE_UP
    while button_down and time.time() < deadline:
        time.sleep(0.01)

    window = find_window(address)
    if window is None or not window.get("floating"):
        return
    log("    -> RETILING %s (button released)" % address)
    request('dispatch hl.dsp.window.float({ action = "off", window = '
            '"address:0x%s" })' % address)


def retile_when_dropped(address):
    """Wait for the window to stop moving, then put it back in the layout."""
    if buttons_readable:
        retile_on_release(address)
        return

    last_pos = None
    still = 0
    deadline = time.time() + GIVE_UP

    while time.time() < deadline:
        time.sleep(POLL)
        window = find_window(address)
        if window is None:
            log("    -> %s is gone" % address)
            return
        if not window.get("floating"):
            log("    -> %s tiled itself, nothing to do" % address)
            return
        pos = tuple(window.get("at", []))
        still = still + 1 if pos == last_pos else 0
        last_pos = pos
        if still >= STILL_SAMPLES:
            break
    else:
        log("    -> %s never settled, leaving it" % address)
        return

    log("    -> RETILING %s" % address)
    request('dispatch hl.dsp.window.float({ action = "off", window = '
            '"address:0x%s" })' % address)


def handle(event, payload):
    now = time.time()
    if event in ("changefloatingmode", "movewindow", "openwindow",
                 "closewindow"):
        log("EV  %s >> %s" % (event, payload))

    if event == "changefloatingmode":
        address, _, state = payload.rpartition(",")
        with lock:
            if state == "1":
                # Only a drag counts, and a drag holds the left button down.
                # Without this check every other route to a float looks like a
                # carried window: a window rule floating a window at map time,
                # then SUPER+SHIFT+n to send it away, is a float followed by a
                # movewindow inside FLOAT_SETTLED, and it got tiled back.
                # That is how Autodesk Fusion lost its virtual desktop — the
                # canvas shrank under a running Fusion, which never notices a
                # frame resize, and the UI stayed half painted (2026-08-12).
                if buttons_readable and not button_down:
                    log("    -> %s floated with no button down, not a drag"
                        % address)
                    return
                floated_at[address] = now
                log("    -> %s floated, watching" % address)
            else:
                floated_at.pop(address, None)

    elif event == "movewindow":
        address = payload.split(",")[0]
        with lock:
            when = floated_at.pop(address, None)
            age = None if when is None else now - when
            log("    -> moved; floated %s ago"
                % ("never" if age is None else "%.1fs" % age))
            if age is None or age > FLOAT_SETTLED:
                return
        threading.Thread(target=retile_when_dropped,
                         args=(address,), daemon=True).start()

    elif event == "closewindow":
        with lock:
            floated_at.pop(payload.strip(), None)

    if len(floated_at) > 32:
        with lock:
            for address in [a for a, t in floated_at.items()
                            if now - t > FLOAT_SETTLED]:
                floated_at.pop(address, None)


def main():
    if not SIGNATURE:
        raise SystemExit("HYPRLAND_INSTANCE_SIGNATURE is not set")

    threading.Thread(target=watch_mouse_button, daemon=True).start()
    time.sleep(0.2)                     # let it report what it found

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(EVENT_SOCKET)
    log("== started, listening on %s" % EVENT_SOCKET)

    buffer = ""
    with sock:
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break                   # Hyprland went away
            buffer += chunk.decode("utf-8", "replace")
            while "\n" in buffer:
                line, buffer = buffer.split("\n", 1)
                event, _, payload = line.partition(">>")
                if event:
                    handle(event, payload)


if __name__ == "__main__":
    main()
