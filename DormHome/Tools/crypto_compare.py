#!/usr/bin/env python3
"""Print the Python reference outputs used by the DormHome crypto self-test.

Requires pycryptodome. The reference implementation is imported directly from
wanxiao_door.py; a tiny cryptography shim maps its AES-ECB helper to pycryptodome.
"""
import hashlib
import sys
import types
from pathlib import Path

from Crypto.Cipher import AES
from Crypto.Util.Padding import pad, unpad

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))


class _Padder:
    def __init__(self):
        self.buffer = b""

    def update(self, data):
        self.buffer += data
        return b""

    def finalize(self):
        return pad(self.buffer, 16)


class _Unpadder:
    def __init__(self):
        self.buffer = b""

    def update(self, data):
        self.buffer += data
        return b""

    def finalize(self):
        return unpad(self.buffer, 16)


class _Encryptor:
    def __init__(self, key):
        self.cipher = AES.new(key, AES.MODE_ECB)

    def update(self, data):
        return self.cipher.encrypt(data)

    def finalize(self):
        return b""


class _Decryptor(_Encryptor):
    def update(self, data):
        return self.cipher.decrypt(data)


class _Cipher:
    def __init__(self, algorithm, mode):
        self.key = algorithm.key

    def encryptor(self):
        return _Encryptor(self.key)

    def decryptor(self):
        return _Decryptor(self.key)


def install_shims():
    sym_padding = types.ModuleType("cryptography.hazmat.primitives.padding")
    sym_padding.PKCS7 = lambda bits: types.SimpleNamespace(padder=_Padder, unpadder=_Unpadder)

    ciphers = types.ModuleType("cryptography.hazmat.primitives.ciphers")
    ciphers.Cipher = _Cipher
    ciphers.algorithms = types.SimpleNamespace(AES=lambda key: types.SimpleNamespace(key=key))
    ciphers.modes = types.SimpleNamespace(ECB=lambda: "ECB")

    for name, module in {
        "cryptography": types.ModuleType("cryptography"),
        "cryptography.hazmat": types.ModuleType("cryptography.hazmat"),
        "cryptography.hazmat.primitives": types.ModuleType("cryptography.hazmat.primitives"),
        "cryptography.hazmat.primitives.padding": sym_padding,
        "cryptography.hazmat.primitives.ciphers": ciphers,
    }.items():
        sys.modules[name] = module

    try:
        import requests  # noqa: F401
    except Exception:
        requests = types.ModuleType("requests")
        requests.Session = lambda: None
        sys.modules["requests"] = requests

    try:
        import urllib3  # noqa: F401
    except Exception:
        urllib3 = types.ModuleType("urllib3")
        urllib3.exceptions = types.SimpleNamespace(InsecureRequestWarning=Warning)
        urllib3.disable_warnings = lambda *args, **kwargs: None
        sys.modules["urllib3"] = urllib3


def main():
    install_shims()
    from wanxiao_door import aes_ecb_encrypt_b64, des3_encrypt, DES_IV

    key = "0123456789abcdefghijklmn"
    plain = '{"appCode":"M002","password":"密码测试","userName":"13800000000"}'
    aes_plain = (
        '{"request_data":{"deviceId":647,"serialNo":"SN1234567890","mode":"0",'
        '"outid":"abc","customerCode":"2502"},"method":"remotelyOpen"}&1710000000000'
    )
    sha_input = '{"session":"sess-123","data":"QUJDREVGRw=="}'

    print("PY_3DES=" + des3_encrypt(plain, key))
    print("PY_AES=" + aes_ecb_encrypt_b64(aes_plain))
    print("PY_SHA=" + hashlib.sha256(sha_input.encode()).hexdigest())
    print("PY_IV=" + DES_IV)


if __name__ == "__main__":
    main()
