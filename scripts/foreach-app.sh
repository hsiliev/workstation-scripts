#!/bin/bash
set -e

cf apps | tail -n +5 | awk '{print $1}' | xargs -n 1 $1
