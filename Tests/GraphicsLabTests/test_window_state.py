"""Exercise preferences across separate player processes on a real Mac."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[2]

@unittest.skipUnless(sys.platform == 'darwin', 'requires AppKit on macOS')
class WindowStateTests(unittest.TestCase):
    def test_restart_and_disconnected_monitor(self):
        with tempfile.TemporaryDirectory() as folder:
            folder = Path(folder)
            suite = 'org.stratovo.WindowStateTest.' + uuid.uuid4().hex
            fragment = (ROOT/'Packaging/GraphicsLab/window_state.m.inc').read_text()
            fragment = fragment.replace('org.stratovo.WindowsPlayer', suite)
            program = r'''
#import <AppKit/AppKit.h>
#include <math.h>
#include <assert.h>
FRAGMENT
static int stratovo_native(void) { return 1; }
@interface QemuCocoaView : NSView
- (void)updateScale;
- (void)updateUIInfo;
- (BOOL)isSelfResizing;
@end
@implementation QemuCocoaView
- (void)updateScale {}
- (void)updateUIInfo {}
- (BOOL)isSelfResizing { return NO; }
@end
@interface Player : NSObject { QemuCocoaView *cocoaView; }
@end
@implementation Player
CALLBACKS
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        [NSApplication sharedApplication];
        NSRect bounds = [[NSScreen mainScreen] visibleFrame];
        assert(bounds.size.width >= 600 && bounds.size.height >= 400);
        NSWindow *w = [[NSWindow alloc] initWithContentRect:NSMakeRect(0,0,500,350)
            styleMask:NSWindowStyleMaskTitled|NSWindowStyleMaskResizable
            backing:NSBackingStoreBuffered defer:NO];
        NSRect desired = NSMakeRect(bounds.origin.x+20, bounds.origin.y+20, 560, 380);
        if (argv[1][0] == 'w') {
            [w setFrame:desired display:NO];
            stratovo_save_window(w);
        } else {
            stratovo_restore_window(w);
            assert(NSEqualRects([w frame], desired));
            NSUserDefaults *d = stratovo_window_defaults();
            [d setObject:@"{{1000000, 1000000}, {90000, 90000}}" forKey:@"NormalWindowFrame.v1"];
            stratovo_restore_window(w);
            assert(NSContainsRect(bounds, [w frame]));
            NSRect before = [w frame];
            [d setObject:@"invalid frame" forKey:@"NormalWindowFrame.v1"];
            stratovo_restore_window(w);
            assert(NSEqualRects([w frame], before));
            [d removePersistentDomainForName:@"SUITE"];
            [d synchronize];
        }
    }
    return 0;
}
'''.replace('FRAGMENT', fragment).replace('SUITE', suite).replace('CALLBACKS', (ROOT/'Packaging/GraphicsLab/window_callbacks.m.inc').read_text())
            source = folder/'window.m'; source.write_text(program)
            executable = folder/'window'
            subprocess.run(['xcrun', 'clang', '-framework', 'AppKit', str(source), '-o', str(executable)], check=True)
            for mode in ['write', 'read']:
                subprocess.run([str(executable), mode], check=True)
