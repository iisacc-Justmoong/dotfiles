import json
import os
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from workspace_runner import compose_windows_path, contained, execute


class WorkspaceRunnerTests(unittest.TestCase):
    def test_windows_path_deduplicates_native_and_forward_slash_spellings(self):
        path = compose_windows_path(["C:/Tools/node/", "C:/Qt/bin"], "c:\\tools\\NODE;C:\\Windows;C:/Qt/bin")
        self.assertEqual(path, "C:\\Tools\\node;C:\\Qt\\bin;C:\\Windows")

    def test_failure_records_log_and_stops_later_steps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = {"name": "fixture", "path": ".", "kind": "command", "steps": [
                {"phase": "runtime", "command": ["{python}", "-c", "print('observed'); raise SystemExit(7)"]},
                {"phase": "runtime", "command": ["{python}", "-c", "raise SystemExit(0)"]}]}
            result = execute(project, root, os.environ, {"runtime"}, root)
            self.assertEqual(result["status"], "failed")
            self.assertEqual(len(result["steps"]), 1)
            self.assertEqual(result["steps"][0]["returncode"], 7)
            self.assertIn("observed", Path(result["steps"][0]["log"]).read_text())

    def test_success_runs_real_interpreter(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = {"name": "fixture", "path": ".", "kind": "command", "steps": [
                {"phase": "runtime", "command": ["{python}", "-c", "print('success')"]}]}
            self.assertEqual(execute(project, root, os.environ, {"runtime"}, root)["status"], "passed")

    def test_project_dependency_path_precedes_inherited_runtime(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            project = {"name": "fixture", "path": ".", "steps": [{"phase": "runtime",
                "prepend_path": ["C:/Legacy/bin"], "command": ["{python}", "-c", "import os; print(os.environ['PATH'])"]}]}
            result = execute(project, root, {"PATH": "C:\\Modern\\bin;C:\\Legacy\\bin"}, {"runtime"}, root)
            self.assertEqual(result["status"], "passed")
            self.assertEqual(Path(result["steps"][0]["log"]).read_text().strip(), "C:\\Legacy\\bin;C:\\Modern\\bin")

    def test_workspace_boundary_and_platform_exclusion(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            with self.assertRaises(ValueError):
                contained(root, "../outside")
            result = execute({"path": ".", "excluded": "macOS only"}, root, os.environ, {"runtime"}, root)
            self.assertEqual(result["status"], "excluded")

    def test_manifest_has_unique_projects_and_explicit_mac_exclusions(self):
        manifest = json.loads((Path(__file__).resolve().parents[1] / "projects.json").read_text(encoding="utf-8"))
        projects = manifest["projects"]
        self.assertEqual(len(projects), 50)
        self.assertEqual(len({p["name"] for p in projects}), 50)
        self.assertEqual({p["name"] for p in projects if p.get("excluded")}, {"Alright", "Time Scopes"})
        for project in projects:
            if project.get("kind") != "documentation" and not project.get("excluded"):
                self.assertTrue(any(step["phase"] == "runtime" for step in project["steps"]), project["name"])


if __name__ == "__main__":
    unittest.main()
