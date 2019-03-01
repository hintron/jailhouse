cmake_minimum_required(VERSION 2.6)
project(mgh)

add_executable(uio-userspace uio-userspace)

set(CMAKE_C_FLAGS_DEBUG "-DDEBUG")
set(CMAKE_C_FLAGS "-std=c99 -g -Wall -D_DEFAULT_SOURCE")

