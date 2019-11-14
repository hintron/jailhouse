project('mgh-sha3-512', 'c')

src = [
    '../../inmates/lib/mgh-sha3.c',
    'src/sha3-512.c',
]

profile_src = [
    '../../inmates/lib/mgh-sha3.c',
    'src/sha3-512-profile.c',
]

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

executable(
    'sha3-512', # name
    src, # source files
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

executable(
    'sha3-512-profile', # name
    profile_src, # source files
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)

executable(
    'count-set-bits', # name
    ['src/count-set-bits.c', '../../inmates/lib/mgh-count-set-bits.c',],
    install: true,
    include_directories: [
        inmate_x86_inc,
        inmate_common_inc,
        jailhouse_inc,
        jailhouse_x86_inc
    ],
)


# Run test through ninja install
test('Test sha3-512', find_program('test-sha3-512.sh'))
test('Test sha3-512-profile', find_program('test-sha3-512-profile.sh'))
test('Test count-set-bits', find_program('test-count-set-bits.sh'))