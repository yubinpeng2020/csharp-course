#!/bin/bash
# ============================================================
#  双击这个文件 → 把 C# 网页课件拷到 U 盘
#  目标：/Volumes/NO NAME/2026程序设计基础C#/csharp-course
#  只拷「运行要用」的东西（网页 + 图片 + vendor），不拷 .git / 备份 / py 脚本
# ============================================================
cd "$(dirname "$0")" || exit 1
SRC="$(pwd)"

# ★ 固定目标
FIXED_DEST="/Volumes/NO NAME/2026程序设计基础C#/csharp-course"

clear
echo "=================================================="
echo "   C# 课件打包到 U 盘"
echo "   来源：$SRC"
echo "=================================================="
echo ""

# ---------- 0) 基本检查 ----------
if [ ! -f index.html ]; then
    echo "❌ 当前位置不像课件目录（找不到 index.html）：$SRC"
    read -n 1 -s -r -p "按任意键关闭…"; exit 1
fi

# ---------- 1) 定目标 ----------
DEST=""
if [ -n "$1" ]; then
    DEST="$1"                                  # 命令行给完整目标（测试用）
elif [ -n "$PACK_TARGET" ]; then
    DEST="$PACK_TARGET"
elif [ -d "/Volumes/NO NAME" ]; then           # 固定 U 盘在
    DEST="$FIXED_DEST"
    echo "目标（固定）：$DEST"
else
    echo "没找到 /Volumes/NO NAME，改成自动找盘…"
    CAND=""; N=0
    for v in /Volumes/*; do
        [ -d "$v" ] || continue
        name="$(basename "$v")"
        [ "$name" = "Macintosh HD" ] && continue
        [ -w "$v" ] || continue
        CAND="$v"; N=$((N+1))
    done
    if [ "$N" -eq 1 ]; then
        DEST="$CAND/2026程序设计基础C#/csharp-course"
        echo "检测到可移动磁盘：$CAND"
        printf "就拷到 %s ？[Y/n] " "$DEST"
        read -r ans
        case "$ans" in n|N) DEST="" ;; esac
    fi
    if [ -z "$DEST" ]; then
        echo "请在弹出的窗口里选择 U 盘…"
        PICK="$(osascript -e 'POSIX path of (choose folder with prompt "选择 U 盘")' 2>/dev/null)"
        PICK="${PICK%/}"
        [ -n "$PICK" ] && DEST="$PICK/2026程序设计基础C#/csharp-course"
    fi
    if [ -z "$DEST" ]; then
        echo ""
        echo "没有选中目标，已取消。"
        read -n 1 -s -r -p "按任意键关闭…"; exit 1
    fi
fi

DEST="${DEST%/}"
DEST_ROOT="$(dirname "$DEST")"
FOLDER="$(basename "$DEST")"

if [ -d "$DEST" ] && [ -n "$(ls -A "$DEST" 2>/dev/null)" ]; then
    echo ""
    echo "注意：$DEST 里已有内容，本次会覆盖同名文件（不删除 U 盘上多出来的旧文件）。"
    printf "继续？[Y/n] "
    read -r ans
    case "$ans" in n|N) echo "已取消。"; read -n 1 -s -r -p "按任意键关闭…"; exit 1 ;; esac
fi
mkdir -p "$DEST" || { echo "❌ 建目录失败：$DEST"; read -n 1 -s -r -p "按任意键关闭…"; exit 1; }

# 空间检查（源体积 ×2 余量）
need_kb=$(du -sk images vendor 2>/dev/null | awk '{s+=$1} END{print s+5000}')
avail_kb=$(df -k "$DEST" | awk 'NR==2{print $4}')
if [ -n "$avail_kb" ] && [ "$avail_kb" -lt "$need_kb" ]; then
    echo ""
    echo "⚠️  U 盘剩余空间不足：需要约 $((need_kb/1024)) MB，只剩 $((avail_kb/1024)) MB"
    printf "仍然继续？[y/N] "; read -r ans
    case "$ans" in y|Y) ;; *) echo "已取消。"; read -n 1 -s -r -p "按任意键关闭…"; exit 1 ;; esac
fi

echo ""
echo "正在拷贝到：$DEST"
echo ""

# ---------- 2) HTML ----------
# rsync 增量：没改的秒过，改过的覆盖
cnt=0; skip=0
if command -v rsync >/dev/null 2>&1; then
    for f in 课件*.html index.html knowledge_graph.html; do
        case "$(basename "$f")" in _bak_*|_tmp_*) continue ;; esac
        [ -f "$f" ] || continue
        if rsync -a --update "$f" "$DEST/$f" 2>/dev/null; then
            cnt=$((cnt+1))
        else
            cp -p "$f" "$DEST/" && cnt=$((cnt+1))
        fi
    done
else
    for f in 课件*.html index.html knowledge_graph.html; do
        case "$(basename "$f")" in _bak_*|_tmp_*) continue ;; esac
        [ -f "$f" ] && cp -p "$f" "$DEST/" && cnt=$((cnt+1))
    done
fi
echo "  网页 $cnt 个"

# ---------- 3) 站点图标 ----------
ico=0
for f in favicon.ico favicon.svg apple-touch-icon.png; do
    [ -f "$f" ] && cp -p "$f" "$DEST/" && ico=$((ico+1))
done
echo "  站点图标 $ico 个"

# ---------- 4) 图片与依赖 ----------
if command -v rsync >/dev/null 2>&1; then
    rsync -a --exclude='.DS_Store' images/ "$DEST/images/"
    rsync -a --exclude='.DS_Store' vendor/ "$DEST/vendor/"
else
    cp -R images "$DEST/" 2>/dev/null
    cp -R vendor "$DEST/" 2>/dev/null
    find "$DEST" -name '.DS_Store' -delete 2>/dev/null
fi
echo "  图片与依赖已拷完"

# ---------- 5) Windows 教室机服务脚本 ----------
srv=0
for f in server.ps1 start_server.bat 启动课件服务.bat; do
    if [ -f "$f" ]; then cp -p "$f" "$DEST/" && srv=$((srv+1)); fi
done
echo "  服务器脚本 $srv 个"

echo ""
echo "--------------------------------------------------"
printf "完成。合计 %s\n" "$(du -sh "$DEST" | awk '{print $1}')"
echo "U 盘上的位置：$DEST"
echo "--------------------------------------------------"

# ---------- 6) U 盘根目录放一键启动器 ----------
if [ -w "$DEST_ROOT" ] && [ "$srv" -gt 0 ]; then
    LAUNCHER="$DEST_ROOT/启动课件.bat"
    printf '@echo off\r\ncd /d "%%~dp0%s"\r\ncall "启动课件服务.bat"\r\n' "$FOLDER" > /tmp/_launcher_utf8.bat
    if command -v iconv >/dev/null 2>&1; then
        iconv -f UTF-8 -t GBK /tmp/_launcher_utf8.bat > "$LAUNCHER" 2>/dev/null
    fi
    if [ -s "$LAUNCHER" ]; then
        echo "U 盘根目录已放「启动课件.bat」——插上后双击它就行"
    fi
    rm -f /tmp/_launcher_utf8.bat
fi

# ---------- 7) 自检：页面引用了但没拷到的图片 ----------
miss=0
if command -v python3 >/dev/null 2>&1; then
    miss=$(cd "$DEST" && python3 - <<'PY' 2>/dev/null
import glob, os, re, urllib.parse, unicodedata
N = lambda s: unicodedata.normalize('NFC', s)
ref = set()
for f in glob.glob('*.html'):
    s = open(f, encoding='utf-8', errors='ignore').read()
    for m in re.finditer(r'(?:src|href)="((?:images|vendor)/[^"]+)"', s):
        ref.add(N(urllib.parse.unquote(m.group(1)).split('?')[0]))
have = {N(os.path.relpath(os.path.join(r, f), '.').replace('\\', '/'))
        for r, _, fs in os.walk('.') for f in fs}
miss = [p for p in ref if p not in have]
print(len(miss))
if miss:
    for p in sorted(miss)[:5]:
        print('   缺：' + p, file=__import__('sys').stderr)
PY
)
    echo "自检：页面引用但没拷到的图片 $miss 张（多为还没拍的缺图占位，属正常）"
fi

echo ""
echo "教室电脑（Windows）上：插 U 盘 → 双击根目录「启动课件.bat」"
echo "学生用浏览器访问窗口里显示的 http://IP:8000/"
echo "--------------------------------------------------"

[ -z "$1" ] && open "$DEST" 2>/dev/null
echo ""
read -n 1 -s -r -p "按任意键关闭这个窗口…"
