#!/bin/bash
# ============================================
#  OI 刷题自动上传脚本
#  用法：双击运行 或 bash push.sh
#  自动识别改动 → 规范 commit → 推送 GitHub
# ============================================
set -e
cd "$(dirname "$0")"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${CYAN}╔════════════════════════════════════╗${NC}"
echo -e "${CYAN}║    OI 刷题 · 自动上传             ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════╝${NC}"
echo ""

# ---- 1. 检查是否有改动 ----
if git diff-index --quiet HEAD -- 2>/dev/null && \
   [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo -e "${GREEN}✅ 没有改动，无需提交${NC}"
    echo ""
    read -p "按任意键退出..."
    exit 0
fi

echo -e "${YELLOW}🔍 正在分析改动...${NC}"
echo ""

# ---- 2. 收集改动文件，按类型分组 ----
declare -A problem_dirs
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

    # 分类
    if [[ "$file" == problems/*/*/* ]]; then
        # problems/<来源>/<题目>/<文件>
        dir=$(echo "$file" | cut -d'/' -f1-3)
        problem_dirs["$dir"]=1
    elif [[ "$file" == templates/* ]] && [[ "$file" != templates/.gitkeep ]]; then
        template_files+=("$file")
    elif [[ "$file" == notes/* ]] && [[ "$file" != notes/.gitkeep ]]; then
        note_files+=("$file")
    elif [[ "$file" != .gitkeep ]] && [[ "$file" != *.gitkeep ]]; then
        other_files+=("$file")
    fi
done < <(git status --porcelain)

commit_count=0

# ---- 3. 每道题一个 commit ----
for dir in "${!problem_dirs[@]}"; do
    source_name=$(echo "$dir" | cut -d'/' -f2)
    problem_dir=$(echo "$dir" | cut -d'/' -f3)

    # 提取题号（纯数字部分）
    problem_id=$(echo "$problem_dir" | grep -oP '^\d+' || echo "$problem_dir")

    # 尝试从 README.md 读题名
    problem_name=""
    readme_path="$dir/README.md"
    if [ -f "$readme_path" ]; then
        # 解析 README 第一行：去掉 # 前缀、英文括号、题号
        problem_name=$(head -1 "$readme_path" \
            | sed 's/^# *//' \
            | sed 's/ *([^)]*)$//' \
            | sed 's/^[0-9]*[ .\-]*//' \
            | xargs)
    fi
    [ -z "$problem_name" ] && problem_name="$problem_dir"

    message="solve: $source_name $problem_id $problem_name"
    echo -e "${YELLOW}📝 题目：$message${NC}"
    git add "$dir"
    git commit -m "$message"
    ((commit_count++))
done

# ---- 4. 模板单独 commit ----
if [ ${#template_files[@]} -gt 0 ]; then
    names=""
    for f in "${template_files[@]}"; do
        base=$(basename "$f" .cpp)
        [ -n "$names" ] && names="$names, $base" || names="$base"
    done
    echo -e "${YELLOW}📝 模板：$names${NC}"
    git add "${template_files[@]}"
    git commit -m "template: $names"
    ((commit_count++))
fi

# ---- 5. 笔记单独 commit ----
if [ ${#note_files[@]} -gt 0 ]; then
    echo -e "${YELLOW}📝 笔记${NC}"
    git add "${note_files[@]}"
    git commit -m "note: 更新学习笔记"
    ((commit_count++))
fi

# ---- 6. 其他文件合并 commit ----
if [ ${#other_files[@]} -gt 0 ]; then
    echo -e "${YELLOW}📝 其他改动${NC}"
    git add "${other_files[@]}"
    git commit -m "chore: 更新项目文件"
    ((commit_count++))
fi

# ---- 7. 推送 ----
echo ""
echo -e "${CYAN}🚀 正在推送到 GitHub...${NC}"
git push

# ---- 8. 完成 ----
echo ""
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ✅ 全部完成！共推送 $commit_count 个提交  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════╝${NC}"
echo ""
read -p "按任意键退出..."
