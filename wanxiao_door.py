# -*- coding: utf-8 -*-
"""
完美校园「开门助手」远程开门 —— 参考实现

协议来源：对 App v5.8.37 (com.newcapec.mobile.ncp) 的 H5 页面与接口抓包分析
适用场景：本人账号、本人门禁的自动化（如 ESP32 联动）

完整链路：
    1. exchangeSecretkey   生成 RSA-1024 密钥对，与服务器交换 session + 3DES 密钥
    2. loginnew / sms      3DES 加密登录，拿到 token(= session)
    3. authorize           token 换 accessH5New cookie
    4. loginCheck          取 outid（用户唯一标识）
    5. postAuth / pageList 取门锁列表
    6. remotelyOpen        下发开门指令

用法：
    python wanxiao_door.py 手机号 密码            # 登录并列出设备
    python wanxiao_door.py 手机号 密码 --open     # 登录并开门（第一台设备）
    python wanxiao_door.py 手机号 --sms           # 短信验证码登录
    python wanxiao_door.py 手机号 密码 --open --device 647
"""
import argparse
import base64
import hashlib
import json
import os
import sys
import time
import urllib.parse

import requests
import urllib3
from Crypto.Cipher import DES3, PKCS1_v1_5
from Crypto.PublicKey import RSA
from Crypto.Random import get_random_bytes
from Crypto.Util.Padding import pad, unpad
from cryptography.hazmat.primitives import padding as sym_padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)

# ---------------------------------------------------------------- 常量
APP_BASE = "https://app.17wanxiao.com/campus/cam_iface46"
H5_BASE = "https://xqh5.17wanxiao.com/keychainService2019"
AUTH_URL = "https://open.17wanxiao.com/api/authorize"

CLIENT_ID = "75dd569e9b1e4362ab92628eddda0f4b"
CUSTOMER_CODE = "2502"
H5_AES_KEY = b"r8xRjp877LzkoVUt"      # H5 开门接口的 AES-128 密钥（ECB / PKCS7）
DES_IV = "66666666"

UA_WEB = ("Mozilla/5.0 (Linux; Android 12; 2206122SC Build/V417IR; wv) AppleWebKit/537.36 "
          "(KHTML, like Gecko) Version/4.0 Chrome/110.0.5481.154 Mobile Safari/537.36 "
          "Wanxiao/5.8.9 Wmxy/5.8.37")
UA_APP = "Dalvik/2.1.0 (Linux; U; Android 12; 2206122SC Build/f9139cc.1)"

STATE_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".wanxiao_state.json")


# ---------------------------------------------------------------- 密码学
def des3_encrypt(text, key, iv=DES_IV):
    k = key.encode() if isinstance(key, str) else key
    c = DES3.new(k, DES3.MODE_CBC, iv.encode())
    return base64.b64encode(c.encrypt(pad(text.encode("utf-8"), 8))).decode()


def des3_decrypt(b64, key, iv=DES_IV):
    k = key.encode() if isinstance(key, str) else key
    c = DES3.new(k, DES3.MODE_CBC, iv.encode())
    return unpad(c.decrypt(base64.b64decode(b64)), 8).decode()


def aes_ecb_encrypt_b64(plain):
    p = sym_padding.PKCS7(128).padder()
    data = p.update(plain.encode("utf-8")) + p.finalize()
    e = Cipher(algorithms.AES(H5_AES_KEY), modes.ECB()).encryptor()
    return base64.b64encode(e.update(data) + e.finalize()).decode()


def aes_ecb_decrypt_b64(b64text):
    d = Cipher(algorithms.AES(H5_AES_KEY), modes.ECB()).decryptor()
    raw = d.update(base64.b64decode(b64text)) + d.finalize()
    u = sym_padding.PKCS7(128).unpadder()
    return (u.update(raw) + u.finalize()).decode("utf-8")


# ---------------------------------------------------------------- 主体
class WanxiaoDoor:
    """完美校园开门助手客户端"""

    def __init__(self, phone, device_id=None, app_version=1050837101, timeout=30):
        self.phone = phone
        self.device_id = device_id or self._load_device_id()
        self.app_version = app_version
        self.timeout = timeout

        self.session_id = None      # 登录后同时作为 token
        self.app_key = None         # 3DES 密钥（服务端下发）
        self.outid = None           # 用户唯一标识
        self.final_url = None       # 授权后的最终跳转地址

        self.http = requests.Session()
        self.http.verify = False

    # ---------- 本地状态 ----------
    def _load_device_id(self):
        try:
            with open(STATE_FILE, encoding="utf-8") as f:
                dev = json.load(f).get("device_id")
                if dev:
                    return dev
        except Exception:
            pass
        dev = "wx-door-%d" % int(time.time())
        self._save_state({"device_id": dev})
        return dev

    def _save_state(self, data):
        try:
            with open(STATE_FILE, encoding="utf-8") as f:
                old = json.load(f)
        except Exception:
            old = {}
        old.update(data)
        with open(STATE_FILE, "w", encoding="utf-8") as f:
            json.dump(old, f, ensure_ascii=False, indent=2)

    # ---------- 1. 交换密钥 ----------
    def exchange_secret(self):
        rsa_key = RSA.generate(1024)
        pub = rsa_key.publickey().export_key().decode()
        pub = pub.split("-\n")[1].split("\n-")[0]

        r = self.http.post(APP_BASE + "/exchangeSecretkey.action",
                           headers={"User-Agent": UA_APP},
                           json={"key": pub}, timeout=self.timeout)
        cipher = PKCS1_v1_5.new(rsa_key)
        plain = cipher.decrypt(base64.b64decode(r.text), get_random_bytes(16)).decode()
        info = json.loads(plain)

        self.session_id = info["session"]
        self.app_key = info["key"][:24]
        return info

    # ---------- 2a. 账密登录 ----------
    def login_password(self, password):
        args = {
            "appCode": "M002",
            "deviceId": self.device_id,
            "netWork": "wifi",
            "password": [des3_encrypt(ch, self.app_key) for ch in password],
            "qudao": "guanwang",
            "requestMethod": "cam_iface46/loginnew.action",
            "shebeixinghao": "2206122SC",
            "systemType": "android",
            "telephoneInfo": "12",
            "telephoneModel": "2206122SC",
            "type": "1",
            "userName": self.phone,
            "wanxiaoVersion": self.app_version,
        }
        return self._post_signed("/loginnew.action", args)

    # ---------- 2b. 短信登录 ----------
    def send_sms(self):
        send = {
            "action": "registAndLogin",
            "deviceId": self.device_id,
            "mobile": self.phone,
            "requestMethod": "cam_iface46/gainMatrixCaptcha.action",
            "type": "sms",
        }
        return self._post_signed("/gainMatrixCaptcha.action", send)

    def login_sms(self, code):
        args = {
            "appCode": "M002",
            "deviceId": self.device_id,
            "netWork": "wifi",
            "qudao": "guanwang",
            "requestMethod": "cam_iface46/registerUsersByTelAndLoginNew.action",
            "shebeixinghao": "2206122SC",
            "sms": code,
            "systemType": "android",
            "telephoneInfo": "12",
            "telephoneModel": "2206122SC",
            "mobile": self.phone,
            "type": "2",
            "wanxiaoVersion": self.app_version,
        }
        return self._post_signed("/registerUsersByTelAndLoginNew.action", args)

    def _post_signed(self, path, args):
        upload = {"session": self.session_id, "data": des3_encrypt(json.dumps(args), self.app_key)}
        sign = hashlib.sha256(json.dumps(upload).encode("utf-8")).hexdigest()
        r = self.http.post(APP_BASE + path, headers={"campusSign": sign},
                           json=upload, timeout=self.timeout)
        return r.json()

    # ---------- 3. 换 H5 会话 ----------
    def h5_session(self):
        url = AUTH_URL + "?" + urllib.parse.urlencode({
            "client_id": CLIENT_ID,
            "response_type": "code",
            "redirect_uri": H5_BASE + "/OpenCampus?apply=accessH5New",
            "versionnum": self.app_version,
            "customerId": CUSTOMER_CODE,
            "systemType": "Android",
            "UAinfo": "wanxiao",
            "versioncode": 10589101,
            "token": self.session_id,
        })
        r = self.http.get(url, headers={"User-Agent": UA_WEB}, allow_redirects=False, timeout=self.timeout)
        for _ in range(8):
            loc = r.headers.get("location")
            if not loc:
                break
            if loc.startswith("/"):
                p = urllib.parse.urlparse(r.url)
                loc = "%s://%s%s" % (p.scheme, p.netloc, loc)
            r = self.http.get(loc, headers={"User-Agent": UA_WEB}, allow_redirects=False, timeout=self.timeout)
        self.final_url = r.url
        return r

    # ---------- 4. loginCheck ----------
    def login_check(self):
        u = urllib.parse.urlparse(self.final_url or "")
        q = urllib.parse.parse_qs(u.query)
        if "params" not in q and "?" in u.fragment:
            q = urllib.parse.parse_qs(u.fragment.split("?", 1)[1])
        params = q.get("params", [""])[0]
        if not params:
            raise RuntimeError("跳转地址中没有 params，无法 loginCheck: %s" % (self.final_url or "")[:200])

        r = self.http.post(H5_BASE + "/loginCheck",
                           data={"data": params},
                           headers=self._h5_headers(), timeout=self.timeout)
        if not r.content:
            raise RuntimeError("loginCheck 返回空响应（会话无效）")

        outer = json.loads(json.loads(aes_ecb_decrypt_b64(r.json()["resultdata"]))["body"])
        data = outer.get("data", {})
        self.outid = str(data.get("outid"))
        self._save_state({"outid": self.outid, "name": data.get("name")})
        return data

    # ---------- 5. 业务调用 ----------
    def _h5_headers(self):
        return {
            "User-Agent": UA_WEB,
            "Content-Type": "application/x-www-form-urlencoded;charset=UTF-8",
            "Origin": "https://xqh5.17wanxiao.com",
            "Referer": H5_BASE + "/accessH5New/index.html",
            "X-Requested-With": "com.newcapec.mobile.ncp",
        }

    def invoke(self, payload):
        if self.outid:
            payload["request_data"].setdefault("outid", self.outid)
        payload["request_data"].setdefault("customerCode", CUSTOMER_CODE)

        plain = json.dumps(payload, separators=(",", ":")) + "&" + str(int(time.time() * 1000))
        body = urllib.parse.urlencode({
            "method": "AccessH5",
            "param": aes_ecb_encrypt_b64(plain),
            "customercode": CUSTOMER_CODE,
        })
        r = self.http.post(H5_BASE + "/WXInvokFront", data=body,
                           headers=self._h5_headers(), timeout=self.timeout)
        if not r.content:
            return None
        return json.loads(r.json().get("body", "{}"))

    def post_auth(self):
        return self.invoke({"request_data": {"userId": self.outid}, "method": "postAuth"})

    def list_devices(self):
        return self.invoke({
            "request_data": {"currentPage": 1, "pageSize": 20, "userId": self.outid, "status": 0},
            "method": "pageList",
        })

    def open_door(self, device_id, serial_no, mode="0"):
        return self.invoke({
            "request_data": {"deviceId": device_id, "serialNo": serial_no, "mode": mode},
            "method": "remotelyOpen",
        })

    # ---------- 一键流程 ----------
    def try_cached_session(self):
        """尝试复用上次的登录态，返回 (是否成功, 缓存时间描述)"""
        try:
            with open(STATE_FILE, encoding="utf-8") as f:
                st = json.load(f)
        except Exception:
            return False, ""
        sid = st.get("session_id")
        ts = st.get("session_ts")
        if not sid or not ts:
            return False, ""
        age_min = (time.time() - ts) / 60
        self.session_id = sid
        try:
            self.h5_session()
            self.login_check()
            self.post_auth()
            return True, "%.0f 分钟前" % age_min
        except Exception:
            return False, "%.0f 分钟前" % age_min

    def connect(self, password=None, sms_code=None, reuse=True):
        if reuse:
            ok, age = self.try_cached_session()
            if ok:
                print("[+] 复用登录态成功（登录于 %s）" % age)
                return self
            if age:
                print("[-] 缓存登录态已失效（登录于 %s），重新登录" % age)

        self.exchange_secret()
        if sms_code:
            res = self.login_sms(sms_code)
        elif password:
            res = self.login_password(password)
            if str(res.get("code_")) == "5" and "新设备" in str(res.get("message_", "")):
                raise RuntimeError("新设备登录需要短信验证，请改用 --sms 参数")
        else:
            raise ValueError("必须提供密码或短信验证码")
        if not res.get("result_"):
            raise RuntimeError("登录失败: %s" % res.get("message_"))

        self._save_state({"session_id": self.session_id, "session_ts": time.time()})
        self.h5_session()
        self.login_check()
        self.post_auth()
        return self


# ---------------------------------------------------------------- CLI
def main():
    ap = argparse.ArgumentParser(description="完美校园 开门助手 远程开门")
    ap.add_argument("phone", help="登录手机号")
    ap.add_argument("password", nargs="?", help="密码（短信登录时省略）")
    ap.add_argument("--sms", action="store_true", help="使用短信验证码登录")
    ap.add_argument("--open", action="store_true", help="登录后执行开门")
    ap.add_argument("--device", type=int, help="指定门锁 deviceId（默认取第一台）")
    ap.add_argument("--list", action="store_true", help="只列出设备")
    ap.add_argument("--fresh", action="store_true", help="忽略缓存的登录态，强制重新登录")
    args = ap.parse_args()

    door = WanxiaoDoor(args.phone)

    if args.sms:
        door.exchange_secret()
        door.send_sms()
        code = input("请输入短信验证码: ").strip()
        res = door.login_sms(code)
        if not res.get("result_"):
            print("登录失败:", res.get("message_"))
            return 1
        door._save_state({"session_id": door.session_id, "session_ts": time.time()})
        door.h5_session()
        door.login_check()
        door.post_auth()
    else:
        if not args.password:
            ap.error("账密登录需要提供密码")
        door.connect(password=args.password, reuse=not args.fresh)

    res = door.list_devices()
    if not res:
        print("获取设备列表失败（会话无效）")
        return 1

    devices = res.get("data", {}).get("list", [])
    if not devices:
        print("没有可用门锁")
        return 1

    print("\n门锁列表:")
    for d in devices:
        print("  id=%-6s 名称=%-8s 类型=%-6s 电量=%-6s 在线=%s  sn=%s" % (
            d["deviceId"], d["deviceName"], d["deviceTypeName"],
            d.get("battery"), d.get("onlineStatus"), d["sn"]))

    if args.open:
        target = None
        for d in devices:
            if args.device is None or int(d["deviceId"]) == args.device:
                target = d
                break
        if not target:
            print("没找到指定的门锁")
            return 1
        print("\n>>> 开门: %s (%s)" % (target["deviceName"], target["sn"]))
        out = door.open_door(target["deviceId"], target["sn"])
        print("返回:", json.dumps(out, ensure_ascii=False))
        if out and out.get("data", {}).get("data") == "命令发送成功":
            print("✅ 开门指令已下发")
        return 0

    return 0


if __name__ == "__main__":
    sys.exit(main())
