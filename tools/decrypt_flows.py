# -*- coding: utf-8 -*-
"""
从 mitmproxy 抓包文件里解密「开门助手」的 H5 请求

用法:
    python decrypt_flows.py flows.mitm                # 解密所有 H5 业务请求
    python decrypt_flows.py flows.mitm --dump h5      # 顺带导出 H5 静态资源到 h5/
    python decrypt_flows.py flows.mitm --host xqh5    # 只看某个域名

需要: pip install mitmproxy cryptography
"""
import argparse
import base64
import json
import os
import sys
import urllib.parse

from cryptography.hazmat.primitives import padding
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

try:
    from mitmproxy import io as mio
    from mitmproxy.http import HTTPFlow
except ImportError:
    sys.exit("需要先安装 mitmproxy: pip install mitmproxy")

# H5 页面 JS 里硬编码的 AES-128 密钥（ECB / PKCS7）
AES_KEY = b"r8xRjp877LzkoVUt"


def dec(b64text):
    d = Cipher(algorithms.AES(AES_KEY), modes.ECB()).decryptor()
    raw = d.update(base64.b64decode(b64text)) + d.finalize()
    u = padding.PKCS7(128).unpadder()
    return (u.update(raw) + u.finalize()).decode("utf-8", "replace")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("flows", help="mitmproxy 保存的 flow 文件")
    ap.add_argument("--host", default="wanxiao", help="只处理域名包含该字符串的请求")
    ap.add_argument("--dump", metavar="DIR", help="把命中的响应体（JS/CSS/HTML）导出到目录")
    args = ap.parse_args()

    if args.dump:
        os.makedirs(args.dump, exist_ok=True)

    n = 0
    with open(args.flows, "rb") as f:
        for flow in mio.FlowReader(f).stream():
            if not isinstance(flow, HTTPFlow):
                continue
            url = flow.request.pretty_url
            if args.host and args.host not in flow.request.pretty_host:
                continue

            # 导出静态资源
            if args.dump and flow.response and flow.response.raw_content:
                name = url.split("?")[0].rstrip("/").split("/")[-1] or "index.html"
                with open(os.path.join(args.dump, name), "wb") as g:
                    g.write(flow.response.raw_content)

            body = flow.request.get_text(strict=False) or ""
            if "param=" not in body and "data=" not in body:
                continue

            n += 1
            print("=" * 90)
            print("%s %s" % (flow.request.method, url.split("?")[0]))

            for key in ("param", "data"):
                q = urllib.parse.parse_qs(body)
                val = q.get(key, [""])[0]
                if not val:
                    continue
                try:
                    print("  [%s] -> %s" % (key, dec(val)))
                except Exception as e:
                    print("  [%s] 解密失败: %s" % (key, e))

            if flow.response:
                try:
                    j = flow.response.json()
                    if isinstance(j, dict) and j.get("resultdata"):
                        print("  [resp] -> %s" % dec(j["resultdata"])[:600])
                    elif isinstance(j, dict) and j.get("body"):
                        print("  [resp] -> %s" % j["body"][:600])
                except Exception:
                    pass

    print("\n共处理 %d 个加密请求" % n)


if __name__ == "__main__":
    main()
