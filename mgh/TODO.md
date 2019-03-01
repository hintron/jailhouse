[Back to README-MGH.md](README-MGH.md)
# TODO List

(Roughly sorted by priority)

* Get root cell properly sending interrupts back to the inmate

    See https://groups.google.com/forum/#!searchin/jailhouse-dev/ivshmem|sort:date/jailhouse-dev/Lyw3PQlK_wU/N0IhKbNRDgAJ

* Figure out why mmap() of /dev/uio0 doesn't work for the first mem region


# Completed Tasks

* 83c98c90: Make the userspace program only modify shared memory when it receives an
        interrupt from the inmate (event-driven).



