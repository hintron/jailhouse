#!/bin/bash
cd "${BASH_SOURCE%/*}" || exit
../../tools/jailhouse cell destroy bazooka-demo
