import os
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from web_runner import run_web

class WebRunnerTests(unittest.TestCase):
    def test_real_server_response_and_owned_process_cleanup(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            (root/'index.html').write_text('<title>runtime fixture</title>',encoding='utf-8')
            result=run_web([sys.executable,'-m','http.server','{port}','--bind','127.0.0.1'],root,
                           os.environ,root/'server.log','runtime fixture',timeout=10)
            self.assertTrue(result['success'], result)
            self.assertTrue(result['server_stopped'])

    def test_failed_start_cannot_be_reported_as_success(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary)
            result=run_web([sys.executable,'-c','raise SystemExit(9)'],root,os.environ,root/'error.log','fixture',timeout=2)
            self.assertFalse(result['success'])
            self.assertEqual(result['early_exit'],9)
            self.assertTrue(result['server_stopped'])
