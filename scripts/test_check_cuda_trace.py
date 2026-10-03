"""Synthetic SQLite/transcript adversarial gates, not physical GPU evidence."""
from pathlib import Path
from contextlib import closing
import sqlite3
import tempfile
import unittest

import check_cuda_trace as check
import profile_native_cuda as capture


def fixture(path):
    with closing(sqlite3.connect(path)) as db:
        db.executescript("""
        CREATE TABLE META_DATA_EXPORT(name,value);
        INSERT INTO META_DATA_EXPORT VALUES('EXPORT_PRODUCT_NAME','NVIDIA Nsight Systems'),('EXPORT_PRODUCT_VERSION','2023.4.4.54');
        CREATE TABLE StringIds(id,value);
        INSERT INTO StringIds VALUES(1,'cuLaunchKernelEx'),(2,'packed_projection_test'),(3,'cuStreamSynchronize');
        CREATE TABLE ANALYSIS_DETAILS(duration,startTime,stopTime);
        INSERT INTO ANALYSIS_DETAILS VALUES(1000,100,1100);
        CREATE TABLE PROCESSES(globalPid,pid,name);
        INSERT INTO PROCESSES VALUES(16777216,1,'path/aesir');
        CREATE TABLE TARGET_INFO_GPU(id,name,computeMajor,computeMinor,totalMemory);
        INSERT INTO TARGET_INFO_GPU VALUES(0,'synthetic GPU',7,5,6000000000);
        CREATE TABLE CUPTI_ACTIVITY_KIND_RUNTIME(start,end,globalTid,correlationId,nameId,returnValue);
        INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME VALUES(110,120,16777217,1,1,0),(310,320,16777217,2,1,0),(300,500,16777217,3,3,0);
        CREATE TABLE CUPTI_ACTIVITY_KIND_KERNEL(start,end,deviceId,contextId,streamId,correlationId,globalPid,shortName);
        INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES(130,230,0,1,1,1,16777216,2),(330,430,0,1,1,2,16777216,2);
        CREATE TABLE CUPTI_ACTIVITY_KIND_MEMCPY(start,end,globalPid,bytes,copyKind);
        INSERT INTO CUPTI_ACTIVITY_KIND_MEMCPY VALUES(210,250,16777216,4,2);
        """)


class Contracts(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        self.path = Path(self.directory.name) / "trace.sqlite"
        fixture(self.path)

    def mutate(self, sql):
        with closing(sqlite3.connect(self.path)) as db:
            db.executescript(sql)
            db.commit()

    def rejects(self, sql):
        self.mutate(sql)
        with self.assertRaises((ValueError, sqlite3.Error)):
            check.analyze(self.path)

    def test_valid_union_and_read_only(self):
        before = self.path.read_bytes()
        data = check.analyze(self.path)
        self.assertEqual(data["kernel_count"], 2)
        self.assertEqual(data["gpu_busy_in_kernel_window_ns"], 220)
        self.assertEqual(data["uncovered_in_kernel_window_ns"], 80)
        self.assertEqual(self.path.read_bytes(), before)
        self.assertEqual(check.union_ns([(0, 10), (2, 3), (9, 12), (15, 16)]), 13)

    def test_empty_kernels(self):
        self.rejects("DELETE FROM CUPTI_ACTIVITY_KIND_KERNEL")

    def test_missing_table(self):
        self.rejects("DROP TABLE PROCESSES")

    def test_view_rejected(self):
        self.rejects("ALTER TABLE StringIds RENAME TO original; CREATE VIEW StringIds AS SELECT * FROM original")

    def test_wrong_exporter(self):
        self.rejects("UPDATE META_DATA_EXPORT SET value='2026.1' WHERE name='EXPORT_PRODUCT_VERSION'")

    def test_timestamp_reversal(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET end=start-1 WHERE correlationId=1")

    def test_timestamp_outside(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET end=1101 WHERE correlationId=1")

    def test_noninteger_timestamp(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET start=130.5 WHERE correlationId=1")

    def test_foreign_pid(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET globalPid=33554432 WHERE correlationId=1")

    def test_wrong_executable(self):
        self.rejects("UPDATE PROCESSES SET name='ollama'")

    def owned_range(self):
        self.mutate("""CREATE TABLE NVTX_EVENTS(start,end,eventType,globalTid,endGlobalTid,text,textId);
                    INSERT INTO NVTX_EVENTS VALUES(100,500,59,16777217,NULL,'aesir.fixture.prefill',NULL);""")

    def test_exact_probe_pid_and_range(self):
        self.owned_range()
        result = check.analyze(self.path, expected_pid=1, nvtx_range="aesir.fixture.prefill")
        self.assertEqual(result["owned_nvtx_range"]["duration_ns"], 400)
        with self.assertRaises(ValueError):
            check.analyze(self.path, expected_pid=2, nvtx_range="aesir.fixture.prefill")

    def test_missing_or_duplicate_range(self):
        self.owned_range()
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="missing")
        self.mutate("INSERT INTO NVTX_EVENTS SELECT * FROM NVTX_EVENTS")
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="aesir.fixture.prefill")

    def test_range_type_owner_and_completion(self):
        for sql in ("UPDATE NVTX_EVENTS SET eventType=60", "UPDATE NVTX_EVENTS SET end=NULL",
                    "UPDATE NVTX_EVENTS SET globalTid=33554433",
                    "UPDATE NVTX_EVENTS SET endGlobalTid=16777218"):
            with self.subTest(sql=sql):
                self.owned_range()
                self.mutate(sql)
                with self.assertRaises(ValueError):
                    check.analyze(self.path, nvtx_range="aesir.fixture.prefill")
                self.mutate("DROP TABLE NVTX_EVENTS")

    def test_launch_thread_and_range(self):
        self.owned_range()
        self.mutate("UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET globalTid=16777218 WHERE correlationId=1")
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="aesir.fixture.prefill")
        self.mutate("UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET globalTid=16777217; UPDATE NVTX_EVENTS SET start=121")
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="aesir.fixture.prefill")

    def test_work_outside_synchronized_range(self):
        self.owned_range()
        self.mutate("UPDATE NVTX_EVENTS SET end=420")
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="aesir.fixture.prefill")
        self.mutate("UPDATE NVTX_EVENTS SET end=500; UPDATE CUPTI_ACTIVITY_KIND_MEMCPY SET end=501")
        with self.assertRaises(ValueError):
            check.analyze(self.path, nvtx_range="aesir.fixture.prefill")

    def test_registered_range_string(self):
        self.owned_range()
        self.mutate("INSERT INTO StringIds VALUES(4,'aesir.fixture.prefill'); UPDATE NVTX_EVENTS SET text=NULL,textId=4")
        self.assertEqual(check.analyze(self.path, nvtx_range="aesir.fixture.prefill")["kernel_count"], 2)

    def test_outside_work_retained_and_fully_validated(self):
        self.owned_range()
        self.mutate("""INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME VALUES(510,520,16777217,4,1,0);
                    INSERT INTO CUPTI_ACTIVITY_KIND_KERNEL VALUES(530,630,0,1,1,4,16777216,2);""")
        result = check.analyze(self.path, nvtx_range="aesir.fixture.prefill")
        self.assertEqual(result["kernel_count"], 2)
        self.assertEqual(result["complete_capture_kernel_count"], 3)
        self.assertEqual(result["excluded_kernel_count"], 1)
        self.mutate("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET shortName=999 WHERE correlationId=4")
        with self.assertRaises(ValueError): check.analyze(self.path, nvtx_range="aesir.fixture.prefill")
        self.mutate("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET shortName=2 WHERE correlationId=4")
        self.mutate("UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET returnValue=1 WHERE correlationId=4")
        with self.assertRaises(ValueError): check.analyze(self.path, nvtx_range="aesir.fixture.prefill")

    def test_unknown_name(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_KERNEL SET shortName=99")

    def test_missing_launch(self):
        self.rejects("DELETE FROM CUPTI_ACTIVITY_KIND_RUNTIME WHERE correlationId=1")

    def test_missing_kernel(self):
        self.rejects("DELETE FROM CUPTI_ACTIVITY_KIND_KERNEL WHERE correlationId=1")

    def test_failed_launch(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET returnValue=1 WHERE correlationId=1")

    def test_duplicate_launch(self):
        self.rejects("INSERT INTO CUPTI_ACTIVITY_KIND_RUNTIME SELECT * FROM CUPTI_ACTIVITY_KIND_RUNTIME WHERE correlationId=1")

    def test_foreign_api(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_RUNTIME SET globalTid=33554433 WHERE correlationId=3")

    def test_foreign_copy(self):
        self.rejects("UPDATE CUPTI_ACTIVITY_KIND_MEMCPY SET globalPid=33554432")

    def test_sidecar_and_symlink(self):
        sidecar = Path(str(self.path) + "-wal")
        sidecar.write_text("active")
        with self.assertRaises(ValueError):
            check.analyze(self.path)
        sidecar.unlink()
        link = self.path.parent / "link"
        link.symlink_to(self.path)
        with self.assertRaises(OSError):
            check.analyze(link)

    def test_size_and_row_bounds(self):
        from unittest.mock import patch
        with patch.object(check, "MAX_BYTES", 100), self.assertRaises(ValueError):
            check.analyze(self.path)
        with patch.object(check, "MAX_ROWS", 1), self.assertRaises(ValueError):
            check.analyze(self.path)

    def test_owned_child_timeout_reaps_process(self):
        import subprocess
        import sys
        log = self.path.parent / "timeout.txt"
        with self.assertRaises(subprocess.TimeoutExpired):
            capture.run([sys.executable, "-c", "import time; time.sleep(10)"], log, .05, {})
        self.assertTrue(log.is_file())

    def test_existing_capture_directory_refuses_before_gpu(self):
        from unittest.mock import patch
        with patch("sys.argv", ["profile_native_cuda.py", "--prompt", str(self.path),
                                "--weights-sha256", "a" * 64,
                                "--output-dir", str(self.path.parent)]), patch.object(capture, "validate_build") as gate:
            with self.assertRaises(FileExistsError):
                capture.main()
            gate.assert_not_called()

    def test_special_input_rejected_before_read(self):
        import os
        fifo = self.path.parent / "fifo"
        os.mkfifo(fifo)
        with self.assertRaises(ValueError):
            capture.read_text(fifo, 1024)

    def test_transcript_requires_complete_matching_counts(self):
        text = ('backend=cuda; model=llama-3B; layers=28/28; cpu_offload=0; context=4096; '
                '\n## Turn 1\nAssistant: A public answer.\n\n'
                '[turn=1 prompt_tokens=37 generated_tokens=32 context_used=70 max_new_tokens=32 finish=length backend=cuda cpu_offload=0]\nCompleted turns: 1\n')
        self.assertEqual(capture.completion(text, 32)["answer"], "A public answer.")
        for bad in (text.replace('Completed turns: 1', ''), text + text,
                    text.replace('generated_tokens=32', 'generated_tokens=31'),
                    text.replace('context_used=70', 'context_used=9000'),
                    text.replace('backend=cuda;', 'backend=cpu;')):
            with self.assertRaises(ValueError):
                capture.completion(bad, 32)


if __name__ == "__main__":
    unittest.main()
