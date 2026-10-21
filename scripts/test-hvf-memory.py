#!/usr/bin/env python3
"""Execute the production ARM memory decoder with address/UB sanitizers."""
from pathlib import Path
import subprocess, tempfile, os
root = Path(__file__).resolve().parents[1]
program = r'''
#include <assert.h>
#include <stdio.h>
FRAGMENT
static uint8_t memory[16384];
static bool fail;
static bool rw(void *unused, uint64_t va, uint8_t *data, unsigned size, bool write) {
    if (fail || va > sizeof(memory) || size > sizeof(memory)-va) { return false; }
    if (write) { memcpy(memory+va,data,size); } else { memcpy(data,memory+va,size); }
    return true;
}
int main(void) {
    StratovoArmMemoryState s={0},before;
    /* stp x0,x1,[x2] : page-straddling pair, not the faulting page's start. */
    s.x[0]=0x0123456789abcdefULL; s.x[1]=0xfedcba9876543210ULL;s.x[2]=4092;
    assert(stratovo_arm_memory(&s,0xa9000440,true,rw,NULL));
    assert(!memcmp(memory+4092,&s.x[0],8) && !memcmp(memory+4100,&s.x[1],8));
    /* ldp x3,x4,[x2] */
    assert(stratovo_arm_memory(&s,0xa9401043,false,rw,NULL));
    assert(s.x[3]==s.x[0] && s.x[4]==s.x[1]);
    /* stp q0,q1,[sp,#-32]! ; ldp q2,q3,[sp],#32 */
    for(int i=0;i<16;i++){s.q[0][i]=i+10;s.q[1][i]=i+80;}
    s.x[31]=8192;
    assert(stratovo_arm_memory(&s,0xadbf07e0,true,rw,NULL));
    assert(s.x[31]==8160);
    assert(stratovo_arm_memory(&s,0xacc10fe2,false,rw,NULL));
    assert(s.x[31]==8192 && !memcmp(s.q[2],s.q[0],16) && !memcmp(s.q[3],s.q[1],16));
    /* str q0,[x2,#16]; ldr q4,[x2,#16] */
    s.x[2]=128;
    assert(stratovo_arm_memory(&s,0x3d800440,true,rw,NULL));
    assert(!memcmp(memory+144,s.q[0],16));
    assert(stratovo_arm_memory(&s,0x3dc00444,false,rw,NULL));
    assert(!memcmp(s.q[0],s.q[4],16));
    /* str xzr,[x2]; ldr xzr,[x2] must preserve SP. */
    memset(memory+128,0xff,8);
    assert(stratovo_arm_memory(&s,0xf900005f,true,rw,NULL));
    assert(!memcmp(memory+128,(uint8_t[8]){0},8));
    assert(stratovo_arm_memory(&s,0xf940005f,false,rw,NULL));assert(s.x[31]==8192);
    /* ldrsb x0,[x2]; ldrsb w1,[x2] */
    memory[128]=0x80;
    assert(stratovo_arm_memory(&s,0x39800040,false,rw,NULL)); assert(s.x[0]==UINT64_MAX-127);
    assert(stratovo_arm_memory(&s,0x39c00041,false,rw,NULL)); assert(s.x[1]==0xffffff80);
    /* stnp x0,x1,[x2,#16]; str x0,[x2],#8; ldr x5,[x2,#-8]! */
    assert(stratovo_arm_memory(&s,0xa8010440,true,rw,NULL));
    assert(!memcmp(memory+144,&s.x[0],8));
    assert(stratovo_arm_memory(&s,0xf8008440,true,rw,NULL)); assert(s.x[2]==136);
    assert(stratovo_arm_memory(&s,0xf85f8c45,false,rw,NULL)); assert(s.x[2]==128 && s.x[5]==s.x[0]);
    /* str x0,[x2,x3,lsl #3] */
    s.x[3]=3;
    assert(stratovo_arm_memory(&s,0xf8237840,true,rw,NULL));assert(!memcmp(memory+152,&s.x[0],8));
    before=s;
    assert(!stratovo_arm_memory(&s,0xd503201f,true,rw,NULL)); /* nop isn't memory */
    assert(!stratovo_arm_memory(&s,0xf9000040,false,rw,NULL)); /* direction mismatch */
    assert(!stratovo_arm_memory(&s,0xf8200040,true,rw,NULL)); /* atomic */
    assert(!stratovo_arm_memory(&s,0x6d000440,true,rw,NULL)); /* invalid SIMD pair opc=3? see below */
    assert(!memcmp(&before,&s,sizeof(s)));
    fail=true;
    assert(!stratovo_arm_memory(&s,0xacc10fe2,false,rw,NULL));
    assert(!memcmp(&before,&s,sizeof(s))); /* no writeback on failed access */
    fail=false;s.x[2]=sizeof(memory)-4;before=s;
    assert(!stratovo_arm_memory(&s,0xa9401043,false,rw,NULL));
    assert(!memcmp(&before,&s,sizeof(s)));
    puts("PASS: ARM pair/SIMD/immediate/register-offset, zero/SP, sign extension, failure preservation");
}
'''.replace('FRAGMENT',(root/'Packaging/GraphicsLab/isv_memory.h.inc').read_text())
# opc=3 is reserved for a SIMD pair.
program=program.replace('0x6d000440','0xed000440')
with tempfile.TemporaryDirectory() as tmp:
    src=Path(tmp)/'memory.c';src.write_text(program);exe=Path(tmp)/'memory'
    subprocess.run([os.environ.get('CC','cc'),'-std=c11','-Wall','-Wextra','-Wno-unused-parameter',
                    '-Werror','-fsanitize=address,undefined','-fno-omit-frame-pointer',str(src),'-o',str(exe)],check=True)
    subprocess.run([str(exe)],check=True,env=dict(os.environ, ASAN_OPTIONS="detect_leaks=0"))
