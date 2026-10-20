#!/usr/bin/env python3
"""Exercise actual letterboxing and mouse geometry without AppKit/GPU mocks."""
from pathlib import Path
import os,subprocess,tempfile
root=Path(__file__).resolve().parents[1]
code=r'''
#include <math.h>
#include <stdbool.h>
#include <assert.h>
'''+(root/'Packaging/GraphicsLab/native_geometry.h.inc').read_text()+r'''
int main(void) {
    double views[][2]={{1100,760},{1920,1080},{3440,1440},{480,1000},{2560,1440}};
    int guests[][2]={{1920,1080},{1280,720},{1440,3120},{2560,1440}};
    for(unsigned v=0;v<5;v++)for(unsigned g=0;g<4;g++) {
        int w=guests[g][0],h=guests[g][1],x,y;
        StratovoRect r=stratovo_fit(views[v][0],views[v][1],w,h);
        assert(r.width<=views[v][0]+1e-6 && r.height<=views[v][1]+1e-6);
        assert(fabs(r.width/r.height-(double)w/h)<1e-6);
        assert(fabs(r.x*2+r.width-views[v][0])<1e-6);
        assert(fabs(r.y*2+r.height-views[v][1])<1e-6);
        assert(stratovo_point(r,r.x,r.y+r.height,w,h,&x,&y) && x==0 && y==0);
        assert(stratovo_point(r,r.x+r.width,r.y,w,h,&x,&y) && x==w-1 && y==h-1);
        assert(stratovo_point(r,r.x+r.width/2,r.y+r.height/2,w,h,&x,&y) && x==w/2 && y==h/2);
        assert(stratovo_point(r,-100,-100,w,h,&x,&y) && x==0 && y==h-1);
    }
    assert(stratovo_fit(0,800,1920,1080).width==0);
    assert(stratovo_fit(NAN,800,1920,1080).width==0);
    return 0;
}
'''
with tempfile.TemporaryDirectory() as tmp:
    file=Path(tmp)/'geometry.c';exe=Path(tmp)/'geometry';file.write_text(code)
    subprocess.run(['cc','-std=c11','-fsanitize=address,undefined',str(file),'-lm','-o',str(exe)],check=True)
    subprocess.run([str(exe)],env=dict(os.environ,ASAN_OPTIONS='detect_leaks=0'),check=True)
print('PASS: native viewport and pointer alignment across wide, tall, maximized and Retina-sized views (ASan/UBSan).')
