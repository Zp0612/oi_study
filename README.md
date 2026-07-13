# OI 算法学习

我的算法与数据结构学习记录。

<!-- AUTO_GEN_START -->
## 目录结构

```
├── templates/               # 算法模板（1 个）
│   └── bucket_sort.cpp
├── problems/                # 刷题记录（5 题）
│   ├── leetcode/            #   力扣（1 题）
│   │   ├── easy/
│   ├── luogu/            #   洛谷（3 题）
│   │   ├── easy/
│   │   ├── popularize/
│   ├── other/            #   其他（0 题）
│   ├── poj/            #   POJ（1 题）
├── notes/                   # 学习笔记
└── README.md
```

## 刷题记录

| # | 题目 | 来源 | 难度 | 算法 | 日期 |
|---|------|------|------|------|------|
| 1 | 1、两数之和 | LeetCode | Easy | - | 2026-07-08 |
| 2 | B2087 与指定数字相同数个数 | 洛谷 | 入门 | 模拟 | 2026-07-09 |
| 3 | B2105 矩阵乘法 | 洛谷 | 普及− | 模拟 | 2026-07-09 |
| 4 | #B2615-神奇幻方 | 洛谷 | 普及− | - | - |
| 5 | 1222 - 熄灯问题 (Extended Lights Out) | POJ / 百练 | ★★☆ | 位运算枚举 | 2026-07-08 |

已完成：5 题

## 算法模板

| 模板 | 文件 | 说明 |
|------|------|------|
| 桶排序 (Bucket Sort) | `templates/bucket_sort.cpp` | 思路：将元素按值域范围分配到多个桶中，每个桶内部排序，再合并。 |
<!-- AUTO_GEN_END -->

## Commit 规范

```
solve: <来源> <题号> <题名>      # 做新题
improve: <题号> <改进点>         # 优化解法
add-solution: <题号> <方法>      # 补不同解法
template: <算法名>               # 添加/更新模板
note: <内容>                     # 学习笔记
```

**示例：**

```bash
git commit -m "solve: luogu P1001 A+B Problem"
git commit -m "solve: leetcode 0001 两数之和"
git commit -m "improve: leetcode 0001 优化为一遍哈希"
git commit -m "template: 快速排序"
```

## 日常流程

```bash
cd d:/lzp/oi_study
git add .
git commit -m "solve: <来源> <题号> <题名>"
git push
```

**每次只提交一道题**，保持历史干净可查。
