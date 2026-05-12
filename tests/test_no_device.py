from apdif.adb import list_devices, adb_available

def test_no_device_graceful_failure():
    assert isinstance(list_devices(), list); assert isinstance(adb_available(), bool)
