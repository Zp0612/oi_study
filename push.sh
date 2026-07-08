#!/bin/bash
# ============================================
#  OI 刷题自动上传脚本  v2
#  用法：
#    ./push.sh              直接提交+推送
#    ./push.sh --dry-run    仅预览，不实际操作
#    ./push.sh --help       查看帮助
# ============================================
set -eo pipefail
cd "$(dirname "$0")"

# ---- 颜色 ----
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

# ---- 参数解析 ----
DRY_RUN=false
case "${1:-}" in
    --dry-run|-n) DRY_RUN=true ;;
    --help|-h)
        echo "用法: ./push.sh [--dry-run]"
        echo ""
        echo "  (无参数)     自动识别改动 → 生成规范 commit → 推送"
        echo "  --dry-run    仅预览，不提交也不推送"
        exit 0
        ;;
esac

echo ""
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    OI 刷题 · 自动上传             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo ""

$DRY_RUN && echo -e "${YELLOW}⚠️  DRY-RUN 模式：仅预览，不会实际提交${NC}" && echo ""

# ---- 1. 检查未推送的提交 ----
unpushed=0
if git rev-parse --abbrev-ref @{u} &>/dev/null; then
    unpushed=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
fi
if [ "$unpushed" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  发现 $unpushed 个本地未推送的提交（上次可能推送失败），将一并推送${NC}"
    echo ""
fi

# ---- 2. 检查是否有未提交的改动 ----
if git diff-index --quiet HEAD -- 2>/dev/null && \
   [ -z "$(git ls-files --others --exclude-standard)" ]; then
    if [ "$unpushed" -eq 0 ]; then
        echo -e "${GREEN}✅ 没有改动，无需提交${NC}"
    else
        echo -e "${YELLOW}📤 没有新改动，但还有 $unpushed 个提交未推送，直接推送...${NC}"
        if ! $DRY_RUN; then
            git push
            echo -e "${GREEN}✅ 推送完成${NC}"
        fi
    fi
    echo ""
    read -p "按任意键退出..."
    exit 0
fi

echo -e "${YELLOW}🔍 正在分析改动...${NC}"
echo ""

# ---- 3. 收集改动文件，按类型分组 ----
declare -A problem_dirs   # key=问题目录路径
declare -a template_files
declare -a note_files
declare -a other_files

while IFS= read -r line; do
    [ -z "$line" ] && continue

    # 提取文件路径（处理重命名 "old -> new"）
    file=$(echo "$line" | cut -c4-)
    if [[ "$file" == *" -> "* ]]; then
        file="${file##* -> }"
    fi

    # 分类：用 dirname 提取问题目录，支持任意深度
    if [[ "$file" == problems/*/* ]]; then
        # 文件所在目录即为题目目录
        prob_dir=$(dirname "$file")
        problem_dirs["$prob_dir"]=1
    elif [[ "$file" == templates/* ]] && [[ "$file" != templates/.gitkeep ]]; then
        template_files+=("$file")
    elif [[ "$file" == notes/* ]] && [[ "$file" != notes/.gitkeep ]]; then
        note_files+=("$file")
    elif [[ "$file" != .gitkeep ]] && [[ "$file" != */.gitkeep ]]; then
        other_files+=("$file")
    fi
done < <(git status --porcelain)

# ---- 4. 提取题名的通用函数 ----
get_problem_name() {
    local readme="$1/README.md"
    local fallback="$2"
    if [ -f "$readme" ]; then
        # 解析 README 第一行：
        #   去掉 # 前缀 → 去掉中文括号内容 → 去掉英文括号内容 → 去掉题号 → trim
        head -1 "$readme" \
            | sed 's/^# *//' \
            | sed 's/（[^）]*）//g' \
            | sed 's/([^)]*)//g' \
            | sed 's/^[0-9]*[ .\-]*//' \
            | xargs
    else
        echo "$fallback"
    fi
}

# ---- 5. 每个问题一个 commit（按路径排序） ----
commit_count=0
sorted_dirs=($(printf '%s\n' "${!problem_dirs[@]}" | sort))

for dir in "${sorted_dirs[@]}"; do
    # 提取来源名：problems 之后的第一段
    #   problems/poj/1222-lights-out      → poj
    #   problems/leetcode/easy/0001-two   → leetcode
    rel="${dir#problems/}"
    source_name="${rel%%/*}"
    problem_dir=$(basename "$dir")

    # 提取题号
    problem_id=$(echo "$problem_dir" | grep -oP '^\d+' || echo "$problem_dir")

    # 提取题名
    problem_name=$(get_problem_name "$dir" "$problem_dir")

    message="solve: $source_name $problem_id $problem_name"

    if $DRY_RUN; then
        echo -e "  ${CYAN}[预览]${NC} $message"
    else
        echo -e "${YELLOW}📝 题目：$message${NC}"
        git add "$dir"

        # 连带处理：如果本题目录的父级有 .gitkeep 被删除，一并加入
        parent="$dir"
        while [[ "$parent" == problems/*/* ]]; do
            parent=$(dirname "$parent")
            gk="$parent/.gitkeep"
            if git status --porcelain "$gk" 2>/dev/null | grep -q '^[ D]'; then
                git add "$gk" 2>/dev/null || true
            fi
        done

        git commit -m "$message"
    fi
    ((commit_count++))
done

# ---- 6. 模板单独 commit ----
if [ ${#template_files[@]} -gt 0 ]; then
    names=""
    for f in "${template_files[@]}"; do
        base=$(basename "$f" .cpp)
        [ -n "$names" ] && names="$names, $base" || names="$base"
    done
    if $DRY_RUN; then
        echo -e "  ${CYAN}[预览]${NC} template: $names"
    else
        echo -e "${YELLOW}📝 模板：$names${NC}"
        git add "${template_files[@]}"
        git commit -m "template: $names"
    fi
    ((commit_count++))
fi

# ---- 7. 笔记单独 commit ----
if [ ${#note_files[@]} -gt 0 ]; then
    if $DRY_RUN; then
        echo -e "  ${CYAN}[预览]${NC} note: 更新学习笔记"
    else
        echo -e "${YELLOW}📝 笔记${NC}"
        git add "${note_files[@]}"
        git commit -m "note: 更新学习笔记"
    fi
    ((commit_count++))
fi

# ---- 8. 兜底：仅提交已知项目文件，未知文件跳过并警告 ----
# 白名单：根目录下允许自动提交的文件
SAFE_FILES=("README.md" "push.sh" ".gitignore")

remaining=$(git status --porcelain 2>/dev/null | grep -v '^$' || true)
safe_to_commit=()
unknown_files=()

while IFS= read -r line; do
    [ -z "$line" ] && continue
    f=$(echo "$line" | cut -c4-)
    [[ "$f" == *" -> "* ]] && f="${f##* -> }"

    # 检查文件是否属于已处理的问题/模板/笔记目录
    already_handled=false
    if [ ${#sorted_dirs[@]} -gt 0 ]; then
        for d in "${sorted_dirs[@]}"; do
            [[ "$f" == "$d"* ]] && already_handled=true && break
        done
    fi
    $already_handled && continue

    # 检查是否在白名单
    is_safe=false
    for sf in "${SAFE_FILES[@]}"; do
        [[ "$f" == "$sf" ]] && is_safe=true && break
    done

    if $is_safe; then
        safe_to_commit+=("$f")
    else
        unknown_files+=("$f")
    fi
done <<< "$remaining"

if [ ${#safe_to_commit[@]} -gt 0 ]; then
    if $DRY_RUN; then
        echo -e "  ${CYAN}[预览]${NC} chore: ${safe_to_commit[*]}"
    else
        echo -e "${YELLOW}📝 项目文件：${safe_to_commit[*]}${NC}"
        git add "${safe_to_commit[@]}"
        git commit -m "chore: 更新项目文件"
    fi
    ((commit_count++))
fi

if [ ${#unknown_files[@]} -gt 0 ]; then
    echo -e "${RED}⚠️  以下文件未被识别，跳过上传：${NC}"
    for f in "${unknown_files[@]}"; do
        echo -e "${RED}      $f${NC}"
    done
    echo -e "${RED}   （如需上传，请放入 problems/ templates/ 或 notes/ 目录）${NC}"
    echo ""
fi

# ---- 9. 推送 ----
echo ""
if $DRY_RUN; then
    echo -e "${CYAN}📋 以上为预览，未实际提交。去掉 --dry-run 即可正式运行。${NC}"
else
    echo -e "${CYAN}🚀 正在推送到 GitHub...${NC}"
    git push

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║   ✅ 全部完成！共推送 $commit_count 个提交  ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════╝${NC}"
fi
echo ""
read -p "按任意键退出..."
