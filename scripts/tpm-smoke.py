#!/usr/bin/env python3
"""Initialize a real TPM without touching user VM disks or booting a guest OS."""
import json
from pathlib import Path
import platform
import shutil
import subprocess
import tempfile
import time


def engine_run(qemu, accelerator, extra=()):
    commands = [
        {"execute": "qmp_capabilities", "id": "caps"},
        {"execute": "query-status", "id": "status"},
    ]
    if extra:
        commands.append({"execute": "query-tpm", "id": "tpm"})
        commands.append({"execute": "query-block", "id": "blocks"})
    commands.append({"execute": "quit", "id": "quit"})
    cpu = "host" if accelerator == "hvf" else "cortex-a72"
    result = subprocess.run(
        [qemu, "-machine", "virt", "-accel", accelerator, "-cpu", cpu,
         "-m", "256", "-smp", "1", "-nodefaults", "-display", "none",
         "-serial", "none", "-monitor", "none", "-nic", "none", "-S",
         "-qmp", "stdio", *extra],
        input="".join(json.dumps(c) + "\n" for c in commands),
        capture_output=True, text=True, timeout=15,
    )
    if result.returncode:
        raise RuntimeError(f"{accelerator}: exit {result.returncode}: {result.stderr}")
    responses = {}
    for line in result.stdout.splitlines():
        message = json.loads(line)
        if "id" in message:
            responses[message["id"]] = message
    for command in commands:
        reply = responses.get(command["id"], {})
        if "return" not in reply:
            raise RuntimeError(f"Missing successful QMP response: {command}: {reply}")
    if extra:
        tpms = responses["tpm"]["return"]
        if not any(tpm.get("id") == "tpm0" for tpm in tpms):
            raise RuntimeError(f"TPM was not realized: {tpms}")
        optical = [item for item in responses["blocks"]["return"] if "installer-cd" in item.get("qdev", "")]
        if len(optical) != 1 or not optical[0].get("removable") or not optical[0].get("inserted", {}).get("ro"):
            raise RuntimeError(f"Installer must be an inserted read-only CD/DVD: {optical}")


def check_tpm(qemu, swtpm, accelerator):
    # A short /tmp path also works with macOS' Unix socket path limit.
    with tempfile.TemporaryDirectory(prefix="og-tpm-", dir="/tmp") as temporary:
        root = Path(temporary)
        state = root / "state"
        state.mkdir(mode=0o700)
        socket = root / "tpm.sock"
        iso = root / "test.iso"
        iso.write_bytes(bytes(1024 * 1024))  # Fixture medium only, not a bootable OS.
        with (root / "swtpm.log").open("w+") as log:
            process = subprocess.Popen(
                [swtpm, "socket", "--tpm2", "--tpmstate", f"dir={state}",
                 "--ctrl", f"type=unixio,path={socket},terminate",
                 "--flags", "not-need-init"],
                stdin=subprocess.DEVNULL, stdout=log, stderr=log,
            )
            try:
                deadline = time.monotonic() + 5
                while not socket.exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        log.seek(0)
                        raise RuntimeError("swtpm failed to start: " + log.read())
                    time.sleep(0.02)
                engine_run(qemu, accelerator, [
                    "-chardev", f"socket,id=chrtpm,path={socket}",
                    "-tpmdev", "emulator,id=tpm0,chardev=chrtpm",
                    "-device", "tpm-tis-device,tpmdev=tpm0,ppi=off",
                    "-device", "qemu-xhci,id=usb",
                    "-blockdev", json.dumps({"driver": "raw", "node-name": "installer", "read-only": True,
                        "file": {"driver": "file", "filename": str(iso)}}),
                    "-device", "usb-bot,id=installer-usb,bus=usb.0",
                    "-device", "scsi-cd,id=installer-cd,drive=installer,bus=installer-usb.0,scsi-id=0,lun=0,bootindex=1",
                ])
            finally:
                if process.poll() is None:
                    process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait()
    print(f"PASS: {accelerator} initialized a real TPM with ppi=off; QMP confirmed tpm0 and an inserted read-only CD/DVD.")


def main():
    qemu = shutil.which("qemu-system-aarch64")
    swtpm = shutil.which("swtpm")
    if not qemu or not swtpm:
        raise RuntimeError("qemu-system-aarch64 and swtpm are required")
    print(subprocess.check_output([qemu, "--version"], text=True).splitlines()[0])
    check_tpm(qemu, swtpm, "tcg")
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        print("HVF NOT TESTED: runner is not an Apple Silicon Mac.")
        return
    try:
        engine_run(qemu, "hvf")
    except RuntimeError as error:
        # Probe without TPM first: lack of nested virtualization is not the TPM bug.
        message = str(error)
        if any(reason in message for reason in ["HV_UNSUPPORTED", "HV_DENIED", "HV_ERROR", "not supported", "invalid accelerator"]):
            print("HVF NOT TESTED: this runner cannot create a hardware VM: " + message)
            return
        raise
    # Once plain HVF works, any TPM initialization error must fail CI.
    check_tpm(qemu, swtpm, "hvf")


if __name__ == "__main__":
    main()
