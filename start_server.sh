#!/bin/bash
# ================================================
#  C# 课件局域网服务 - macOS / Linux 版
#  用法：终端里执行  ./start_server.sh
#  首次使用需授权：chmod +x start_server.sh
# ================================================
cd "$(dirname "$0")"

PY=$(command -v python3 || command -v python)
if [ -z "$PY" ]; then
    echo "未找到 Python，请先安装 Python3"
    read -p "按回车退出"
    exit 1
fi

IP=$(ipconfig getifaddr en0 2>/dev/null || ip -4 addr show 2>/dev/null | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '^127\.' | head -1)
[ -z "$IP" ] && IP="127.0.0.1"

echo "================================================"
echo "   C# 课件 - 局域网访问服务"
echo "   本机 IP:   $IP"
echo "   学生访问:  http://$IP:8000/"
echo "   本机测试:  http://127.0.0.1:8000/"
echo "   （Ctrl+C 停止服务）"
echo "================================================"
echo ""

# 自动打开浏览器
(sleep 1; open "http://127.0.0.1:8000/" 2>/dev/null) &

"$PY" -m http.server 8000 --bind 0.0.0.0
