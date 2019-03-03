#!/usr/bin/python

import mmap
import contextlib

with open('/dev/uio0', 'r+b') as f:
    with contextlib.closing(mmap.mmap(f.fileno(), 4096, offset=4096)) as m:
        print('Shmem content: ' + m.read(30))
    with contextlib.closing(mmap.mmap(f.fileno(), 4096, offset=0)) as m:
        print('mmapped it!')
        m.seek(12)
        for i in range(32):
            for j in range(32):
                m.write(((i & 0xffff) << 16 ) + (j & 0xffff))
