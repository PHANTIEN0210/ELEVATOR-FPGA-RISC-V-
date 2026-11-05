"""Build four byte-wide 16 KiB memory images for the Ibex system top.

objcopy's raw binary starts at the first loadable byte (the Ibex reset PC,
0x80), so the bytes before that address must be restored here.
"""

import pathlib
import sys

ROM_BYTES = 16 * 1024


def main() -> None:
    source = pathlib.Path(sys.argv[1] if len(sys.argv) > 1 else "firmware.bin")
    output_dir = pathlib.Path(sys.argv[2] if len(sys.argv) > 2 else "../src")
    load_address = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x80

    payload = source.read_bytes()
    if load_address < 0 or load_address % 4:
        raise ValueError("Firmware load address must be nonnegative and word aligned")
    if load_address + len(payload) > ROM_BYTES:
        raise ValueError("Firmware image exceeds 16 KiB ROM/RAM")

    image = bytearray(ROM_BYTES)
    image[load_address:load_address + len(payload)] = payload
    output_dir.mkdir(parents=True, exist_ok=True)

    for bank in range(4):
        path = output_dir / f"firmware_bank{bank}.hex"
        path.write_text(
            "".join(f"{image[index]:02x}\n" for index in range(bank, ROM_BYTES, 4)),
            encoding="ascii",
        )

    print(f"Wrote four 4096-byte HEX banks, entry at 0x{load_address:08X}")


if __name__ == "__main__":
    main()

