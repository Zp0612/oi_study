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


# ============================================
#  README 自动更新函数
# ============================================

# ---- 提取 README 元数据 ----
extract_meta() {
    local readme="$1"
    local key="$2"
    case "$key" in
        title)
            head -1 "$readme" | sed 's/^# *//' | xargs
            ;;
        source)
            sed -n 's/^- *来源：//p; s/^- *来源://p' "$readme" | head -1 | xargs
            ;;
        algo)
            sed -n 's/^- *算法：//p; s/^- *算法://p' "$readme" | head -1 | xargs
            ;;
        diff)
            sed -n 's/^- *难度：//p; s/^- *难度://p' "$readme" | head -1 | xargs
            ;;
        date)
            sed -n 's/^- *日期：//p; s/^- *日期://p' "$readme" | head -1 | xargs
            ;;
    esac
}

# ---- 推断来源名 ----
infer_source() {
    local rel="${1#problems/}"
    local src="${rel%%/*}"
    case "$src" in
        leetcode) echo "LeetCode" ;;
        luogu)    echo "洛谷" ;;
        poj)      echo "POJ" ;;
        other)    echo "其他" ;;
        *)        echo "$src" ;;
    esac
}

# ---- 推断难度 ----
infer_difficulty() {
    local rel="${1#problems/}"
    case "$rel" in
        */easy/*)   echo "Easy" ;;
        */medium/*) echo "Medium" ;;
        */hard/*)   echo "Hard" ;;
        *)          echo "-" ;;
    esac
}

# ---- 获取题目首次提交日期 ----
get_problem_date() {
    local dir="$1"
    git log --diff-filter=A --follow --format=%as -- "$dir" 2>/dev/null | tail -1
}

# ---- 判断是否是题目目录（有代码文件或没有子目录） ----
is_problem_dir() {
    local dir="$1"
    # 目录下有没有 .cpp .py .java .c（非 README 非 gitkeep）？
    local code_count
    code_count=$(find "$dir" -maxdepth 1 -type f \
        ! -name "README.md" ! -name ".gitkeep" 2>/dev/null | wc -l)
    [ "$code_count" -gt 0 ] && return 0
    # 没有子目录 → 也是题目目录（可能还没写代码，只有 README）
    local subdir_count
    subdir_count=$(find "$dir" -maxdepth 1 -type d ! -path "$dir" 2>/dev/null | wc -l)
    [ "$subdir_count" -eq 0 ] && return 0
    return 1
}

# ---- 列出所有题目 README ----
find_problem_readmes() {
    find problems -name "README.md" | sort | while IFS= read -r readme; do
        local dir
        dir=$(dirname "$readme")
        is_problem_dir "$dir" && echo "$readme"
    done
}

# ---- 生成目录树 ----
generate_dir_tree() {
    echo "## 目录结构"
    echo ""
    echo '```'

    # ---- templates ----
    local tcount=0
    local tfiles=()
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        tfiles+=("$f")
    done < <(find templates -type f ! -name ".gitkeep" | sort)
    tcount=${#tfiles[@]}

    if [ "$tcount" -gt 0 ]; then
        echo "├── templates/               # 算法模板（$tcount 个）"
        for f in "${tfiles[@]}"; do
            echo "│   └── $(basename "$f")"
        done
    else
        echo "├── templates/               # 算法模板"
    fi

    # ---- problems ----
    local ptotal=0
    while IFS= read -r readme; do
        [ -n "$readme" ] && ((ptotal++))
    done < <(find_problem_readmes)

    echo "├── problems/                # 刷题记录（$ptotal 题）"

    for src_dir in problems/*/; do
        [ ! -d "$src_dir" ] && continue
        local src_name
        src_name=$(basename "$src_dir")
        local src_label=""
        case "$src_name" in
            leetcode) src_label="力扣" ;;
            luogu)    src_label="洛谷" ;;
            poj)      src_label="POJ" ;;
            other)    src_label="其他" ;;
        esac

        # 统计该来源下题目数
        local scount=0
        while IFS= read -r readme; do
            [ -n "$readme" ] && ((scount++))
        done < <(find_problem_readmes | grep "^$src_dir")

        if [ "$scount" -gt 0 ]; then
            echo "│   ├── $src_name/            #   $src_label（$scount 题）"
        else
            echo "│   ├── $src_name/            #   $src_label（0 题）"
        fi

        # 列出该来源下的子目录结构（难度分级等，最多列两级）
        find "$src_dir" -mindepth 1 -maxdepth 2 -type d ! -name ".*" 2>/dev/null | sort | while IFS= read -r sub; do
            local depth
            depth=$(echo "${sub#$src_dir}" | tr -cd '/' | wc -c)
            local indent="│   │   "
            [ "$depth" -eq 1 ] && indent="│   │   "
            [ "$depth" -eq 2 ] && indent="│   │       "
            local sname
            sname=$(basename "$sub")
            # 只显示非叶子目录（分类目录），叶子是题目目录，由表格展示即可
            local has_sub
            has_sub=$(find "$sub" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | head -1)
            if [ -n "$has_sub" ]; then
                echo "${indent}├── $sname/"
            fi
        done
    done

    # ---- notes ----
    local ncount=0
    while IFS= read -r f; do
        [ -z "$f" ] && continue
        [ "$(basename "$f")" = ".gitkeep" ] && continue
        ((ncount++))
    done < <(find notes -type f | sort)
    if [ "$ncount" -gt 0 ]; then
        echo "├── notes/                   # 学习笔记（$ncount 篇）"
    else
        echo "├── notes/                   # 学习笔记"
    fi

    echo "└── README.md"
    echo '```'
}

# ---- 生成刷题记录表格 ----
generate_problems_table() {
    echo "## 刷题记录"
    echo ""
    echo "| # | 题目 | 来源 | 难度 | 算法 | 日期 |"
    echo "|---|------|------|------|------|------|"

    local count=0
    while IFS= read -r readme; do
        [ -z "$readme" ] && continue
        local dir
        dir=$(dirname "$readme")

        local title src algo diff date
        title=$(extract_meta "$readme" title)
        src=$(extract_meta "$readme" source)
        algo=$(extract_meta "$readme" algo)
        diff=$(extract_meta "$readme" diff)
        date=$(extract_meta "$readme" date)

        # 回退：从目录结构推断
        [ -z "$title" ] && title=$(get_problem_name "$dir" "$(basename "$dir")")
        [ -z "$src" ]   && src=$(infer_source "$dir")
        [ -z "$diff" ]  && diff=$(infer_difficulty "$dir")
        [ -z "$algo" ]  && algo="-"
        [ -z "$date" ]  && date=$(get_problem_date "$dir")
        [ -z "$date" ]  && date="-"

        ((count++))
        echo "| $count | $title | $src | $diff | $algo | $date |"
    done < <(find_problem_readmes)

    if [ "$count" -eq 0 ]; then
        echo "| - | 暂无刷题记录 | - | - | - | - |"
    else
        echo ""
        echo "已完成：$count 题"
    fi
}

# ---- 生成模板表格 ----
generate_templates_table() {
    echo "## 算法模板"
    echo ""
    echo "| 模板 | 文件 | 说明 |"
    echo "|------|------|------|"

    local count=0
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        [ "$(basename "$file")" = ".gitkeep" ] && continue

        local name desc
        if head -5 "$file" | grep -q '/\*\*'; then
            # 从文件头部 `/** ... */` 注释块中提取
            #   第一行 → 模板名称（如 "桶排序 (Bucket Sort)"）
            #   第二行 → 说明（如 "思路：..."）
            local comment_body
            comment_body=$(sed -n '/\/\*\*/,/\*\//p' "$file" \
                | grep -v '/\*\*' | grep -v '\*/' \
                | sed 's/^[[:space:]]*\*[[:space:]]*//' \
                | grep -v '^$')
            name=$(echo "$comment_body" | head -1 | xargs)
            desc=$(echo "$comment_body" | head -2 | tail -1 | xargs)
        fi
        [ -z "$name" ] && name=$(basename "$file" | sed 's/\.[^.]*$//')
        [ -z "$desc" ] && desc="-"

        ((count++))
        echo "| $name | \`$file\` | $desc |"
    done < <(find templates -type f | sort)

    if [ "$count" -eq 0 ]; then
        echo "| - | - | 暂无模板 |"
    fi
}

# ---- 更新 README.md ----
update_readme() {
    local start_line end_line
    start_line=$(grep -n '<!-- AUTO_GEN_START -->' README.md | cut -d: -f1)
    end_line=$(grep -n '<!-- AUTO_GEN_END -->' README.md | cut -d: -f1)

    if [ -z "$start_line" ] || [ -z "$end_line" ]; then
        echo -e "${RED}❌ README.md 缺少 AUTO_GEN 标记，跳过自动更新${NC}" >&2
        return 1
    fi

    local tmp_auto tmp_readme
    tmp_auto=$(mktemp)
    tmp_readme=$(mktemp)

    # 生成自动内容到临时文件
    {
        generate_dir_tree
        echo ""
        generate_problems_table
        echo ""
        generate_templates_table
    } > "$tmp_auto"

    # 拼装：标记前的内容 + 自动生成内容 + 标记后的内容
    head -n "$start_line" README.md > "$tmp_readme"
    cat "$tmp_auto" >> "$tmp_readme"
    tail -n +"$end_line" README.md >> "$tmp_readme"

    if ! diff -q README.md "$tmp_readme" > /dev/null 2>&1; then
        if $DRY_RUN; then
            echo -e "  ${CYAN}[预览] README.md 差异：${NC}"
            diff --color=auto README.md "$tmp_readme" 2>/dev/null || diff README.md "$tmp_readme" || true
            echo ""
        else
            mv "$tmp_readme" README.md
        fi
        rm -f "$tmp_auto" "$tmp_readme"
        return 0  # 有更新
    else
        rm -f "$tmp_readme" "$tmp_auto"
        return 1  # 无变化
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
    ((++commit_count))
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
    ((++commit_count))
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
    ((++commit_count))
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
    ((++commit_count))
fi

if [ ${#unknown_files[@]} -gt 0 ]; then
    echo -e "${RED}⚠️  以下文件未被识别，跳过上传：${NC}"
    for f in "${unknown_files[@]}"; do
        echo -e "${RED}      $f${NC}"
    done
    echo -e "${RED}   （如需上传，请放入 problems/ templates/ 或 notes/ 目录）${NC}"
    echo ""
fi

# ---- 9. 自动更新 README 索引 ----
if update_readme; then
    if $DRY_RUN; then
        echo -e "  ${CYAN}[预览]${NC} chore: 更新 README 索引"
    else
        echo -e "${YELLOW}📝 更新 README 索引${NC}"
        git add README.md
        git commit -m "chore: 更新 README 索引"
    fi
    ((++commit_count))
fi

# ---- 10. 推送 ----
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
