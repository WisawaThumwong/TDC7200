# -*- coding: utf-8 -*-
# file: read_sensor_cli.py
import argparse
import sys
import time
import csv
import re
import os
import serial
import serial.tools.list_ports
from datetime import datetime

BAUD_DEFAULT = 115200
SER_TIMEOUT = 0.05  # timeout สั้นเพื่อไม่บล็อก

# pattern ตัวเลขทศนิยม
float_pattern = re.compile(r'[+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?')

SENSOR_NAME = {
    "0": "AK09973D",
    "1": "AK09940A",
    "2": "TLV493D",
    "3": "TMAG3001A1",
    "4": "TMAG3001A2",
}

AXIS_CMD = {
    "x": "13\r",
    "y": "14\r",
    "z": "15\r",
    "tri": "34\r",
}


def pick_XYZ_float(text: str):
    """ดึงค่า Z,Y,X จาก string ตามโค้ด GUI เดิม"""
    parts = text.split()
    if len(parts) >= 5:
        try:
            return float(parts[2]), float(parts[3]), float(parts[4])
        except ValueError:
            pass
    floats = float_pattern.findall(text)
    if len(floats) >= 5:
        try:
            return float(floats[2]), float(floats[3]), float(floats[4])
        except ValueError:
            return None
    return None


def auto_pick_port():
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        return None
    def score(p):
        t = f"{p.device} {p.description} {p.hwid}".lower()
        s = 0
        if "usb" in t: s += 2
        if "acm" in t: s += 2
        if "cdc" in t: s += 1
        if "uart" in t: s += 1
        return s
    ports.sort(key=score, reverse=True)
    return ports[0].device


def probe_device(ser: serial.Serial):
    """ส่ง '31\\r' เพื่ออ่านชนิด sensor + '30\\r' เพื่ออ่าน firmware"""
    ser.reset_input_buffer()
    ser.write(b"31\r")
    time.sleep(0.05)
    sensor_code = None
    if ser.in_waiting > 0:
        line = ser.readline().decode(errors="replace").strip()
        if line in {"0", "1", "2", "3", "4"}:
            sensor_code = line
    fw = None
    ser.reset_input_buffer()
    ser.write(b"30\r")
    time.sleep(0.05)
    if ser.in_waiting > 0:
        fw = ser.readline().decode(errors="replace").strip()
    return sensor_code, SENSOR_NAME.get(sensor_code, "Unknown"), fw


def set_axis(ser: serial.Serial, axis_key: str):
    cmd = AXIS_CMD.get(axis_key.lower())
    if not cmd:
        return False
    ser.write(cmd.encode())
    time.sleep(0.02)
    return True


def start_stream(ser: serial.Serial):
    ser.write(b"32\r")
    time.sleep(0.02)


def main():
    ap = argparse.ArgumentParser(description="Read sensor over USB-Serial (no GUI) and print values.")
    ap.add_argument("--port", help="ระบุพอร์ต เช่น COM5 หรือ /dev/ttyACM0")
    ap.add_argument("--baud", type=int, default=BAUD_DEFAULT, help=f"baudrate (default: {BAUD_DEFAULT})")
    ap.add_argument("--axis", choices=["x", "y", "z", "tri"], help="เลือกแกนก่อนเริ่มสตรีม (13/14/15/34)")
    ap.add_argument("--raw", action="store_true", help="พิมพ์บรรทัดดิบแทนการ parse XYZ")
    ap.add_argument("--csv", help="บันทึกข้อมูลลงไฟล์ CSV")
    # ✅ เพิ่ม alias --show และ --show-info ใช้ได้ทั้งคู่
    ap.add_argument("--show-info", "--show", dest="show", action="store_true",
                    help="แสดงชนิดเซ็นเซอร์และเฟิร์มแวร์ที่ตรวจพบ")
    args = ap.parse_args()

    port = args.port or auto_pick_port()
    if not port:
        print("❌ ไม่พบพอร์ต USB-Serial ที่ต่ออยู่ ลองระบุด้วย --port", file=sys.stderr)
        sys.exit(1)

    try:
        with serial.Serial(port, args.baud, timeout=SER_TIMEOUT) as ser:
            csv_writer = None
            if args.csv:
                file_exists = os.path.exists(args.csv)
                csv_writer = csv.writer(open(args.csv, "a", newline="", encoding="utf-8"))
                if not file_exists:
                    csv_writer.writerow(["timestamp_iso", "raw", "Z", "Y", "X"])

            code, name, fw = probe_device(ser)
            if args.show:
                print(f"🔌 PORT     : {port} @ {args.baud}")
                print(f"🧭 SENSOR   : {name} ({code if code else '-'})")
                print(f"💾 FIRMWARE : {fw if fw else '-'}")

            if args.axis:
                set_axis(ser, args.axis)

            start_stream(ser)
            print("📡 เริ่มอ่านค่า (Ctrl+C เพื่อหยุด)...")

            while True:
                raw = ser.readline()
                if not raw:
                    continue
                text = raw.decode(errors="replace").strip()

                if args.raw:
                    print(text)
                    if csv_writer:
                        csv_writer.writerow([datetime.now().isoformat(timespec="seconds"), text, "", "", ""])
                    continue

                triple = pick_XYZ_float(text)
                if triple is None:
                    print(text)
                    if csv_writer:
                        csv_writer.writerow([datetime.now().isoformat(timespec="seconds"), text, "", "", ""])
                else:
                    z, y, x = triple
                    print(f"X={x:.6g}, Y={y:.6g}, Z={z:.6g}")
                    if csv_writer:
                        csv_writer.writerow([
                            datetime.now().isoformat(timespec="seconds"),
                            text,
                            f"{z:.9g}", f"{y:.9g}", f"{x:.9g}"
                        ])

    except KeyboardInterrupt:
        print("\n🛑 หยุดการทำงาน")
    except serial.SerialException as e:
        print(f"Serial error: {e}", file=sys.stderr)
        sys.exit(2)
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(3)


if __name__ == "__main__":
    main()
 