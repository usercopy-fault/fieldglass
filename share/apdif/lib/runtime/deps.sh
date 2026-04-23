#!/usr/bin/env bash

need_python() {
  need python3
}

need_android_host_tools() {
  need adb
  need aapt
}
