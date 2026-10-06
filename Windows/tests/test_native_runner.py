import importlib.util
import os
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location("native_runner", ROOT / "Windows/native_runner.py")
runner = importlib.util.module_from_spec(spec)
spec.loader.exec_module(runner)


class NativeRunnerTests(unittest.TestCase):
    def test_observes_real_window_and_closes_the_owned_process(self):
        result = runner.run_native(os.environ["WINDOWS_RUNTIME_FIXTURE"], [],
                                   ROOT / "build/window-fixture.log", dwell=0.2)
        self.assertTrue(result["success"], result)
        self.assertEqual(result["windows"][0]["title"], "Windows Runtime Fixture")

    def test_early_zero_exit_without_a_window_is_not_a_success(self):
        result = runner.run_native(os.environ["WINDOWS_RUNTIME_FIXTURE"], ["--exit-early"],
                                   ROOT / "build/early-exit.log", dwell=0.2)
        self.assertFalse(result["success"], result)
        self.assertFalse(result["window_observed"])
        self.assertEqual(result["returncode"], 0)


if __name__ == "__main__":
    unittest.main()
