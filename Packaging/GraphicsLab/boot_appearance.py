#!/usr/bin/env python3
"""Read a known EDK II boot bitmap for the player; never write firmware or VM data."""
import argparse
import json
import lzma
from pathlib import Path
import struct
import uuid
LZMA_GUID = uuid.UUID('ee4e5898-3914-4259-9d6e-dc7bd79403cf').bytes_le
LOGO_GUID = uuid.UUID('f74d20ee-37e7-48fc-97f7-9b1047749c69').bytes_le

def u24(data, offset): return int.from_bytes(data[offset:offset+3], 'little')
def align(value, boundary): return (value+boundary-1) & -boundary

def read_hii_image(pe):
    pe = bytes(pe)
    if pe[:2] != b'MZ':
        raise ValueError('LogoDxe has no PE image')
    nt = struct.unpack_from('<I', pe, 0x3c)[0]
    if pe[nt:nt+4] != b'PE\0\0' or struct.unpack_from('<H', pe, nt+4)[0] != 0xaa64:
        raise ValueError('LogoDxe is not ARM64')
    count = struct.unpack_from('<H', pe, nt+6)[0]
    opt = struct.unpack_from('<H', pe, nt+20)[0]
    resource = None
    for index in range(count):
        entry = nt+24+opt+40*index
        if pe[entry:entry+8].rstrip(b'\0') == b'.rsrc':
            size, start = struct.unpack_from('<II', pe, entry+16)
            resource = (start, start+size)
    if resource is None:
        raise ValueError('No HII resource section')
    start, end = resource
    # The package-list GUID is LogoDxe's GUID; image packages use type 0x06.
    pos = pe.find(LOGO_GUID, start, end)
    if pos < 0:
        raise ValueError('No LogoDxe HII package list')
    length = struct.unpack_from('<I', pe, pos+16)[0]
    if pos+length > end:
        raise ValueError('Invalid HII package bounds')
    package = pos+20
    while package+12 < pos+length:
        size = u24(pe, package)
        if size < 4 or package+size > pos+length:
            raise ValueError('Invalid HII package')
        if pe[package+3] == 6:
            info, palette = struct.unpack_from('<II', pe, package+4)
            block = package+info
            if pe[block] != 0x14:  # EFI_HII_IIBT_IMAGE_8BIT
                raise ValueError('Unsupported logo pixel format')
            palette_index = pe[block+1]
            width, height = struct.unpack_from('<HH', pe, block+2)
            if not 64 <= width <= 1024 or not 40 <= height <= 1024:
                raise ValueError('Invalid logo dimensions')
            pixels = block+6
            if pixels+width*height >= package+size or pe[pixels+width*height] != 0:
                raise ValueError('Expected exactly one HII logo image')
            table = package+palette
            number = struct.unpack_from('<H', pe, table)[0]
            if not 1 <= palette_index <= number:
                raise ValueError('Invalid logo palette')
            table += 2
            for _ in range(palette_index-1):
                table += 2+struct.unpack_from('<H', pe, table)[0]
            palette_size = struct.unpack_from('<H', pe, table)[0]
            if palette_size < 9 or table+2+palette_size > package+size:
                raise ValueError('Invalid palette bounds')
            colors = pe[table+2:table+2+palette_size]
            points = []
            for gy in range(9):
                for gx in range(9):
                    x, y = gx*(width-1)//8, gy*(height-1)//8
                    color = pe[pixels+y*width+x]*3
                    blue, green, red = colors[color:color+3]
                    points.append({'x':x, 'y':y, 'red':red, 'green':green, 'blue':blue})
            if max(p['red']+p['green']+p['blue'] for p in points)-min(p['red']+p['green']+p['blue'] for p in points) < 100:
                raise ValueError('Logo has insufficient distinguishing samples')
            return {'width':width, 'height':height, 'samples':points}
        package += size
    raise ValueError('No supported HII logo image')

def inspect_volume(data):
    data = bytes(data)
    fv = data.find(b'_FVH')-40
    if fv < 0:
        raise ValueError('No decompressed firmware volume')
    size = struct.unpack_from('<Q', data, fv+32)[0]
    header = struct.unpack_from('<H', data, fv+48)[0]
    if fv+size > len(data) or header < 56:
        raise ValueError('Invalid firmware volume')
    file = align(fv+header, 8)
    while file+24 <= fv+size and data[file:file+24] != b'\xff'*24:
        length = u24(data, file+20)
        if length < 24 or file+length > fv+size:
            raise ValueError('Invalid firmware file')
        if data[file:file+16] == LOGO_GUID:
            section = file+24
            while section+4 <= file+length:
                section_size = u24(data, section)
                if section_size < 4 or section+section_size > file+length:
                    raise ValueError('Invalid LogoDxe section')
                if data[section+3] == 0x10:
                    return read_hii_image(data[section+4:section+section_size])
                section = align(section+section_size, 4)
        file = align(file+length, 8)
    raise ValueError('LogoDxe not found')


def inspect_firmware(source):
    position = 0
    while True:
        position = source.find(LZMA_GUID, position)
        if position < 0:
            raise ValueError('Supported LZMA firmware section not found')
        section = position-4
        position += 16
        if section < 0 or source[section+3] != 2:
            continue
        size = u24(source, section)
        offset = struct.unpack_from('<H', source, section+20)[0]
        if offset != 24 or size <= offset or section+size > len(source):
            continue
        compressed = source[section+offset:section+size]
        expected = struct.unpack_from('<Q', compressed, 5)[0]
        if not 0 < expected < 32*1024*1024:
            raise ValueError('Unexpected uncompressed firmware size')
        decoder = lzma.LZMADecompressor(format=lzma.FORMAT_ALONE, memlimit=64*1024*1024)
        plain = decoder.decompress(compressed, max_length=expected+1)
        if len(plain) != expected or not decoder.eof:
            raise ValueError('Invalid LZMA firmware')
        return inspect_volume(plain)

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--firmware', required=True)
    args = parser.parse_args()
    path = Path(args.firmware).resolve(strict=True)
    if not path.is_file() or not 1024*1024 <= path.stat().st_size <= 128*1024*1024:
        raise SystemExit('Invalid firmware file')
    try:
        print(json.dumps(inspect_firmware(path.read_bytes())))
    except (ValueError, lzma.LZMAError):
        print('{}')
