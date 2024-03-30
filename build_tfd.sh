#!/bin/bash

cd tinyfiledialogs
gcc -c -o tfd.o tinyfiledialogs.c
ar rcs ../tfd.a tfd.o