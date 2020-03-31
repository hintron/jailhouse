project('workloads', 'c')

# NOTE: Make sure to build with the command `CC=gcc-7 meson build` in order to
# match how Jailhouse is currently being built in my scripts!

# NOTE: Make sure to pass `LDFLAGS=-no-pie` env to `meson build` in order to
# suppress the automatic pie builds on my system!

inmate_x86_inc = include_directories(
    join_paths('..','..','inmates','lib','x86','include')
)
inmate_common_inc = include_directories(
    join_paths('..','..','inmates','lib','include')
)
jailhouse_inc = include_directories(
    join_paths('..','..','include')
)
jailhouse_x86_inc = include_directories(
    join_paths('..','..','include','arch','x86')
)

# Note that the source and build paths are both added to the include dirs by
# default!

# Since these binaries now all include leftover object files from the Jailhouse
# inmate library, make sure to build Jailhouse first!

executable(
    'count-set-bits', # name
    ['src/count-set-bits.c',],
    objects: ['../../inmates/lib/mgh-count-set-bits.o',],
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

executable(
    'prng', # name
    ['src/prng.c',],
    objects: ['../../inmates/lib/mgh-prng.o',],
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

executable(
    'random-access', # name
    ['src/random-access.c',],
    objects: ['../../inmates/lib/mgh-random-access.o',],
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

executable(
    'sha3-512', # name
    ['src/sha3-512.c',],
    objects: ['../../inmates/lib/mgh-sha3.o',],
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

# Run test through ninja install
# Do NOT run them in parallel to avoid conflicts with temp files
test('count-set-bits', find_program('test-count-set-bits.sh'), is_parallel : false)
test('prng', find_program('test-prng.sh'), is_parallel : false)
test('random-access', find_program('test-random-access.sh'), is_parallel : false)
test('sha3-512', find_program('test-sha3-512.sh'), is_parallel : false)