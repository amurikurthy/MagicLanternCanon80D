#!/usr/bin/env python3
"""
Boot the 80D in qemu-eos headless and capture the serial log (and optional
screenshots). Works around run_qemu.py hardcoding a GTK display by driving
ml_qemu.run.QemuRunner directly with display=None.

Usage:
    40_boot_qemu.py                 # boot bare Canon firmware
    40_boot_qemu.py --boot          # boot Magic Lantern from the emulated card
    40_boot_qemu.py --boot --gdb    # also attach gdb to apply emulation patches
    40_boot_qemu.py --seconds 45    # how long to let it run

Env:
    WORKROOT   default /home/user/src
"""
import os, sys, time, argparse, subprocess

WORKROOT = os.environ.get("WORKROOT", "/home/user/src")
ML_QEMU  = os.path.join(WORKROOT, "qemu-eos", "magiclantern")
BUILD    = os.path.join(WORKROOT, "qemu-eos-build")
ROMS     = os.path.join(WORKROOT, "roms")
ML_SRC   = os.path.join(WORKROOT, "magiclantern_simplified")
PLATDIR  = os.path.join(ML_SRC, "platform", "80D.103")
HERE     = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--boot", action="store_true", help="boot ML autoexec.bin from card")
    ap.add_argument("--gdb", action="store_true", help="attach gdb with emulation patches")
    ap.add_argument("--seconds", type=int, default=35)
    ap.add_argument("--serial", default=os.path.join(HERE, "serial80d.log"))
    args = ap.parse_args()

    sys.path.insert(0, ML_QEMU)
    os.chdir(ML_QEMU)
    from ml_qemu.run import QemuRunner

    sd = os.path.join(PLATDIR, "build", "sd.qcow2")
    cf = os.path.join(PLATDIR, "build", "cf.qcow2")
    if args.boot and not os.path.isfile(sd):
        sys.exit("No %s — run 30_make_sd_image.sh first" % sd)

    open(args.serial, "w").close()
    print("rom_dir=%s  boot=%s  gdb=%s" % (ROMS, args.boot, args.gdb))

    with QemuRunner(BUILD, ROMS, ML_SRC, "80D",
                    sd_file=sd, cf_file=cf,
                    serial_out=args.serial,
                    display=None, verbose=False,
                    boot=args.boot,
                    gdb_port=(1234 if args.gdb else 0)) as q:
        gdb = None
        if args.gdb:
            gdb = subprocess.Popen(
                ["gdb-multiarch", "-nx", "-batch", "-x",
                 os.path.join(HERE, "patches_80d.gdb")])
            print("gdb attached (pid %s)" % gdb.pid)
        for _ in range(args.seconds):
            if q.qemu_process.poll() is not None:
                print("qemu exited rc=%s" % q.qemu_process.returncode)
                break
            time.sleep(1)
        try:
            q.shutdown(force=True)
        except Exception as e:
            print("shutdown:", e)
        if gdb:
            gdb.terminate()

    print("\n==== serial log (%s) ====" % args.serial)
    with open(args.serial) as f:
        sys.stdout.write(f.read())


if __name__ == "__main__":
    main()
