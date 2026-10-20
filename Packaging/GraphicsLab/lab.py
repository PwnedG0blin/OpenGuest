#!/usr/bin/env python3
"""Experimental Stratovo graphics lab. No shell execution, no writes to the source VM."""
import argparse
import contextlib
from collections import deque
import fcntl
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shlex
import shutil
import stat
import subprocess
import sys
import tarfile
import tempfile
import time
import urllib.request
import zipfile

def prepare_runtime_dependencies(root):
    import importlib.util
    spec = importlib.util.spec_from_file_location('stratovo_runtime_dependencies', Path(__file__).with_name('runtime_dependencies.py'))
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.prepare(root)


def regular(path):
    path = Path(path)
    if not stat.S_ISREG(path.lstat().st_mode):
        raise RuntimeError("Keine normale Datei: " + str(path))
    return path


def directory(path):
    path = Path(path).absolute()
    # Reject linked ancestors, including dangling links, before any mutation.
    for item in [path] + list(path.parents):
        if item.is_symlink():
            raise RuntimeError("Verknüpfungen sind im Grafiklabor nicht erlaubt: " + str(item))
    path.mkdir(parents=True, exist_ok=True, mode=0o700)
    if not path.is_dir():
        raise RuntimeError("Ordner fehlt: " + str(path))
    return path


@contextlib.contextmanager
def locked(path):
    fd = os.open(str(path), os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise RuntimeError("Ungültige Sitzungssperre.")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            raise RuntimeError("Windows beziehungsweise ein Grafiktest läuft bereits. Zuerst vollständig beenden.")
        yield
    finally:
        os.close(fd)


def write_json(path, value):
    path = Path(path)
    fd, tmp = tempfile.mkstemp(prefix=".receipt-", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w") as out:
            json.dump(value, out, indent=2)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def download(url, target, size=None, digest=None):
    target = Path(target)
    if not url.startswith("https://"):
        raise RuntimeError("Download benötigt HTTPS.")
    def valid(path):
        if not path.exists() or path.is_symlink() or not path.is_file():
            return False
        if size is not None and path.stat().st_size != size:
            return False
        if digest:
            h = hashlib.sha256()
            with regular(path).open("rb") as src:
                for block in iter(lambda: src.read(1024 * 1024), b""):
                    h.update(block)
            return h.hexdigest() == digest.removeprefix("sha256:")
        return True
    if valid(target):
        return target
    fd, tmp = tempfile.mkstemp(prefix=".download-", dir=str(target.parent))
    try:
        print("Lade", target.name, flush=True)
        with os.fdopen(fd, "wb") as out, urllib.request.urlopen(url, timeout=60) as src:
            shutil.copyfileobj(src, out, 1024 * 1024)
        if not valid(Path(tmp)):
            raise RuntimeError("Größe oder Prüfsumme stimmt nicht: " + target.name)
        os.replace(tmp, target)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)
    return target


def extract_zip(archive, target):
    target = directory(target)
    with zipfile.ZipFile(regular(archive)) as z:
        for item in z.infolist():
            parts = Path(item.filename).parts
            if item.filename.startswith("/") or ".." in parts or stat.S_ISLNK(item.external_attr >> 16):
                raise RuntimeError("Unsicherer Eintrag im Treiberarchiv.")
        z.extractall(target)


def run(args, *, cwd=None, env=None, capture=False):
    args = [str(a) for a in args]
    print("+", shlex.join(args), flush=True)
    if capture:
        return subprocess.check_output(args, cwd=cwd, env=env, text=True)
    subprocess.run(args, cwd=cwd, env=env, check=True)


def write_log(path, text, append=False):
    path = Path(path)
    directory(path.parent)
    fd = os.open(str(path), os.O_CREAT | os.O_WRONLY | os.O_NOFOLLOW | (os.O_APPEND if append else os.O_TRUNC), 0o600)
    with os.fdopen(fd, "w") as out:
        out.write(text)


def run_logged(args, logfile, *, cwd=None, env=None):
    """Keep complete compiler output and repeat real errors after the noisy build summary."""
    args = [str(a) for a in args]
    logfile = Path(logfile)
    directory(logfile.parent)
    fd = os.open(str(logfile), os.O_CREAT | os.O_TRUNC | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
    errors = deque(maxlen=20)
    print("+", shlex.join(args), flush=True)
    with os.fdopen(fd, "w") as log:
        with subprocess.Popen(args, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              text=True, encoding="utf-8", errors="replace") as process:
            for line in process.stdout:
                log.write(line); log.flush()
                print(line, end="", flush=True)
                if any(word in line.lower() for word in ("error:", "fatal error", "cannot execute tool", "missing metal toolchain")):
                    errors.append(line.rstrip()[:2000])
            status = process.wait()
    if status:
        message = "Bau fehlgeschlagen (Code %d). Vollständiges Protokoll: %s" % (status, logfile)
        message += "\n" + ("\n".join(errors) if errors else "Keine konkrete Compiler-Fehlerzeile erkannt; vollständiges Protokoll öffnen.")
        write_log(logfile.parent / "Letzter-Fehler.log", message + "\n")
        raise RuntimeError(message)


def metal_probe(root, env):
    """xcrun --find can locate a stub even when the Metal Toolchain is missing."""
    root = Path(root)
    temp = directory(root / "Temp")
    logfile = directory(root / "Logs") / "Metal-Pruefung.log"
    write_log(logfile, "Stratovo · tatsächlicher Metal-Compiler-Test\n")
    try:
        with tempfile.TemporaryDirectory(prefix="metal-pruefung-", dir=temp) as test:
            source = Path(test) / "probe.metal"
            source.write_text("#include <metal_stdlib>\nusing namespace metal;\nkernel void pixelkoje_probe(device uint *out [[buffer(0)]], uint id [[thread_position_in_grid]]) { out[id] = id; }\n")
            for args in (["/usr/bin/xcrun", "--sdk", "macosx", "metal", "-c", str(source), "-o", str(Path(test) / "probe.air")],
                         ["/usr/bin/xcrun", "--sdk", "macosx", "metallib", str(Path(test) / "probe.air"), "-o", str(Path(test) / "probe.metallib")]):
                result = subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=45)
                write_log(logfile, shlex.join(args) + "\n" + result.stdout + "\n", append=True)
                if result.returncode or not Path(args[-1]).is_file():
                    detail = result.stdout.strip() or "Der Compiler hat keine Ausgabedatei erzeugt."
                    message = "Metal-Compiler kann keinen Testshader bauen:\n" + detail + "\nIn Xcode die Metal Toolchain unter Settings > Components prüfen. Details: " + str(logfile)
                    write_log(logfile.parent / "Letzter-Fehler.log", message + "\n")
                    raise RuntimeError(message)
    except (OSError, subprocess.TimeoutExpired) as error:
        raise RuntimeError("Metal-Kompilierung nicht ausführbar: " + str(error))
    print("Metal-Testshader erfolgreich kompiliert und verknüpft.", flush=True)



def libcpp_assertion_setting(root, env):
    """Probe the selected Apple SDK; preserve assertions on modern and older libc++."""
    logfile = directory(Path(root) / "Logs") / "CXX-Pruefung.log"
    write_log(logfile, "Stratovo · libc++-Kompatibilitätsprüfung\n")
    probes = [
        ("-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE",
         "#include <vector>\n#ifndef _LIBCPP_HARDENING_MODE_EXTENSIVE\n#error hardening mode unavailable\n#endif\n#if _LIBCPP_HARDENING_MODE != _LIBCPP_HARDENING_MODE_EXTENSIVE\n#error hardening mode not selected\n#endif\nint main() { std::vector<int> v(1); return v.at(0); }\n"),
        ("-D_LIBCPP_ENABLE_ASSERTIONS=1",
         "#include <vector>\nint main() { std::vector<int> v(1); return v.at(0); }\n")]
    errors = []
    for flag, source in probes:
        args = ["/usr/bin/xcrun", "--sdk", "macosx", "clang++", "-std=c++20", "-x", "c++",
                "-fsyntax-only", flag, "-"]
        try:
            result = subprocess.run(args, input=source, env=env, stdout=subprocess.PIPE,
                                    stderr=subprocess.STDOUT, text=True, timeout=45)
        except (OSError, subprocess.TimeoutExpired) as error:
            raise RuntimeError("C++-SDK-Prüfung nicht ausführbar: " + str(error))
        write_log(logfile, shlex.join(args) + "\n" + result.stdout + "\n", append=True)
        if result.returncode == 0:
            setting = "WK_LIBCPP_ASSERTIONS_CFLAGS=" + flag
            print("ANGLE · C++-Prüfungen: " + flag, flush=True)
            return setting
        errors.append(result.stdout.strip())
    message = "Das gewählte Xcode-SDK kann weder den modernen libc++-Prüfmodus noch den alten Modus kompilieren.\n" + "\n".join(errors) + "\nDetails: " + str(logfile)
    write_log(logfile.parent / "Letzter-Fehler.log", message + "\n")
    raise RuntimeError(message)


def checkout(source, target, env, sparse=False):
    target = directory(target)
    if not (target / ".git").exists():
        run(["/usr/bin/git", "init", target], env=env)
        run(["/usr/bin/git", "remote", "add", "origin", source["url"]], cwd=target, env=env)
    else:
        origin = run(["/usr/bin/git", "remote", "get-url", "origin"], cwd=target, env=env, capture=True).strip()
        if origin != source["url"]:
            raise RuntimeError("Quellordner hat einen anderen Ursprung: " + str(target))
    if sparse:
        run(["/usr/bin/git", "config", "remote.origin.promisor", "true"], cwd=target, env=env)
        run(["/usr/bin/git", "config", "remote.origin.partialclonefilter", "blob:none"], cwd=target, env=env)
        run(["/usr/bin/git", "sparse-checkout", "init", "--cone"], cwd=target, env=env)
        run(["/usr/bin/git", "sparse-checkout", "set", "Source/ThirdParty/ANGLE", "Configurations", "Tools/ccache", "WebKitLibraries/SDKs"], cwd=target, env=env)
    run(["/usr/bin/git", "fetch", "--depth=1"] + (["--filter=blob:none"] if sparse else []) + ["origin", source["commit"]], cwd=target, env=env)
    run(["/usr/bin/git", "checkout", "--detach", source["commit"]], cwd=target, env=env)
    if not sparse:
        run(["/usr/bin/git", "submodule", "update", "--init", "--recursive", "--depth=1"], cwd=target, env=env)
    return target


def extract_source(archive, target, top):
    target = directory(target)
    with tarfile.open(regular(archive)) as tar:
        for member in tar.getmembers():
            parts = Path(member.name).parts
            if not parts or Path(member.name).is_absolute() or ".." in parts or parts[0] != top:
                raise RuntimeError("Unsicherer Pfad im Werkzeugarchiv.")
            if not (member.isfile() or member.isdir()):
                raise RuntimeError("Unerwarteter Verweis im Werkzeugarchiv.")
            output = target / member.name
            for existing in [output] + list(output.parents):
                if existing == target:
                    break
                if existing.is_symlink():
                    raise RuntimeError("Verknüpfung im Werkzeug-Zielordner.")
        tar.extractall(target)
        for member in tar.getmembers():
            if member.isfile():
                (target / member.name).chmod(member.mode & 0o755)
    return target / top


def ensure_pkg_config(root, sources, env):
    if shutil.which("pkg-config", path=env["PATH"]):
        return
    prefix = directory(root / "BuildTools/pkgconf")
    binary = prefix / "bin/pkgconf"
    if not binary.is_file():
        info = sources["pkgconf"]
        cache = directory(root / "Cache")
        cached = cache / "pkgconf.tar.xz"
        bundled = Path(__file__).parent / "pkgconf-2.3.0.tar.xz"
        if not cached.exists() and bundled.is_file():
            shutil.copy2(regular(bundled), cached)
        archive = download(info["url"], cached, size=info["size"], digest=info["digest"])
        source = extract_source(archive, directory(root / "Toolchains"), info["directory"])
        print("Fehlendes pkg-config wird auf dem gewählten Laufwerk gebaut.", flush=True)
        run([source / "configure", "--prefix=" + str(prefix), "--disable-dependency-tracking",
             "--with-pkg-config-dir=/opt/homebrew/lib/pkgconfig:/opt/homebrew/share/pkgconfig"], cwd=source, env=env)
        # The release tarball includes generated Autotools files. Do not require
        # a matching developer Autotools version just because extraction changed timestamps.
        generated = ["ACLOCAL=true", "AUTOCONF=true", "AUTOMAKE=true", "AUTOHEADER=true"]
        run(["make", "-j4"] + generated, cwd=source, env=env)
        run(["make", "install"] + generated, cwd=source, env=env)
    wrapper = prefix / "bin/pkg-config"
    if not wrapper.exists():
        shutil.copy2(regular(binary), wrapper)
    env["PATH"] = str(prefix / "bin") + ":" + env["PATH"]
    env["PKG_CONFIG"] = str(wrapper)


def prerequisites(root, env):
    issues = []
    def probe(args):
        try:
            result = subprocess.run(args, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=30)
            return result.returncode == 0, result.stdout.strip()
        except (OSError, subprocess.TimeoutExpired) as error:
            return False, str(error)
    ok, detail = probe(["/usr/bin/xcrun", "--find", "metal"])
    print("Metal-Werkzeuge: " + (detail if ok else "FEHLEN"), flush=True)
    if not ok:
        issues.append("Vollständiges Xcode mit Metal Toolchain installieren und in Xcode > Settings > Locations als Command Line Tools auswählen. Nur die Command Line Tools reichen für den 3D-Bau nicht.")
    else:
        try:
            metal_probe(root, env)
        except RuntimeError as error:
            issues.append(str(error))
    ok, _ = probe(["/usr/bin/xcodebuild", "-version"])
    if not ok:
        issues.append("Xcode einmal öffnen, Erstinstallation/Lizenz abschließen und das aktive Xcode auswählen.")
    if not shutil.which("pkg-config", path=env["PATH"]):
        print("pkg-config fehlt: wird beim Grafikbau automatisch auf dem gewählten Laufwerk bereitgestellt.", flush=True)
        for name in ("glib-2.0.pc", "pixman-1.pc", "slirp.pc"):
            candidates = [Path("/opt/homebrew/lib/pkgconfig") / name]
            candidates += [Path("/opt/homebrew/opt") / package / "lib/pkgconfig" / name for package in ("glib", "pixman", "libslirp")]
            if not any(path.is_file() for path in candidates):
                issues.append("Entwicklungsbibliothek fehlt: " + name + ". Vorhandene QEMU-/Homebrew-Installation prüfen; Stratovo installiert nichts auf die interne Platte.")
    else:
        for package in ("glib-2.0", "pixman-1", "slirp"):
            ok, _ = probe(["pkg-config", "--exists", package])
            if not ok:
                issues.append("Entwicklungsbibliothek fehlt: " + package + ". Vorhandene QEMU-/Homebrew-Installation prüfen.")
    free = shutil.disk_usage(root).free
    print("Freier Platz auf dem Datenlaufwerk: %.1f GiB" % (free / 1024**3), flush=True)
    if free < 30 * 1024**3:
        issues.append("Mindestens 30 GiB freier Platz für die Grafiklaufzeit benötigt. Die vorhandene Windows-Festplatte wird weiterverwendet.")
    if " " in str(root):
        issues.append("Die experimentellen Buildwerkzeuge benötigen einen Datenpfad ohne Leerzeichen.")
    if issues:
        raise RuntimeError("Vor dem Grafikbau erledigen:\n• " + "\n• ".join(issues))
    print("Voraussetzungen erfüllt. Für den Bau wird kein physischer Windows-PC benötigt.", flush=True)


def runtime_ready(root):
    required = (root / "runtime-ready.json", root / "Runtime/bin/qemu-system-aarch64",
                root / "Runtime/libexec/virgl_render_server", root / "Runtime/lib/libdxmt-native.dylib", root / "GraphicsDrivers.iso")
    return all(path.is_file() and not path.is_symlink() for path in required)


def graphics_pkg_config_path(root):
    return ":".join([str(root / "Runtime/lib/pkgconfig"),
                     "/opt/homebrew/opt/zlib/lib/pkgconfig",
                     "/opt/homebrew/lib/pkgconfig", "/opt/homebrew/share/pkgconfig"])


def prepare_embedded_player(qemu):
    import importlib.util
    path = Path(__file__).with_name("embedded_display.py")
    spec = importlib.util.spec_from_file_location("stratovo_embedded_display", path)
    helper = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(helper)
    helper.patch(qemu)


def upgrade_embedded_player(root, sources, env):
    qemu = root / "Sources/qemu"
    regular(qemu / "ui/cocoa.m")
    commit = run(["/usr/bin/git", "rev-parse", "HEAD"], cwd=qemu, env=env, capture=True).strip()
    if commit != sources["qemu"]["commit"]:
        raise RuntimeError("QEMU-Quelle passt nicht zur vorbereiteten 3D-Laufzeit.")
    backup = directory(root / "PlayerBackup-before-v6")
    binary = regular(root / "Runtime/bin/qemu-system-aarch64")
    if not (backup / binary.name).exists():
        shutil.copy2(binary, backup / binary.name)
    regular(backup / binary.name)
    prepare_embedded_player(qemu)
    build_env = dict(env, PATH=str(root / "BuildTools/bin") + ":" + str(root / "Runtime/bin") + ":" + env["PATH"])
    print("Aktualisiere den eingebetteten 3D-Player. Vorhandene ANGLE-/LLVM-Bauten bleiben erhalten.", flush=True)
    try:
        run_logged(["make", "-j4", "install"], root / "Logs/Player-Build.log", cwd=qemu / "build", env=build_env)
    except BaseException:
        shutil.copy2(backup / binary.name, binary)
        raise
    receipt = json.loads(regular(root / "runtime-ready.json").read_text())
    receipt["embeddedPlayer"] = 1
    receipt["embeddedRevision"] = 6
    write_json(root / "runtime-ready.json", receipt)


def build(root, sources, config, env):
    if runtime_ready(root):
        prepare_runtime_dependencies(root)
        receipt = json.loads(regular(root / "runtime-ready.json").read_text())
        if receipt.get("embeddedPlayer") != 1 or receipt.get("embeddedRevision") != 6:
            upgrade_embedded_player(root, sources, env)
        receipt = json.loads(regular(root / "runtime-ready.json").read_text())
        receipt["runtimeDependencies"] = 1
        write_json(root / "runtime-ready.json", receipt)
        print("3D-Player bereit. Vorhandene Windows-Installation über Windows starten öffnen.", flush=True)
        return
    if " " in str(root):
        raise RuntimeError("Die experimentellen QEMU-Buildwerkzeuge benötigen einen Datenpfad ohne Leerzeichen.")
    env["PKG_CONFIG_PATH"] = graphics_pkg_config_path(root)
    prerequisites(root, env)
    assertion_setting = libcpp_assertion_setting(root, env)
    ensure_pkg_config(root, sources, env)
    for package in ("glib-2.0", "pixman-1", "slirp", "gnutls", "libtasn1", "zlib"):
        run(["pkg-config", "--cflags", "--libs", package], env=env)
    run(["pkg-config", "--atleast-version=3.6.14", "gnutls"], env=env)
    toolchains = directory(root / "Toolchains")
    llvm = Path("/opt/homebrew/opt/llvm@15")
    if not (llvm / "bin/llvm-config").is_file():
        info = sources["llvm15"]
        llvm = toolchains / info["directory"]
        if not (llvm / "bin/llvm-config").is_file():
            archive = download(info["url"], toolchains / "llvm15.tar.xz", size=info["size"])
            # Official pinned LLVM release. Extract links only inside its own tree.
            with tarfile.open(archive) as tar:
                for member in tar.getmembers():
                    name = Path(member.name)
                    if name.is_absolute() or ".." in name.parts or name.parts[0] != info["directory"]:
                        raise RuntimeError("Unerwarteter Pfad im LLVM-Archiv.")
                    if member.issym() or member.islnk():
                        dest = (name.parent / member.linkname) if member.issym() else Path(member.linkname)
                        normalized = Path(os.path.normpath(str(dest)))
                        if normalized.is_absolute() or ".." in normalized.parts or normalized.parts[0] != info["directory"]:
                            raise RuntimeError("Unsichere LLVM-Verknüpfung.")
                tar.extractall(toolchains)
                for member in tar.getmembers():
                    if member.isfile():
                        (toolchains / member.name).chmod(member.mode & 0o755)
    if not run([llvm / "bin/llvm-config", "--version"], env=env, capture=True).startswith("15."):
        raise RuntimeError("DXMT benötigt LLVM 15.")
    venv = root / "BuildTools"
    if not (venv / "bin/python3").exists():
        run([sys.executable, "-m", "venv", venv], env=env)
    run([venv / "bin/python3", "-m", "pip", "install", "meson>=1.3,<1.12", "ninja", "cmake", "PyYAML", "tomli"], env=env)
    env = dict(env, PATH=str(venv / "bin") + ":" + env["PATH"])
    prefix = directory(root / "Runtime")
    src = directory(root / "Sources")
    angle = checkout(sources["angle"], src / "WebKit", env, sparse=True)
    archive = root / "ANGLE.xcarchive"
    run_logged(["/usr/bin/xcodebuild", "archive", "-archivePath", archive, "-derivedDataPath", root / "DerivedData",
         "-scheme", "ANGLE", "-sdk", "macosx", "-arch", "arm64", "-configuration", "Release",
         "WEBCORE_LIBRARY_DIR=/usr/local/lib", "NORMAL_UMBRELLA_FRAMEWORKS_DIR=", "CODE_SIGNING_ALLOWED=NO",
         "MACOSX_DEPLOYMENT_TARGET=14.0", assertion_setting,
         "WK_FIXME_WARNING_CFLAGS=-Wno-deprecated-declarations -Wno-inconsistent-missing-override -Wno-macro-redefined -Wno-undef -Wno-unused-parameter -Wno-error=unnecessary-virtual-specifier -Wno-error=nontrivial-memcall", "CLANG_MODULE_CACHE_PATH=" + str(root / "ModuleCache")],
        root / "Logs/ANGLE-Build.log", cwd=angle / "Source/ThirdParty/ANGLE", env=env)
    angle_inc = angle / "Source/ThirdParty/ANGLE/include"
    angle_lib = archive / "Products/usr/local/lib"
    env["PKG_CONFIG_PATH"] = graphics_pkg_config_path(root)
    env["CMAKE_PREFIX_PATH"] = str(prefix) + ":/opt/homebrew"
    def meson_build(path, subdir, options):
        dest = path / subdir
        if (dest / "meson-private/coredata.dat").exists():
            run(["meson", "setup", "--reconfigure", dest, path] + options, env=env)
        else:
            run(["meson", "setup", dest, path] + options, env=env)
        run(["meson", "compile", "-C", dest, "-j", "4"], env=env)
        run(["meson", "install", "-C", dest], env=env)
    epoxy = checkout(sources["libepoxy"], src / "libepoxy", env)
    meson_build(epoxy, "build", ["-Dc_args=-I" + str(angle_inc), "-Degl=yes", "-Dx11=false", "--prefix=" + str(prefix)])
    dxmt = checkout(sources["dxmt"], src / "dxmt", env)
    meson_build(dxmt, "build-native", ["-Dnative_llvm_path=" + str(llvm), "--buildtype=release", "--prefix=" + str(prefix)])
    virgl = checkout(sources["virglrenderer"], src / "virglrenderer", env)
    meson_build(virgl, "build-arm64", ["-Dc_args=-I" + str(angle_inc), "-Dvenus=false", "-Dneptune=true",
                "-Drender-server-worker=process", "-Dcheck-gl-errors=false", "--pkg-config-path=" + str(prefix / "lib/pkgconfig"), "--prefix=" + str(prefix)])
    qemu = checkout(sources["qemu"], src / "qemu", env)
    prepare_embedded_player(qemu)
    qb = directory(qemu / "build")
    run([qemu / "configure", "--extra-cflags=-I" + str(angle_inc), "--extra-ldflags=-L" + str(angle_lib),
         "--prefix=" + str(prefix), "--target-list=aarch64-softmmu", "--enable-cocoa", "--enable-hvf",
         "--enable-opengl", "--enable-virglrenderer", "--disable-pvg", "--enable-gnutls", "--disable-nettle", "--disable-gcrypt", "--disable-docs", "--disable-gtk", "--disable-sdl", "--disable-werror"], cwd=qb, env=env)
    run(["make", "-j4", "install"], cwd=qb, env=env)
    driver = next(a for a in sources["drivers"]["assets"] if a["name"] == "viogpu3d-arm64x-signed.zip")
    downloaded = download(driver["browser_download_url"], root / driver["name"], size=driver["size"], digest=driver["digest"])
    driver_files = directory(root / "Drivers")
    extract_zip(downloaded, driver_files)
    shutil.copy2(Path(__file__).parent / "INSTALL_GRAPHICS.ps1", driver_files / "INSTALL_GRAPHICS.ps1")
    shutil.copy2(Path(__file__).parent / "INSTALL_GRAPHICS.cmd", driver_files / "INSTALL_GRAPHICS.cmd")
    iso = root / "GraphicsDrivers.iso"
    run(["/usr/bin/hdiutil", "makehybrid", "-o", iso, "-iso", "-joliet", "-default-volume-name", "PKGRAPHICS", driver_files], env=env)
    required = [prefix / "bin/qemu-system-aarch64", prefix / "libexec/virgl_render_server", prefix / "lib/libdxmt-native.dylib", iso]
    for path in required:
        resolved = path.resolve()
        if path != iso and prefix.resolve() not in resolved.parents:
            raise RuntimeError("Grafiklaufzeit verweist außerhalb des Buildordners.")
        regular(resolved)
    test_env = runtime_env(root, env)
    models = run([prefix / "bin/qemu-system-aarch64", "-device", "help"], env=test_env, capture=True)
    if "virtio-ramfb-gl" not in models:
        raise RuntimeError("Gebautes QEMU enthält den benötigten Grafikmodus nicht.")
    prepare_runtime_dependencies(root)
    write_json(root / "runtime-ready.json", {"version": 1, "sources": sources, "backend": "dxmt", "embeddedPlayer": 1, "embeddedRevision": 6, "runtimeDependencies": 1, "builtAt": time.time()})
    print("Grafiklaufzeit fertig. In Stratovo öffnet anschließend die vorhandene oder einmalig erstellte Testkopie.", flush=True)


def runtime_env(root, env):
    return dict(env, NPT_BACKEND="dxmt", ANGLE_DEFAULT_PLATFORM="metal",
                RENDER_SERVER_EXEC_PATH=str(root / "Runtime/libexec/virgl_render_server"),
                DYLD_FALLBACK_LIBRARY_PATH=str(root / "Runtime/lib") + ":" + str(root / "ANGLE.xcarchive/Products/usr/local/lib"),
                VIRGL_LOG_LEVEL="info")


def copy_tree(source, target):
    source, target = Path(source), Path(target)
    for path in [source] + list(source.rglob("*")):
        if not (path.is_file() or path.is_dir()) or path.is_symlink():
            raise RuntimeError("Nicht unterstützter Eintrag in VM-Zustand: " + str(path))
    shutil.copytree(source, target)


def clone_vm(config, root, env):
    original = Path(config["root"]) / "Windows"
    target = root / "TestVM"
    if target.exists():
        regular(target / "clone-ready.json")
        regular(target / "windows.qcow2")
        return target
    disk = regular(original / "windows.qcow2")
    estimate = json.loads(run([config["qemuImg"], "measure", "-f", "qcow2", "-O", "qcow2", "--output=json", disk], env=env, capture=True))
    if shutil.disk_usage(root).free < int(estimate["required"]) + 5 * 1024**3:
        raise RuntimeError("Auf dem Laufwerk fehlt Platz für eine unabhängige Windows-Testkopie.")
    stage = Path(tempfile.mkdtemp(prefix=".TestVM-", dir=root))
    try:
        run([config["qemuImg"], "convert", "-p", "-f", "qcow2", "-O", "qcow2", disk, stage / "windows.qcow2"], env=env)
        run([config["qemuImg"], "compare", "-f", "qcow2", "-F", "qcow2", disk, stage / "windows.qcow2"], env=env)
        secure = original / "SecureBoot/state.json"
        enabled = secure.exists() and json.loads(regular(secure).read_text())["enabled"]
        firmware = original / "SecureBoot/firmware.fd" if enabled else Path(config["firmware"])
        variables = original / "SecureBoot/uefi-vars.fd" if enabled else original / "uefi-vars.fd"
        shutil.copy2(regular(firmware), stage / "firmware.fd")
        shutil.copy2(regular(variables), stage / "uefi-vars.fd")
        copy_tree(original / "TPM", stage / "TPM")
        if (original / "Machine").exists():
            copy_tree(original / "Machine", stage / "Machine")
        write_json(stage / "clone-ready.json", {"version": 1, "source": str(disk), "createdAt": time.time()})
        os.replace(stage, target)
    except BaseException:
        # Only this invocation's newly created staging directory is removed.
        shutil.rmtree(stage)
        raise
    return target


def launch_arguments(root, vm, tpm_socket, qmp_socket):
    identity_file = vm / "Machine/identity.json"
    identity = json.loads(regular(identity_file).read_text()) if identity_file.exists() else {}
    serial = identity.get("serial", "OpenGuestWindows")
    if not re.fullmatch(r"(?:OpenGuestWindows|PK[0-9a-f]{18})", serial):
        raise RuntimeError("Ungültige Seriennummer der Testkopie.")
    def block(name, fmt, path, readonly):
        return json.dumps({"driver": fmt, "node-name": name, "read-only": readonly, "file": {"driver": "file", "filename": str(path)}})
    args = [str(root / "Runtime/bin/qemu-system-aarch64"), "-name", "Stratovo · EXPERIMENTELLER 3D-TEST · eigene Kopie", "-nodefaults",
            "-machine", "virt,pflash0=code,pflash1=vars,gic-version=3", "-accel", "hvf,ipa-granule-size=0x1000", "-cpu", "host", "-smp", "4", "-m", "4096",
            "-blockdev", block("code", "raw", vm / "firmware.fd", True), "-blockdev", block("vars", "raw", vm / "uefi-vars.fd", False),
            "-blockdev", block("system", "qcow2", vm / "windows.qcow2", False), "-device", "nvme,drive=system,serial=" + serial + ",bootindex=1",
            "-vga", "none", "-device", "virtio-ramfb-gl,hostmem=8G,blob=true,venus=false,neptune=true",
            "-display", "cocoa,gl=es", "-device", "qemu-xhci,id=usb", "-device", "usb-tablet,bus=usb.0", "-device", "usb-kbd,bus=usb.0",
            "-chardev", "socket,id=chrtpm,path=" + str(tpm_socket), "-tpmdev", "emulator,id=tpm0,chardev=chrtpm", "-device", "tpm-tis-device,tpmdev=tpm0",
            "-device", "virtio-rng-pci", "-netdev", "user,id=net0", "-device", "virtio-net-pci,netdev=net0",
            "-blockdev", block("drivers", "raw", root / "GraphicsDrivers.iso", True), "-device", "usb-bot,id=drivers-usb,bus=usb.0",
            "-device", "scsi-cd,drive=drivers,bus=drivers-usb.0", "-serial", "stdio", "-monitor", "none", "-qmp", "unix:" + str(qmp_socket) + ",server=on,wait=off"]
    if identity.get("uuid"):
        import uuid
        args += ["-uuid", str(uuid.UUID(identity["uuid"])), "-smbios", "type=1,manufacturer=Pixelkoje,product=Pixelkoje Windows ARM64,serial=" + serial]
    if identity.get("mac"):
        mac = identity["mac"]
        if not re.fullmatch(r"[0-9a-f]{2}(?::[0-9a-f]{2}){5}", mac):
            raise RuntimeError("Ungültige MAC-Adresse.")
        args[args.index("virtio-net-pci,netdev=net0")] += ",mac=" + mac
    return args


def launch(config, root, env):
    if not runtime_ready(root):
        raise RuntimeError("Zuerst in Stratovo Grafiklaufzeit bauen wählen. Es wird noch keine Windows-Testkopie verändert.")
    regular(root / "runtime-ready.json")
    vm = clone_vm(config, root, env)
    for item in ("firmware.fd", "uefi-vars.fd", "windows.qcow2"):
        regular(vm / item)
    with locked(vm / "session.lock"):
        # Short sockets are transient; disks, caches and logs stay on the SSD.
        with tempfile.TemporaryDirectory(prefix="pk-gpu-", dir="/tmp") as sockets:
            tpm_socket = Path(sockets) / "tpm.sock"
            args = [config["swtpm"], "socket", "--tpm2", "--tpmstate", "dir=" + str(vm / "TPM"), "--ctrl", "type=unixio,path=" + str(tpm_socket) + ",terminate", "--flags", "not-need-init"]
            with (root / "Logs/tpm-last.log").open("w") as log:
                tpm = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
                try:
                    for _ in range(100):
                        if tpm_socket.exists():
                            break
                        if tpm.poll() is not None:
                            raise RuntimeError("Test-TPM konnte nicht starten. TPM-Protokoll im Grafiklabor prüfen.")
                        time.sleep(.05)
                    if not tpm_socket.exists():
                        raise RuntimeError("Zeitlimit beim Start des Test-TPM.")
                    print("Eigenes Testfenster startet. Zuerst Treiber vom DVD-Laufwerk PKGRAPHICS installieren. Danach die Testkopie neu starten.", flush=True)
                    qmp = Path(sockets) / "qmp.sock"
                    write_json(root / "running.json", {"qmp": str(qmp)})
                    try:
                        run(launch_arguments(root, vm, tpm_socket, qmp), env=runtime_env(root, env))
                    finally:
                        (root / "running.json").unlink(missing_ok=True)
                finally:
                    if tpm.poll() is None:
                        tpm.terminate()
                        try:
                            tpm.wait(timeout=5)
                        except subprocess.TimeoutExpired:
                            tpm.kill()
                            tpm.wait()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", required=True)
    parser.add_argument("--managed-process-group", action="store_true")
    parser.add_argument("action", choices=["check", "build", "launch", "setup"])
    args = parser.parse_args()
    if platform.system() != "Darwin" or platform.machine() != "arm64":
        raise RuntimeError("Dieses Grafiklabor benötigt einen Apple-Silicon-Mac ohne Rosetta.")
    # Own process group permits cancelling a build without leaving compiler children.
    if args.managed_process_group and os.getpgrp() != os.getpid():
        os.setsid()
    config = json.loads(regular(args.config).read_text())
    base = Path(config["root"]).absolute()
    if regular(base / ".openguest-storage-id").read_text() != config["storageID"]:
        raise RuntimeError("Das ausgewählte Datenlaufwerk fehlt oder wurde ausgetauscht.")
    root = directory(base / "GraphicsLab")
    for sub in ("Temp", "Cache", "Logs", "ModuleCache"):
        directory(root / sub)
    env = dict(os.environ, PKG_CONFIG_PATH=graphics_pkg_config_path(root), TMPDIR=str(root / "Temp") + "/", XDG_CACHE_HOME=str(root / "Cache"),
               PIP_CACHE_DIR=str(root / "Cache/pip"), CLANG_MODULE_CACHE_PATH=str(root / "ModuleCache"),
               GIT_TERMINAL_PROMPT="0", PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin")
    sources = json.loads((Path(__file__).parent / "sources.json").read_text())
    # Serialize build, clone and launches; keep ordinary Stratovo out of the source VM.
    with locked(root / "lab.lock"), locked(base / "Windows/session.lock"):
        try:
            if args.action == "check":
                prerequisites(root, env)
            elif args.action == "build":
                build(root, sources, config, env)
            elif args.action == "setup":
                if not runtime_ready(root):
                    build(root, sources, config, env)
                launch(config, root, env)
            else:
                launch(config, root, env)
        except Exception as error:
            try:
                write_log(root / "Logs/Letzter-Fehler.log", str(error) + "\n")
            except OSError:
                pass
            raise



if __name__ == "__main__":
    try:
        main()
    except (Exception, KeyboardInterrupt) as error:
        print("\nGrafiklabor angehalten:", error, file=sys.stderr, flush=True)
        code = 1
    else:
        code = 0
    sys.exit(code)
