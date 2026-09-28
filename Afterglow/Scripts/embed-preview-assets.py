#!/usr/bin/env python3
"""Compatibility entry point: rebuild the offline preview and its embedded assets."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('build-preview.py')),run_name='__main__')
