#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.11"
# dependencies = ["rich>=13.7"]
# ///
"""agent-stream ölçüm takımı: boşta CPU, tarama ve kare maliyeti.

Kullanım: ./bench/bench.py     (depo kökünden ya da herhangi bir yerden)
Sayılar süreç içinde time.process_time ile alınır; süreç dışından ölçmek
yorumlayıcının açılışını da sayar ve boş bir kökte bile %2 gösterir.
"""
import importlib.machinery
import importlib.util
import io
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
TOOL = os.path.join(os.path.dirname(HERE), "agent-stream")
spec = importlib.util.spec_from_loader("ags", importlib.machinery.SourceFileLoader("ags", TOOL))
m = importlib.util.module_from_spec(spec)
sys.modules["ags"] = m
spec.loader.exec_module(m)

from rich.console import Console
from rich.live import Live

WALL = float(os.environ.get("BENCH_WALL", 8))


def stream_idle(backend: str) -> None:
    os.environ["AGENT_STREAM_WATCH"] = backend
    r = m.Reader(m.DEFAULT_ROOT, None, None, True, True, 30)
    r.poll(first=True)
    c0, t0, turns = time.process_time(), time.time(), 0
    while time.time() - t0 < WALL:
        r.poll()
        turns += 1
        r.wait(0.25)
    cpu = time.process_time() - c0
    note = "" if r.watcher.name == backend else f" (→ {r.watcher.name})"
    print(f"  akış boşta · {backend:8}{note:10} {turns:3} tur · CPU {cpu * 1000:6.1f} ms = %{cpu / WALL * 100:.3f}")
    r.close()


def scan_cost() -> None:
    r = m.Reader(m.DEFAULT_ROOT, None, None, True, True, 30, watch=False)
    t = time.process_time()
    files, dirs = r._walk()
    dt = time.process_time() - t
    print(f"  tarama · {len(files)} dosya, {len(dirs)} dizin · {dt * 1000:.1f} ms")


def dash_frames() -> None:
    now = m.datetime.now()
    cmd = m.Cmd(uid="x", sid="a3d10e42", cwd=str(m.HOME / "proje"), branch="main", sub=False,
                tool="Bash", text="npx vitest run test/x.spec.ts\ngrep -n 'foo' app",
                desc="Ölçüm", started=now, ended=now)
    cmd.out = "\n".join(f"satir {i}" for i in range(20))
    lane = m.Lane("a3d10e42", tag="a3d1", cwd=cmd.cwd, branch="main", last=cmd, seen=time.time())
    con = Console(file=io.StringIO(), width=160, height=44, force_terminal=True)
    m.dash_frame({"a": lane}, [], time.time(), 1, con, 4, 4)          # ısınma
    for label, running in (("boşta", False), ("koşarken", True)):
        frames, drawn = 0, 0.0
        c0, t0 = time.process_time(), time.time()
        with Live(console=con, auto_refresh=False, transient=True) as live:
            while time.time() - t0 < WALL:
                n = time.time()
                if (running and n - drawn >= 0.25) or n - drawn >= 5.0:
                    live.update(m.dash_frame({"a": lane, "b": lane}, [cmd] * 5, t0, 12, con, 4, 4),
                                refresh=True)
                    drawn, frames = n, frames + 1
                time.sleep(0.02)
        cpu = time.process_time() - c0
        print(f"  pano {label:9} {frames:3} kare · CPU {cpu * 1000:6.1f} ms = %{cpu / WALL * 100:.2f}")


if __name__ == "__main__":
    print(f"agent-stream {m.VERSION} · pencere {WALL:.0f} sn")
    scan_cost()
    for backend in ("kqueue", "inotify", "poll"):
        try:
            stream_idle(backend)
        except Exception as exc:
            print(f"  akış boşta · {backend:8} atlandı ({exc})")
    dash_frames()
