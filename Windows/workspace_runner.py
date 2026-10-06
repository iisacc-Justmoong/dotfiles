"""Replay each project's recorded Windows build and runtime commands."""
import argparse
import json
import os
import ntpath
from pathlib import Path
import subprocess
import sys
import time

from native_runner import run_native
from web_runner import run_web


def expand(value, root):
    return str(value).replace("{workspace}", str(root)).replace("{python}", sys.executable)


def contained(root, relative):
    path = (root / relative).resolve()
    if not path.is_relative_to(root.resolve()):
        raise ValueError(f"Project path escapes the workspace: {relative}")
    return path


def compose_windows_path(paths, inherited):
    """Keep native tools reachable without duplicating a captured machine PATH."""
    result = []
    seen = set()
    for value in [*paths, *inherited.split(";")]:
        if not value:
            continue
        normalized = ntpath.normpath(value)
        key = normalized.casefold()
        if key not in seen:
            seen.add(key)
            result.append(normalized)
    return ";".join(result)


def execute(project, root, environment, phases, output):
    path = contained(root, project["path"])
    if project.get("excluded"):
        return {"status": "excluded", "reason": project["excluded"]}
    if project.get("kind") == "documentation":
        readme = contained(root, project["path"] + "/README.md")
        return {"status": "documentation", "readme_exists": readme.is_file()}
    result = {"path": str(path), "steps": []}
    for index, step in enumerate(project["steps"]):
        if step["phase"] not in phases:
            continue
        log = output / (project["name"].replace("/", "_") + f"-{index}.log")
        command = [expand(arg, root) for arg in step["command"]]
        local_environment = dict(environment)
        for key, value in step.get("env", {}).items():
            local_environment[key.upper()] = expand(value, root)
        if step.get("prepend_path"):
            local_environment["PATH"] = compose_windows_path(
                [expand(value, root) for value in step["prepend_path"]], local_environment.get("PATH", ""))
        if step.get("http"):
            record = run_web(command, contained(root, step.get("cwd", project["path"])), local_environment,
                             log, step["http"]["expected"], step["http"].get("path", "/"),
                             timeout=step.get("timeout", 60))
            record["phase"] = step["phase"]
            result["steps"].append(record)
            if not record["success"]: break
        elif step.get("native"):
            local_environment["QT_QPA_PLATFORM"] = "windows"
            record = run_native(command[0], command[1:], log,
                                timeout=step.get("timeout", 60), environment=local_environment)
            record["phase"] = step["phase"]
            result["steps"].append(record)
            if not record["success"]:
                break
        else:
            start = time.monotonic()
            with log.open("w", encoding="utf-8") as stream:
                try:
                    run = subprocess.run(command, cwd=contained(root, step.get("cwd", project["path"])),
                                         env=local_environment, stdout=stream, stderr=subprocess.STDOUT,
                                         timeout=step.get("timeout", 3600))
                    code = run.returncode
                except subprocess.TimeoutExpired:
                    code = 124
                except OSError as error:
                    stream.write(str(error))
                    code = 127
            result["steps"].append({"phase": step["phase"], "command": command,
                                    "returncode": code, "log": str(log),
                                    "seconds": round(time.monotonic() - start, 2), "success": code == 0})
            if code:
                break
    result["status"] = "passed" if result["steps"] and all(x["success"] for x in result["steps"]) else "failed"
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--workspace", type=Path, default=Path(__file__).resolve().parents[2])
    parser.add_argument("--manifest", type=Path, default=Path(__file__).with_name("projects.json"))
    parser.add_argument("--projects", nargs="*")
    parser.add_argument("--phase", choices=("runtime", "build", "all"), default="runtime")
    parser.add_argument("--list", action="store_true")
    parser.add_argument("--launch", action="store_true", help="Open one desktop app with its recorded dependency environment")
    args = parser.parse_args()
    root = args.workspace.resolve(strict=True)
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    projects = manifest["projects"]
    if args.projects:
        missing = set(args.projects) - {p["name"] for p in projects}
        if missing:
            parser.error("Unknown projects: " + ", ".join(sorted(missing)))
        projects = [p for p in projects if p["name"] in args.projects]
    if args.list:
        for project in projects:
            print(project["name"], project["path"], project.get("excluded", project["kind"]))
        return 0
    if os.name != "nt":
        parser.error("This manifest requires Windows")
    environment = {key.upper(): value for key, value in os.environ.items()}
    for key, value in manifest["environment"].items():
        environment[key] = expand(value, root)
    environment["PATH"] = compose_windows_path(
        [expand(value, root) for value in manifest["path"]], os.environ.get("PATH", ""))
    if args.launch:
        if len(projects) != 1 or projects[0].get("excluded"):
            parser.error("--launch requires exactly one supported desktop project via --projects")
        native = next((step for step in projects[0]["steps"] if step.get("native")), None)
        if native is None:
            parser.error("The selected project does not have a desktop executable")
        for key, value in native.get("env", {}).items():
            environment[key.upper()] = expand(value, root)
        if native.get("prepend_path"):
            environment["PATH"] = compose_windows_path(
                [expand(value, root) for value in native["prepend_path"]], environment.get("PATH", ""))
        environment["QT_QPA_PLATFORM"] = "windows"
        command = [expand(value, root) for value in native["command"]]
        return subprocess.run(command, cwd=str(Path(command[0]).parent), env=environment).returncode
    phases = {"build", "runtime"} if args.phase == "all" else {args.phase}
    output = contained(root, "dotfiles/build/workspace-runs/" + time.strftime("%Y%m%d-%H%M%S"))
    output.mkdir(parents=True, exist_ok=False)
    results = {}
    for project in projects:
        print(project["name"], "running", flush=True)
        try:
            results[project["name"]] = execute(project, root, environment, phases, output)
        except Exception as error:
            results[project["name"]] = {"status": "failed", "error": str(error)}
        (output / "results.json").write_text(json.dumps(results, ensure_ascii=False, indent=2), encoding="utf-8")
        print(project["name"], results[project["name"]]["status"], flush=True)
    print(output / "results.json")
    return int(any(record["status"] == "failed" for record in results.values()))


if __name__ == "__main__":
    raise SystemExit(main())
