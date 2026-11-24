#!/usr/bin/python3
"""Runs on the TV, started by apply.sh. Each time the no-signal art screen appears, it gets a new
random order of the photos, repeated until the screen closes.

LG's input app shows a random one of 16 fixed slots about every 10 seconds, and its code can't be
changed. So all 16 slots hold the same photo. When the input app has opened a slot (seen with
inotify) and gone quiet for a second, every slot moves on to the next photo in the order.
Whichever slot the app picks next, it gets the next photo. When no slot is opened for
SESSION_GAP seconds, the screen has closed, and the slots get the first photo of a new order.
"""
import ctypes
import glob
import os
import random
import select
import struct
import sys

BASE = "/media/developer/photo-screensaver"
SLOTS = BASE + "/nosignal"
PIDFILE = "/tmp/photo-screensaver-shuffle.pid"
NUM_SLOTS = 16
IN_OPEN = 0x20
IN_CLOSE_NOWRITE = 0x10
# Wait this long after the last open before moving on, so a load that opens the file more than
# once still reads one photo. The input app loads a new slot only every 10 seconds or so.
QUIET_SECONDS = 1.0
# No open for this long means the art screen has closed
SESSION_GAP = 25.0
EVENT_HEADER = struct.Struct("iIII")


def point_slots(photo):
    """Hard-links every slot name to one photo. Each name is replaced with a rename, so the
    input app never finds a slot missing."""
    for i in range(NUM_SLOTS):
        tmp = "%s/.next%d" % (SLOTS, i)
        if os.path.lexists(tmp):
            os.unlink(tmp)
        os.link(photo, tmp)
        os.rename(tmp, "%s/modernart_%d.jpg" % (SLOTS, i))
        # rename does nothing when both names are already the same file
        if os.path.lexists(tmp):
            os.unlink(tmp)


def slot_opened(buf):
    """Whether a batch of inotify events includes an open or close of a slot file."""
    pos = 0
    found = False
    while pos + EVENT_HEADER.size <= len(buf):
        _, _, _, length = EVENT_HEADER.unpack_from(buf, pos)
        start = pos + EVENT_HEADER.size
        if buf[start:start + length].startswith(b"modernart_"):
            found = True
        pos = start + length
    return found


def main():
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))

    libc = ctypes.CDLL("libc.so.6", use_errno=True)
    fd = libc.inotify_init()
    if fd < 0 or libc.inotify_add_watch(fd, SLOTS.encode(), IN_OPEN | IN_CLOSE_NOWRITE) < 0:
        sys.exit("inotify setup failed: errno %d" % ctypes.get_errno())

    order = []
    pos = 0

    def show(index):
        nonlocal pos
        pos = index
        try:
            point_slots(order[pos])
        except OSError as e:
            # A photo removed by a sync: the slots keep the previous photo until the next open
            print("could not point slots at %s: %s" % (order[pos], e), file=sys.stderr)

    def new_order():
        nonlocal order
        order = glob.glob(BASE + "/photos/*.jpg")
        random.shuffle(order)
        if order:
            show(0)

    new_order()
    pending = False      # a slot was opened, move on once the app goes quiet
    showing = False      # the art screen is up
    while True:
        if pending:
            timeout = QUIET_SECONDS
        elif showing:
            timeout = SESSION_GAP
        else:
            timeout = None
        ready, _, _ = select.select([fd], [], [], timeout)
        if ready:
            if slot_opened(os.read(fd, 65536)):
                pending = True
        elif pending:
            pending = False
            showing = True
            if order:
                show((pos + 1) % len(order))
        elif showing:
            showing = False
            new_order()


if __name__ == "__main__":
    main()
