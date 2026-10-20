#!/usr/bin/env python3
"""Real directory/regular-file ownership and public ABI checks, no model math."""
import argparse
from collections import Counter
import hashlib
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import unittest

CONFIG=argparse.Namespace()
POLICY=(4095,100,100000,1048576)


def escaped(path):
    return "".join("\\%03o" % b if b>=128 else chr(b) for b in str(path).encode())


class SourceRoot(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.api=str(Path(CONFIG.api).resolve(strict=True))
        cls.faults=str(Path(CONFIG.faults).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix="aesir-source-root-")
        cls.base=Path(cls.temp.name)
        cls.root=cls.base/"model"
        cls.root.mkdir()
        cls.file=cls.root/"tiny.json"
        cls.raw=b"tiny static source bytes\x00\xff"
        cls.file.write_bytes(cls.raw)
        (cls.root/"sub").mkdir()
        (cls.root/"sub"/"nested.json").write_bytes(b"nested")
        (cls.base/"outside.json").write_bytes(b"outside")
        (cls.root/"inside-link").symlink_to("sub/nested.json")
        (cls.root/"escape-link").symlink_to("../outside.json")
        (cls.root/"absolute-link").symlink_to(cls.file)
        (cls.root/"magic-link").symlink_to("/proc/self/fd/0")
        os.mkfifo(cls.root/"pipe")
        cls.sock=socket.socket(socket.AF_UNIX)
        cls.sock.bind(str(cls.root/"socket"))
        cls.evidence=Path(CONFIG.evidence).resolve()
        cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/"runs.json").write_text(json.dumps(cls.records,indent=2)+"\n")
        counts=dict(Counter("accepted" if x["returncode"]==0 else "refused" for x in cls.records))
        (cls.evidence/"summary.json").write_text(json.dumps(counts,indent=2)+"\n")
        print("Native outcomes:",counts)
        cls.sock.close()
        cls.temp.cleanup()

    def child(self, command, trace=None, env=None):
        if trace:
            command=[CONFIG.strace,"-y","-o",str(self.evidence/trace),"-e",
                     "trace=openat,openat2,close,statx,read,write,ioctl,rename",*command]
        command=list(map(str,command))
        result=subprocess.run(command,capture_output=True,text=True,timeout=10,
                              stdin=subprocess.DEVNULL,check=False,env=env)
        self.records.append({"arguments":command,"returncode":result.returncode,
                             "stdout":result.stdout,"stderr":result.stderr})
        self.assertEqual(self.file.read_bytes(),self.raw)
        return result

    def invoke(self,label="tiny.json",policy=POLICY,trace=None,root=None,env=None):
        return self.child([self.binary,root or self.root,label,*policy],trace,env)

    def accept(self,result):
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        return json.loads(result.stdout)

    def refuse(self,result):
        self.assertNotEqual(result.returncode,0,result.stdout)
        self.assertEqual(result.stdout,"")

    def test_public_abi_and_host_guard(self):
        expected=json.loads(Path(CONFIG.layout).read_text())
        r=self.child([self.api,"abi","aarch64"])
        self.assertEqual(r.returncode,0,r.stderr)
        self.assertEqual(r.stdout.strip(),expected["bytes_hex"])
        for arch in ("x86_64","arm","","unknown"):
            self.refuse(self.child([self.api,"abi",arch]))
        value=self.accept(self.invoke(trace="regular.strace"))
        self.assertEqual(value["source_bytes"],len(self.raw))
        self.assertIs(value["file_admitted"],True)
        for flag in ("tensor_header_parsed","source_fingerprint_verified","hardware_fit_verified","execution_tested"):
            self.assertIs(value[flag],False)
        text=(self.evidence/"regular.strace").read_text()
        lines=[line for line in text.splitlines() if "openat2(" in line]
        self.assertEqual(len(lines),1)
        for token in ("RESOLVE_BENEATH","RESOLVE_NO_MAGICLINKS","O_CLOEXEC","O_NONBLOCK"):
            self.assertIn(token,lines[0])
        self.assertNotIn("ioctl(",text)
        self.assertFalse(any("read(" in line and f"<{self.file}>" in line for line in text.splitlines()))
        self.assertEqual(sum("close(" in line and f"<{self.file}>" in line for line in text.splitlines()),1)
        self.assertEqual(sum("close(" in line and f"<{self.root}>" in line for line in text.splitlines()),1)

    def test_nested_paths_and_symlinks(self):
        labels=("sub/nested.json","inside-link","./tiny.json","sub/../tiny.json","sub//nested.json")
        for label in labels:
            value=self.accept(self.invoke(label))
            self.assertEqual(value["label"],label)
            self.assertEqual(value["source_path"],str(self.root)+"/"+label)
        name="Æsir-🜁.json"
        (self.root/name).write_bytes(b"unicode")
        self.assertEqual(self.accept(self.invoke(name))["source_bytes"],7)
        link=self.base/"root-link"
        link.symlink_to(self.root,target_is_directory=True)
        self.accept(self.invoke(root=link))
        for label in ("../outside.json","escape-link","absolute-link","magic-link",
                      str(self.file),"","missing.json",".","sub","pipe","socket"):
            self.refuse(self.invoke(label))
        for mode in ("nullabel","nulroot"):
            self.refuse(self.child([self.api,mode,self.root,"tiny.json"]))
        for root in (self.base/"missing",self.file,self.root/"pipe"):
            self.refuse(self.invoke(root=root))

    def test_exact_policies_and_mutated_state(self):
        n=len(str(self.root).encode())
        m=len("tiny.json")
        exact=(n,1,n+m+1,len(self.raw))
        value=self.accept(self.invoke(policy=exact))
        self.assertEqual(value["attempts"],1)
        self.assertEqual(value["work_units"],n+m+1)
        for index in (0,2,3):
            policy=list(exact);policy[index]-=1
            self.refuse(self.invoke(policy=policy))
        for index in range(4):
            for val in (0,-1):
                policy=list(POLICY);policy[index]=val
                self.refuse(self.child([self.api,"plain",self.root,"tiny.json",*policy]))
        self.refuse(self.invoke(policy=(4096,*POLICY[1:])))
        self.refuse(self.child([self.api,"repeat",self.root,"tiny.json",*exact]))
        empty=self.root/"empty.json";empty.write_bytes(b"")
        self.assertEqual(self.accept(self.invoke("empty.json",policy=(*POLICY[:3],1)))["source_bytes"],0)
        sparse=self.root/"sparse.json"
        with sparse.open("wb") as stream:stream.truncate(1048577)
        self.refuse(self.invoke("sparse.json"))
        long="q"*120
        (self.root/long).write_bytes(b"x")
        self.refuse(self.invoke(long,policy=(n,*POLICY[1:])))
        for field in ("path","files","work","source","attempts","used"):
            for value in (-1,-9223372036854775808):
                self.refuse(self.child([self.api,"mutate",self.root,"tiny.json",field,value]))
        for field,value in (("path",4096),("attempts",101),("used",100001)):
            self.refuse(self.child([self.api,"mutate",self.root,"tiny.json",field,value]))

    def test_descriptor_transfer_and_cleanup(self):
        for mode in ("plain","implicit","transfer","cycles","closedroot","unwind"):
            result=self.child([self.api,mode,self.root,"tiny.json"],f"{mode}.strace")
            if mode in ("closedroot","unwind"):
                self.refuse(result)
            else:
                self.accept(result)
            trace=(self.evidence/f"{mode}.strace").read_text()
            count=40 if mode=="cycles" else 0 if mode=="closedroot" else 1
            self.assertEqual(sum("close(" in line and f"<{self.file}>" in line for line in trace.splitlines()),count)
            self.assertEqual(sum("close(" in line and f"<{self.root}>" in line for line in trace.splitlines()),1)
            self.assertNotIn("ioctl(",trace)
        old=self.base/"rename-before";old.mkdir()
        (old/"tiny.json").write_bytes(b"rename")
        new=self.base/"rename-after"
        self.accept(self.child([self.api,"rename",old,"tiny.json",new],"rename.strace"))
        self.assertFalse(old.exists())
        self.assertEqual((new/"tiny.json").read_bytes(),b"rename")

    def test_injected_failures_close_same_descriptors(self):
        for mode in ("root","open","enosys","statx","mask","type","file_close","root_close","transfer_statx"):
            env=os.environ.copy()
            env.update(LD_PRELOAD=self.faults,AESIR_ROOT_FAULT_PATH=str(self.root),
                       AESIR_ROOT_FAULT_LABEL="tiny.json",AESIR_ROOT_FAULT_MODE=mode)
            if mode=="transfer_statx":
                self.refuse(self.child([self.api,"transfer",self.root,"tiny.json"],f"fault-{mode}.strace",env))
            else:
                self.refuse(self.invoke(trace=f"fault-{mode}.strace",env=env))
            text=(self.evidence/f"fault-{mode}.strace").read_text()
            root_closes=sum("close(" in line and f"<{self.root}>" in line for line in text.splitlines())
            file_closes=sum("close(" in line and f"<{self.file}>" in line for line in text.splitlines())
            self.assertEqual(root_closes,0 if mode=="root" else 1)
            self.assertEqual(file_closes,0 if mode in ("root","open","enosys") else 1)
            if mode=="enosys":
                self.assertFalse(any("openat(" in line and "tiny.json" in line for line in text.splitlines()))


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    for name in ("binary","api","faults","layout","strace","evidence"):
        parser.add_argument("--"+name,required=True)
    CONFIG,rest=parser.parse_known_args()
    unittest.main(argv=["source-root",*rest])
