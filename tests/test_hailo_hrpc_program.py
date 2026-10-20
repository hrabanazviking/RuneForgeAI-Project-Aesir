#!/usr/bin/env python3
"""Frozen public-schema oracle for host program wire values; never uploads."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import struct
import subprocess
import sys
import tempfile
import unittest
from google.protobuf import descriptor_pb2,descriptor_pool,message_factory

CONFIG=argparse.Namespace()
U32=(1<<32)-1
U64=(1<<64)-1
HEADER=struct.Struct('<5I')
MAGIC=0x8a554432
LIFECYCLE={3:'InferModel_Destroy',5:'ConfiguredInferModel_Destroy',
           10:'ConfiguredInferModel_Activate',11:'ConfiguredInferModel_Deactivate',
           12:'ConfiguredInferModel_Shutdown'}


def packet(body,action=2,message_id=17,status=0):
    return (HEADER.pack(MAGIC,len(body),message_id,action,status)+body).hex()


class ProgramWire(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.binary=str(Path(CONFIG.binary).resolve(strict=True))
        cls.temp=tempfile.TemporaryDirectory(prefix='aesir-program-wire-')
        cls.root=Path(cls.temp.name)
        cls.evidence=Path(CONFIG.evidence).resolve();cls.evidence.mkdir(parents=True,exist_ok=True)
        cls.records=[]
        schema=Path(CONFIG.schema).resolve(strict=True)
        header=Path(CONFIG.enum_header).resolve(strict=True)
        assert hashlib.sha256(schema.read_bytes()).hexdigest()=='c44ec3a28d075bae5f814f99491a4f1de0c3cbd026721243e8876c67b5da9225'
        assert hashlib.sha256(header.read_bytes()).hexdigest()=='e02cdb188ac543edd2a4b746c50399b6a74ad8ef1eb230ba5431ae47fccd3a87'
        descriptor=cls.root/'rpc.pb'
        subprocess.run([CONFIG.protoc,'-I',str(schema.parent),'--descriptor_set_out='+str(descriptor),str(schema)],check=True,capture_output=True)
        files=descriptor_pb2.FileDescriptorSet.FromString(descriptor.read_bytes())
        cls.pool=descriptor_pool.DescriptorPool()
        for file in files.file: cls.pool.Add(file)
        # Parse the pinned public enum declaration independently of Mojo IDs.
        body=re.search(r'enum class HailoRpcActionID\s*\{(.*?)\};',header.read_text(),re.S).group(1)
        enum={};value=0
        for item in re.sub(r'//[^\n]*','',body).split(','):
            item=item.strip()
            if not item: continue
            if '=' in item:
                name,number=item.split('=',1);value=int(number.strip(),0)
            else: name=item
            enum[name.strip()]=value;value+=1
        cls.enum=enum
        (cls.evidence/'oracle-provenance.json').write_text(json.dumps({
            'revision':'d503417f2a0db186a838390fb08690c4ea0f415e',
            'schema_sha256':hashlib.sha256(schema.read_bytes()).hexdigest(),
            'enum_header_sha256':hashlib.sha256(header.read_bytes()).hexdigest(),
            'descriptor_sha256':hashlib.sha256(descriptor.read_bytes()).hexdigest(),
            'protoc':subprocess.check_output([CONFIG.protoc,'--version'],text=True).strip(),
            'runtime':'google.protobuf 6.33.6; BSD-3-Clause license inspected before use',
            'source_license':'HailoRT MIT, read before source/schema use; external/generated files stay outside Git',
            'enum_check':'pinned header declaration lexical enum oracle; no external implementation copying',
            'cpp_header_oracle':'not built: internal header depends on unavailable full HailoRT source include graph; descriptor plus frozen enum declaration used',
            'actions':{k:v for k,v in enum.items() if v in (2,3,5,10,11,12)}
        },indent=2)+'\n')

    @classmethod
    def tearDownClass(cls):
        (cls.evidence/'runs.json').write_text(json.dumps(cls.records,indent=2)+'\n')
        cls.temp.cleanup()
        print('Native outcomes: '+str(dict(Counter('accepted' if r['returncode']==0 else 'refused' for r in cls.records))))

    def message(self,name):
        return message_factory.GetMessageClass(self.pool.FindMessageTypeByName(name))()

    def invoke(self,*args,trace=False):
        command=[self.binary,*map(str,args)]
        if trace:command=[CONFIG.strace,'-y','-o',str(self.evidence/'codec.strace'),'-e','trace=openat,ioctl,mmap,munmap',*command]
        result=subprocess.run(command,capture_output=True,text=True,timeout=10,stdin=subprocess.DEVNULL)
        self.records.append(dict(arguments=list(map(str,args)),returncode=result.returncode,stdout=result.stdout,stderr=result.stderr))
        return result

    def accepted(self,*args,trace=False):
        result=self.invoke(*args,trace=trace)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        data=json.loads(result.stdout)
        for flag in ('device_access','program_transferred','execution_tested'):self.assertIs(data[flag],False)
        return data

    def refused(self,*args):
        result=self.invoke(*args)
        self.assertNotEqual(result.returncode,0,args)
        self.assertEqual(result.stdout,'')
        self.assertTrue(any(s in result.stderr for s in ('BadProgramRpc','BadRpc','RpcReplyMismatch','RpcRemoteFailure','BadArgs')),result.stderr)

    def test_create_metadata_matches_generated_public_schema(self):
        action=self.enum['VDEVICE__CREATE_INFER_MODEL'];self.assertEqual(action,2)
        for handle in (0,1,127,128,U32-1):
            for size in (1,127,128,1<<32,1<<63,U64):
                name='' if size==1 else 'original-模型-Æsir'
                expected=self.message('VDevice_CreateInferModel_Request')
                expected.vdevice_handle.id=handle;expected.hef_size=size;expected.name=name
                actual=self.accepted('create-request',U32,handle,size,size,name)
                self.assertEqual(actual['packet_hex'],packet(expected.SerializeToString(),action,U32,1))

    def test_lifecycle_requests_match_public_schema_and_enum(self):
        enum_names={3:'INFER_MODEL__DESTROY',5:'CONFIGURED_INFER_MODEL__DESTROY',
                    10:'CONFIGURED_INFER_MODEL__ACTIVATE',11:'CONFIGURED_INFER_MODEL__DEACTIVATE',12:'CONFIGURED_INFER_MODEL__SHUTDOWN'}
        for action,name in LIFECYCLE.items():
            self.assertEqual(action,self.enum[enum_names[action]])
            for handle in (0,1,128,U32-1):
                expected=self.message(name+'_Request')
                field='infer_model_handle' if action==3 else 'configured_infer_model_handle'
                getattr(expected,field).id=handle
                actual=self.accepted('handle-request',0,action,handle)
                self.assertEqual(actual['packet_hex'],packet(expected.SerializeToString(),action,0,1))

    def test_exact_body_boundary_utf8_and_explicit_host_bounds(self):
        for handle,size,count in ((0,1,2041),(U32-1,U64,2026)):
            name='x'*count
            data=self.accepted('create-request',17,handle,size,size,name)
            raw=bytes.fromhex(data['packet_hex']);self.assertEqual(HEADER.unpack_from(raw)[1],2048)
            self.refused('create-request',17,handle,size,size,name+'x')
        self.refused('create-request',17,0,1,1,'ø'*1021)  # byte count, not code points
        self.refused('create-request',17,0,1,1,'x'*2049)
        for size,bound in ((0,1),(1,0),(2,1),(U64,U64-1)):
            self.refused('create-request',17,0,size,bound,'original')
        self.refused('create-request',17,U32,1,1,'original')
        for value in ('-1',str(U64+1),'1x',''):
            self.refused('create-request',17,0,value,1,'original')
        for action in (0,1,2,4,6,9,13,18,U32):self.refused('handle-request',17,action,0)
        for action in LIFECYCLE:self.refused('handle-request',17,action,U32)

    def test_create_replies_zero_maximum_and_unknown_valid_fields(self):
        for handle in (0,1,127,128,U32-1):
            expected=self.message('VDevice_CreateInferModel_Reply');expected.infer_model_handle.id=handle
            data=self.accepted('create-reply',17,packet(expected.SerializeToString()))
            self.assertEqual(data['handle'],handle)
        # Unknown varint/fixed64/bytes/fixed32 fields outside and inside nesting.
        unknown=b'\x10\x01\x19'+bytes(8)+b'\x22\x03abc\x2d'+bytes(4)
        nested=b'\x08\x07'+unknown
        body=b'\x0a'+bytes([len(nested)])+nested+unknown
        self.assertEqual(self.accepted('create-reply',17,packet(body))['handle'],7)

    def test_malformed_created_replies_and_correlation_refusals(self):
        invalid=[b'',b'\x08\x01',b'\x0a\x00\x0a\x00',b'\x0a\x02\x0a\x00',
                 b'\x0a\x04\x08\x00\x08\x01',b'\x0a\x02\x08\x80',
                 b'\x0a\x06\x08\xff\xff\xff\xff\x0f',
                 b'\x0a\x06\x08\x80\x80\x80\x80\x10',b'\x0a\x01',
                 b'\x00',b'\x0b',b'\x0a\x00\x10'+b'\x80'*10+b'\x01',
                 b'\x0a\x00\x10'+b'\xff'*9+b'\x02',b'\x0a\x00\x19\x00',
                 b'\x0a\x00\x22\x03ab',b'\x0a\x00\x2d\x00']
        for body in invalid:self.refused('create-reply',17,packet(body))
        for action,message_id,status in ((3,17,0),(2,18,0),(2,17,1),(2,17,U32)):
            self.refused('create-reply',17,packet(b'\x0a\x00',action,message_id,status))
        for raw in ('00','z0','0',packet(b'\x0a\x00')[:-2],packet(bytes(2049))):
            self.refused('create-reply',17,raw)

    def test_empty_success_replies_and_malformed_unknown_fields(self):
        unknown=b'\x08\x01\x11'+bytes(8)+b'\x1a\x01x\x25'+bytes(4)
        for action,name in LIFECYCLE.items():
            body=self.message(name+'_Reply').SerializeToString()
            self.accepted('empty-reply',17,action,packet(body,action))
            self.accepted('empty-reply',17,action,packet(unknown,action))
            self.refused('empty-reply',17,action,packet(body,action,18))
            self.refused('empty-reply',17,action,packet(body,action,17,1))
        for body in (b'\x00',b'\x0b',b'\x08\x80',b'\x12\x03ab',b'\x19',b'\x25'):
            self.refused('empty-reply',17,10,packet(body,10))
        self.refused('empty-reply',17,4,packet(b'',4))
        self.refused('empty-reply',17,10,packet(b'',11))

    def test_owned_requests_and_embedded_nul_string(self):
        data=self.accepted('ownership',17)
        expected=self.message('VDevice_CreateInferModel_Request')
        expected.vdevice_handle.id=0;expected.hef_size=1;expected.name='a\x00b'
        self.assertEqual(data['packet_hex'],packet(expected.SerializeToString(),2,17,1))

    def test_no_device_or_vendor_runtime_access(self):
        self.accepted('create-request',17,0,1,1,'original',trace=True)
        trace=(self.evidence/'codec.strace').read_text()
        for forbidden in ('/dev/h1x-','libhailort','libcuda','libggml'):self.assertNotIn(forbidden,trace)


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    for name in ('binary','schema','enum-header','protoc','strace','evidence'):parser.add_argument('--'+name,required=True)
    CONFIG,remaining=parser.parse_known_args()
    unittest.main(argv=[sys.argv[0],*remaining])
